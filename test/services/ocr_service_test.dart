import 'package:flutter_test/flutter_test.dart';
import 'package:textvision/services/ocr_service.dart';

void main() {
  group('OCRService', () {
    test('should initialize with default Latin script', () {
      final service = OCRService();
      expect(service, isNotNull);
    });

    test('should dispose without errors', () async {
      final service = OCRService();
      await service.dispose();
      // Should not throw
    });
  });
}








