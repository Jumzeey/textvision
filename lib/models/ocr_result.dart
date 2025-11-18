/// Model representing the result of OCR processing
/// 
/// Contains:
/// - Extracted text
/// - Confidence scores
/// - Processing metadata
/// - Text blocks with positions
class OCRResult {
  /// The full extracted text
  final String text;

  /// Formatted text with line breaks
  final String formattedText;

  /// Average confidence score (0.0 to 1.0, or null if not available)
  final double? confidence;

  /// Whether the text appears to be handwritten
  final bool isHandwritten;

  /// Processing time in milliseconds
  final int processingTimeMs;

  /// Number of text blocks detected
  final int blockCount;

  /// Number of lines detected
  final int lineCount;

  /// Timestamp when OCR was performed
  final DateTime timestamp;

  /// Image path that was processed
  final String? imagePath;

  OCRResult({
    required this.text,
    required this.formattedText,
    this.confidence,
    this.isHandwritten = false,
    required this.processingTimeMs,
    required this.blockCount,
    required this.lineCount,
    required this.timestamp,
    this.imagePath,
  });

  /// Create OCRResult from JSON
  factory OCRResult.fromJson(Map<String, dynamic> json) {
    return OCRResult(
      text: json['text'] as String,
      formattedText: json['formattedText'] as String,
      confidence: json['confidence'] as double?,
      isHandwritten: json['isHandwritten'] as bool? ?? false,
      processingTimeMs: json['processingTimeMs'] as int,
      blockCount: json['blockCount'] as int,
      lineCount: json['lineCount'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      imagePath: json['imagePath'] as String?,
    );
  }

  /// Convert OCRResult to JSON
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'formattedText': formattedText,
      'confidence': confidence,
      'isHandwritten': isHandwritten,
      'processingTimeMs': processingTimeMs,
      'blockCount': blockCount,
      'lineCount': lineCount,
      'timestamp': timestamp.toIso8601String(),
      'imagePath': imagePath,
    };
  }

  /// Check if OCR result is empty
  bool get isEmpty => text.trim().isEmpty;

  /// Check if OCR result has content
  bool get hasContent => !isEmpty;

  /// Get a summary of the OCR result
  String get summary {
    if (isEmpty) {
      return 'No text detected';
    }
    
    final wordCount = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    return 'Detected $wordCount words in $blockCount blocks, $lineCount lines';
  }
}








