import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
  // TODO: Move to secure storage for production
  static const String _apiKey = 'AIzaSyBPb2vg43jpFjBRe_ISbhnHJw1l5rMlz0U';
  static const String _model = 'gemini-2.0-flash'; // Latest fast model
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

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
      // Step 1: Prepare image (resize, compress)
      final preparedImage = await _prepareImage(imageFile);

      // Step 2: Convert to base64
      final base64Image = base64Encode(preparedImage);

      // Step 3: Call Gemini API
      final response = await _callGeminiApi(base64Image);

      return response;
    } catch (e) {
      debugPrint('Gemini Vision error: $e');
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

    debugPrint('Calling Gemini API...');
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

    onProgress?.call('Processing response...');

    if (response.statusCode != 200) {
      debugPrint('Gemini API error: ${response.statusCode}');
      debugPrint('Response: ${response.body}');
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
      ).timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
