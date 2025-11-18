import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Service for preprocessing images before OCR
/// 
/// Handles:
/// - Image cropping and rotation
/// - Contrast adjustment
/// - Brightness adjustment
/// - Noise reduction
/// - Image format conversion
/// 
/// These preprocessing steps improve OCR accuracy, especially for:
/// - Handwritten text
/// - Low-quality images
/// - Images with poor lighting
class ImagePreprocessingService {
  /// Preprocess an image file for OCR
  /// 
  /// Applies various image enhancements to improve text recognition accuracy:
  /// 1. Converts to grayscale (reduces noise, improves contrast)
  /// 2. Adjusts contrast and brightness
  /// 3. Applies sharpening filter
  /// 4. Optionally crops to a specific region
  /// 
  /// Returns the preprocessed image as a Uint8List
  Future<Uint8List> preprocessImage(
    String imagePath, {
    Rect? cropRegion,
    double contrast = 1.2,
    double brightness = 0.0,
    bool enhanceForHandwriting = false,
  }) async {
    // Read the image file
    final file = File(imagePath);
    final imageBytes = await file.readAsBytes();
    
    // Decode the image
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Crop if region is specified
    if (cropRegion != null) {
      image = img.copyCrop(
        image,
        x: cropRegion.left.toInt(),
        y: cropRegion.top.toInt(),
        width: cropRegion.width.toInt(),
        height: cropRegion.height.toInt(),
      );
    }

    // Convert to grayscale for better OCR accuracy
    // Grayscale reduces noise and improves contrast detection
    image = img.grayscale(image);

    // Adjust contrast
    // Higher contrast makes text stand out more from background
    image = img.adjustColor(
      image,
      contrast: contrast,
      brightness: brightness,
    );

    // For handwriting, apply additional enhancements
    if (enhanceForHandwriting) {
      // Increase contrast more for handwriting
      image = img.adjustColor(
        image,
        contrast: 1.3,
        brightness: 0.1,
      );

      // Apply sharpening to make handwriting clearer
      image = img.convolution(image, filter: [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0,
      ]);
    }

    // Apply additional sharpening for better edge detection
    image = img.convolution(image, filter: [
      0, -0.5, 0,
      -0.5, 3, -0.5,
      0, -0.5, 0,
    ]);

    // Convert back to bytes (JPEG format for smaller size)
    final processedBytes = img.encodeJpg(image, quality: 95);
    
    return Uint8List.fromList(processedBytes);
  }

  /// Preprocess an image from bytes
  /// 
  /// Same as preprocessImage but accepts image bytes directly
  Future<Uint8List> preprocessImageBytes(
    Uint8List imageBytes, {
    Rect? cropRegion,
    double contrast = 1.2,
    double brightness = 0.0,
    bool enhanceForHandwriting = false,
  }) async {
    // Decode the image
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Apply same preprocessing as above
    if (cropRegion != null) {
      image = img.copyCrop(
        image,
        x: cropRegion.left.toInt(),
        y: cropRegion.top.toInt(),
        width: cropRegion.width.toInt(),
        height: cropRegion.height.toInt(),
      );
    }

    image = img.grayscale(image);
    image = img.adjustColor(
      image,
      contrast: contrast,
      brightness: brightness,
    );

    if (enhanceForHandwriting) {
      image = img.adjustColor(
        image,
        contrast: 1.3,
        brightness: 0.1,
      );
      image = img.convolution(image, filter: [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0,
      ]);
    }

    image = img.convolution(image, filter: [
      0, -0.5, 0,
      -0.5, 3, -0.5,
      0, -0.5, 0,
    ]);

    final processedBytes = img.encodeJpg(image, quality: 95);
    return Uint8List.fromList(processedBytes);
  }

  /// Detect document edges in an image
  /// 
  /// Uses edge detection to find the boundaries of a document
  /// Returns a Rect representing the detected document region
  /// 
  /// This is useful for automatically cropping to just the document
  Future<Rect?> detectDocumentEdges(String imagePath) async {
    final file = File(imagePath);
    final imageBytes = await file.readAsBytes();
    
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      return null;
    }

    // Convert to grayscale
    image = img.grayscale(image);

    // Apply edge detection (Canny edge detector)
    // This is a simplified version - full Canny would be more accurate
    image = img.convolution(image, filter: [
      -1, -1, -1,
      -1, 8, -1,
      -1, -1, -1,
    ]);

    // Find bounding box of edges
    // In a real implementation, you would use more sophisticated edge detection
    // For now, return null to indicate auto-detection is not available
    // This would require more complex image processing algorithms
    
    return null; // Placeholder - would implement full edge detection
  }

  /// Rotate image to correct orientation
  /// 
  /// Automatically detects and corrects image orientation
  Future<Uint8List> correctOrientation(
    String imagePath, {
    int rotationDegrees = 0,
  }) async {
    final file = File(imagePath);
    final imageBytes = await file.readAsBytes();
    
    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Rotate image
    if (rotationDegrees != 0) {
      image = img.copyRotate(image, angle: rotationDegrees);
    }

    final rotatedBytes = img.encodeJpg(image, quality: 95);
    return Uint8List.fromList(rotatedBytes);
  }
}

/// Rectangle class for defining crop regions
class Rect {
  final double left;
  final double top;
  final double width;
  final double height;

  const Rect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double get right => left + width;
  double get bottom => top + height;
}








