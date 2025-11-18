import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ocr_result.dart';

/// Service for storing and retrieving OCR results and transcripts
///
/// Handles:
/// - Saving OCR results to local storage
/// - Loading saved transcripts
/// - Managing document history
/// - Exporting transcripts
class StorageService {
  static const String _historyKey = 'scan_history';

  /// Get the documents directory for storing files
  Future<Directory> getDocumentsDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final transcriptsDir = Directory('${directory.path}/transcripts');
    if (!await transcriptsDir.exists()) {
      await transcriptsDir.create(recursive: true);
    }
    return transcriptsDir;
  }

  /// Save an OCR result to local storage
  ///
  /// [result] - The OCR result to save
  /// Returns the file path where the result was saved
  Future<String> saveTranscript(OCRResult result) async {
    try {
      final transcriptsDir = await getDocumentsDirectory();
      final timestamp = result.timestamp.toIso8601String().replaceAll(':', '-');
      final fileName = 'transcript_$timestamp.json';
      final file = File('${transcriptsDir.path}/$fileName');

      // Save as JSON
      final json = jsonEncode(result.toJson());
      await file.writeAsString(json);

      // Update history
      await _addToHistory(fileName, result.timestamp);

      return file.path;
    } catch (e) {
      throw Exception('Failed to save transcript: $e');
    }
  }

  /// Load a saved transcript from file path
  ///
  /// [filePath] - Path to the saved transcript file
  /// Returns the OCRResult object
  Future<OCRResult> loadTranscript(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Transcript file not found');
      }

      final jsonString = await file.readAsString();
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return OCRResult.fromJson(json);
    } catch (e) {
      throw Exception('Failed to load transcript: $e');
    }
  }

  /// Get all saved transcripts
  ///
  /// Returns a list of OCRResult objects sorted by timestamp (newest first)
  Future<List<OCRResult>> getAllTranscripts() async {
    try {
      final transcriptsDir = await getDocumentsDirectory();
      final files = transcriptsDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList();

      final transcripts = <OCRResult>[];
      for (final file in files) {
        try {
          final transcript = await loadTranscript(file.path);
          transcripts.add(transcript);
        } catch (e) {
          // Skip files that can't be loaded
          continue;
        }
      }

      // Sort by timestamp (newest first)
      transcripts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return transcripts;
    } catch (e) {
      return [];
    }
  }

  /// Delete a saved transcript
  ///
  /// [filePath] - Path to the transcript file to delete
  Future<void> deleteTranscript(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete transcript: $e');
    }
  }

  /// Export transcript as plain text
  ///
  /// [result] - The OCR result to export
  /// Returns the file path where the text was saved
  Future<String> exportAsText(OCRResult result) async {
    try {
      final transcriptsDir = await getDocumentsDirectory();
      final timestamp = result.timestamp.toIso8601String().replaceAll(':', '-');
      final fileName = 'transcript_$timestamp.txt';
      final file = File('${transcriptsDir.path}/$fileName');

      await file.writeAsString(result.formattedText);
      return file.path;
    } catch (e) {
      throw Exception('Failed to export transcript: $e');
    }
  }

  /// Add a transcript to history
  ///
  /// [fileName] - Name of the saved file
  /// [timestamp] - Timestamp of the scan
  Future<void> _addToHistory(String fileName, DateTime timestamp) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey) ?? '[]';
      final history = jsonDecode(historyJson) as List<dynamic>;

      history.insert(0, {
        'fileName': fileName,
        'timestamp': timestamp.toIso8601String(),
      });

      // Keep only last 100 entries
      if (history.length > 100) {
        history.removeRange(100, history.length);
      }

      await prefs.setString(_historyKey, jsonEncode(history));
    } catch (e) {
      // Ignore history errors
    }
  }

  /// Get scan history
  ///
  /// Returns a list of history entries sorted by timestamp (newest first)
  Future<List<Map<String, dynamic>>> getScanHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey) ?? '[]';
      final history = jsonDecode(historyJson) as List<dynamic>;

      return history.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Clear scan history
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      // Ignore errors
    }
  }

  /// Get storage usage information
  ///
  /// Returns the total size of saved transcripts in bytes
  Future<int> getStorageUsage() async {
    try {
      final transcriptsDir = await getDocumentsDirectory();
      final files = transcriptsDir.listSync().whereType<File>();

      int totalSize = 0;
      for (final file in files) {
        totalSize += await file.length();
      }

      return totalSize;
    } catch (e) {
      return 0;
    }
  }
}
