import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Service for handling app permissions
///
/// Manages camera, storage, and microphone permissions required for:
/// - Camera access for scanning documents
/// - Storage access for saving transcripts and audio
/// - Microphone access for future voice commands
class PermissionService {
  /// Check if camera permission is granted
  /// This checks both permission_handler and tries to verify by initializing camera
  Future<bool> checkCameraPermission() async {
    // First check permission_handler
    var status = await permission_handler.Permission.camera.status;
    if (status.isGranted) {
      return true;
    }

    // If permission_handler says denied, verify by actually trying to use the camera
    // Sometimes permission_handler is out of sync with actual camera access
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        return false;
      }

      // Try to initialize a camera controller to verify permission
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await controller.initialize();
      // If we got here, permission is actually granted
      await controller.dispose();
      return true;
    } catch (e) {
      // If initialization fails, permission is truly denied
      return false;
    }
  }

  /// Check if camera permission is permanently denied
  /// Returns true if permission was permanently denied and user must go to settings
  Future<bool> isCameraPermissionPermanentlyDenied() async {
    final status = await permission_handler.Permission.camera.status;
    return status.isPermanentlyDenied;
  }

  /// Request camera permission
  /// Returns a map with 'granted' (bool) and 'permanentlyDenied' (bool)
  ///
  /// On iOS, calling availableCameras() from the camera package actually triggers
  /// the native permission dialog. This is the proper way to request camera permission.
  Future<Map<String, bool>> requestCameraPermissionWithStatus() async {
    try {
      // First check the current status using permission_handler
      var status = await permission_handler.Permission.camera.status;

      // If already granted, return true
      if (status.isGranted) {
        return {'granted': true, 'permanentlyDenied': false};
      }

      // If permanently denied, we can't show the native dialog anymore
      // Return false so the caller can prompt to go to settings
      if (status.isPermanentlyDenied) {
        return {'granted': false, 'permanentlyDenied': true};
      }

      // On iOS, the permission dialog appears when we actually try to initialize a CameraController
      // Just calling availableCameras() doesn't trigger it - we need to initialize the camera
      try {
        // Get available cameras first
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          status = await permission_handler.Permission.camera.request();
        } else {
          // Try to initialize a camera controller - THIS triggers the iOS permission dialog
          bool cameraInitialized = false;
          try {
            final controller = CameraController(
              cameras.first,
              ResolutionPreset.low,
              enableAudio: false,
            );
            // This initialization will trigger the iOS permission dialog
            await controller.initialize();
            cameraInitialized = true;
            // Dispose immediately since we only needed it to trigger permission
            await controller.dispose();
          } catch (e) {
            // If initialization fails, permission is likely denied
            cameraInitialized = false;
          }

          // If camera initialized successfully, permission is granted regardless of permission_handler status
          if (cameraInitialized) {
            return {'granted': true, 'permanentlyDenied': false};
          }
        }
      } catch (e) {
        // Fallback to permission_handler
        status = await permission_handler.Permission.camera.request();
      }

      // Wait a moment for iOS to update the permission status after the dialog
      await Future.delayed(const Duration(milliseconds: 500));

      // Check the status again after the request - check multiple times to ensure it's updated
      status = await permission_handler.Permission.camera.status;

      // If still denied, wait a bit more and check again (iOS sometimes takes a moment)
      if (!status.isGranted && !status.isPermanentlyDenied) {
        await Future.delayed(const Duration(milliseconds: 500));
        status = await permission_handler.Permission.camera.status;
      }

      // Return status from permission_handler
      // Note: If camera initialized successfully above, we already returned granted=true
      return {
        'granted': status.isGranted,
        'permanentlyDenied': status.isPermanentlyDenied,
      };
    } catch (e) {
      // If there's an error, log it and return false
      debugPrint('Error checking camera permission: $e');
      return {'granted': false, 'permanentlyDenied': false};
    }
  }

  /// Request camera permission
  /// Returns true if permission is granted, false otherwise
  ///
  /// This will show the native iOS permission dialog if the permission
  /// hasn't been permanently denied. If permanently denied, returns false
  /// and the caller should prompt the user to go to settings.
  Future<bool> requestCameraPermission() async {
    final result = await requestCameraPermissionWithStatus();
    return result['granted'] ?? false;
  }

  /// Check if storage permission is granted
  Future<bool> checkStoragePermission() async {
    if (await permission_handler.Permission.storage.isGranted) {
      return true;
    }
    // For Android 13+, check photos permission
    if (await permission_handler.Permission.photos.isGranted) {
      return true;
    }
    return false;
  }

  /// Request storage permission
  Future<bool> requestStoragePermission() async {
    // Request storage permission (for Android < 13)
    var status = await permission_handler.Permission.storage.request();
    if (status.isGranted) {
      return true;
    }

    // For Android 13+, request photos permission
    status = await permission_handler.Permission.photos.request();
    return status.isGranted;
  }

  /// Check if microphone permission is granted
  Future<bool> checkMicrophonePermission() async {
    final status = await permission_handler.Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission
  Future<bool> requestMicrophonePermission() async {
    final status = await permission_handler.Permission.microphone.request();
    return status.isGranted;
  }

  /// Check all required permissions
  /// Returns true if all permissions are granted
  Future<bool> checkAllPermissions() async {
    final camera = await checkCameraPermission();
    final storage = await checkStoragePermission();
    // Microphone is optional for now
    return camera && storage;
  }

  /// Request all required permissions
  /// Returns true if all permissions are granted
  Future<bool> requestAllPermissions() async {
    final camera = await requestCameraPermission();
    final storage = await requestStoragePermission();
    // Microphone is optional for now
    return camera && storage;
  }

  /// Open app settings so user can manually grant permissions
  ///
  /// Opens the device settings page where the user can manually grant permissions
  Future<bool> openAppSettings() async {
    // Use the permission_handler's top-level openAppSettings function
    return await permission_handler.openAppSettings();
  }
}
