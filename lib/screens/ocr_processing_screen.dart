import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ocr_service.dart';
import '../services/handwriting_recognition_service.dart';
import '../services/image_preprocessing_service.dart';
import '../models/ocr_result.dart';
import 'text_display_screen.dart';

/// OCR Processing Screen
/// 
/// Processes the captured image to extract text using Google ML Kit
/// Supports both printed and handwritten text recognition
class OCRProcessingScreen extends StatefulWidget {
  final String imagePath;
  final bool isHandwriting;

  const OCRProcessingScreen({
    super.key,
    required this.imagePath,
    this.isHandwriting = false,
  });

  @override
  State<OCRProcessingScreen> createState() => _OCRProcessingScreenState();
}

class _OCRProcessingScreenState extends State<OCRProcessingScreen> {
  OCRService? _ocrService;
  ImagePreprocessingService? _preprocessingService;
  OCRResult? _result;
  bool _isProcessing = false;
  String? _errorMessage;
  String? _preprocessedImagePath;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _processImage();
  }

  /// Initialize OCR and preprocessing services
  Future<void> _initializeServices() async {
    try {
      // Use handwriting recognition service if scanning handwriting
      // Otherwise use standard OCR service
      if (widget.isHandwriting) {
        _ocrService = HandwritingRecognitionService();
      } else {
        _ocrService = OCRService();
      }
      
      // Initialize preprocessing service
      _preprocessingService = ImagePreprocessingService();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize services: $e';
        });
      }
    }
  }

  /// Process the image to extract text
  Future<void> _processImage() async {
    if (_ocrService == null || _preprocessingService == null) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final startTime = DateTime.now();

      // Preprocess the image for better OCR accuracy
      final preprocessedBytes = await _preprocessingService!.preprocessImageBytes(
        await File(widget.imagePath).readAsBytes(),
        enhanceForHandwriting: widget.isHandwriting,
      );

      // Save preprocessed image temporarily
      final tempDir = Directory.systemTemp;
      final preprocessedFile = File('${tempDir.path}/preprocessed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await preprocessedFile.writeAsBytes(preprocessedBytes);
      _preprocessedImagePath = preprocessedFile.path;

      // Perform OCR on the preprocessed image
      final recognizedText = await _ocrService!.recognizeText(preprocessedFile.path);

      // Extract text and metadata
      final plainText = _ocrService!.extractPlainText(recognizedText);
      final formattedText = recognizedText.formattedText;
      final blocks = _ocrService!.extractTextBlocks(recognizedText);
      final lines = _ocrService!.extractTextLines(recognizedText);
      final confidence = _ocrService!.getAverageConfidence(recognizedText);

      final processingTime = DateTime.now().difference(startTime).inMilliseconds;

      // Create OCR result
      final result = OCRResult(
        text: plainText,
        formattedText: formattedText,
        confidence: confidence,
        isHandwritten: widget.isHandwriting,
        processingTimeMs: processingTime,
        blockCount: blocks.length,
        lineCount: lines.length,
        timestamp: DateTime.now(),
        imagePath: widget.imagePath,
      );

      if (mounted) {
        setState(() {
          _result = result;
          _isProcessing = false;
        });

        // Provide haptic feedback on success
        HapticFeedback.mediumImpact();

        // Navigate to text display screen after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TextDisplayScreen(
                  ocrResult: result,
                  imagePath: widget.imagePath,
                ),
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to process image: $e';
          _isProcessing = false;
        });
        
        // Provide haptic feedback on error
        HapticFeedback.heavyImpact();
      }
    }
  }

  @override
  void dispose() {
    _ocrService?.dispose();
    
    // Clean up temporary preprocessed image
    if (_preprocessedImagePath != null) {
      try {
        File(_preprocessedImagePath!).deleteSync();
      } catch (e) {
        // Ignore cleanup errors
      }
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing Image'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _processImage,
                child: const Text('Retry'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const Text(
              'Processing image for OCR...',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isHandwriting
                  ? 'Recognizing handwriting...'
                  : 'Recognizing printed text...',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (_result != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            const Text(
              'Text extracted successfully!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _result!.summary,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

