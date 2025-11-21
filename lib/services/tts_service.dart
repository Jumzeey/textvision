import 'package:flutter_tts/flutter_tts.dart';

/// Service for text-to-speech functionality
///
/// Handles:
/// - Reading text aloud
/// - Controlling speech rate, pitch, and volume
/// - Language selection
/// - Pausing, resuming, and stopping speech
/// - Interrupting speech
class TTSService {
  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  String _currentLanguage = 'en-US';

  /// Get the FlutterTts instance
  FlutterTts? get flutterTts => _flutterTts;

  /// Check if TTS is initialized
  bool get isInitialized => _isInitialized;

  /// Check if TTS is currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Check if TTS is paused
  bool get isPaused => _isPaused;

  /// Initialize the TTS service
  ///
  /// Sets up default settings and language
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      _flutterTts = FlutterTts();

      // Set default language (English)
      _currentLanguage = 'en-US';
      await _flutterTts!.setLanguage(_currentLanguage);

      // Set default speech rate (0.0 to 1.0, where 0.5 is normal speed)
      // Slower rate for better clarity and smoother reading
      await _flutterTts!.setSpeechRate(0.4);

      // Set default pitch (0.5 to 2.0, where 1.0 is normal pitch)
      await _flutterTts!.setPitch(1.0);

      // Set default volume (0.0 to 1.0, where 1.0 is maximum volume)
      await _flutterTts!.setVolume(1.0);

      // Set up completion handler
      _flutterTts!.setCompletionHandler(() {
        _isSpeaking = false;
        _isPaused = false;
      });

      // Set up error handler
      _flutterTts!.setErrorHandler((msg) {
        _isSpeaking = false;
        _isPaused = false;
      });

      // Set up start handler
      _flutterTts!.setStartHandler(() {
        _isSpeaking = true;
        _isPaused = false;
      });

      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize TTS: $e');
    }
  }

  /// Speak text aloud with proper pauses at punctuation
  ///
  /// [text] - The text to speak
  /// [pauseAtPunctuation] - If true, adds pauses at punctuation marks for natural reading
  ///
  /// Returns the result of the speak operation
  Future<int> speak(String text, {bool pauseAtPunctuation = true}) async {
    if (!_isInitialized || _flutterTts == null) {
      await initialize();
    }

    if (text.isEmpty) {
      return 0;
    }

    try {
      // Stop any ongoing speech
      await stop();

      if (pauseAtPunctuation) {
        // Split text by punctuation and read with pauses
        await _speakWithPauses(text);
        return 1;
      } else {
        // Speak the text directly
        final result = await _flutterTts!.speak(text);
        return result;
      }
    } catch (e) {
      throw Exception('Failed to speak text: $e');
    }
  }

  /// Speak text with natural pauses at punctuation marks
  ///
  /// Splits text at punctuation and adds appropriate pauses
  Future<void> _speakWithPauses(String text) async {
    // Split text into chunks at punctuation marks
    final chunks = _splitTextWithPunctuation(text);

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i].trim();
      if (chunk.isEmpty) continue;

      // Speak the chunk
      await _flutterTts!.speak(chunk);

      // Wait for speech to complete
      int waitCount = 0;
      while (_isSpeaking && waitCount < 300) {
        await Future.delayed(const Duration(milliseconds: 50));
        waitCount++;
      }

      // Add pause based on punctuation type
      if (i < chunks.length - 1) {
        final pauseDuration = _getPauseDuration(chunk);
        await Future.delayed(pauseDuration);
      }
    }
  }

  /// Split text into chunks at punctuation marks while preserving punctuation
  List<String> _splitTextWithPunctuation(String text) {
    final chunks = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(char);

      // Check for sentence-ending punctuation (period, question mark, exclamation)
      if (char == '.' || char == '?' || char == '!') {
        // Check if it's not part of a decimal number or abbreviation
        if (i == text.length - 1 ||
            (i < text.length - 1 &&
                text[i + 1].trim().isNotEmpty &&
                !text[i + 1].trim().toLowerCase().startsWith(
                  RegExp(r'[a-z]'),
                ))) {
          chunks.add(buffer.toString());
          buffer.clear();
        }
      }
      // Check for comma, semicolon, colon
      else if (char == ',' || char == ';' || char == ':') {
        // Add comma/semicolon/colon as a separate chunk for pause
        if (buffer.length > 1) {
          chunks.add(buffer.toString());
          buffer.clear();
        }
      }
    }

    // Add remaining text
    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString());
    }

    // If no punctuation found, return original text as single chunk
    if (chunks.isEmpty) {
      chunks.add(text);
    }

    return chunks;
  }

  /// Get pause duration based on punctuation type
  Duration _getPauseDuration(String chunk) {
    if (chunk.trim().endsWith('.')) {
      // Period: longer pause (sentence end)
      return const Duration(milliseconds: 600);
    } else if (chunk.trim().endsWith('?') || chunk.trim().endsWith('!')) {
      // Question mark or exclamation: medium pause
      return const Duration(milliseconds: 700);
    } else if (chunk.trim().endsWith(';')) {
      // Semicolon: medium pause
      return const Duration(milliseconds: 500);
    } else if (chunk.trim().endsWith(':')) {
      // Colon: medium pause
      return const Duration(milliseconds: 500);
    } else if (chunk.trim().endsWith(',')) {
      // Comma: short pause
      return const Duration(milliseconds: 300);
    }
    // Default pause
    return const Duration(milliseconds: 200);
  }

  /// Stop speaking
  ///
  /// Immediately stops any ongoing speech
  Future<void> stop() async {
    if (!_isInitialized || _flutterTts == null) {
      return;
    }

    try {
      await _flutterTts!.stop();
      _isSpeaking = false;
      _isPaused = false;
    } catch (e) {
      throw Exception('Failed to stop TTS: $e');
    }
  }

  /// Pause speaking
  ///
  /// Pauses the current speech (if supported by the platform)
  Future<void> pause() async {
    if (!_isInitialized || _flutterTts == null) {
      return;
    }

    try {
      await _flutterTts!.pause();
      _isPaused = true;
    } catch (e) {
      // Pause may not be supported on all platforms
      // Fall back to stop
      await stop();
    }
  }

  /// Resume speaking
  ///
  /// Resumes paused speech (if supported by the platform)
  Future<void> resume() async {
    if (!_isInitialized || _flutterTts == null) {
      return;
    }

    try {
      // Note: Resume functionality depends on platform support
      // On iOS, pause/resume may not work, so we'll just mark as not paused
      // The actual resume will happen when speak() is called again
      _isPaused = false;
      _isSpeaking = false; // Reset state since we can't actually resume
    } catch (e) {
      _isPaused = false;
      _isSpeaking = false;
      throw Exception('Failed to resume TTS: $e');
    }
  }

  /// Set speech rate
  ///
  /// [rate] - Speech rate from 0.0 to 1.0 (where 0.5 is normal speed)
  Future<void> setSpeechRate(double rate) async {
    if (!_isInitialized || _flutterTts == null) {
      await initialize();
    }

    // Clamp rate to valid range
    final clampedRate = rate.clamp(0.0, 1.0);
    await _flutterTts!.setSpeechRate(clampedRate);
  }

  /// Set pitch
  ///
  /// [pitch] - Pitch from 0.5 to 2.0 (where 1.0 is normal pitch)
  Future<void> setPitch(double pitch) async {
    if (!_isInitialized || _flutterTts == null) {
      await initialize();
    }

    // Clamp pitch to valid range
    final clampedPitch = pitch.clamp(0.5, 2.0);
    await _flutterTts!.setPitch(clampedPitch);
  }

  /// Set volume
  ///
  /// [volume] - Volume from 0.0 to 1.0 (where 1.0 is maximum volume)
  Future<void> setVolume(double volume) async {
    if (!_isInitialized || _flutterTts == null) {
      await initialize();
    }

    // Clamp volume to valid range
    final clampedVolume = volume.clamp(0.0, 1.0);
    await _flutterTts!.setVolume(clampedVolume);
  }

  /// Set language
  ///
  /// [language] - Language code (e.g., 'en-US', 'es-ES', 'fr-FR')
  Future<void> setLanguage(String language) async {
    if (!_isInitialized || _flutterTts == null) {
      await initialize();
    }

    try {
      _currentLanguage = language;
      await _flutterTts!.setLanguage(language);
    } catch (e) {
      throw Exception('Failed to set language: $e');
    }
  }

  /// Get available languages
  ///
  /// Returns a list of available language codes
  Future<List<String>> getAvailableLanguages() async {
    if (!_isInitialized || _flutterTts == null) {
      await initialize();
    }

    try {
      final languages = await _flutterTts!.getLanguages;
      return languages.cast<String>();
    } catch (e) {
      return ['en-US']; // Default to English if unable to get languages
    }
  }

  /// Get current language
  ///
  /// Returns the current language code
  Future<String> getCurrentLanguage() async {
    if (!_isInitialized || _flutterTts == null) {
      await initialize();
    }

    // Return the stored current language
    return _currentLanguage;
  }

  /// Dispose of the TTS service
  ///
  /// Call this when done using the TTS service to free up resources
  Future<void> dispose() async {
    if (_isInitialized && _flutterTts != null) {
      await stop();
      _flutterTts = null;
      _isInitialized = false;
    }
  }
}
