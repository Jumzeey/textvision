import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service for grouping individual characters into words
///
/// Fixes the issue where ML Kit returns "A R E" instead of "are"
/// by analyzing character proximity and spacing to merge characters into words
class WordGroupingService {
  /// Group characters into words from RecognizedText
  ///
  /// Analyzes the bounding boxes of text elements to determine
  /// which characters belong to the same word based on proximity
  String groupCharactersIntoWords(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) {
      // Fallback to raw text if no blocks detected
      return recognizedText.text;
    }

    final groupedLines = <String>[];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final groupedLine = _groupLineIntoWords(line);
        if (groupedLine.isNotEmpty) {
          groupedLines.add(groupedLine);
        } else if (line.text.trim().isNotEmpty) {
          // If grouping fails but line has text, use original line text
          groupedLines.add(line.text);
        }
      }
    }

    final result = groupedLines.join('\n');
    // If grouping resulted in empty string but original text exists, return original
    if (result.trim().isEmpty && recognizedText.text.trim().isNotEmpty) {
      return recognizedText.text;
    }
    return result;
  }

  /// Group characters in a single line into words
  String _groupLineIntoWords(TextLine line) {
    if (line.elements.isEmpty) {
      return line.text;
    }

    // If we have elements, analyze their positions
    final elements = line.elements;
    if (elements.length <= 1) {
      return line.text;
    }

    // Sort elements by horizontal position (left to right)
    final sortedElements = List<TextElement>.from(elements);
    sortedElements.sort((a, b) {
      return a.boundingBox.left.compareTo(b.boundingBox.left);
    });

    final words = <String>[];
    StringBuffer currentWord = StringBuffer();
    double? lastRight;

    for (int i = 0; i < sortedElements.length; i++) {
      final element = sortedElements[i];
      final text = element.text.trim();

      if (text.isEmpty) continue;

      // Calculate spacing between elements
      final spacing = lastRight != null
          ? element.boundingBox.left - lastRight
          : double.infinity;

      // Determine if this element starts a new word
      // Use average character width to estimate word boundaries
      final avgCharWidth = _calculateAverageCharWidth(sortedElements);
      final wordBreakThreshold = avgCharWidth * 1.5; // 1.5x char width = word break

      // Check if this is a punctuation mark that should attach to previous word
      final isPunctuation = RegExp(r'^[.,!?;:)\]\}]+$').hasMatch(text);
      final isOpeningPunctuation = RegExp(r'^[\(\[\{]+$').hasMatch(text);

      if (isPunctuation && currentWord.isNotEmpty) {
        // Attach punctuation to current word
        currentWord.write(text);
      } else if (isOpeningPunctuation && currentWord.isEmpty) {
        // Start new word with opening punctuation
        currentWord.write(text);
      } else if (spacing > wordBreakThreshold && currentWord.isNotEmpty) {
        // Large spacing indicates word break
        words.add(currentWord.toString());
        currentWord.clear();
        currentWord.write(text);
      } else {
        // Continue current word
        if (currentWord.isNotEmpty && !isPunctuation) {
          // Add space only if not punctuation
          currentWord.write(' ');
        }
        currentWord.write(text);
      }

      lastRight = element.boundingBox.right;
    }

    // Add the last word
    if (currentWord.isNotEmpty) {
      words.add(currentWord.toString());
    }

    // If grouping didn't work well, fall back to original text
    if (words.isEmpty || words.join(' ').trim().isEmpty) {
      return line.text;
    }

    // Join words with spaces and clean up
    final result = words.join(' ');
    final cleaned = _cleanGroupedText(result);
    
    // Final safety check: if cleaned result is empty but original line has text, return original
    if (cleaned.trim().isEmpty && line.text.trim().isNotEmpty) {
      return line.text;
    }
    
    return cleaned;
  }

  /// Calculate average character width from elements
  double _calculateAverageCharWidth(List<TextElement> elements) {
    if (elements.isEmpty) return 20.0; // Default fallback

    double totalWidth = 0.0;
    int charCount = 0;

    for (final element in elements) {
      final width = element.boundingBox.width;
      final textLength = element.text.trim().length;
      if (textLength > 0) {
        totalWidth += width / textLength;
        charCount++;
      }
    }

    return charCount > 0 ? totalWidth / charCount : 20.0;
  }

  /// Clean and normalize grouped text
  String _cleanGroupedText(String text) {
    // Remove extra spaces
    var cleaned = text.replaceAll(RegExp(r'\s+'), ' ');

    // Fix spacing around punctuation
    cleaned = cleaned.replaceAll(RegExp(r'\s+([.,!?;:)\]\}])'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'([\(\[\{])\s+'), r'$1');

    // Fix common letter-by-letter patterns
    cleaned = _fixLetterSpelling(cleaned);

    return cleaned.trim();
  }

  /// Fix letter-by-letter spelling (e.g., "A R E" → "are")
  String _fixLetterSpelling(String text) {
    // Split into potential words
    final parts = text.split(RegExp(r'\s+'));

    final fixedParts = <String>[];

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i].trim();
      if (part.isEmpty) continue;

      // Check if this looks like a letter-by-letter word
      // Pattern: single letters separated by spaces (e.g., "A R E")
      if (part.length == 1 && RegExp(r'[A-Za-z]').hasMatch(part)) {
        // Look ahead to see if we have a sequence of single letters
        final sequence = <String>[part];
        int j = i + 1;

        while (j < parts.length) {
          final nextPart = parts[j].trim();
          if (nextPart.length == 1 &&
              RegExp(r'[A-Za-z]').hasMatch(nextPart) &&
              !RegExp(r'[.,!?;:()]').hasMatch(nextPart)) {
            sequence.add(nextPart);
            j++;
          } else {
            break;
          }
        }

        // If we found a sequence of 2+ letters, try to form a word
        if (sequence.length >= 2) {
          // Try to match common words
          final combined = sequence.join('').toLowerCase();
          final word = _tryCommonWord(combined, sequence.length);

          if (word != null) {
            fixedParts.add(word);
            i = j - 1; // Skip processed parts
            continue;
          } else {
            // If no match, keep as is but join letters
            fixedParts.add(combined);
            i = j - 1;
            continue;
          }
        }
      }

      // Check if part is a known abbreviation (A, B, C, D for multiple choice)
      if (part.length == 1 &&
          RegExp(r'^[A-D]$', caseSensitive: false).hasMatch(part)) {
        // Check context - if followed by period or in list, it's likely an option
        final isOption = (i < parts.length - 1 &&
                parts[i + 1].startsWith('.')) ||
            (i > 0 && RegExp(r'^\d+[\.\):]$').hasMatch(parts[i - 1]));

        if (isOption) {
          fixedParts.add(part.toUpperCase());
          continue;
        }
      }

      fixedParts.add(part);
    }

    return fixedParts.join(' ');
  }

  /// Try to match a sequence of letters to a common word
  String? _tryCommonWord(String letters, int length) {
    // Common short words that might be spelled letter-by-letter
    final commonWords = <String, List<String>>{
      'are': ['a', 'r', 'e'],
      'the': ['t', 'h', 'e'],
      'and': ['a', 'n', 'd'],
      'for': ['f', 'o', 'r'],
      'not': ['n', 'o', 't'],
      'but': ['b', 'u', 't'],
      'you': ['y', 'o', 'u'],
      'all': ['a', 'l', 'l'],
      'can': ['c', 'a', 'n'],
      'had': ['h', 'a', 'd'],
      'her': ['h', 'e', 'r'],
      'was': ['w', 'a', 's'],
      'one': ['o', 'n', 'e'],
      'our': ['o', 'u', 'r'],
      'out': ['o', 'u', 't'],
      'day': ['d', 'a', 'y'],
      'get': ['g', 'e', 't'],
      'has': ['h', 'a', 's'],
      'him': ['h', 'i', 'm'],
      'his': ['h', 'i', 's'],
      'how': ['h', 'o', 'w'],
      'its': ['i', 't', 's'],
      'may': ['m', 'a', 'y'],
      'new': ['n', 'e', 'w'],
      'now': ['n', 'o', 'w'],
      'old': ['o', 'l', 'd'],
      'see': ['s', 'e', 'e'],
      'two': ['t', 'w', 'o'],
      'way': ['w', 'a', 'y'],
      'who': ['w', 'h', 'o'],
      'boy': ['b', 'o', 'y'],
      'did': ['d', 'i', 'd'],
      'let': ['l', 'e', 't'],
      'put': ['p', 'u', 't'],
      'say': ['s', 'a', 'y'],
      'she': ['s', 'h', 'e'],
      'too': ['t', 'o', 'o'],
      'use': ['u', 's', 'e'],
    };

    // Direct match
    if (commonWords.containsKey(letters)) {
      return letters;
    }

    // Try case-insensitive match
    final lowerLetters = letters.toLowerCase();
    if (commonWords.containsKey(lowerLetters)) {
      return lowerLetters;
    }

    // If length matches and it's a reasonable word pattern, return as-is
    if (length >= 2 && length <= 5 && RegExp(r'^[a-z]+$').hasMatch(letters)) {
      return letters;
    }

    return null;
  }

  /// Process plain text string to fix letter-by-letter issues
  ///
  /// This is a fallback method when we don't have bounding box information
  String fixLetterSpellingInText(String rawText) {
    if (rawText.trim().isEmpty) return rawText;

    // First, try to fix obvious letter-by-letter patterns
    var fixed = _fixLetterSpelling(rawText);

    // Additional cleanup
    fixed = fixed.replaceAll(RegExp(r'\s+'), ' ');
    fixed = fixed.trim();

    return fixed;
  }
}

