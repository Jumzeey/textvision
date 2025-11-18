import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';
import '../services/tts_service.dart';
import '../services/text_processing_service.dart';
import '../services/google_cloud_vision_service.dart';

/// Camera scan screen for capturing exam paper images
///
/// This screen provides a camera interface with:
/// - Live camera preview
/// - Capture button with haptic feedback
/// - Accessibility labels for screen readers
/// - Visual feedback for successful captures
/// - Support for both printed and handwritten text
class CameraScanScreen extends StatefulWidget {
  final bool isHandwriting;

  const CameraScanScreen({super.key, this.isHandwriting = false});

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  final CameraService _cameraService = CameraService();
  late final GoogleCloudVisionService _visionService;
  final TTSService _ttsService = TTSService();
  final TextProcessingService _textProcessor = TextProcessingService();
  CameraController? _controller;
  bool _isInitialized = false;
  String? _errorMessage;
  final List<String> _collectedTextBlocks =
      []; // Store full text blocks from each scan
  final List<Uint8List> _capturedImages =
      []; // Store captured images for batch processing
  bool _isCapturingImages = false; // Track if capturing images
  bool _isReading = false; // Track if currently reading text
  bool _isProcessing = false; // Track if processing OCR results
  String _currentStatus = 'Initializing camera...';
  List<String> _questions = []; // Store detected questions
  int _currentQuestionIndex =
      -1; // Current question being read (-1 means not started)

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  /// Initialize all services
  Future<void> _initializeServices() async {
    try {
      // Initialize Google Cloud Vision service
      _visionService = GoogleCloudVisionService();
      await _ttsService.initialize();
      await _initializeCamera();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Failed to initialize services: $e\n\n${e.toString()}';
        });
      }
    }
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
              'Camera ready. Tap "Capture 2 Images" to scan the paper.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize camera: $e';
          _isInitialized = false;
        });
      }
    }
  }

  /// Capture 2 images for processing
  Future<void> _captureTwoImages() async {
    if (_isCapturingImages ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }

    setState(() {
      _isCapturingImages = true;
      _capturedImages.clear();
      _collectedTextBlocks.clear();
      _questions.clear();
      _currentQuestionIndex = -1;
      _currentStatus = 'Capturing images... Position paper and tap when ready.';
    });

    // Provide haptic feedback
    HapticFeedback.mediumImpact();

    try {
      // Capture first image
      if (mounted) {
        setState(() {
          _currentStatus = 'Capturing first image...';
        });
      }
      final imageFile1 = await _controller!.takePicture();
      final imageBytes1 = await imageFile1.readAsBytes();
      if (imageBytes1.isNotEmpty) {
        _capturedImages.add(imageBytes1);
      }

      // Small delay between captures
      await Future.delayed(const Duration(milliseconds: 500));

      // Capture second image
      if (mounted) {
        setState(() {
          _currentStatus = 'Capturing second image...';
        });
      }
      final imageFile2 = await _controller!.takePicture();
      final imageBytes2 = await imageFile2.readAsBytes();
      if (imageBytes2.isNotEmpty) {
        _capturedImages.add(imageBytes2);
      }

      // Provide haptic feedback when done
      HapticFeedback.mediumImpact();

      if (mounted) {
        setState(() {
          _currentStatus =
              'Captured ${_capturedImages.length} images. Processing...';
        });
      }

      // Process images immediately
      await _processImagesAndDetectQuestions();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCapturingImages = false;
          _currentStatus = 'Error capturing images: $e';
        });
      }
    }
  }

  /// Process captured images and detect questions
  Future<void> _processImagesAndDetectQuestions() async {
    if (_capturedImages.isEmpty) {
      if (mounted) {
        setState(() {
          _isCapturingImages = false;
          _currentStatus = 'No images captured.';
        });
      }
      return;
    }

    // Process all captured images with Google Cloud Vision API
    if (mounted) {
      setState(() {
        _isProcessing = true;
        _currentStatus =
            'Processing ${_capturedImages.length} images with Google Cloud Vision...';
      });
    }

    try {
      // Process images in batch for efficiency
      final visionResponses = await _visionService.detectTextBatch(
        _capturedImages,
      );

      // Extract text from all responses
      for (final response in visionResponses) {
        if (response.hasText) {
          final text = _visionService.extractPlainText(response);
          if (text.trim().isNotEmpty) {
            _collectedTextBlocks.add(text);
          }
        }
      }

      // Merge and organize text
      final mergedText = _textProcessor.mergeTextBlocks(_collectedTextBlocks);
      if (mergedText.trim().isEmpty) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _isCapturingImages = false;
            _currentStatus =
                'No text detected. Try adjusting the paper position.';
          });
        }
        return;
      }

      // Process text and detect questions
      final processedText = await _textProcessor.processTextForReading(
        mergedText,
      );

      // Split text into questions
      _questions = _detectQuestions(processedText);

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isCapturingImages = false;
          if (_questions.isEmpty) {
            _currentStatus =
                'No questions detected. Text will be read as a whole.';
            // If no questions detected, treat entire text as one question
            _questions = [processedText];
          } else {
            _currentStatus =
                'Found ${_questions.length} questions. Ready to read.';
          }
        });
      }

      // Announce to user with proper pauses
      if (_questions.isNotEmpty) {
        await _ttsService.speak(
          'Found ${_questions.length} questions. Starting with question 1.',
          pauseAtPunctuation: true,
        );
        await Future.delayed(const Duration(milliseconds: 800));
        _readCurrentQuestion();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isCapturingImages = false;
          _errorMessage = 'Failed to process images: $e';
        });
      }
    }
  }

  /// Detect questions in text
  /// Looks for numbered questions (Arabic, Roman numerals), question marks, and common question patterns
  /// Intelligently determines when a question ends and a new one begins
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
      if (lowerText.startsWith('$word ') ||
          lowerText.startsWith('$word?')) {
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

  /// Read the current question
  Future<void> _readCurrentQuestion() async {
    if (_questions.isEmpty || _currentQuestionIndex < 0) {
      _currentQuestionIndex = 0;
    }

    if (_currentQuestionIndex >= _questions.length) {
      // All questions read
      if (mounted) {
        setState(() {
          _currentStatus =
              'All questions read. Tap "Capture 2 Images" to scan again.';
        });
      }
      await _ttsService.speak('All questions have been read.');
      return;
    }

    setState(() {
      _isReading = true;
      _currentStatus =
          'Reading question ${_currentQuestionIndex + 1} of ${_questions.length}';
    });

    final question = _questions[_currentQuestionIndex];
    final questionNumber = _currentQuestionIndex + 1;

    // Announce question number with pause
    await _ttsService.speak(
      'Question $questionNumber.',
      pauseAtPunctuation: true,
    );
    await Future.delayed(const Duration(milliseconds: 500));

    // Read the question with proper pauses at punctuation
    await _ttsService.speak(question, pauseAtPunctuation: true);

    // Wait for speech to complete
    int waitCount = 0;
    while (_ttsService.isSpeaking && waitCount < 200) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }

    if (mounted) {
      setState(() {
        _isReading = false;
        _currentStatus =
            'Question ${_currentQuestionIndex + 1} of ${_questions.length} read. Use buttons to navigate.';
      });
    }
  }

  /// Re-read current question
  Future<void> _rereadCurrentQuestion() async {
    if (_questions.isEmpty) return;
    await _readCurrentQuestion();
  }

  /// Pause or resume reading
  Future<void> _pauseOrResumeReading() async {
    if (_ttsService.isSpeaking && !_ttsService.isPaused) {
      // Pause reading
      await _ttsService.pause();
      if (mounted) {
        setState(() {
          _currentStatus =
              'Reading paused. Tap "Resume" to continue or "Re-read" to start over.';
        });
      }
    } else if (_ttsService.isPaused) {
      // Resume by re-reading the current question from the beginning
      // (since TTS resume may not work on all platforms)
      await _ttsService.stop();
      if (mounted) {
        setState(() {
          _currentStatus = 'Resuming...';
        });
      }
      // Re-read the current question
      await _readCurrentQuestion();
    }
  }

  /// Build control buttons based on current state
  Widget _buildControlButtons() {
    // Show question controls if questions are detected
    if (_questions.isNotEmpty && !_isProcessing && !_isCapturingImages) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Control buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Pause/Resume button
                ElevatedButton.icon(
                  onPressed:
                      (_isReading || _ttsService.isPaused) &&
                          !_isCapturingImages &&
                          !_isProcessing
                      ? _pauseOrResumeReading
                      : null,
                  icon: Icon(
                    _ttsService.isPaused ? Icons.play_arrow : Icons.pause,
                  ),
                  label: Text(_ttsService.isPaused ? 'Resume' : 'Pause'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ttsService.isPaused
                        ? Colors.green
                        : Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
                // Re-read current question button
                ElevatedButton.icon(
                  onPressed:
                      !_isReading &&
                          _currentQuestionIndex >= 0 &&
                          !_isCapturingImages &&
                          !_isProcessing
                      ? _rereadCurrentQuestion
                      : null,
                  icon: const Icon(Icons.replay),
                  label: const Text('Re-read'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Capture new images button
            ElevatedButton.icon(
              onPressed: !_isReading && !_isCapturingImages && !_isProcessing
                  ? _captureTwoImages
                  : null,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture 2 Images'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show capture button when no questions detected
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton.icon(
        onPressed:
            !_isCapturingImages &&
                !_isProcessing &&
                !_isReading &&
                _controller != null &&
                _controller!.value.isInitialized
            ? _captureTwoImages
            : null,
        icon: const Icon(Icons.camera_alt),
        label: Text(
          _isCapturingImages
              ? 'Capturing...'
              : _isProcessing
              ? 'Processing...'
              : 'Capture 2 Images',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          minimumSize: const Size(double.infinity, 56),
        ),
      ),
    );
  }

  /// Stop reading and reset state
  Future<void> _stopAndReset() async {
    await _ttsService.stop();
    if (mounted) {
      setState(() {
        _isReading = false;
        _currentQuestionIndex = -1;
        _currentStatus = 'Reading stopped. Ready to scan.';
      });
    }
  }

  @override
  void dispose() {
    _stopAndReset();
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Stop reading and reset before navigating back
        await _stopAndReset();
        return true; // Allow navigation
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isHandwriting ? 'Scan Handwriting' : 'Scan Exam Paper',
          ),
          centerTitle: true,
        ),
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

    // Camera preview
    return Stack(
      children: [
        // Camera preview fills the screen
        Positioned.fill(child: CameraPreview(_controller!)),

        // Overlay with scanning guide
        Positioned.fill(child: CustomPaint(painter: ScanningGuidePainter())),

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
                if (_questions.isEmpty)
                  Text(
                    widget.isHandwriting
                        ? 'Position handwritten text within the frame. Tap "Capture 2 Images" to scan.'
                        : 'Position the exam paper within the frame. Tap "Capture 2 Images" to scan.',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  )
                else
                  Text(
                    'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),

        // Control buttons at the bottom
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: _buildControlButtons(),
        ),
      ],
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
