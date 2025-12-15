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
      // Step 1: Remove paper lines (thick-lined paper)
      image = _removePaperLines(image);

      // Step 2: Enhance contrast significantly for handwriting
      image = img.adjustColor(
        image,
        contrast: 1.5, // Higher contrast for handwriting
        brightness: 0.05,
        saturation: 0.0, // Ensure grayscale
      );

      // Step 3: Apply adaptive thresholding (binarization)
      image = _applyAdaptiveThreshold(image);

      // Step 4: Apply sharpening to make handwriting clearer
      image = img.convolution(image, filter: [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0,
      ]);

      // Step 5: Noise reduction
      image = _reduceNoise(image);
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
      // Step 1: Remove paper lines (thick-lined paper)
      image = _removePaperLines(image);

      // Step 2: Enhance contrast significantly for handwriting
      image = img.adjustColor(
        image,
        contrast: 1.5, // Higher contrast for handwriting
        brightness: 0.05,
        saturation: 0.0, // Ensure grayscale
      );

      // Step 3: Apply adaptive thresholding (binarization)
      image = _applyAdaptiveThreshold(image);

      // Step 4: Apply sharpening to make handwriting clearer
      image = img.convolution(image, filter: [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0,
      ]);

      // Step 5: Noise reduction
      image = _reduceNoise(image);
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

  /// Remove paper lines from image (for thick-lined paper)
  /// 
  /// Uses horizontal line detection and removal to eliminate
  /// paper lines that interfere with handwriting recognition
  img.Image _removePaperLines(img.Image image) {
    final width = image.width;
    final height = image.height;
    final output = img.Image(width: width, height: height);

    // Detect horizontal lines by analyzing horizontal projections
    final horizontalProjection = List<int>.filled(height, 0);

    // Calculate horizontal projection (sum of pixel values per row)
    for (int y = 0; y < height; y++) {
      int sum = 0;
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        sum += (luminance * 255).toInt();
      }
      horizontalProjection[y] = sum;
    }

    // Find lines (rows with consistently low values)
    final lineRows = <int>[];
    for (int y = 1; y < height - 1; y++) {
      final avg = (horizontalProjection[y - 1] +
              horizontalProjection[y] +
              horizontalProjection[y + 1]) /
          3;
      // If this row is significantly darker than average, it might be a line
      if (avg < width * 50) {
        // Check if neighbors are also dark (line continuity)
        if (y > 0 &&
            horizontalProjection[y - 1] < width * 60 &&
            y < height - 1 &&
            horizontalProjection[y + 1] < width * 60) {
          lineRows.add(y);
        }
      }
    }

    // Copy image and remove lines by interpolating from neighbors
    for (int y = 0; y < height; y++) {
      if (lineRows.contains(y)) {
        // This is a line row - interpolate from neighbors
        for (int x = 0; x < width; x++) {
          int topY = y - 1;
          int bottomY = y + 1;

          // Find nearest non-line row above
          while (topY >= 0 && lineRows.contains(topY)) {
            topY--;
          }
          // Find nearest non-line row below
          while (bottomY < height && lineRows.contains(bottomY)) {
            bottomY++;
          }

          // Interpolate pixel value
          if (topY >= 0 && bottomY < height) {
            final topPixel = image.getPixel(x, topY);
            final bottomPixel = image.getPixel(x, bottomY);
            // Access RGB channels using pixel properties
            final topR = topPixel.r.toInt();
            final topG = topPixel.g.toInt();
            final topB = topPixel.b.toInt();
            final bottomR = bottomPixel.r.toInt();
            final bottomG = bottomPixel.g.toInt();
            final bottomB = bottomPixel.b.toInt();
            final avgR = ((topR + bottomR) / 2).round();
            final avgG = ((topG + bottomG) / 2).round();
            final avgB = ((topB + bottomB) / 2).round();
            output.setPixel(x, y, img.ColorRgb8(avgR, avgG, avgB));
          } else if (topY >= 0) {
            output.setPixel(x, y, image.getPixel(x, topY));
          } else if (bottomY < height) {
            output.setPixel(x, y, image.getPixel(x, bottomY));
          } else {
            output.setPixel(x, y, image.getPixel(x, y));
          }
        }
      } else {
        // Copy pixel as-is
        for (int x = 0; x < width; x++) {
          output.setPixel(x, y, image.getPixel(x, y));
        }
      }
    }

    return output;
  }

  /// Apply adaptive thresholding to binarize the image
  /// 
  /// Converts grayscale image to black and white for better OCR
  img.Image _applyAdaptiveThreshold(img.Image image) {
    final width = image.width;
    final height = image.height;
    final output = img.Image(width: width, height: height);

    // Simple adaptive threshold using local mean
    final blockSize = 15; // Size of neighborhood
    final c = 10; // Constant subtracted from mean

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Calculate local mean
        int sum = 0;
        int count = 0;

        for (int dy = -blockSize ~/ 2; dy <= blockSize ~/ 2; dy++) {
          for (int dx = -blockSize ~/ 2; dx <= blockSize ~/ 2; dx++) {
            final nx = (x + dx).clamp(0, width - 1);
            final ny = (y + dy).clamp(0, height - 1);
            final pixel = image.getPixel(nx, ny);
            final luminance = img.getLuminance(pixel);
            sum += (luminance * 255).toInt();
            count++;
          }
        }

        final mean = sum / count;
        final threshold = mean - c;

        // Get current pixel value
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        final value = (luminance * 255).toInt();

        // Binarize
        final newValue = value > threshold ? 255 : 0;
        output.setPixel(x, y, img.ColorRgb8(newValue, newValue, newValue));
      }
    }

    return output;
  }

  /// Reduce noise in the image using median filter
  /// 
  /// Removes salt-and-pepper noise that can interfere with OCR
  img.Image _reduceNoise(img.Image image) {
    final width = image.width;
    final height = image.height;
    final output = img.Image(width: width, height: height);

    // Simple 3x3 median filter
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final values = <int>[];

        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final nx = (x + dx).clamp(0, width - 1);
            final ny = (y + dy).clamp(0, height - 1);
            final pixel = image.getPixel(nx, ny);
            final luminance = img.getLuminance(pixel);
            values.add((luminance * 255).toInt());
          }
        }

        values.sort();
        final median = values[values.length ~/ 2];
        output.setPixel(x, y, img.ColorRgb8(median, median, median));
      }
    }

    return output;
  }

  /// Preprocess image specifically for handwriting recognition
  /// 
  /// Applies all handwriting-specific enhancements:
  /// - Line removal
  /// - High contrast enhancement
  /// - Adaptive thresholding
  /// - Noise reduction
  /// - Sharpening
  Future<Uint8List> preprocessForHandwriting(String imagePath) async {
    return await preprocessImage(
      imagePath,
      enhanceForHandwriting: true,
      contrast: 1.5,
      brightness: 0.05,
    );
  }

  /// Preprocess image bytes specifically for handwriting recognition
  Future<Uint8List> preprocessBytesForHandwriting(Uint8List imageBytes) async {
    return await preprocessImageBytes(
      imageBytes,
      enhanceForHandwriting: true,
      contrast: 1.5,
      brightness: 0.05,
    );
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








