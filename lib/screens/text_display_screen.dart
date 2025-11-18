import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ocr_result.dart';
import '../services/tts_service.dart';
import '../services/storage_service.dart';
import '../services/accessibility_service.dart';

/// Text Display Screen
///
/// Displays the extracted text from OCR processing
/// Includes text-to-speech functionality for reading text aloud
class TextDisplayScreen extends StatefulWidget {
  final OCRResult ocrResult;
  final String? imagePath;

  const TextDisplayScreen({super.key, required this.ocrResult, this.imagePath});

  @override
  State<TextDisplayScreen> createState() => _TextDisplayScreenState();
}

class _TextDisplayScreenState extends State<TextDisplayScreen> {
  final TTSService _ttsService = TTSService();
  final StorageService _storageService = StorageService();
  bool _isTTSInitialized = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  bool _isSaving = false;
  double _speechRate = 0.5;
  double _pitch = 1.0;
  double _volume = 1.0;

  @override
  void initState() {
    super.initState();
    _initializeTTS();
  }

  /// Initialize TTS service
  Future<void> _initializeTTS() async {
    try {
      await _ttsService.initialize();
      await _ttsService.setSpeechRate(_speechRate);
      await _ttsService.setPitch(_pitch);
      await _ttsService.setVolume(_volume);

      if (mounted) {
        setState(() {
          _isTTSInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to initialize TTS: $e');
    }
  }

  /// Start reading text aloud
  Future<void> _startReading() async {
    if (!_isTTSInitialized) {
      await _initializeTTS();
    }

    try {
      await _ttsService.speak(widget.ocrResult.text);
      if (mounted) {
        setState(() {
          _isSpeaking = true;
          _isPaused = false;
        });
      }

      // Provide haptic feedback
      AccessibilityService.hapticFeedback('medium');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start reading: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Stop reading
  Future<void> _stopReading() async {
    try {
      await _ttsService.stop();
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _isPaused = false;
        });
      }

      // Provide haptic feedback
      AccessibilityService.hapticFeedback('medium');
    } catch (e) {
      debugPrint('Failed to stop reading: $e');
    }
  }

  /// Pause reading
  Future<void> _pauseReading() async {
    try {
      await _ttsService.pause();
      if (mounted) {
        setState(() {
          _isPaused = true;
        });
      }

      // Provide haptic feedback
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Failed to pause reading: $e');
    }
  }

  /// Resume reading
  Future<void> _resumeReading() async {
    try {
      await _ttsService.resume();
      if (mounted) {
        setState(() {
          _isPaused = false;
        });
      }

      // Provide haptic feedback
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('Failed to resume reading: $e');
    }
  }

  /// Update speech rate
  Future<void> _updateSpeechRate(double rate) async {
    _speechRate = rate;
    await _ttsService.setSpeechRate(rate);
  }

  /// Update pitch
  Future<void> _updatePitch(double pitch) async {
    _pitch = pitch;
    await _ttsService.setPitch(pitch);
  }

  /// Update volume
  Future<void> _updateVolume(double volume) async {
    _volume = volume;
    await _ttsService.setVolume(volume);
  }

  /// Save transcript to local storage
  Future<void> _saveTranscript() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _storageService.saveTranscript(widget.ocrResult);

      if (mounted) {
        AccessibilityService.hapticFeedback('success');
        AccessibilityService.announceToScreenReader(
          context,
          'Transcript saved successfully',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transcript saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AccessibilityService.hapticFeedback('error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save transcript: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// Get color for confidence score
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) {
      return Colors.green;
    } else if (confidence >= 0.6) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// Build confidence indicator widget
  Widget _buildConfidenceIndicator(double confidence) {
    return Container(
      width: 60,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: confidence,
        child: Container(
          decoration: BoxDecoration(
            color: _getConfidenceColor(confidence),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extracted Text'),
        actions: [
          // Share button (to be implemented)
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share functionality
            },
            tooltip: 'Share text',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (widget.ocrResult.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.text_fields, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No text detected',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please try scanning again with better lighting and focus.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Scan Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.ocrResult.summary,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.ocrResult.confidence != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Confidence: ${(widget.ocrResult.confidence! * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: _getConfidenceColor(
                          widget.ocrResult.confidence!,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildConfidenceIndicator(widget.ocrResult.confidence!),
                  ],
                ),
                if (widget.ocrResult.confidence! < 0.7) ...[
                  const SizedBox(height: 4),
                  const Text(
                    '⚠ Low confidence - consider manual review',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),

        // Text content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              widget.ocrResult.formattedText,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        ),

        // Action buttons
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // TTS control buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Play/Pause button
                  Semantics(
                    label: _isSpeaking && !_isPaused
                        ? 'Pause reading button. Double tap to pause text-to-speech.'
                        : _isPaused
                        ? 'Resume reading button. Double tap to resume text-to-speech.'
                        : 'Read aloud button. Double tap to start text-to-speech.',
                    button: true,
                    child: ElevatedButton.icon(
                      onPressed: _isTTSInitialized
                          ? (_isSpeaking && !_isPaused
                                ? _pauseReading
                                : _isPaused
                                ? _resumeReading
                                : _startReading)
                          : null,
                      icon: Icon(
                        _isSpeaking && !_isPaused
                            ? Icons.pause
                            : _isPaused
                            ? Icons.play_arrow
                            : Icons.volume_up,
                      ),
                      label: Text(
                        _isSpeaking && !_isPaused
                            ? 'Pause'
                            : _isPaused
                            ? 'Resume'
                            : 'Read Aloud',
                      ),
                    ),
                  ),

                  // Stop button (only show when speaking)
                  if (_isSpeaking || _isPaused)
                    Semantics(
                      label:
                          'Stop reading button. Double tap to stop text-to-speech.',
                      button: true,
                      child: OutlinedButton.icon(
                        onPressed: _stopReading,
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                      ),
                    ),

                  // Save button
                  Semantics(
                    label:
                        'Save transcript button. Double tap to save the extracted text.',
                    button: true,
                    child: OutlinedButton.icon(
                      onPressed: _isSaving ? null : _saveTranscript,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save'),
                    ),
                  ),
                ],
              ),

              // TTS settings (expandable)
              ExpansionTile(
                title: const Text('Speech Settings'),
                leading: const Icon(Icons.settings_voice),
                children: [
                  // Speech rate slider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Speech Rate'),
                            Text('${(_speechRate * 100).toStringAsFixed(0)}%'),
                          ],
                        ),
                        Slider(
                          value: _speechRate,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          label: '${(_speechRate * 100).toStringAsFixed(0)}%',
                          onChanged: _updateSpeechRate,
                        ),
                      ],
                    ),
                  ),

                  // Pitch slider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pitch'),
                            Text(_pitch.toStringAsFixed(1)),
                          ],
                        ),
                        Slider(
                          value: _pitch,
                          min: 0.5,
                          max: 2.0,
                          divisions: 15,
                          label: _pitch.toStringAsFixed(1),
                          onChanged: _updatePitch,
                        ),
                      ],
                    ),
                  ),

                  // Volume slider
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Volume'),
                            Text('${(_volume * 100).toStringAsFixed(0)}%'),
                          ],
                        ),
                        Slider(
                          value: _volume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          label: '${(_volume * 100).toStringAsFixed(0)}%',
                          onChanged: _updateVolume,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
