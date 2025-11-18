import 'package:flutter_test/flutter_test.dart';
import 'package:textvision/models/ocr_result.dart';

void main() {
  group('OCRResult', () {
    test('should create OCRResult with all fields', () {
      final result = OCRResult(
        text: 'Sample text',
        formattedText: 'Sample\ntext',
        confidence: 0.95,
        isHandwritten: false,
        processingTimeMs: 1000,
        blockCount: 2,
        lineCount: 2,
        timestamp: DateTime.now(),
        imagePath: '/path/to/image.jpg',
      );

      expect(result.text, 'Sample text');
      expect(result.formattedText, 'Sample\ntext');
      expect(result.confidence, 0.95);
      expect(result.isHandwritten, false);
      expect(result.processingTimeMs, 1000);
      expect(result.blockCount, 2);
      expect(result.lineCount, 2);
      expect(result.imagePath, '/path/to/image.jpg');
    });

    test('should identify empty result', () {
      final emptyResult = OCRResult(
        text: '',
        formattedText: '',
        processingTimeMs: 0,
        blockCount: 0,
        lineCount: 0,
        timestamp: DateTime.now(),
      );

      expect(emptyResult.isEmpty, true);
      expect(emptyResult.hasContent, false);
    });

    test('should identify non-empty result', () {
      final result = OCRResult(
        text: 'Sample text',
        formattedText: 'Sample text',
        processingTimeMs: 1000,
        blockCount: 1,
        lineCount: 1,
        timestamp: DateTime.now(),
      );

      expect(result.isEmpty, false);
      expect(result.hasContent, true);
    });

    test('should generate summary', () {
      final result = OCRResult(
        text: 'This is a sample text with multiple words',
        formattedText: 'This is a sample text\nwith multiple words',
        processingTimeMs: 1000,
        blockCount: 2,
        lineCount: 2,
        timestamp: DateTime.now(),
      );

      final summary = result.summary;
      expect(summary, contains('words'));
      expect(summary, contains('blocks'));
      expect(summary, contains('lines'));
    });

    test('should serialize to JSON', () {
      final result = OCRResult(
        text: 'Sample text',
        formattedText: 'Sample text',
        confidence: 0.95,
        isHandwritten: false,
        processingTimeMs: 1000,
        blockCount: 2,
        lineCount: 2,
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        imagePath: '/path/to/image.jpg',
      );

      final json = result.toJson();
      expect(json['text'], 'Sample text');
      expect(json['formattedText'], 'Sample text');
      expect(json['confidence'], 0.95);
      expect(json['isHandwritten'], false);
      expect(json['processingTimeMs'], 1000);
      expect(json['blockCount'], 2);
      expect(json['lineCount'], 2);
      expect(json['imagePath'], '/path/to/image.jpg');
    });

    test('should deserialize from JSON', () {
      final json = {
        'text': 'Sample text',
        'formattedText': 'Sample text',
        'confidence': 0.95,
        'isHandwritten': false,
        'processingTimeMs': 1000,
        'blockCount': 2,
        'lineCount': 2,
        'timestamp': '2024-01-01T12:00:00.000Z',
        'imagePath': '/path/to/image.jpg',
      };

      final result = OCRResult.fromJson(json);
      expect(result.text, 'Sample text');
      expect(result.formattedText, 'Sample text');
      expect(result.confidence, 0.95);
      expect(result.isHandwritten, false);
      expect(result.processingTimeMs, 1000);
      expect(result.blockCount, 2);
      expect(result.lineCount, 2);
      expect(result.imagePath, '/path/to/image.jpg');
    });
  });
}





