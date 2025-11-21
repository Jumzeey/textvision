import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';

/// Main entry point for the TextVision app
///
/// This app assists blind students during exams by:
/// - Scanning exam papers using the device camera
/// - Extracting both printed and handwritten text using offline OCR (Google ML Kit)
/// - Reading the recognized text aloud using text-to-speech
/// - Providing full accessibility features for screen readers
/// - Works completely offline - no internet connection required
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file (if needed for future features)
  // Note: No longer required for OCR as we use offline Google ML Kit
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: Could not load .env file: $e');
  }

  // Set preferred orientations to support both portrait and landscape
  // This is important for camera scanning in different orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const TextVisionApp());
}

/// Root widget of the TextVision application
///
/// Configures the Material app with accessibility features and theme
class TextVisionApp extends StatelessWidget {
  const TextVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TextVision - Exam Assistant',
      debugShowCheckedModeBanner: false,

      // Theme configuration optimized for accessibility
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),

        // Enhanced text contrast for better readability
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
        ),

        // Elevated button style for better touch targets
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(88, 48), // Minimum touch target size
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Icon button style with larger touch targets
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(48, 48), // Accessibility minimum
          ),
        ),
      ),

      // Dark theme for users who prefer it
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(88, 48),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
      ),

      // Start with the home screen
      home: const HomeScreen(),

      // Enable semantic labels for screen readers
      builder: (context, child) {
        return MediaQuery(
          // Ensure text scaling respects accessibility settings
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.of(context).textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor:
                  1.3, // Prevent excessive scaling that breaks layout
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
