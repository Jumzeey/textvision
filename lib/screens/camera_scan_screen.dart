import 'dart:ui' as ui;
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import '../services/hybrid_tts_service.dart';
import '../services/ocr_service.dart';
import '../services/image_preprocessing_service.dart';
import '../services/permission_service.dart';
import '../services/blind_reader_service.dart';
import '../services/gemini_vision_service.dart';

/// Camera scan screen for capturing document images
///
/// This screen provides a camera interface with:
/// - Live camera preview
/// - Capture button with haptic feedback
/// - Accessibility labels for screen readers
/// - Visual feedback for successful captures
/// - Auto-detection of printed vs handwritten text
/// - Real-time alignment guidance for blind users
class CameraScanScreen extends StatefulWidget {
  const CameraScanScreen({super.key});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  final CameraService _cameraService = CameraService();
  late final OCRService _ocrService;
  final HybridTTSService _ttsService = HybridTTSService();
  final ImagePreprocessingService _preprocessingService =
      ImagePreprocessingService();
  final PermissionService _permissionService = PermissionService();
  final BlindReaderService _blindReaderService = BlindReaderService();
  final GeminiVisionService _geminiService = GeminiVisionService();
  CameraController? _controller;
  bool _isInitialized = false;
  String? _errorMessage;
  bool _isMonitoringAlignment = false;
  Timer? _alignmentTimer;
  final List<XFile> _capturedImageFiles = [];
  bool _isCapturingImages = false;
  bool _isReading = false;
  bool _isProcessing = false;
  bool _isPaused = false;
  String _currentStatus = 'Initializing camera...';
  String _lastReadText = ''; // Store for repeat

  // Sentence-based navigation for blind users
  List<String> _sentences = [];
  int _currentSentenceIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// Initialize all services
  Future<void> _initializeServices() async {
    try {
      // Check and request camera permission first
      final hasPermission = await _permissionService.checkCameraPermission();

      if (!hasPermission) {
        // Request camera permission
        final permissionResult = await _permissionService
            .requestCameraPermissionWithStatus();
        final hasPermissions = permissionResult['granted'] ?? false;
        final isPermanentlyDenied =
            permissionResult['permanentlyDenied'] ?? false;

        if (!hasPermissions) {
          if (mounted) {
            if (isPermanentlyDenied) {
              // Show dialog to go to settings
              _showPermissionDeniedDialog();
            } else {
              setState(() {
                _errorMessage =
                    'Camera permission is required to scan documents. '
                    'Please allow camera access when prompted.';
              });
            }
          }
          return;
        }
      }

      // Initialize OCR service (will auto-detect handwriting during processing)
      _ocrService = OCRService();

      // Initialize camera first (critical for app functionality)
      await _initializeCamera();

      // Initialize TTS in background AFTER camera is ready (non-blocking)
      // This prevents TTS initialization issues from blocking app startup
      // Use a longer delay to ensure app is fully started before attempting TTS
      Future.delayed(const Duration(seconds: 2), () async {
        try {
          debugPrint('Starting TTS initialization in background...');
          final ttsInitialized = await _ttsService.initialize();
          if (!ttsInitialized) {
            debugPrint(
              'TTS initialization failed - app will continue without TTS',
            );
            if (mounted) {
              setState(() {
                if (_currentStatus.contains('ready')) {
                  _currentStatus =
                      'Camera ready. Note: Text-to-speech is not available.';
                }
              });
            }
          } else {
            debugPrint('TTS initialized successfully in background');
          }
        } catch (e, stackTrace) {
          debugPrint('TTS initialization error (non-blocking): $e');
          debugPrint('Stack trace: $stackTrace');
          // Don't update UI - app is already working
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          // Only show error if it's a critical service (camera), not TTS
          if (e.toString().contains('camera') ||
              e.toString().contains('permission')) {
            _errorMessage =
                'Failed to initialize services: $e\n\n${e.toString()}';
          } else {
            // Non-critical error (like TTS) - just log it
            debugPrint('Non-critical initialization error: $e');
            _currentStatus = 'Camera ready. Some features may be limited.';
          }
        });
      }
    }
  }

  /// Show dialog when permissions are permanently denied
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'TextVision needs camera access to scan documents. '
          'Please enable camera permission in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back/close app
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _permissionService.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Initialize the camera controller
  Future<void> _initializeCamera() async {
    try {
      await _cameraService.initializeCamera();
      if (mounted) {
        setState(() {
          _controller = _cameraService.controller;
          _isInitialized = true;
          _currentStatus =
              'Camera ready. Position the document in the frame. Tap anywhere on the screen to capture.';
        });

        // Test TTS immediately
        debugPrint('Testing TTS service...');
        try {
          await _ttsService.speak(
            'Camera is ready.',
            pauseAtPunctuation: false,
          );
          debugPrint('TTS test successful');
        } catch (e) {
          debugPrint('TTS test failed: $e');
        }

        // Start monitoring with FULL instructions on app launch
        _startAlignmentMonitoring(fullInstructions: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize camera: $e';
          _isInitialized = false;
        });
        await _ttsService.speak(
          'Failed to initialize camera. Please check permissions.',
          pauseAtPunctuation: false,
        );
      }
    }
  }

  /// Start monitoring document alignment
  /// Now provides simple guidance without continuous captures
  void _startAlignmentMonitoring({bool fullInstructions = false}) async {
    if (_isMonitoringAlignment || _controller == null) {
      debugPrint(
        'Alignment monitoring: Already monitoring or controller is null',
      );
      return;
    }

    debugPrint('Starting alignment monitoring (no continuous captures)...');
    _isMonitoringAlignment = true;

    // Speak instructions for blind users
    if (fullInstructions) {
      await _speakFullInstructions();
    } else {
      await _speakQuickReady();
    }
  }

  /// Speak full instructions for blind users (on first launch or swipe down)
  /// If reading was in progress, it will resume after instructions
  Future<void> _speakFullInstructions() async {
    // Save current reading state to resume after
    final wasReading = _isReading;
    final savedSentenceIndex = _currentSentenceIndex;
    final savedText = _lastReadText;

    // Pause current reading
    if (_isReading) {
      _isReading = false;
      _isPaused = false;
      await _ttsService.stop();
    }

    debugPrint('Speaking full instructions...');
    HapticFeedback.mediumImpact();

    const instructions = '''
Document scanner ready.
Here are the controls.
Tap to capture a document.
While reading, tap to pause or resume.
Double tap to stop, or repeat when finished.
Swipe left to go back a few sentences.
Swipe right to skip forward.
Long press anytime to start fresh.
Swipe down to hear these instructions again.
''';

    await _ttsService.speak(instructions, pauseAtPunctuation: true);
    debugPrint('Full instructions spoken');

    // Resume reading if it was in progress
    if (wasReading && savedText.isNotEmpty) {
      debugPrint('Resuming reading from sentence $savedSentenceIndex');
      await _ttsService.speak('Resuming.', pauseAtPunctuation: false);
      await Future.delayed(const Duration(milliseconds: 300));
      await _readTextAloud(savedText, startFrom: savedSentenceIndex);
    }
  }

  /// Speak quick ready message
  Future<void> _speakQuickReady() async {
    debugPrint('Speaking quick ready...');
    await _ttsService.speak(
      'Ready. Tap to capture.',
      pauseAtPunctuation: false,
    );
  }

  /// Stop monitoring document alignment
  void _stopAlignmentMonitoring() {
    _isMonitoringAlignment = false;
    _alignmentTimer?.cancel();
    _alignmentTimer = null;
  }

  /// Capture single image and process immediately
  ///
  /// OPTIMIZED FOR BLIND USERS:
  /// - Single capture (faster, more reliable)
  /// - Immediate processing
  /// - Haptic feedback for confirmation
  Future<void> _captureTwoImages() async {
    if (_isCapturingImages ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    // Stop any ongoing speech and alignment monitoring
    await _ttsService.stop();
    _stopAlignmentMonitoring();

    setState(() {
      _isCapturingImages = true;
      _capturedImageFiles.clear();
      _currentStatus = 'Capturing...';
    });

    // Immediate haptic feedback - user knows tap registered
    HapticFeedback.heavyImpact();

    // SPEAK: Let user know capture started
    await _ttsService.speak('Capturing.', pauseAtPunctuation: false);

    try {
      // Capture ONE image (faster and more reliable than multiple)
      final imageFile = await _controller!.takePicture();
      _capturedImageFiles.add(imageFile);

      // Confirmation haptic
      HapticFeedback.mediumImpact();

      if (mounted) {
        setState(() {
          _currentStatus = 'Reading...';
        });
      }

      // Process immediately - no delay
      await _processImagesAndDetectQuestions();

      // Resume monitoring when done
      if (mounted && _isInitialized) {
        _startAlignmentMonitoring();
      }
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        setState(() {
          _isCapturingImages = false;
          _currentStatus = 'Error. Tap to try again.';
        });
        _startAlignmentMonitoring();
      }
      await _ttsService.speak(
        'Error. Please try again.',
        pauseAtPunctuation: false,
      );
    }
  }

  /// Process captured images and read text aloud
  ///
  /// HYBRID APPROACH FOR BLIND USERS:
  /// - Online: Use Gemini Vision for superior text extraction
  /// - Offline: Fall back to ML Kit OCR
  /// - Single TTS call for smooth reading
  Future<void> _processImagesAndDetectQuestions() async {
    if (_capturedImageFiles.isEmpty) {
      if (mounted) {
        setState(() {
          _isCapturingImages = false;
          _currentStatus = 'No image captured.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isProcessing = true;
        _currentStatus = 'Processing...';
      });
    }

    try {
      final imageFile = _capturedImageFiles.first;
      String readableText = '';

      // Check for internet - use Gemini if available
      final hasInternet = await GeminiVisionService.isAvailable();

      if (hasInternet) {
        // ONLINE: Use Gemini Vision for best results
        debugPrint('Using Gemini Vision (online)');

        // SPEAK: Let user know we're analyzing
        await _ttsService.speak('Analyzing image.', pauseAtPunctuation: false);

        // Set up progress callback to update UI
        GeminiVisionService.onProgress = (status) {
          if (mounted) {
            setState(() {
              _currentStatus = status;
            });
          }
        };

        try {
          readableText = await _geminiService.processImage(
            File(imageFile.path),
          );
          debugPrint('Gemini extracted: ${readableText.length} chars');

          // Update status - text extracted, now generating audio
          if (mounted) {
            setState(() {
              _currentStatus = 'Text extracted. Generating audio...';
            });
          }

          // SPEAK: Let user know text was found
          await _ttsService.speak(
            'Text found. Preparing to read.',
            pauseAtPunctuation: false,
          );
        } catch (e) {
          debugPrint('Gemini failed, falling back to ML Kit: $e');
          if (mounted) {
            setState(() {
              _currentStatus = 'Using offline mode...';
            });
          }
          // Fall back to ML Kit
          readableText = await _processWithMLKit(imageFile);
        } finally {
          GeminiVisionService.onProgress = null;
        }
      } else {
        // OFFLINE: Use ML Kit OCR
        debugPrint('Using ML Kit (offline)');

        // SPEAK: Let user know we're processing offline
        await _ttsService.speak(
          'Processing offline.',
          pauseAtPunctuation: false,
        );

        if (mounted) {
          setState(() {
            _currentStatus = 'Processing offline...';
          });
        }
        readableText = await _processWithMLKit(imageFile);

        if (readableText.isNotEmpty) {
          await _ttsService.speak(
            'Text found. Preparing to read.',
            pauseAtPunctuation: false,
          );
        }
      }

      if (readableText.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _isCapturingImages = false;
            _currentStatus = 'No text detected.';
          });
        }
        await _ttsService.speak(
          'No text found. Try again.',
          pauseAtPunctuation: false,
        );
        return;
      }

      // Read the extracted text
      await _readTextAloud(readableText);
    } catch (e) {
      debugPrint('Error processing image: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isCapturingImages = false;
          _currentStatus = 'Error. Try again.';
        });
      }
      await _ttsService.speak(
        'Error reading document. Please try again.',
        pauseAtPunctuation: false,
      );
    }
  }

  /// Process image with ML Kit (offline fallback)
  Future<String> _processWithMLKit(XFile imageFile) async {
    final recognizedText = await _ocrService.recognizeText(imageFile.path);

    if (recognizedText.blocks.isEmpty) {
      // Try with preprocessing
      try {
        final preprocessedBytes = await _preprocessingService
            .preprocessImageBytes(await File(imageFile.path).readAsBytes());

        final tempFile = File(
          '${Directory.systemTemp.path}/preprocessed_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await tempFile.writeAsBytes(preprocessedBytes);

        final retryRecognized = await _ocrService.recognizeText(tempFile.path);
        await tempFile.delete().catchError((_) => tempFile);

        if (retryRecognized.blocks.isNotEmpty) {
          return _blindReaderService.extractTextForReading(retryRecognized);
        }
      } catch (e) {
        debugPrint('Preprocessing retry failed: $e');
      }
      return '';
    }

    return _blindReaderService.extractTextForReading(recognizedText);
  }

  /// Read extracted text aloud with sentence-based navigation
  ///
  /// Supports: pause, resume, rewind, stop for blind users
  Future<void> _readTextAloud(String text, {int startFrom = 0}) async {
    if (text.trim().isEmpty) return;

    _lastReadText = text; // Store for repeat

    // Split into sentences for navigation
    _sentences = _splitIntoSentences(text);
    _currentSentenceIndex = startFrom.clamp(0, _sentences.length - 1);

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isCapturingImages = false;
        _currentStatus = 'Reading...';
      });
    }

    // AUDIBLE CUE: Reading started
    HapticFeedback.mediumImpact();

    _isReading = true;
    _isPaused = false;

    try {
      // Read sentences one by one for navigation support
      while (_currentSentenceIndex < _sentences.length && _isReading) {
        if (_isPaused) {
          // Wait while paused
          await Future.delayed(const Duration(milliseconds: 100));
          continue;
        }

        final sentence = _sentences[_currentSentenceIndex];
        debugPrint(
          'Reading sentence ${_currentSentenceIndex + 1}/${_sentences.length}',
        );

        await _ttsService.speak(sentence, pauseAtPunctuation: false);

        // Move to next sentence if not paused/stopped
        if (_isReading && !_isPaused) {
          _currentSentenceIndex++;
        }
      }

      // Finished all sentences
      if (_isReading && _currentSentenceIndex >= _sentences.length) {
        HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 300));
        await _ttsService.speak(
          'Reading complete. Swipe left to go back. Double tap to repeat.',
          pauseAtPunctuation: false,
        );

        if (mounted) {
          setState(() {
            _currentStatus =
                'Done. Swipe left to rewind. Double-tap to repeat.';
          });
        }
      }
    } catch (e) {
      debugPrint('TTS error: $e');
      await _ttsService.speak(
        'Error reading. Please try again.',
        pauseAtPunctuation: false,
      );
      if (mounted) {
        setState(() {
          _currentStatus = 'Audio error. Double-tap to retry.';
        });
      }
    } finally {
      _isReading = false;
      _isPaused = false;
    }
  }

  /// Split text into sentences for navigation
  List<String> _splitIntoSentences(String text) {
    // Split on sentence-ending punctuation, keeping the punctuation
    final sentences = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);

      // Check for sentence end (.!?) followed by space or end of text
      if ('.!?'.contains(text[i])) {
        final nextIsSpaceOrEnd =
            (i + 1 >= text.length) || text[i + 1] == ' ' || text[i + 1] == '\n';
        if (nextIsSpaceOrEnd) {
          final sentence = buffer.toString().trim();
          if (sentence.isNotEmpty) {
            sentences.add(sentence);
          }
          buffer.clear();
        }
      }
    }

    // Add any remaining text
    final remaining = buffer.toString().trim();
    if (remaining.isNotEmpty) {
      sentences.add(remaining);
    }

    // If no sentences found, return the whole text as one
    if (sentences.isEmpty && text.trim().isNotEmpty) {
      sentences.add(text.trim());
    }

    return sentences;
  }

  /// Repeat last reading (double-tap gesture)
  Future<void> _repeatLastReading() async {
    if (_lastReadText.isEmpty) {
      await _ttsService.speak('Nothing to repeat.', pauseAtPunctuation: false);
      return;
    }

    HapticFeedback.mediumImpact();
    await _ttsService.speak('Repeating.', pauseAtPunctuation: false);
    await Future.delayed(const Duration(milliseconds: 300));
    await _readTextAloud(_lastReadText);
  }

  /// Pause or resume reading (tap while reading)
  Future<void> _togglePauseResume() async {
    if (!_isReading) return;

    if (_isPaused) {
      // Resume from current sentence
      _isPaused = false;
      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() {
          _currentStatus = 'Reading...';
        });
      }
      // The reading loop will automatically continue
    } else {
      // Pause - stop current speech and flag
      _isPaused = true;
      HapticFeedback.lightImpact();
      await _ttsService.stop();
      if (mounted) {
        setState(() {
          _currentStatus = 'Paused. Tap to resume. Swipe left to rewind.';
        });
      }
      await _ttsService.speak('Paused.', pauseAtPunctuation: false);
    }
  }

  /// Stop reading completely
  Future<void> _stopReading() async {
    if (!_isReading) return;

    _isReading = false;
    _isPaused = false;
    await _ttsService.stop();
    HapticFeedback.heavyImpact();

    if (mounted) {
      setState(() {
        _currentStatus = 'Stopped. Double-tap to repeat. Long-press to scan.';
      });
    }
    await _ttsService.speak('Stopped.', pauseAtPunctuation: false);
  }

  /// Rewind - go back a few sentences
  Future<void> _rewind() async {
    if (_sentences.isEmpty || _lastReadText.isEmpty) {
      await _ttsService.speak('Nothing to rewind.', pauseAtPunctuation: false);
      return;
    }

    // Stop current reading
    if (_isReading) {
      _isReading = false;
      _isPaused = false;
      await _ttsService.stop();
    }

    // Go back 3 sentences (or to start)
    _currentSentenceIndex = (_currentSentenceIndex - 3).clamp(
      0,
      _sentences.length - 1,
    );

    HapticFeedback.mediumImpact();
    await _ttsService.speak(
      'Rewinding to sentence ${_currentSentenceIndex + 1}.',
      pauseAtPunctuation: false,
    );

    // Resume reading from new position
    await Future.delayed(const Duration(milliseconds: 300));
    await _readTextAloud(_lastReadText, startFrom: _currentSentenceIndex);
  }

  /// Skip forward a few sentences
  Future<void> _skipForward() async {
    if (_sentences.isEmpty || _lastReadText.isEmpty) {
      await _ttsService.speak('Nothing to skip.', pauseAtPunctuation: false);
      return;
    }

    // Stop current reading
    if (_isReading) {
      _isReading = false;
      _isPaused = false;
      await _ttsService.stop();
    }

    // Skip forward 3 sentences (or to end)
    _currentSentenceIndex = (_currentSentenceIndex + 3).clamp(
      0,
      _sentences.length - 1,
    );

    HapticFeedback.mediumImpact();

    if (_currentSentenceIndex >= _sentences.length - 1) {
      await _ttsService.speak('End of text.', pauseAtPunctuation: false);
      if (mounted) {
        setState(() {
          _currentStatus = 'End. Double-tap to repeat. Long-press to scan.';
        });
      }
    } else {
      await _ttsService.speak(
        'Skipping to sentence ${_currentSentenceIndex + 1}.',
        pauseAtPunctuation: false,
      );
      await Future.delayed(const Duration(milliseconds: 300));
      await _readTextAloud(_lastReadText, startFrom: _currentSentenceIndex);
    }
  }

  // Old question detection methods - replaced by Gemini Vision
  // Commented out but kept for reference
  /*
  List<String> _detectQuestions(String text) {
    if (text.trim().isEmpty) return [];

    final questions = <String>[];

    // Pattern 1: Arabic numerals (1., 2., 3., etc.)
    // Pattern 2: Roman numerals (I., II., III., IV., V., VI., VII., VIII., IX., X., etc.)
    // Pattern 3: Parenthesized numbers ((1), (2), etc.)
    // Pattern 4: "Question" prefix (Question 1:, Question I:, etc.)

    // Comprehensive pattern matching Arabic and Roman numerals
    final questionNumberPattern = RegExp(
      r'(?:^|\n)\s*(?:(?:Question\s*)?(?:'
      r'\d+[\.\):]' // Arabic: 1., 2), 3:
      r'|'
      r'[IVXLCDM]+[\.\):]' // Roman: I., II), III:
      r'|'
      r'\(\d+\)' // Parenthesized: (1), (2)
      r'|'
      r'\([IVXLCDM]+\)' // Parenthesized Roman: (I), (II)
      r')\s*)',
      multiLine: true,
      caseSensitive: false,
    );

    // Find all question number matches
    final matches = questionNumberPattern.allMatches(text);

    if (matches.isEmpty) {
      // No numbered questions found, try splitting by question marks or other patterns
      return _detectQuestionsByContent(text);
    }

    // Extract questions based on question numbers
    int lastEnd = 0;
    String? currentQuestionNumber;
    StringBuffer currentQuestion = StringBuffer();

    for (final match in matches) {
      final matchStart = match.start;
      final matchText = match.group(0)?.trim() ?? '';

      // If we have a previous question, save it
      if (currentQuestionNumber != null && currentQuestion.isNotEmpty) {
        final questionText = currentQuestion.toString().trim();
        if (questionText.isNotEmpty && questionText.length > 5) {
          questions.add('$currentQuestionNumber $questionText');
        }
        currentQuestion.clear();
      }

      // Get text between last match and current match
      if (matchStart > lastEnd) {
        final betweenText = text.substring(lastEnd, matchStart).trim();
        if (betweenText.isNotEmpty) {
          // This might be part of the previous question or standalone text
          if (currentQuestion.isNotEmpty) {
            currentQuestion.write(' $betweenText');
          } else {
            // Check if this looks like a question
            if (betweenText.endsWith('?') || _looksLikeQuestion(betweenText)) {
              questions.add(betweenText);
            }
          }
        }
      }

      // Start new question with this number
      currentQuestionNumber = matchText;
      lastEnd = match.end;

      // Get text after this question number until next question number or end
      int nextStart = text.length;
      if (matches.length > 1) {
        final nextMatch = matches
            .skip(matches.toList().indexOf(match) + 1)
            .firstOrNull;
        if (nextMatch != null) {
          nextStart = nextMatch.start;
        }
      }

      // Extract question content
      final questionContent = text.substring(lastEnd, nextStart).trim();

      // Determine where this question actually ends
      final questionEnd = _findQuestionEnd(questionContent, text, nextStart);
      final actualQuestionContent = questionContent
          .substring(
            0,
            questionEnd < questionContent.length
                ? questionEnd
                : questionContent.length,
          )
          .trim();

      if (actualQuestionContent.isNotEmpty) {
        currentQuestion.write(actualQuestionContent);
      }

      lastEnd = lastEnd + questionEnd;
    }

    // Add the last question
    if (currentQuestionNumber != null && currentQuestion.isNotEmpty) {
      final questionText = currentQuestion.toString().trim();
      if (questionText.isNotEmpty && questionText.length > 5) {
        questions.add('$currentQuestionNumber $questionText');
      }
    }

    // Clean up and validate questions
    return questions
        .map((q) => q.trim())
        .where((q) => q.isNotEmpty && q.length > 5)
        .toList();
  }

  /// Detect questions by content when no clear numbering is found
  List<String> _detectQuestionsByContent(String text) {
    final questions = <String>[];

    // Try splitting by question marks followed by capital letters or numbers
    final questionMarkPattern = RegExp(r'[?]\s+(?=[A-Z]|\d|\([IVXLCDM\d]+\))');
    final parts = text.split(questionMarkPattern);

    if (parts.length > 1) {
      for (int i = 0; i < parts.length; i++) {
        String question = parts[i].trim();
        if (i < parts.length - 1) {
          question += '?';
        }
        if (question.isNotEmpty && question.length > 10) {
          questions.add(question);
        }
      }
    } else {
      // No clear questions found, return entire text as one
      questions.add(text);
    }

    return questions;
  }

  /// Check if text looks like a question
  bool _looksLikeQuestion(String text) {
    if (text.trim().isEmpty) return false;

    // Check for question words at the start
    final questionWords = [
      'what',
      'where',
      'when',
      'who',
      'why',
      'how',
      'which',
      'whose',
      'whom',
      'can',
      'could',
      'should',
      'would',
      'will',
      'is',
      'are',
      'was',
      'were',
      'do',
      'does',
      'did',
      'has',
      'have',
      'had',
    ];

    final lowerText = text.toLowerCase().trim();
    for (final word in questionWords) {
      if (lowerText.startsWith('$word ') || lowerText.startsWith('$word?')) {
        return true;
      }
    }

    return false;
  }

  /// Find where a question actually ends
  /// Looks for the next question number or natural question boundaries
  int _findQuestionEnd(String content, String fullText, int nextQuestionStart) {
    if (content.isEmpty) return 0;

    // Look for patterns that indicate question end:
    // 1. Next question number (already handled by caller)
    // 2. Multiple blank lines
    // 3. Section headers or new major sections
    // 4. End of content

    // Check for multiple newlines (paragraph break often indicates new question)
    final doubleNewline = content.indexOf('\n\n');
    if (doubleNewline > 0 && doubleNewline < content.length * 0.8) {
      return doubleNewline;
    }

    // Check for section markers
    final sectionMarkers = [
      RegExp(
        r'\n\s*(?:Part|Section|Chapter)\s+[IVXLCDM\d]+',
        caseSensitive: false,
      ),
      RegExp(r'\n\s*[A-Z][a-z]+\s+[IVXLCDM\d]+[\.\):]', caseSensitive: false),
    ];

    for (final marker in sectionMarkers) {
      final match = marker.firstMatch(content);
      if (match != null && match.start > 10) {
        return match.start;
      }
    }

    // If content is short, return it all
    if (content.length < 200) {
      return content.length;
    }

    // Look for natural sentence boundaries near the end
    // But not too close to the start (at least 50% through)
    final sentenceEnd = RegExp(r'[.!?]\s+(?=[A-Z])');
    final matches = sentenceEnd.allMatches(content);

    if (matches.isNotEmpty) {
      // Take the last sentence boundary that's at least halfway through
      for (final match in matches.toList().reversed) {
        if (match.end > content.length * 0.5) {
          return match.end;
        }
      }
    }

    // Default: return most of the content (80%) to avoid cutting off mid-sentence
    return (content.length * 0.8).round();
  }
  */

  /// Stop reading and reset state
  Future<void> _stopAndReset() async {
    await _ttsService.stop();
    if (mounted) {
      setState(() {
        _isReading = false;
        _currentStatus = 'Ready to scan.';
      });
    }
  }

  @override
  void dispose() {
    _stopAlignmentMonitoring();
    _stopAndReset();
    _cameraService.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          // Stop reading and reset before navigating back
          await _stopAndReset();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Scan Document'), centerTitle: true),
        body: _buildBody(),
      ),
    );
  }

  /// Build the main body content
  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeCamera,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Camera preview with gesture controls for blind users
    // GestureDetector wraps EVERYTHING so taps work anywhere on screen
    return GestureDetector(
      // SINGLE TAP: Capture (if not reading) or Pause/Resume (if reading)
      onTap: () {
        debugPrint('TAP detected! isReading=$_isReading, isPaused=$_isPaused');
        if (_isReading || _isPaused) {
          _togglePauseResume();
        } else if (!_isCapturingImages && !_isProcessing) {
          _captureTwoImages();
        }
      },
      // DOUBLE TAP: Stop (if reading) or Repeat (if done)
      onDoubleTap: () {
        debugPrint('DOUBLE TAP detected! isReading=$_isReading');
        if (_isReading || _isPaused) {
          _stopReading();
        } else if (!_isCapturingImages && !_isProcessing) {
          _repeatLastReading();
        }
      },
      // LONG PRESS: New capture
      onLongPress: () {
        debugPrint('LONG PRESS detected!');
        if (_isReading) {
          _stopReading();
        }
        if (!_isCapturingImages && !_isProcessing) {
          HapticFeedback.heavyImpact();
          _captureTwoImages();
        }
      },
      // ALL SWIPES: Combined handler for left/right/down
      onPanEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond;
        final dx = velocity.dx;
        final dy = velocity.dy;

        // Determine if horizontal or vertical swipe based on which is stronger
        if (dx.abs() > dy.abs()) {
          // Horizontal swipe
          if (dx < -200) {
            debugPrint('SWIPE LEFT detected - Rewind');
            _rewind();
          } else if (dx > 200) {
            debugPrint('SWIPE RIGHT detected - Skip');
            _skipForward();
          }
        } else {
          // Vertical swipe
          if (dy > 300) {
            debugPrint('SWIPE DOWN detected - Instructions');
            _speakFullInstructions();
          }
        }
      },
      child: Stack(
        children: [
          // Camera preview
          Positioned.fill(child: CameraPreview(_controller!)),

          // Overlay with scanning guide
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: ScanningGuidePainter()),
            ),
          ),

          // Status and instructions at the top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isReading
                        ? 'Tap: pause. Double-tap: stop. Swipe: rewind/skip.'
                        : _isPaused
                        ? 'Tap: resume. Swipe left: rewind. Double-tap: stop.'
                        : _lastReadText.isNotEmpty
                        ? 'Tap: scan. Double-tap: repeat. Swipe left: rewind.'
                        : 'Tap to capture. Long-press anytime to scan.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for drawing scanning guide overlay
class ScanningGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw a rectangle in the center as a guide
    final guideWidth = size.width * 0.8;
    final guideHeight = size.height * 0.6;
    final guideLeft = (size.width - guideWidth) / 2;
    final guideTop = (size.height - guideHeight) / 2;

    final guideRect = RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(guideLeft, guideTop, guideWidth, guideHeight),
      const Radius.circular(8),
    );

    canvas.drawRRect(guideRect, paint);

    // Draw corner indicators
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final cornerLength = 20.0;

    // Top-left corner
    canvas.drawLine(
      Offset(guideLeft, guideTop),
      Offset(guideLeft + cornerLength, guideTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(guideLeft, guideTop),
      Offset(guideLeft, guideTop + cornerLength),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(guideLeft + guideWidth, guideTop),
      Offset(guideLeft + guideWidth - cornerLength, guideTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(guideLeft + guideWidth, guideTop),
      Offset(guideLeft + guideWidth, guideTop + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(guideLeft, guideTop + guideHeight),
      Offset(guideLeft + cornerLength, guideTop + guideHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(guideLeft, guideTop + guideHeight),
      Offset(guideLeft, guideTop + guideHeight - cornerLength),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(guideLeft + guideWidth, guideTop + guideHeight),
      Offset(guideLeft + guideWidth - cornerLength, guideTop + guideHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(guideLeft + guideWidth, guideTop + guideHeight),
      Offset(guideLeft + guideWidth, guideTop + guideHeight - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(ScanningGuidePainter oldDelegate) => false;
}
