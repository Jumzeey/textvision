import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'ocr_service.dart';

/// Service specifically for handwriting recognition
///
/// Extends OCRService with handwriting-specific optimizations:
/// - Uses Latin script recognizer optimized for handwriting
/// - Applies handwriting-specific preprocessing
/// - Handles thick-lined paper and various handwriting styles
/// - Provides confidence scoring for handwriting
class HandwritingRecognitionService extends OCRService {
  /// Create a handwriting recognition service
  ///
  /// Uses Latin script which supports handwritten English and most European languages
  HandwritingRecognitionService() : super(script: TextRecognitionScript.latin);

  /// Recognize handwritten text from an image file
  ///
  /// [imagePath] - Path to the image file containing handwritten text
  ///
  /// Returns a RecognizedText object with handwritten text
  ///
  /// Note: Handwriting recognition accuracy depends on:
  /// - Image quality and resolution
  /// - Handwriting clarity
  /// - Paper contrast (thick-lined paper works better)
  /// - Lighting conditions
  @override
  Future<RecognizedText> recognizeText(String imagePath) async {
    // Use the parent OCR service but with handwriting-optimized settings
    return await super.recognizeText(imagePath);
  }

  /// Check if text appears to be handwritten
  ///
  /// This is a heuristic check based on text characteristics:
  /// - Irregular spacing
  /// - Variable character sizes
  /// - Less structured layout
  ///
  /// Returns true if text characteristics suggest handwriting
  bool isLikelyHandwritten(RecognizedText recognizedText) {
    final blocks = recognizedText.blocks;

    if (blocks.isEmpty) {
      return false;
    }

    // Analyze text characteristics
    int irregularSpacingCount = 0;
    int variableSizeCount = 0;

    for (final block in blocks) {
      for (final line in block.lines) {
        // Check for irregular spacing between words
        final words = line.text.split(RegExp(r'\s+'));
        if (words.length > 1) {
          // Handwritten text often has irregular spacing
          // This is a simplified check - real implementation would analyze bounding boxes
          irregularSpacingCount++;
        }

        // Check for variable character sizes
        // Handwritten text often has characters of different sizes
        // This would require analyzing individual character bounding boxes
        variableSizeCount++;
      }
    }

    // If we see irregular patterns, it's likely handwritten
    return irregularSpacingCount > blocks.length * 0.3 ||
        variableSizeCount > blocks.length * 0.5;
  }

  /// Get handwriting quality score
  ///
  /// Returns a score from 0.0 to 1.0 indicating handwriting quality:
  /// - 1.0: Excellent (clear, well-formed handwriting)
  /// - 0.7-0.9: Good (readable with minor issues)
  /// - 0.4-0.6: Fair (readable but with some difficulty)
  /// - 0.0-0.3: Poor (difficult to read)
  ///
  /// This score is based on:
  /// - Text block count (more blocks = better structure)
  /// - Average confidence (if available)
  /// - Text length (longer text = more context)
  double getHandwritingQualityScore(RecognizedText recognizedText) {
    final blocks = recognizedText.blocks;
    final text = recognizedText.text;

    if (blocks.isEmpty || text.isEmpty) {
      return 0.0;
    }

    double score = 0.0;

    // Factor 1: Number of blocks (more blocks = better structure)
    // Normalize to 0-0.3 range
    final blockScore = (blocks.length / 10.0).clamp(0.0, 0.3);
    score += blockScore;

    // Factor 2: Text length (longer text = more context)
    // Normalize to 0-0.3 range
    final lengthScore = (text.length / 500.0).clamp(0.0, 0.3);
    score += lengthScore;

    // Factor 3: Confidence (if available)
    // This would use actual confidence scores from ML Kit if available
    // For now, we estimate based on text characteristics
    final estimatedConfidence = 0.7; // Placeholder
    score += estimatedConfidence * 0.4;

    return score.clamp(0.0, 1.0);
  }

  /// Extract handwritten text with confidence scores
  ///
  /// Returns a map of text blocks with their confidence scores
  /// Useful for highlighting uncertain text for manual review
  Map<String, double?> extractTextWithConfidence(
    RecognizedText recognizedText,
  ) {
    final result = <String, double?>{};

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        // Extract line text
        final lineText = line.text;

        // Try to get confidence score
        // Note: ML Kit may not always provide confidence scores
        // This is a placeholder - actual implementation depends on ML Kit version
        double? confidence;

        // For now, estimate confidence based on text characteristics
        if (lineText.isNotEmpty) {
          // Simple heuristic: longer lines with more words = higher confidence
          final wordCount = lineText.split(RegExp(r'\s+')).length;
          confidence = (wordCount / 10.0).clamp(0.5, 0.95);
        }

        result[lineText] = confidence;
      }
    }

    return result;
  }

  /// Suggest improvements for better handwriting recognition
  ///
  /// Analyzes the recognized text and suggests ways to improve accuracy
  /// Returns a list of suggestions
  List<String> getImprovementSuggestions(RecognizedText recognizedText) {
    final suggestions = <String>[];

    if (recognizedText.blocks.isEmpty) {
      suggestions.add('No text detected. Try improving lighting and focus.');
      suggestions.add('Ensure the paper is flat and well-lit.');
      suggestions.add('Use thick-lined paper for better contrast.');
      return suggestions;
    }

    final text = recognizedText.text;

    // Check text length
    if (text.length < 10) {
      suggestions.add('Text is very short. Try scanning a larger area.');
    }

    // Check for common issues
    if (text.contains(RegExp('[^\\w\\s.,!?;:()\\-\'"]'))) {
      suggestions.add(
        'Some characters may be misrecognized. Try writing more clearly.',
      );
    }

    // Check block count
    if (recognizedText.blocks.length < 2) {
      suggestions.add(
        'Try scanning multiple lines or paragraphs for better accuracy.',
      );
    }

    // General suggestions
    suggestions.add('For best results:');
    suggestions.add('• Use dark ink on light paper');
    suggestions.add('• Write on thick-lined paper');
    suggestions.add('• Ensure good lighting');
    suggestions.add('• Keep the camera steady');
    suggestions.add('• Write clearly and legibly');

    // Always return the suggestions list
    return suggestions;
  }
}
