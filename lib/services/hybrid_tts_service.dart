import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Hybrid TTS Service using native platform TTS for instant speech
///
/// Uses flutter_tts (native iOS/Android TTS) which:
/// - Speaks INSTANTLY without generating audio files
/// - Is optimized and fast on all devices
/// - Has high quality voices built into the OS
/// - Supports streaming (starts speaking immediately)
class HybridTTSService {
  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  static bool _disabled = false;

  /// Initialize the TTS service with native platform TTS
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    if (_disabled) {
      debugPrint('TTS is disabled - skipping initialization');
      return false;
    }

    try {
      _flutterTts = FlutterTts();

      // CRITICAL: Set iOS audio category FIRST before any other config
      // This ensures audio plays even when camera is active
      await _flutterTts!.setSharedInstance(true);
      await _flutterTts!.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );

      // Configure for accessibility/blind users
      await _flutterTts!.setLanguage('en-US');
      await _flutterTts!.setSpeechRate(0.5); // Good pace for clarity
      await _flutterTts!.setVolume(1.0);
      await _flutterTts!.setPitch(1.0);

      // CRITICAL: This makes speak() wait until audio finishes
      await _flutterTts!.awaitSpeakCompletion(true);

      // Set up handlers for state tracking
      _flutterTts!.setStartHandler(() {
        _isSpeaking = true;
        debugPrint('TTS: Started speaking');
      });

      _flutterTts!.setCompletionHandler(() {
        _isSpeaking = false;
        debugPrint('TTS: Completed');
      });

      _flutterTts!.setErrorHandler((msg) {
        _isSpeaking = false;
        debugPrint('TTS Error: $msg');
      });

      _flutterTts!.setCancelHandler(() {
        _isSpeaking = false;
        debugPrint('TTS: Cancelled');
      });

      _flutterTts!.setPauseHandler(() {
        _isPaused = true;
        debugPrint('TTS: Paused');
      });

      _flutterTts!.setContinueHandler(() {
        _isPaused = false;
        debugPrint('TTS: Resumed');
      });

      _isInitialized = true;
      debugPrint('Native TTS initialized successfully');
      return true;
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
      _flutterTts = null;
      _isInitialized = false;
      return false;
    }
  }

  /// Initialize asynchronously without blocking
  Future<void> initializeAsync() async {
    initialize()
        .then((success) {
          if (success) {
            debugPrint('TTS initialized successfully in background');
          } else {
            debugPrint('TTS initialization failed');
          }
        })
        .catchError((e) {
          debugPrint('TTS initialization error: $e');
        });
  }

  bool get isInitialized => _isInitialized;
  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;
  bool get isAvailable => _isInitialized && _flutterTts != null;

  static void disable() {
    _disabled = true;
    debugPrint('TTS has been disabled');
  }

  static void enable() {
    _disabled = false;
    debugPrint('TTS has been enabled');
  }

  /// Speak text - starts immediately with native TTS
  ///
  /// Native TTS starts speaking immediately, which is critical for
  /// blind users who need immediate feedback.
  Future<bool> speak(String text, {bool pauseAtPunctuation = true}) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        debugPrint('Cannot speak: TTS not available');
        return false;
      }
    }

    if (text.trim().isEmpty) return true;

    try {
      await stop(); // Stop any ongoing speech

      if (_flutterTts == null) {
        debugPrint('TTS not available');
        return false;
      }

      // Preprocess text for better TTS
      final processedText = _preprocessForTTS(text);

      debugPrint('TTS: Speaking ${processedText.length} chars');
      _isSpeaking = true;

      // speak() will wait for completion because awaitSpeakCompletion(true)
      final result = await _flutterTts!.speak(processedText);

      debugPrint('TTS: speak() returned $result');
      _isSpeaking = false;

      if (result != 1) {
        debugPrint('TTS speak failed with result: $result');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error speaking: $e');
      _isSpeaking = false;
      return false;
    }
  }

  /// Preprocess text for natural TTS output
  String _preprocessForTTS(String text) {
    var processed = text;

    // Convert numbers to words for better pronunciation
    processed = _convertNumbersToWords(processed);

    // Normalize whitespace
    processed = processed.replaceAll(RegExp(r'\s+'), ' ');

    // Clean up punctuation
    processed = processed.replaceAll(RegExp(r'\s+([.,;:!?])'), r'$1');
    processed = processed.replaceAll(RegExp(r'([.,;:!?])([a-zA-Z])'), r'$1 $2');

    // Add slight pauses at colons (for "Option A:" style)
    processed = processed.replaceAll(':', ', ');

    return processed.trim();
  }

  /// Convert numbers to words for better pronunciation
  String _convertNumbersToWords(String text) {
    var result = text;

    final numberWords = {
      '0': 'zero',
      '1': 'one',
      '2': 'two',
      '3': 'three',
      '4': 'four',
      '5': 'five',
      '6': 'six',
      '7': 'seven',
      '8': 'eight',
      '9': 'nine',
      '10': 'ten',
      '11': 'eleven',
      '12': 'twelve',
      '13': 'thirteen',
      '14': 'fourteen',
      '15': 'fifteen',
      '16': 'sixteen',
      '17': 'seventeen',
      '18': 'eighteen',
      '19': 'nineteen',
      '20': 'twenty',
      '21': 'twenty one',
      '22': 'twenty two',
      '23': 'twenty three',
      '24': 'twenty four',
      '25': 'twenty five',
      '26': 'twenty six',
      '27': 'twenty seven',
      '28': 'twenty eight',
      '29': 'twenty nine',
      '30': 'thirty',
      '31': 'thirty one',
      '32': 'thirty two',
      '33': 'thirty three',
      '34': 'thirty four',
      '35': 'thirty five',
      '36': 'thirty six',
      '37': 'thirty seven',
      '38': 'thirty eight',
      '39': 'thirty nine',
      '40': 'forty',
      '50': 'fifty',
      '60': 'sixty',
      '70': 'seventy',
      '80': 'eighty',
      '90': 'ninety',
      '100': 'one hundred',
    };

    // Replace "Question 27" style patterns
    result = result.replaceAllMapped(
      RegExp(r'(Question\s*)(\d+)', caseSensitive: false),
      (m) {
        final prefix = m.group(1)!;
        final num = m.group(2)!;
        final word = numberWords[num] ?? num;
        return '$prefix$word';
      },
    );

    // Replace standalone numbers with period (like "27.")
    result = result.replaceAllMapped(RegExp(r'\b(\d+)\.'), (m) {
      final num = m.group(1)!;
      final word = numberWords[num] ?? num;
      return '$word.';
    });

    return result;
  }

  /// Stop speaking
  Future<void> stop() async {
    if (_flutterTts != null) {
      await _flutterTts!.stop();
    }
    _isSpeaking = false;
    _isPaused = false;
  }

  /// Pause speaking
  Future<void> pause() async {
    if (_flutterTts != null) {
      await _flutterTts!.pause();
      _isPaused = true;
    }
  }

  /// Resume speaking
  Future<void> resume() async {
    if (_flutterTts != null) {
      // flutter_tts doesn't have resume, need to re-speak
      // For now, just unpause flag
      _isPaused = false;
    }
  }

  /// Set speech rate (0.0 to 1.0, default 0.5)
  Future<void> setSpeechRate(double rate) async {
    if (_flutterTts != null) {
      await _flutterTts!.setSpeechRate(rate.clamp(0.0, 1.0));
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await stop();
    await _flutterTts?.stop();
    _flutterTts = null;
    _isInitialized = false;
  }
}
