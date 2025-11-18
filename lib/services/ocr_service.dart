import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service for performing OCR (Optical Character Recognition) on images
///
/// Uses Google ML Kit's on-device text recognition to extract:
/// - Printed text (Latin script)
/// - Handwritten text (when supported)
/// - Text in various languages
///
/// All processing is done on-device for offline support and privacy
class OCRService {
  final TextRecognizer _textRecognizer;
  bool _isDisposed = false;

  /// Create an OCR service instance
  ///
  /// [script] - The text recognition script to use
  ///   - TextRecognitionScript.latin: For printed Latin text (English, Spanish, etc.)
  ///   - TextRecognitionScript.chinese: For Chinese text
  ///   - TextRecognitionScript.devanagari: For Devanagari script
  ///   - TextRecognitionScript.japanese: For Japanese text
  ///   - TextRecognitionScript.korean: For Korean text
  ///
  /// Default is Latin script for English and most European languages
  OCRService({TextRecognitionScript script = TextRecognitionScript.latin})
    : _textRecognizer = TextRecognizer(script: script);

  /// Recognize text from an image file
  ///
  /// [imagePath] - Path to the image file
  ///
  /// Returns a RecognizedText object containing all detected text blocks
  /// with their bounding boxes and confidence scores
  Future<RecognizedText> recognizeText(String imagePath) async {
    if (_isDisposed) {
      throw Exception('OCRService has been disposed');
    }

    try {
      // Create InputImage from file path
      final inputImage = InputImage.fromFilePath(imagePath);

      // Process the image
      final recognizedText = await _textRecognizer.processImage(inputImage);

      return recognizedText;
    } catch (e) {
      throw Exception('Failed to recognize text: $e');
    }
  }

  /// Recognize text from image bytes
  ///
  /// [imageBytes] - Image data as bytes
  /// [metadata] - Image metadata (width, height, rotation, etc.)
  ///
  /// Returns a RecognizedText object containing all detected text blocks
  Future<RecognizedText> recognizeTextFromBytes(
    Uint8List imageBytes,
    InputImageMetadata metadata,
  ) async {
    if (_isDisposed) {
      throw Exception('OCRService has been disposed');
    }

    try {
      // Create InputImage from bytes
      final inputImage = InputImage.fromBytes(
        bytes: imageBytes,
        metadata: metadata,
      );

      // Process the image
      final recognizedText = await _textRecognizer.processImage(inputImage);

      return recognizedText;
    } catch (e) {
      throw Exception('Failed to recognize text: $e');
    }
  }

  /// Extract plain text from recognized text
  ///
  /// [recognizedText] - The RecognizedText object from recognizeText()
  ///
  /// Returns a string containing all recognized text
  String extractPlainText(RecognizedText recognizedText) {
    return recognizedText.text;
  }

  /// Extract text blocks with confidence scores
  ///
  /// [recognizedText] - The RecognizedText object from recognizeText()
  ///
  /// Returns a list of TextBlock objects, each containing:
  /// - Text content
  /// - Bounding box coordinates
  /// - Confidence score (if available)
  List<TextBlock> extractTextBlocks(RecognizedText recognizedText) {
    return recognizedText.blocks;
  }

  /// Extract text lines from recognized text
  ///
  /// [recognizedText] - The RecognizedText object from recognizeText()
  ///
  /// Returns a list of TextLine objects, useful for reading text line by line
  List<TextLine> extractTextLines(RecognizedText recognizedText) {
    final lines = <TextLine>[];
    for (final block in recognizedText.blocks) {
      lines.addAll(block.lines);
    }
    return lines;
  }

  /// Get average confidence score for recognized text
  ///
  /// Note: Google ML Kit doesn't always provide confidence scores
  /// This method returns null if confidence scores are not available
  double? getAverageConfidence(RecognizedText recognizedText) {
    // Note: Google ML Kit's text recognition API doesn't provide
    // confidence scores for individual text elements. This method
    // returns null to indicate that confidence scores are not available.
    // Future versions of ML Kit may add this feature.
    return null;
  }

  /// Dispose of the text recognizer
  ///
  /// Call this when done using the OCR service to free up resources
  Future<void> dispose() async {
    if (!_isDisposed) {
      await _textRecognizer.close();
      _isDisposed = true;
    }
  }
}

/// Extension to add confidence scoring helper methods
extension RecognizedTextExtensions on RecognizedText {
  /// Get all text as a single string with line breaks
  String get formattedText {
    final buffer = StringBuffer();
    for (final block in blocks) {
      for (final line in block.lines) {
        buffer.writeln(line.text);
      }
      buffer.writeln(); // Add blank line between blocks
    }
    return buffer.toString().trim();
  }

  /// Get text blocks sorted by position (top to bottom, left to right)
  List<TextBlock> get sortedBlocks {
    final sorted = List<TextBlock>.from(blocks);
    sorted.sort((a, b) {
      // Sort by top position first, then by left position
      final topDiff = a.boundingBox.top - b.boundingBox.top;
      if (topDiff.abs() > 10) {
        // Different rows
        return topDiff.toInt();
      }
      // Same row, sort by left position
      return (a.boundingBox.left - b.boundingBox.left).toInt();
    });
    return sorted;
  }
}
