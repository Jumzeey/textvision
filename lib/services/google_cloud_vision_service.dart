import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Service for performing OCR using Google Cloud Vision API
///
/// Uses the DOCUMENT_TEXT_DETECTION endpoint for better accuracy
/// compared to on-device OCR, especially for documents and handwriting
class GoogleCloudVisionService {
  static const String _baseUrl = 'https://vision.googleapis.com/v1/images:annotate';
  String? _apiKey;

  /// Initialize the service with API key from environment
  GoogleCloudVisionService() {
    _apiKey = dotenv.env['GOOGLE_CLOUD_VISION_API_KEY'];
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception(
        'Google Cloud Vision API key not found. '
        'Please set GOOGLE_CLOUD_VISION_API_KEY in .env file',
      );
    }
  }

  /// Perform OCR on a single image
  ///
  /// [imageBytes] - Image data as bytes
  ///
  /// Returns a VisionResponse containing detected text with bounding boxes
  Future<VisionResponse> detectText(Uint8List imageBytes) async {
    try {
      // Encode image to base64
      final base64Image = base64Encode(imageBytes);

      // Prepare the request body
      final requestBody = {
        'requests': [
          {
            'image': {
              'content': base64Image,
            },
            'features': [
              {
                'type': 'DOCUMENT_TEXT_DETECTION',
                'maxResults': 1,
              }
            ],
          }
        ]
      };

      // Make the API request
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      // Check for errors
      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        throw Exception(
          'Google Cloud Vision API error: ${errorBody['error']?['message'] ?? response.statusCode}',
        );
      }

      // Parse the response
      final responseData = jsonDecode(response.body);
      return VisionResponse.fromJson(responseData);
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to detect text: $e');
    }
  }

  /// Perform OCR on multiple images in batch
  ///
  /// [imageBytesList] - List of image data as bytes
  ///
  /// Returns a list of VisionResponse objects
  Future<List<VisionResponse>> detectTextBatch(
    List<Uint8List> imageBytesList,
  ) async {
    if (imageBytesList.isEmpty) {
      return [];
    }

    try {
      // Prepare batch request with multiple images
      final requests = imageBytesList.map((imageBytes) {
        final base64Image = base64Encode(imageBytes);
        return {
          'image': {
            'content': base64Image,
          },
          'features': [
            {
              'type': 'DOCUMENT_TEXT_DETECTION',
              'maxResults': 1,
            }
          ],
        };
      }).toList();

      final requestBody = {
        'requests': requests,
      };

      // Make the batch API request
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      // Check for errors
      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        throw Exception(
          'Google Cloud Vision API error: ${errorBody['error']?['message'] ?? response.statusCode}',
        );
      }

      // Parse the batch response
      final responseData = jsonDecode(response.body);
      final responses = <VisionResponse>[];

      final responsesList = responseData['responses'];
      if (responsesList != null) {
        for (final responseJson in responsesList) {
          responses.add(VisionResponse.fromJson({'responses': [responseJson]}));
        }
      }

      return responses;
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to detect text in batch: $e');
    }
  }

  /// Extract plain text from VisionResponse
  String extractPlainText(VisionResponse response) {
    return response.fullTextAnnotation?.text ?? '';
  }

  /// Extract text blocks with bounding boxes
  List<TextBlock> extractTextBlocks(VisionResponse response) {
    if (response.fullTextAnnotation?.pages == null) {
      return [];
    }

    final blocks = <TextBlock>[];
    final pages = response.fullTextAnnotation!.pages;
    if (pages != null) {
      for (final page in pages) {
        if (page.blocks != null) {
          for (final block in page.blocks!) {
            blocks.add(block);
          }
        }
      }
    }
    return blocks;
  }

  /// Extract text lines with bounding boxes
  List<TextLine> extractTextLines(VisionResponse response) {
    if (response.fullTextAnnotation?.pages == null) {
      return [];
    }

    final lines = <TextLine>[];
    final pages = response.fullTextAnnotation!.pages;
    if (pages != null) {
      for (final page in pages) {
        if (page.blocks != null) {
          for (final block in page.blocks!) {
            if (block.paragraphs != null) {
              for (final paragraph in block.paragraphs!) {
                if (paragraph.words != null) {
                  // Group words into lines based on bounding boxes
                  final lineWords = <Word>[];
                  double? currentLineTop;

                  for (final word in paragraph.words!) {
                    final wordTop = word.boundingBox?.vertices?[0].y?.toDouble();
                    if (currentLineTop == null ||
                        (wordTop != null &&
                            currentLineTop != null &&
                            (wordTop - currentLineTop).abs() < 10)) {
                      // Same line
                      lineWords.add(word);
                      if (currentLineTop == null && wordTop != null) {
                        currentLineTop = wordTop;
                      }
                    } else {
                      // New line - save previous line
                      if (lineWords.isNotEmpty) {
                        lines.add(Word.fromWords(lineWords));
                      }
                      lineWords.clear();
                      lineWords.add(word);
                      currentLineTop = wordTop;
                    }
                  }

                  // Add remaining line
                  if (lineWords.isNotEmpty) {
                    lines.add(Word.fromWords(lineWords));
                  }
                }
              }
            }
          }
        }
      }
    }
    return lines;
  }
}

/// Response from Google Cloud Vision API
class VisionResponse {
  final FullTextAnnotation? fullTextAnnotation;
  final String? error;

  VisionResponse({
    this.fullTextAnnotation,
    this.error,
  });

  factory VisionResponse.fromJson(Map<String, dynamic> json) {
    if (json['responses'] != null && json['responses'].isNotEmpty) {
      final response = json['responses'][0];
      return VisionResponse(
        fullTextAnnotation: response['fullTextAnnotation'] != null
            ? FullTextAnnotation.fromJson(response['fullTextAnnotation'])
            : null,
        error: response['error']?['message'],
      );
    }
    return VisionResponse(
      error: json['error']?['message'],
    );
  }

  bool get hasError => error != null;
  bool get hasText => fullTextAnnotation != null;
}

/// Full text annotation from Google Cloud Vision API
class FullTextAnnotation {
  final List<Page>? pages;
  final String? text;

  FullTextAnnotation({
    this.pages,
    this.text,
  });

  factory FullTextAnnotation.fromJson(Map<String, dynamic> json) {
    return FullTextAnnotation(
      pages: json['pages'] != null
          ? (json['pages'] as List)
              .map((p) => Page.fromJson(p))
              .toList()
          : null,
      text: json['text'],
    );
  }
}

/// Page from Google Cloud Vision API
class Page {
  final List<TextBlock>? blocks;
  final int? width;
  final int? height;

  Page({
    this.blocks,
    this.width,
    this.height,
  });

  factory Page.fromJson(Map<String, dynamic> json) {
    return Page(
      blocks: json['blocks'] != null
          ? (json['blocks'] as List).map((b) => TextBlock.fromJson(b)).toList()
          : null,
      width: json['width'],
      height: json['height'],
    );
  }
}

/// Text block from Google Cloud Vision API
class TextBlock {
  final List<Paragraph>? paragraphs;
  final BoundingBox? boundingBox;
  final String? blockType;

  TextBlock({
    this.paragraphs,
    this.boundingBox,
    this.blockType,
  });

  factory TextBlock.fromJson(Map<String, dynamic> json) {
    return TextBlock(
      paragraphs: json['paragraphs'] != null
          ? (json['paragraphs'] as List)
              .map((p) => Paragraph.fromJson(p))
              .toList()
          : null,
      boundingBox: json['boundingBox'] != null
          ? BoundingBox.fromJson(json['boundingBox'])
          : null,
      blockType: json['blockType'],
    );
  }

  String get text {
    if (paragraphs == null) return '';
    return paragraphs!.map((p) => p.text).join(' ');
  }
}

/// Paragraph from Google Cloud Vision API
class Paragraph {
  final List<Word>? words;
  final BoundingBox? boundingBox;

  Paragraph({
    this.words,
    this.boundingBox,
  });

  factory Paragraph.fromJson(Map<String, dynamic> json) {
    return Paragraph(
      words: json['words'] != null
          ? (json['words'] as List).map((w) => Word.fromJson(w)).toList()
          : null,
      boundingBox: json['boundingBox'] != null
          ? BoundingBox.fromJson(json['boundingBox'])
          : null,
    );
  }

  String get text {
    if (words == null) return '';
    return words!.map((w) => w.text).join(' ');
  }
}

/// Word from Google Cloud Vision API
class Word {
  final List<Symbol>? symbols;
  final BoundingBox? boundingBox;

  Word({
    this.symbols,
    this.boundingBox,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      symbols: json['symbols'] != null
          ? (json['symbols'] as List).map((s) => Symbol.fromJson(s)).toList()
          : null,
      boundingBox: json['boundingBox'] != null
          ? BoundingBox.fromJson(json['boundingBox'])
          : null,
    );
  }

  String get text {
    if (symbols == null) return '';
    return symbols!.map((s) => s.text).join('');
  }

  static TextLine fromWords(List<Word> words) {
    if (words.isEmpty) {
      throw ArgumentError('Cannot create TextLine from empty words list');
    }

    // Combine text from all words
    final text = words.map((w) => w.text).join(' ');

    // Calculate bounding box from all words
    double? minX, minY, maxX, maxY;
    for (final word in words) {
      if (word.boundingBox?.vertices != null) {
        for (final vertex in word.boundingBox!.vertices!) {
          if (vertex.x != null && vertex.y != null) {
            final x = vertex.x!.toDouble();
            final y = vertex.y!.toDouble();
            minX = minX == null ? x : (x < minX ? x : minX);
            minY = minY == null ? y : (y < minY ? y : minY);
            maxX = maxX == null ? x : (x > maxX ? x : maxX);
            maxY = maxY == null ? y : (y > maxY ? y : maxY);
          }
        }
      }
    }

    final boundingBox = minX != null &&
            minY != null &&
            maxX != null &&
            maxY != null
        ? BoundingBox(
            vertices: [
              Vertex(x: minX.toInt(), y: minY.toInt()),
              Vertex(x: maxX.toInt(), y: minY.toInt()),
              Vertex(x: maxX.toInt(), y: maxY.toInt()),
              Vertex(x: minX.toInt(), y: maxY.toInt()),
            ],
          )
        : null;

    return TextLine(
      text: text,
      boundingBox: boundingBox,
    );
  }
}

/// Symbol from Google Cloud Vision API
class Symbol {
  final String? text;
  final BoundingBox? boundingBox;

  Symbol({
    this.text,
    this.boundingBox,
  });

  factory Symbol.fromJson(Map<String, dynamic> json) {
    return Symbol(
      text: json['text'],
      boundingBox: json['boundingBox'] != null
          ? BoundingBox.fromJson(json['boundingBox'])
          : null,
    );
  }
}

/// Bounding box from Google Cloud Vision API
class BoundingBox {
  final List<Vertex>? vertices;

  BoundingBox({this.vertices});

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      vertices: json['vertices'] != null
          ? (json['vertices'] as List).map((v) => Vertex.fromJson(v)).toList()
          : null,
    );
  }

  double? get top => vertices?.isNotEmpty == true ? vertices![0].y?.toDouble() : null;
  double? get left => vertices?.isNotEmpty == true ? vertices![0].x?.toDouble() : null;
  double? get bottom => vertices?.length == 4 ? vertices![2].y?.toDouble() : null;
  double? get right => vertices?.length == 4 ? vertices![2].x?.toDouble() : null;
}

/// Vertex from Google Cloud Vision API
class Vertex {
  final int? x;
  final int? y;

  Vertex({this.x, this.y});

  factory Vertex.fromJson(Map<String, dynamic> json) {
    return Vertex(
      x: json['x'],
      y: json['y'],
    );
  }
}

/// Text line representation for compatibility
class TextLine {
  final String text;
  final BoundingBox? boundingBox;

  TextLine({
    required this.text,
    this.boundingBox,
  });
}

