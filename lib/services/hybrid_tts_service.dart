import 'package:flutter_tts/flutter_tts.dart';
// import 'kokoro_tts_service.dart'; // Temporarily disabled
import 'dart:async';

/// Hybrid TTS Service that uses Kokoro TTS when available,
/// falls back to flutter_tts if Kokoro is unavailable
///
/// Provides a unified interface for text-to-speech synthesis
/// optimized for reading exam questions to blind users
class HybridTTSService {
  // KokoroTTSService? _kokoroService; // Temporarily disabled
  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  // bool _useKokoro = false; // Temporarily disabled - always using flutter_tts
  
  // Audio playback for Kokoro (would need audioplayers package)
  // For now, we'll use flutter_tts as fallback
  
  /// Initialize the TTS service (tries Kokoro first, falls back to flutter_tts)
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Kokoro TTS temporarily disabled due to iOS linking issues
    // Always use flutter_tts for now
    await _initializeFlutterTTS();
    _isInitialized = true;
  }

  /// Initialize flutter_tts as fallback
  Future<void> _initializeFlutterTTS() async {
    _flutterTts = FlutterTts();
    await _flutterTts!.setLanguage('en-US');
    await _flutterTts!.setSpeechRate(0.4);
    await _flutterTts!.setPitch(1.0);
    await _flutterTts!.setVolume(1.0);
    
    _flutterTts!.setCompletionHandler(() {
      _isSpeaking = false;
    });
    
    _flutterTts!.setErrorHandler((msg) {
      _isSpeaking = false;
    });
    
    _flutterTts!.setStartHandler(() {
      _isSpeaking = true;
    });
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Check if currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Check if currently paused
  bool get isPaused => _isPaused;

  /// Check if using Kokoro TTS
  bool get usingKokoro => false; // Temporarily disabled

  /// Speak text with natural pauses
  ///
  /// [text] - The text to speak
  /// [pauseAtPunctuation] - Add pauses at punctuation marks
  Future<void> speak(String text, {bool pauseAtPunctuation = true}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (text.trim().isEmpty) return;

    try {
      await stop(); // Stop any ongoing speech

      // Kokoro TTS temporarily disabled
      if (_flutterTts != null) {
        // Use flutter_tts fallback
        await _speakWithFlutterTTS(text, pauseAtPunctuation: pauseAtPunctuation);
      }
    } catch (e) {
      throw Exception('Failed to speak text: $e');
    }
  }

  // Kokoro TTS method temporarily disabled
  // Future<void> _speakWithKokoro(String text, {bool pauseAtPunctuation = true}) async {
  //   // Implementation removed - using flutter_tts only for now
  // }

  /// Speak using flutter_tts
  Future<void> _speakWithFlutterTTS(String text, {bool pauseAtPunctuation = true}) async {
    if (_flutterTts == null) return;
    
    if (pauseAtPunctuation) {
      // Split and speak with pauses
      await _speakWithPauses(text);
    } else {
      await _flutterTts!.speak(text);
    }
  }

  // Format text for natural reading (Kokoro-style) - temporarily disabled
  // String _formatForNaturalReading(String text, bool pauseAtPunctuation) {
  //   if (!pauseAtPunctuation) return text;
  //   
  //   // Add strategic pauses for better comprehension
  //   var formatted = text;
  //   
  //   // Add pause after question numbers
  //   formatted = formatted.replaceAll(RegExp(r'(Question \w+\.)'), r'$1 ... ');
  //   
  //   // Add pause after option labels
  //   formatted = formatted.replaceAll(RegExp(r'(Option [a-d],)'), r'$1 ... ');
  //   
  //   // Ensure proper sentence endings
  //   formatted = formatted.replaceAll(RegExp(r'([.!?])([A-Z])'), r'$1 $2');
  //   
  //   return formatted;
  // }

  /// Speak text with pauses at punctuation
  Future<void> _speakWithPauses(String text) async {
    if (_flutterTts == null) return;
    
    final chunks = _splitTextWithPunctuation(text);
    
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i].trim();
      if (chunk.isEmpty) continue;
      
      // Mark as speaking before starting
      _isSpeaking = true;
      await _flutterTts!.speak(chunk);
      
      // Wait for speech to complete with longer timeout
      int waitCount = 0;
      const maxWaitTime = 600; // 60 seconds max per chunk
      
      while (_isSpeaking && waitCount < maxWaitTime) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
        
        // Double-check if still speaking every 10 checks
        if (waitCount % 10 == 0 && !_isSpeaking) {
          break;
        }
      }
      
      // Additional safety delay to ensure chunk completes
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Add pause based on punctuation
      if (i < chunks.length - 1) {
        final pauseDuration = _getPauseDuration(chunk);
        await Future.delayed(pauseDuration);
      }
    }
    
    // Ensure we mark as not speaking when done
    _isSpeaking = false;
  }

  /// Split text into chunks at punctuation
  List<String> _splitTextWithPunctuation(String text) {
    final chunks = <String>[];
    final buffer = StringBuffer();
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(char);
      
      if (char == '.' || char == '?' || char == '!') {
        if (i == text.length - 1 ||
            (i < text.length - 1 &&
                text[i + 1].trim().isNotEmpty &&
                !text[i + 1].trim().toLowerCase().startsWith(RegExp(r'[a-z]')))) {
          chunks.add(buffer.toString());
          buffer.clear();
        }
      } else if (char == ',' || char == ';' || char == ':') {
        if (buffer.length > 1) {
          chunks.add(buffer.toString());
          buffer.clear();
        }
      }
    }
    
    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString());
    }
    
    return chunks.isEmpty ? [text] : chunks;
  }

  /// Get pause duration based on punctuation
  Duration _getPauseDuration(String chunk) {
    if (chunk.trim().endsWith('.')) {
      return const Duration(milliseconds: 600);
    } else if (chunk.trim().endsWith('?') || chunk.trim().endsWith('!')) {
      return const Duration(milliseconds: 700);
    } else if (chunk.trim().endsWith(';')) {
      return const Duration(milliseconds: 500);
    } else if (chunk.trim().endsWith(':')) {
      return const Duration(milliseconds: 500);
    } else if (chunk.trim().endsWith(',')) {
      return const Duration(milliseconds: 300);
    }
    return const Duration(milliseconds: 200);
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

  /// Dispose of resources
  Future<void> dispose() async {
    await stop();
    // await _kokoroService?.dispose(); // Temporarily disabled
    // _kokoroService = null;
    _flutterTts = null;
    _isInitialized = false;
  }
}

