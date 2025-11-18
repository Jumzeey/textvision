import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import 'camera_scan_screen.dart';

/// Home screen of the TextVision app
///
/// Provides the main navigation interface with large, accessible buttons
/// for blind students to easily navigate the app using screen readers.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PermissionService _permissionService = PermissionService();
  bool _isCheckingPermissions = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    // Check permissions when the screen loads
    _checkPermissions();
  }

  /// Check and request camera permission on app startup
  Future<void> _checkPermissions() async {
    setState(() {
      _isCheckingPermissions = true;
    });

    try {
      // Check camera permission status
      final hasCameraPermission = await _permissionService
          .checkCameraPermission();

      if (!hasCameraPermission && mounted) {
        // Camera permission not granted - request it
        debugPrint('Camera permission not granted on startup, requesting...');

        // Wait a moment for the UI to be ready
        await Future.delayed(const Duration(milliseconds: 800));

        // Check if it's permanently denied BEFORE requesting
        final isPermanentlyDeniedBefore = await _permissionService
            .isCameraPermissionPermanentlyDenied();

        if (isPermanentlyDeniedBefore && mounted) {
          // Already permanently denied - show Settings dialog
          debugPrint('Camera permission already permanently denied on startup');
          _showStartupPermissionDialog();
        } else {
          // Not permanently denied - try to show native iOS dialog
          debugPrint(
            'Requesting camera permission (will show native iOS dialog)...',
          );
          final permissionResult = await _permissionService
              .requestCameraPermissionWithStatus();
          final hasPermissions = permissionResult['granted'] ?? false;
          final isPermanentlyDeniedAfter =
              permissionResult['permanentlyDenied'] ?? false;

          if (!hasPermissions && mounted) {
            if (isPermanentlyDeniedAfter) {
              // Just became permanently denied - show dialog to go to Settings
              debugPrint(
                'Camera permission became permanently denied after request',
              );
              _showStartupPermissionDialog();
            } else {
              // Permission was denied but not permanently - native dialog was shown
              // User can try again later, no need to show anything
              debugPrint(
                'Camera permission denied (not permanent) - native dialog was shown',
              );
            }
          } else if (hasPermissions) {
            debugPrint('Camera permission granted on startup');
          }
        }
      } else {
        debugPrint('Camera permission already granted');
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPermissions = false;
        });
      }
    }
  }

  /// Navigate to camera scan screen
  Future<void> _navigateToCameraScan({bool isHandwriting = false}) async {
    if (_isNavigating) {
      debugPrint('Navigation already in progress, ignoring request');
      return;
    }

    debugPrint('_navigateToCameraScan called, isHandwriting: $isHandwriting');
    setState(() {
      _isNavigating = true;
    });

    try {
      // First check if permission is already granted (don't request again if it is)
      debugPrint('Checking current camera permission status...');
      final alreadyGranted = await _permissionService.checkCameraPermission();

      if (alreadyGranted) {
        debugPrint(
          'Camera permission already granted, proceeding to camera screen',
        );
        // Permission already granted, navigate directly
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CameraScanScreen(isHandwriting: isHandwriting),
            ),
          );
        }
        return;
      }

      // Permission not granted, request it
      debugPrint('Camera permission not granted, requesting...');
      final permissionResult = await _permissionService
          .requestCameraPermissionWithStatus();
      final hasPermissions = permissionResult['granted'] ?? false;
      final isPermanentlyDeniedAfterRequest =
          permissionResult['permanentlyDenied'] ?? false;
      debugPrint(
        'Camera permission granted: $hasPermissions, permanently denied: $isPermanentlyDeniedAfterRequest',
      );

      if (!hasPermissions && mounted) {
        if (isPermanentlyDeniedAfterRequest) {
          // Show dialog to go to settings
          debugPrint(
            'Showing settings dialog - permission is permanently denied',
          );
          _showPermissionDeniedDialog();
        } else {
          // User just denied (not permanently) - show a message
          debugPrint('Permission denied but not permanently, showing snackbar');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Camera permission was denied. Please tap the button again and allow camera access when prompted.',
                ),
                duration: Duration(seconds: 4),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        return;
      }

      // Permission granted, navigate to camera screen
      if (hasPermissions && mounted) {
        debugPrint(
          'Camera permission granted, navigating to CameraScanScreen...',
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CameraScanScreen(isHandwriting: isHandwriting),
          ),
        );
      } else {
        debugPrint(
          'Widget not mounted or permission not granted, cannot navigate',
        );
      }
    } catch (e) {
      // Handle any errors that might occur
      debugPrint('Error navigating to camera scan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isNavigating = false;
        });
      }
    }
  }

  /// Show dialog when permissions are permanently denied (on startup)
  /// Only shown when permission is permanently denied - otherwise native iOS dialog is used
  void _showStartupPermissionDialog() {
    // Only show this if the widget is still mounted
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true, // Allow dismissing
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'TextVision needs camera access to scan exam papers and extract text.\n\n'
          'The camera permission was previously denied. Please enable it in Settings:\n\n'
          '1. Tap "Open Settings" below\n'
          '2. Find "Camera" in the list\n'
          '3. Toggle it ON\n'
          '4. Return to the app',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _permissionService.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Show dialog when permissions are permanently denied (when trying to scan)
  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'TextVision needs camera access to scan exam papers. '
          'Please enable camera permission in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _permissionService.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TextVision'),
        centerTitle: true,
        // Provide semantic label for screen readers
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App title and description
              const Icon(Icons.visibility_off, size: 80, color: Colors.blue),
              const SizedBox(height: 24),

              const Text(
                'TextVision',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              const Text(
                'Exam Assistant for Blind Students',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 48),

              // Main action button - Scan Printed Text
              Semantics(
                label:
                    'Scan printed exam paper button. Double tap to open camera and scan printed text.',
                button: true,
                child: ElevatedButton.icon(
                  onPressed: (_isCheckingPermissions || _isNavigating)
                      ? null
                      : () {
                          debugPrint('Scan Printed Text button pressed');
                          _navigateToCameraScan(isHandwriting: false);
                        },
                  icon: const Icon(Icons.camera_alt, size: 28),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'Scan Printed Text',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(20),
                    minimumSize: const Size(double.infinity, 72),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Handwriting scan button
              Semantics(
                label:
                    'Scan handwritten exam paper button. Double tap to open camera and scan handwritten text.',
                button: true,
                child: ElevatedButton.icon(
                  onPressed: (_isCheckingPermissions || _isNavigating)
                      ? null
                      : () {
                          debugPrint('Scan Handwriting button pressed');
                          _navigateToCameraScan(isHandwriting: true);
                        },
                  icon: const Icon(Icons.edit, size: 28),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'Scan Handwriting',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(20),
                    minimumSize: const Size(double.infinity, 72),
                  ),
                ),
              ),

              const Spacer(),

              // Footer information
              const Text(
                'Place your exam paper in front of the camera and tap the scan button.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
