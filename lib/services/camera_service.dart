import 'package:camera/camera.dart';
import 'dart:io';

/// Service for managing camera operations
/// 
/// Handles:
/// - Camera initialization
/// - Image capture
/// - Camera disposal
/// - Error handling
class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;

  /// Get the camera controller
  CameraController? get controller => _controller;

  /// Get available cameras
  List<CameraDescription>? get cameras => _cameras;

  /// Check if camera is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the camera
  /// 
  /// Attempts to use the back camera first (better quality for document scanning)
  /// Falls back to front camera if back camera is not available
  Future<void> initializeCamera() async {
    try {
      // Get available cameras
      _cameras = await availableCameras();
      
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No cameras available on this device');
      }

      // Prefer back camera for document scanning (better quality)
      CameraDescription? selectedCamera;
      
      for (final camera in _cameras!) {
        if (camera.lensDirection == CameraLensDirection.back) {
          selectedCamera = camera;
          break;
        }
      }

      // Fallback to first available camera if no back camera
      selectedCamera ??= _cameras!.first;

      // Initialize controller
      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high, // Use high resolution for better OCR accuracy
        enableAudio: false, // No audio needed for document scanning
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.jpeg
            : ImageFormatGroup.bgra8888,
      );

      // Initialize the camera
      await _controller!.initialize();
      
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      throw Exception('Failed to initialize camera: $e');
    }
  }

  /// Capture an image from the camera
  /// 
  /// Returns the captured XFile, or null if capture fails
  Future<XFile?> captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }

    try {
      final image = await _controller!.takePicture();
      return image;
    } catch (e) {
      throw Exception('Failed to capture image: $e');
    }
  }

  /// Dispose of camera resources
  Future<void> dispose() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
      _isInitialized = false;
    }
  }
}








