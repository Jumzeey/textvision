/// Service for processing and organizing text for smooth reading
///
/// Can use AI/NLP services for better text organization if available
class TextProcessingService {
  /// Process and organize text for smooth reading
  ///
  /// Takes raw OCR text and organizes it into well-formatted,
  /// natural-sounding sentences and paragraphs
  Future<String> processTextForReading(String rawText) async {
    if (rawText.trim().isEmpty) return '';

    // Step 1: Clean the text
    var cleaned = _cleanText(rawText);

    // Step 2: Fix common OCR errors
    cleaned = _fixOCRErrors(cleaned);

    // Step 3: Organize into natural sentences
    cleaned = _organizeIntoSentences(cleaned);

    // Step 4: Format for smooth reading
    cleaned = _formatForReading(cleaned);

    return cleaned;
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
}
