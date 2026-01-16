import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// Gemini Vision Service for AI-powered text extraction
///
/// Optimized for blind users:
/// - Extracts text and restructures it for natural TTS reading
/// - Handles handwriting, tables, complex layouts
/// - Groups related ideas into paragraphs
/// - Announces sections clearly
///
/// SECURITY NOTE: For production, move API key to:
/// - Backend proxy (recommended), OR
/// - Encrypted storage with rate limiting
/// Never hardcode in release builds.
class GeminiVisionService {
  // API Configuration
  // API key is loaded from --dart-define (CI/CD) or .env file (local dev)
  static String get _apiKey {
    // First try --dart-define (for CI/CD like Codemagic)
    // This is the recommended, production-safe way to pass secrets
    const dartDefineKey = String.fromEnvironment('GEMINI_API_KEY');
    if (dartDefineKey.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('GeminiVisionService: Using API key from --dart-define');
      }
      return dartDefineKey;
    }

    // Fall back to .env file (for local development)
    final dotenvKey = dotenv.env['GEMINI_API_KEY'];
    if (dotenvKey != null && dotenvKey.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('GeminiVisionService: Using API key from .env file');
      }
      return dotenvKey;
    }

    // Debug: Log what we checked
    if (kDebugMode) {
      debugPrint('GeminiVisionService: API key not found!');
      debugPrint(
        '  - String.fromEnvironment("GEMINI_API_KEY"): ${dartDefineKey.isEmpty ? "empty" : "found"}',
      );
      debugPrint(
        '  - dotenv.env["GEMINI_API_KEY"]: ${dotenvKey != null ? "exists but empty" : "null"}',
      );
    }

    throw Exception(
      'GEMINI_API_KEY not found. '
      'For CI/CD: Pass --dart-define=GEMINI_API_KEY=your_key_here in your build command. '
      'For local dev: Create a .env file with GEMINI_API_KEY=your_key_here',
    );
  }

  static const String _model = 'gemini-2.0-flash'; // Latest fast model
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Verify API key is accessible (for debugging)
  /// Returns true if API key is found, false otherwise
  static bool verifyApiKey() {
    try {
      final key = _apiKey;
      if (kDebugMode) {
        debugPrint('✅ Gemini API key verified (length: ${key.length})');
      }
      return key.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Gemini API key verification failed: $e');
      }
      return false;
    }
  }

  /// The accessibility-optimized prompt for blind users
  static const String _accessibilityPrompt = '''
You are an accessibility reading assistant for blind and visually impaired users.

Your task:
- Extract all readable text from the image.
- Reconstruct it into natural, fluent spoken language.
- Preserve the original meaning exactly.
- Do NOT mention visual artifacts like "line", "box", or "handwritten".

Rules:
- Group related ideas into short paragraphs.
- Announce sections clearly (for example: "Part A", "Question B", "Conclusion").
- Convert bullet points and lists into spoken sentences.
- Remove visual line breaks that would sound unnatural when spoken.
- Insert natural pauses using commas and full stops.
- Read numbers and symbols in a way that sounds natural when spoken aloud.
- For multiple choice questions, read as: "Question number, then the question, then Option A, Option B, Option C, Option D."
- Do NOT add new information.
- Do NOT summarize.
- Return plain text only, no markdown, no explanations.

The output must be comfortable and easy to understand when read aloud slowly.
''';

  /// Process an image file with Gemini Vision API
  /// Returns extracted text optimized for TTS
  Future<String> processImage(File imageFile) async {
    try {
      debugPrint('📸 Gemini: Starting image processing...');

      // Step 1: Prepare image (resize, compress)
      final preparedImage = await _prepareImage(imageFile);
      debugPrint('📸 Gemini: Image prepared (${preparedImage.length} bytes)');

      // Step 2: Convert to base64
      final base64Image = base64Encode(preparedImage);
      debugPrint('📸 Gemini: Image encoded to base64');

      // Step 3: Call Gemini API
      debugPrint('📸 Gemini: Calling API...');
      final response = await _callGeminiApi(base64Image);
      debugPrint('📸 Gemini: API call successful');

      return response;
    } catch (e, stackTrace) {
      debugPrint('❌ Gemini Vision error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Process image from path
  Future<String> processImageFromPath(String imagePath) async {
    return processImage(File(imagePath));
  }

  /// Prepare image for API (resize, compress)
  /// Critical for accuracy, speed, and cost
  Future<Uint8List> _prepareImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();

    // Decode image
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Resize if too large (max 1280px width)
    img.Image resized;
    if (image.width > 1280) {
      resized = img.copyResize(image, width: 1280);
    } else {
      resized = image;
    }

    // Encode as JPEG with 70% quality
    final compressed = img.encodeJpg(resized, quality: 70);

    debugPrint('Image prepared: ${compressed.length} bytes');
    return Uint8List.fromList(compressed);
  }

  /// Progress callback for UI updates
  static Function(String)? onProgress;

  /// Call Gemini Vision API
  Future<String> _callGeminiApi(String base64Image) async {
    final url = '$_baseUrl/$_model:generateContent?key=$_apiKey';

    // Notify progress
    onProgress?.call('Analyzing image...');

    final requestBody = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": _accessibilityPrompt},
            {
              "inlineData": {"mimeType": "image/jpeg", "data": base64Image},
            },
          ],
        },
      ],
      "generationConfig": {
        "temperature": 0.2, // LOW temperature for accuracy
        "topP": 0.8,
        "maxOutputTokens": 4096,
      },
    };

    debugPrint('📡 Gemini: Calling API...');
    debugPrint('📡 Gemini: Model: $_model');
    debugPrint('📡 Gemini: URL: $url');
    onProgress?.call('Reading text from image...');

    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
        .timeout(
          const Duration(seconds: 60), // Longer timeout for complex images
          onTimeout: () {
            throw Exception('Gemini API timeout - please try again');
          },
        );

    debugPrint('📡 Gemini: Response received - Status: ${response.statusCode}');
    onProgress?.call('Processing response...');

    if (response.statusCode != 200) {
      debugPrint('❌ Gemini API error: ${response.statusCode}');
      debugPrint('❌ Response body: ${response.body}');

      // Check for specific error types
      if (response.statusCode == 403) {
        throw Exception(
          'Gemini API: Billing not enabled or API key invalid. Please check your Google Cloud billing.',
        );
      } else if (response.statusCode == 429) {
        throw Exception(
          'Gemini API: Rate limit exceeded. Please try again later.',
        );
      } else if (response.statusCode == 404) {
        throw Exception(
          'Gemini API: Model not found. Please check the model name.',
        );
      }

      throw Exception('Gemini API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    // Extract text from response
    try {
      final text =
          data['candidates'][0]['content']['parts'][0]['text'] as String;
      debugPrint('Gemini extracted ${text.length} chars');
      return text.trim();
    } catch (e) {
      debugPrint('Failed to parse Gemini response: $data');
      throw Exception('Failed to parse Gemini response');
    }
  }

  /// Check if Gemini service is available (has internet)
  static Future<bool> isAvailable() async {
    try {
      final result = await InternetAddress.lookup(
        'generativelanguage.googleapis.com',
      ).timeout(const Duration(seconds: 5));
      final hasConnection =
          result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      debugPrint('🌐 Internet check: $hasConnection');
      return hasConnection;
    } catch (e) {
      debugPrint('🌐 Internet check failed: $e');
      return false;
    }
  }
}
