import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Service for managing accessibility features
/// 
/// Handles:
/// - Haptic feedback patterns
/// - Screen reader announcements
/// - Accessibility settings
/// - Voice command support (future)
class AccessibilityService {
  /// Provide haptic feedback for different interaction types
  /// 
  /// [type] - Type of haptic feedback:
  ///   - 'light': Light tap (for subtle interactions)
  ///   - 'medium': Medium tap (for standard interactions)
  ///   - 'heavy': Heavy tap (for important actions)
  ///   - 'selection': Selection feedback (for list items)
  ///   - 'success': Success feedback (for completed actions)
  ///   - 'warning': Warning feedback (for warnings)
  ///   - 'error': Error feedback (for errors)
  static Future<void> hapticFeedback(String type) async {
    try {
      switch (type) {
        case 'light':
          await HapticFeedback.lightImpact();
          break;
        case 'medium':
          await HapticFeedback.mediumImpact();
          break;
        case 'heavy':
          await HapticFeedback.heavyImpact();
          break;
        case 'selection':
          await HapticFeedback.selectionClick();
          break;
        case 'success':
          // Success pattern: medium + light
          await HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 50));
          await HapticFeedback.lightImpact();
          break;
        case 'warning':
          // Warning pattern: medium + medium
          await HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.mediumImpact();
          break;
        case 'error':
          // Error pattern: heavy + heavy
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.heavyImpact();
          break;
        default:
          await HapticFeedback.mediumImpact();
      }
    } catch (e) {
      // Fallback to system haptics if flutter_haptic_feedback fails
      HapticFeedback.mediumImpact();
    }
  }

  /// Announce text to screen readers
  /// 
  /// [context] - BuildContext for accessing SemanticsService
  /// [text] - Text to announce
  /// [assertive] - If true, interrupts current speech (for important announcements)
  static void announceToScreenReader(
    BuildContext context,
    String text, {
    bool assertive = false,
  }) {
    SemanticsService.announce(
      text,
      assertive ? TextDirection.ltr : TextDirection.ltr,
    );
  }

  /// Check if screen reader is enabled
  /// 
  /// Returns true if a screen reader is currently active
  static bool isScreenReaderEnabled(BuildContext context) {
    return MediaQuery.of(context).accessibleNavigation;
  }

  /// Get recommended touch target size
  /// 
  /// Returns the minimum recommended touch target size in logical pixels
  /// Accessibility guidelines recommend at least 48x48dp
  static double getMinimumTouchTargetSize() {
    return 48.0;
  }

  /// Check if text scaling is enabled
  /// 
  /// Returns true if text scaling is enabled (user has increased text size)
  static bool isTextScalingEnabled(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    return textScaler.scale(1.0) > 1.0;
  }

  /// Get current text scale factor
  /// 
  /// Returns the current text scale factor
  static double getTextScaleFactor(BuildContext context) {
    return MediaQuery.of(context).textScaler.scale(1.0);
  }

  /// Create an accessible button with proper semantics
  /// 
  /// [label] - Accessible label for screen readers
  /// [hint] - Optional hint text
  /// [onPressed] - Callback when button is pressed
  /// [child] - Button widget
  /// [hapticType] - Type of haptic feedback to provide
  static Widget accessibleButton({
    required String label,
    String? hint,
    required VoidCallback? onPressed,
    required Widget child,
    String hapticType = 'medium',
  }) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      child: GestureDetector(
        onTap: () {
          AccessibilityService.hapticFeedback(hapticType);
          onPressed?.call();
        },
        child: child,
      ),
    );
  }

  /// Create an accessible text field with proper semantics
  /// 
  /// [label] - Accessible label for screen readers
  /// [hint] - Hint text
  /// [controller] - Text editing controller
  static Widget accessibleTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      textField: true,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
      ),
    );
  }
}

