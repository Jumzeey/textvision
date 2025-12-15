import 'word_grouping_service.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service for processing and organizing text for smooth reading
///
/// Can use AI/NLP services for better text organization if available
class TextProcessingService {
  final WordGroupingService _wordGroupingService = WordGroupingService();
  /// Process and organize text for smooth reading
  ///
  /// Takes raw OCR text and organizes it into well-formatted,
  /// natural-sounding sentences and paragraphs
  ///
  /// This method fixes letter-by-letter spelling issues (A R E → are)
  /// and applies all text cleaning and formatting
  Future<String> processTextForReading(String rawText) async {
    if (rawText.trim().isEmpty) return '';

    try {
      // Step 1: Fix letter-by-letter spelling (A R E → are)
      var cleaned = _wordGroupingService.fixLetterSpellingInText(rawText);
      
      // Safety check: if processing removed all text, return original
      if (cleaned.trim().isEmpty && rawText.trim().isNotEmpty) {
        cleaned = rawText;
      }

      // Step 2: Clean the text
      cleaned = _cleanText(cleaned);
      
      // Safety check again
      if (cleaned.trim().isEmpty && rawText.trim().isNotEmpty) {
        cleaned = rawText;
      }

      // Step 3: Fix common OCR errors
      cleaned = _fixOCRErrors(cleaned);
      
      // Safety check again
      if (cleaned.trim().isEmpty && rawText.trim().isNotEmpty) {
        cleaned = rawText;
      }

      // Step 4: Organize into natural sentences
      cleaned = _organizeIntoSentences(cleaned);
      
      // Safety check again
      if (cleaned.trim().isEmpty && rawText.trim().isNotEmpty) {
        cleaned = rawText;
      }

      // Step 5: Format for smooth reading
      cleaned = _formatForReading(cleaned);
      
      // Final safety check: never return empty if original had text
      if (cleaned.trim().isEmpty && rawText.trim().isNotEmpty) {
        return rawText;
      }

      return cleaned;
    } catch (e) {
      // If any processing step fails, return original text
      return rawText;
    }
  }

  /// Process RecognizedText from ML Kit with word grouping
  ///
  /// Uses bounding box information to properly group characters into words
  /// This is more accurate than processing plain text
  Future<String> processRecognizedText(RecognizedText recognizedText) async {
    // Use word grouping service to merge characters into words
    final groupedText = _wordGroupingService.groupCharactersIntoWords(
      recognizedText,
    );

    // Process the grouped text for reading
    return await processTextForReading(groupedText);
  }

  /// Clean basic text issues
  String _cleanText(String text) {
    // Remove extra whitespace
    var cleaned = text.replaceAll(RegExp(r'\s+'), ' ');

    // Remove leading/trailing whitespace
    cleaned = cleaned.trim();

    return cleaned;
  }

  /// Fix common OCR recognition errors
  String _fixOCRErrors(String text) {
    var fixed = text;

    // Fix spacing before punctuation (remove space before punctuation)
    fixed = fixed.replaceAll(RegExp(r'\s+([.,!?;:])'), r'$1');

    // Fix duplicate punctuation
    fixed = fixed.replaceAll(RegExp(r'([.,!?;:])\s*([.,!?;:])'), r'$1');

    // Ensure space after punctuation (but not after periods in decimals or abbreviations)
    // First, handle sentence-ending punctuation
    fixed = fixed.replaceAll(RegExp(r'([.!?])([A-Za-z])'), r'$1 $2');
    // Then handle commas, semicolons, colons
    fixed = fixed.replaceAll(RegExp(r'([,;:])([A-Za-z0-9])'), r'$1 $2');

    // Ensure proper spacing around parentheses
    fixed = fixed.replaceAllMapped(RegExp(r'\(([^)]+)\)'), (match) {
      final content = match.group(1) ?? '';
      return ' (${content.trim()}) ';
    });

    // Fix common OCR character errors
    fixed = fixed.replaceAll(
      RegExp(r'\b0\b', caseSensitive: false),
      'O',
    ); // 0 -> O in words
    fixed = fixed.replaceAll(RegExp(r'\b1\b'), 'I'); // 1 -> I in words
    fixed = fixed.replaceAll(RegExp(r'\b5\b'), 'S'); // 5 -> S in words

    // Fix spacing around common words
    fixed = fixed.replaceAll(
      RegExp(r'\s+the\s+', caseSensitive: false),
      ' the ',
    );
    fixed = fixed.replaceAll(RegExp(r'\s+a\s+', caseSensitive: false), ' a ');
    fixed = fixed.replaceAll(RegExp(r'\s+an\s+', caseSensitive: false), ' an ');
    fixed = fixed.replaceAll(
      RegExp(r'\s+and\s+', caseSensitive: false),
      ' and ',
    );
    fixed = fixed.replaceAll(RegExp(r'\s+or\s+', caseSensitive: false), ' or ');

    // Normalize multiple spaces to single space
    fixed = fixed.replaceAll(RegExp(r'\s+'), ' ');

    return fixed.trim();
  }

  /// Organize text into natural sentences
  String _organizeIntoSentences(String text) {
    // Split by sentence endings
    final sentences = text.split(RegExp(r'([.!?]+)\s*'));
    final organized = <String>[];
    StringBuffer currentSentence = StringBuffer();

    for (int i = 0; i < sentences.length; i++) {
      final part = sentences[i].trim();
      if (part.isEmpty) continue;

      // Check if this is punctuation
      if (RegExp(r'^[.!?]+$').hasMatch(part)) {
        // Add punctuation to current sentence
        currentSentence.write(part);
        final sentence = currentSentence.toString().trim();
        if (sentence.isNotEmpty) {
          organized.add(sentence);
        }
        currentSentence.clear();
      } else {
        // Add text to current sentence
        if (currentSentence.isNotEmpty) {
          currentSentence.write(' ');
        }
        currentSentence.write(part);
      }
    }

    // Add remaining sentence
    final remaining = currentSentence.toString().trim();
    if (remaining.isNotEmpty) {
      if (!remaining.endsWith('.') &&
          !remaining.endsWith('!') &&
          !remaining.endsWith('?')) {
        organized.add('$remaining.');
      } else {
        organized.add(remaining);
      }
    }

    // Join sentences with proper spacing
    return organized.join(' ');
  }

  /// Format text for smooth reading
  String _formatForReading(String text) {
    // Ensure proper capitalization at sentence starts
    var formatted = text;

    // Capitalize first letter of sentences
    formatted = formatted.replaceAllMapped(
      RegExp(r'(^|[.!?]\s+)([a-z])'),
      (match) => '${match.group(1)}${match.group(2)!.toUpperCase()}',
    );

    // Ensure proper spacing
    formatted = formatted.replaceAll(RegExp(r'\s+'), ' ');

    return formatted.trim();
  }

  /// Merge multiple text blocks intelligently
  /// Uses the most complete version and supplements with unique content
  String mergeTextBlocks(List<String> textBlocks) {
    if (textBlocks.isEmpty) return '';
    if (textBlocks.length == 1) return textBlocks.first;

    // Find the most complete text block
    String bestBlock = textBlocks.first;
    int bestScore = _scoreTextCompleteness(bestBlock);

    for (final block in textBlocks) {
      final score = _scoreTextCompleteness(block);
      if (score > bestScore) {
        bestBlock = block;
        bestScore = score;
      }
    }

    // Use best block as base and add unique words from others
    final baseWords = bestBlock
        .split(RegExp(r'\s+'))
        .map((w) => w.toLowerCase())
        .toSet();
    final merged = StringBuffer(bestBlock);
    final addedWords = <String>{};

    for (final block in textBlocks) {
      if (block == bestBlock) continue;

      final words = block.split(RegExp(r'\s+'));
      final newWords = <String>[];

      for (final word in words) {
        final wordLower = word.toLowerCase();
        if (!baseWords.contains(wordLower) && !addedWords.contains(wordLower)) {
          newWords.add(word);
          addedWords.add(wordLower);
        }
      }

      if (newWords.isNotEmpty) {
        merged.write(' ${newWords.join(' ')}');
      }
    }

    return merged.toString();
  }

  /// Score text completeness (longer text with more words scores higher)
  int _scoreTextCompleteness(String text) {
    final wordCount = text.split(RegExp(r'\s+')).length;
    final hasPunctuation = RegExp(r'[.!?]').hasMatch(text);
    return wordCount * 10 + (hasPunctuation ? 5 : 0) + text.length;
  }

  /// Aggregate text from multiple OCR frames
  ///
  /// Combines results from multiple camera captures to improve accuracy:
  /// - Uses the most complete version as base
  /// - Merges unique words from other frames while preserving structure
  /// - Handles variations in recognition across frames
  /// - Preserves line breaks and paragraph structure
  ///
  /// [textResults] - List of text strings from multiple OCR passes
  /// [confidenceThreshold] - Minimum confidence to include text (0.0-1.0)
  ///
  /// Returns aggregated text with best recognition from all frames
  String aggregateMultiFrameText(
    List<String> textResults, {
    double confidenceThreshold = 0.5,
  }) {
    if (textResults.isEmpty) return '';
    if (textResults.length == 1) return textResults.first;

    // Strategy 1: Try to merge by preserving structure and finding all unique content
    // Split each text into lines to preserve structure
    final allLines = <String>[];
    final lineSet = <String>{}; // Track unique lines to avoid duplicates
    
    for (final text in textResults) {
      if (text.trim().isEmpty) continue;
      
      // Split by newlines, but also preserve paragraph breaks
      final lines = text.split(RegExp(r'\n+'));
      for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;
        
        // Normalize line for comparison (remove extra spaces)
        final normalized = trimmedLine.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
        
        // Check if this line is substantially different from existing lines
        bool isUnique = true;
        for (final existingLine in lineSet) {
          final existingNormalized = existingLine.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
          
          // If lines are very similar (>90% overlap), skip
          if (_calculateSimilarity(normalized, existingNormalized) > 0.9) {
            isUnique = false;
            // But if the new line is longer/more complete, replace it
            if (trimmedLine.length > existingLine.length) {
              lineSet.remove(existingLine);
              lineSet.add(trimmedLine);
              // Update in allLines too
              final index = allLines.indexOf(existingLine);
              if (index >= 0) {
                allLines[index] = trimmedLine;
              }
            }
            break;
          }
        }
        
        if (isUnique) {
          allLines.add(trimmedLine);
          lineSet.add(trimmedLine);
        }
      }
    }
    
    // If we have structured lines, merge them intelligently
    if (allLines.isNotEmpty) {
      // Group similar lines together and use the most complete version
      final mergedLines = <String>[];
      final processedLines = <String>{};
      
      for (final line in allLines) {
        if (processedLines.contains(line)) continue;
        
        // Find similar lines
        final similarLines = <String>[line];
        for (final otherLine in allLines) {
          if (otherLine == line || processedLines.contains(otherLine)) continue;
          
          final similarity = _calculateSimilarity(
            line.replaceAll(RegExp(r'\s+'), ' ').toLowerCase(),
            otherLine.replaceAll(RegExp(r'\s+'), ' ').toLowerCase(),
          );
          
          if (similarity > 0.85) {
            similarLines.add(otherLine);
          }
        }
        
        // Use the longest/most complete version
        String bestLine = line;
        for (final similarLine in similarLines) {
          if (similarLine.length > bestLine.length) {
            bestLine = similarLine;
          }
        }
        
        mergedLines.add(bestLine);
        processedLines.addAll(similarLines);
      }
      
      // Join lines with newlines to preserve structure
      var result = mergedLines.join('\n');
      
      // Now add any unique words that might be missing
      final allWords = <String, int>{}; // word -> count
      for (final text in textResults) {
        final words = _extractWords(text);
        for (final word in words) {
          allWords[word] = (allWords[word] ?? 0) + 1;
        }
      }
      
      // Extract words from merged result
      final mergedWords = _extractWords(result);
      
      // Find words that appear in multiple frames but not in merged result
      final missingWords = <String>[];
      for (final entry in allWords.entries) {
        if (!mergedWords.contains(entry.key) && entry.value >= 2) {
          // Word appears in multiple frames but not in result - might be important
          missingWords.add(entry.key);
        }
      }
      
      // If we have missing words, append them (but this is a fallback)
      if (missingWords.isNotEmpty && result.length < 500) {
        // Only add if result is relatively short (might be incomplete)
        result = '$result ${missingWords.join(' ')}';
      }
      
      // Clean up
      result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n'); // Max 2 newlines
      result = result.replaceAll(RegExp(r'[ \t]+'), ' '); // Normalize spaces
      result = result.trim();
      
      return result;
    }
    
    // Fallback: Original word-based merging (but improved)
    return _aggregateByWords(textResults);
  }
  
  /// Fallback aggregation method using word-based merging
  String _aggregateByWords(List<String> textResults) {
    // Find the most complete text block as base
    String bestText = textResults.first;
    int bestScore = _scoreTextCompleteness(bestText);

    for (final text in textResults) {
      final score = _scoreTextCompleteness(text);
      if (score > bestScore) {
        bestText = text;
        bestScore = score;
      }
    }

    // Extract words from best text
    final baseWords = _extractWords(bestText);
    final aggregated = StringBuffer(bestText);
    final addedWords = <String>{};

    // Add unique words from other frames
    for (final text in textResults) {
      if (text == bestText) continue;

      final words = _extractWords(text);
      final newWords = <String>[];

      for (final word in words) {
        final wordLower = word.toLowerCase().trim();
        // Skip if already in base or already added
        if (baseWords.contains(wordLower) || addedWords.contains(wordLower)) {
          continue;
        }

        // Check if word is meaningful (not just punctuation or single char)
        if (word.length > 1 || RegExp(r'^[A-Za-z]$').hasMatch(word)) {
          newWords.add(word);
          addedWords.add(wordLower);
        }
      }

      // Add new words if found
      if (newWords.isNotEmpty) {
        aggregated.write(' ${newWords.join(' ')}');
      }
    }

    // Clean and normalize the aggregated text
    var result = aggregated.toString();
    result = result.replaceAll(RegExp(r'\s+'), ' ');
    result = result.trim();

    return result;
  }
  
  /// Calculate similarity between two strings (0.0 to 1.0)
  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    // Use longest common subsequence for similarity
    final longer = s1.length > s2.length ? s1 : s2;
    final shorter = s1.length > s2.length ? s2 : s1;
    
    if (longer.isEmpty) return 1.0;
    
    // Simple character overlap calculation
    int matches = 0;
    final shorterChars = shorter.split('');
    final longerChars = longer.split('');
    
    for (int i = 0; i < shorterChars.length && i < longerChars.length; i++) {
      if (shorterChars[i] == longerChars[i]) {
        matches++;
      }
    }
    
    // Also check for substring matches
    if (longer.contains(shorter) || shorter.contains(longer)) {
      matches = (matches + shorter.length) ~/ 2;
    }
    
    return (matches * 2.0) / (longer.length + shorter.length);
  }

  /// Extract words from text, preserving punctuation context
  Set<String> _extractWords(String text) {
    // Split by whitespace and filter empty strings
    final words = text
        .split(RegExp(r'\s+'))
        .where((w) => w.trim().isNotEmpty)
        .map((w) => w.toLowerCase().trim())
        .toSet();
    return words;
  }

  /// Aggregate multiple RecognizedText objects from ML Kit
  ///
  /// Combines OCR results from multiple frames using word-level merging
  /// This is more sophisticated than simple text merging as it uses
  /// bounding box information when available
  Future<String> aggregateRecognizedText(
    List<String> recognizedTexts,
  ) async {
    if (recognizedTexts.isEmpty) return '';
    if (recognizedTexts.length == 1) return recognizedTexts.first;

    // Use the aggregation method
    return aggregateMultiFrameText(recognizedTexts);
  }
  
  /// Aggregate RecognizedText objects using spatial information
  ///
  /// This is the most accurate method as it uses bounding boxes to merge
  /// text blocks spatially, preserving the original document structure
  Future<String> aggregateRecognizedTextObjects(
    List<RecognizedText> recognizedTexts,
  ) async {
    if (recognizedTexts.isEmpty) return '';
    if (recognizedTexts.length == 1) {
      return await processRecognizedText(recognizedTexts.first);
    }
    
    // Collect all text blocks from all frames, sorted by position
    final allBlocks = <TextBlock>[];
    
    for (final recognizedText in recognizedTexts) {
      // Use sorted blocks to preserve spatial order
      final sortedBlocks = _sortBlocksByPosition(recognizedText.blocks);
      allBlocks.addAll(sortedBlocks);
    }
    
    // Merge blocks that are spatially close (likely the same text)
    final mergedBlocks = _mergeSpatialBlocks(allBlocks);
    
    // Convert merged blocks back to RecognizedText-like structure
    // For now, extract text from merged blocks
    final textLines = <String>[];
    
    for (final block in mergedBlocks) {
      final blockLines = <String>[];
      for (final line in block.lines) {
        final lineText = line.text.trim();
        if (lineText.isNotEmpty) {
          blockLines.add(lineText);
        }
      }
      if (blockLines.isNotEmpty) {
        textLines.add(blockLines.join(' '));
      }
    }
    
    // Join blocks with newlines
    final rawText = textLines.join('\n');
    
    // Process the merged text
    return await processTextForReading(rawText);
  }
  
  /// Sort text blocks by position (top to bottom, left to right)
  List<TextBlock> _sortBlocksByPosition(List<TextBlock> blocks) {
    final sorted = List<TextBlock>.from(blocks);
    sorted.sort((a, b) {
      // Sort by top position first
      final topDiff = a.boundingBox.top - b.boundingBox.top;
      if (topDiff.abs() > 20) {
        // Different rows (20px threshold)
        return topDiff.toInt();
      }
      // Same row, sort by left position
      return (a.boundingBox.left - b.boundingBox.left).toInt();
    });
    return sorted;
  }
  
  /// Merge text blocks that are spatially close (likely duplicates)
  List<TextBlock> _mergeSpatialBlocks(List<TextBlock> blocks) {
    if (blocks.isEmpty) return [];
    
    final merged = <TextBlock>[];
    final processed = <int>{};
    
    for (int i = 0; i < blocks.length; i++) {
      if (processed.contains(i)) continue;
      
      final block = blocks[i];
      final similarBlocks = <TextBlock>[block];
      processed.add(i);
      
      // Find blocks that overlap or are very close
      for (int j = i + 1; j < blocks.length; j++) {
        if (processed.contains(j)) continue;
        
        final otherBlock = blocks[j];
        
        // Check if blocks overlap or are close
        if (_blocksOverlap(block, otherBlock, threshold: 30)) {
          similarBlocks.add(otherBlock);
          processed.add(j);
        }
      }
      
      // Use the block with most text as the merged result
      TextBlock bestBlock = block;
      int maxTextLength = block.text.length;
      
      for (final similarBlock in similarBlocks) {
        if (similarBlock.text.length > maxTextLength) {
          bestBlock = similarBlock;
          maxTextLength = similarBlock.text.length;
        }
      }
      
      merged.add(bestBlock);
    }
    
    return merged;
  }
  
  /// Check if two text blocks overlap or are close spatially
  bool _blocksOverlap(TextBlock block1, TextBlock block2, {double threshold = 20}) {
    final box1 = block1.boundingBox;
    final box2 = block2.boundingBox;
    
    // Calculate overlap
    final overlapX = (box1.left < box2.right && box1.right > box2.left);
    final overlapY = (box1.top < box2.bottom && box1.bottom > box2.top);
    
    if (overlapX && overlapY) return true;
    
    // Check if blocks are close (within threshold)
    final centerX1 = box1.left + box1.width / 2;
    final centerY1 = box1.top + box1.height / 2;
    final centerX2 = box2.left + box2.width / 2;
    final centerY2 = box2.top + box2.height / 2;
    
    final distance = ((centerX1 - centerX2).abs() + (centerY1 - centerY2).abs());
    return distance < threshold;
  }
}
