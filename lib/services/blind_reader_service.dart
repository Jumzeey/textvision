import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Optimized text processing service for blind users
///
/// Focus: Extract text from documents and prepare it for natural TTS reading
/// - Top-to-bottom, left-to-right ordering
/// - Smart whitespace handling
/// - Punctuation preserved for natural pauses
/// - Handles exam papers, forms, and structured documents
class BlindReaderService {
  /// Extract and prepare text from OCR result for reading
  ///
  /// This is the main method - takes RecognizedText and returns
  /// clean, readable text ordered correctly
  String extractTextForReading(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) {
      return recognizedText.text.trim();
    }

    // Step 1: Sort ALL lines from all blocks by vertical position
    final allLines = <_PositionedLine>[];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final lineText = line.text.trim();
        if (lineText.isNotEmpty) {
          allLines.add(
            _PositionedLine(
              text: lineText,
              top: line.boundingBox.top,
              left: line.boundingBox.left,
              bottom: line.boundingBox.bottom,
            ),
          );
        }
      }
    }

    // Sort by vertical position (top), then horizontal (left)
    allLines.sort((a, b) {
      // If on roughly the same line (within 15 pixels)
      if ((a.top - b.top).abs() < 15) {
        return a.left.compareTo(b.left);
      }
      return a.top.compareTo(b.top);
    });

    // Step 2: Merge lines that are on the same row
    final mergedLines = _mergeHorizontalLines(allLines);

    // Step 3: Join lines intelligently for reading
    final text = _joinLinesForReading(mergedLines);

    // Step 4: Clean for TTS
    return _cleanForTTS(text);
  }

  /// Merge lines that appear on the same horizontal row
  List<String> _mergeHorizontalLines(List<_PositionedLine> lines) {
    if (lines.isEmpty) return [];

    final result = <String>[];
    var currentRowLines = <_PositionedLine>[lines.first];
    var currentRowTop = lines.first.top;

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];

      // If this line is on the same row (within 15 pixels vertically)
      if ((line.top - currentRowTop).abs() < 15) {
        currentRowLines.add(line);
      } else {
        // New row - merge previous row and start new one
        result.add(_mergeRowLines(currentRowLines));
        currentRowLines = [line];
        currentRowTop = line.top;
      }
    }

    // Don't forget the last row
    if (currentRowLines.isNotEmpty) {
      result.add(_mergeRowLines(currentRowLines));
    }

    return result;
  }

  /// Merge lines in a single row, sorted left to right
  String _mergeRowLines(List<_PositionedLine> rowLines) {
    if (rowLines.isEmpty) return '';
    if (rowLines.length == 1) return rowLines.first.text;

    // Sort by left position
    rowLines.sort((a, b) => a.left.compareTo(b.left));

    // Join with appropriate spacing
    final buffer = StringBuffer();
    for (int i = 0; i < rowLines.length; i++) {
      if (i > 0) {
        final prevText = rowLines[i - 1].text;
        final currText = rowLines[i].text;

        // Add space unless previous ends with opening bracket or current starts with closing
        if (!prevText.endsWith('(') && !currText.startsWith(')')) {
          buffer.write(' ');
        }
      }
      buffer.write(rowLines[i].text);
    }

    return buffer.toString();
  }

  /// Join lines for natural TTS reading with smart flow control
  ///
  /// CRITICAL for blind users:
  /// - Text should flow as ONE continuous reading
  /// - Use punctuation (not newlines) for pauses
  /// - Newlines become sentence breaks for TTS
  String _joinLinesForReading(List<String> lines) {
    if (lines.isEmpty) return '';
    if (lines.length == 1) return _ensureEndsProperly(lines.first);

    final result = StringBuffer();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (i == 0) {
        result.write(line);
        continue;
      }

      final prevLine = lines[i - 1].trim();

      // Detect if this is a new question/section - needs clear pause
      if (_isNewQuestion(line)) {
        // Ensure previous ends with punctuation for TTS pause
        if (!_endsWithPunctuation(prevLine)) {
          result.write('.');
        }
        result.write(' '); // Single space - TTS handles pause via punctuation
        result.write(line);
      } else if (_isSubQuestion(line)) {
        // Sub-question needs brief pause
        if (!_endsWithPunctuation(prevLine)) {
          result.write(','); // Comma for brief pause
        }
        result.write(' ');
        result.write(line);
      } else if (_shouldContinueLine(prevLine, line)) {
        // Continue flowing - same sentence
        result.write(' ');
        result.write(line);
      } else {
        // New sentence but same paragraph
        if (!_endsWithPunctuation(prevLine)) {
          result.write('.');
        }
        result.write(' ');
        result.write(line);
      }
    }

    return _ensureEndsProperly(result.toString());
  }

  /// Check if text ends with sentence punctuation
  bool _endsWithPunctuation(String text) {
    return RegExp(r'[.!?:;,]$').hasMatch(text.trim());
  }

  /// Ensure text ends with proper punctuation for TTS
  String _ensureEndsProperly(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    if (!RegExp(r'[.!?]$').hasMatch(trimmed)) {
      return '$trimmed.';
    }
    return trimmed;
  }

  /// Check if line starts a new question or section
  /// Handles: 27., 28., 1a, Question 1, Specimen B, a), b), C)
  bool _isNewQuestion(String line) {
    final trimmed = line.trim();

    // Match patterns like: 27., 28., 1a., 2a., Question 1, SECTION
    // But NOT just "(a)" which is an MCQ option
    if (RegExp(r'^\([a-d]\)', caseSensitive: false).hasMatch(trimmed)) {
      return false; // MCQ option, not a new question
    }

    // Detect specimen labels: "Specimen B", "Specimen C:", "specimen D"
    if (RegExp(r'^specimen\s*[a-z]', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }

    // Detect section markers: "a)", "b)", "C)", "a.", "b."
    if (RegExp(r'^[a-c][\)\.\:]', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }

    return RegExp(
      r'^(\d+[a-z]?[\.\):]|Question\s*\d+|SECTION)',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  /// Check if line is a sub-question, Roman numeral point, or MCQ option
  bool _isSubQuestion(String line) {
    final trimmed = line.trim();

    // Match Roman numerals: i), ii), iii), i., ii.
    if (RegExp(r'^[ivx]+[\)\.\:]', caseSensitive: false).hasMatch(trimmed)) {
      return true;
    }

    // Match numbered sub-items in handwriting: 1), 2), 11), etc.
    if (RegExp(r'^\d{1,2}[\)\.]').hasMatch(trimmed)) {
      return true;
    }

    // Match: b., c., (i), (ii), but also standalone MCQ option lines
    return RegExp(
      r'^([b-z][\.\)]|\([a-z]\)\s+\w|\([ivxlcdm]+\)|[ivxlcdm]+[\.\)])',
      caseSensitive: false,
    ).hasMatch(trimmed);
  }

  /// Check if current line should continue the previous line
  bool _shouldContinueLine(String prevLine, String currentLine) {
    final prev = prevLine.trim();
    final curr = currentLine.trim();

    // Continue if previous line ends with colon (introducing a list)
    if (prev.endsWith(':')) {
      return false; // Don't continue - list items should be separate
    }

    // Continue if this looks like marks notation
    if (RegExp(r'^\(\d+\s*marks?\)$', caseSensitive: false).hasMatch(curr)) {
      return true;
    }

    // Continue if current is an MCQ option that continues from previous
    // e.g., previous: "(a) Option1 (b) Option2" current: "(c) Option3 (d) Option4"
    if (RegExp(r'^\([a-d]\)', caseSensitive: false).hasMatch(curr) &&
        RegExp(r'\([a-d]\)\s*\w', caseSensitive: false).hasMatch(prev)) {
      return true;
    }

    // Continue if previous doesn't end with sentence punctuation
    if (!RegExp(r'[.!?)\]]$').hasMatch(prev)) {
      return true;
    }

    // Continue if current starts with lowercase
    if (curr.isNotEmpty && RegExp(r'^[a-z]').hasMatch(curr)) {
      return true;
    }

    // Continue if current starts with opening parenthesis for inline MCQ options
    if (curr.startsWith('(') &&
        RegExp(r'^\([a-d]\)\s*\w', caseSensitive: false).hasMatch(curr)) {
      // This is an MCQ option - continue if previous line had MCQ options
      if (RegExp(r'\([a-d]\)', caseSensitive: false).hasMatch(prev)) {
        return true;
      }
    }

    return false;
  }

  /// Clean text for TTS reading
  /// Optimized for exam papers, MCQs, handwriting, and structured documents
  String _cleanForTTS(String text) {
    var cleaned = text;

    // 1. Fix common handwriting OCR errors FIRST
    cleaned = _fixHandwritingOCRErrors(cleaned);

    // 2. Normalize whitespace (but preserve paragraph breaks)
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 3. Handle blank lines in fill-in-the-blank questions
    cleaned = cleaned.replaceAll(RegExp(r'_{2,}'), ' blank ');

    // 4. Format MCQ options for natural reading
    cleaned = _formatMCQOptions(cleaned);

    // 5. Fix spacing around punctuation
    cleaned = cleaned.replaceAll(RegExp(r' +([.,!?;:])'), r'$1');
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'([.!?;:,])([A-Za-z])'),
      (m) => '${m.group(1)} ${m.group(2)}',
    );

    // 6. Format specimen labels for clear reading
    cleaned = _formatSpecimenLabels(cleaned);

    // 7. Handle Roman numerals for better TTS reading
    cleaned = _expandRomanNumerals(cleaned);

    // 8. Handle question numbering
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'^(\d+)([a-z])[\.\)]', multiLine: true),
      (m) => '${m.group(1)}${m.group(2)}.',
    );

    // 9. Handle marks notation
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'\((\d+)\s*marks?\)', caseSensitive: false),
      (m) => '${m.group(1)} marks.',
    );

    // 10. Handle common symbols
    cleaned = cleaned.replaceAll('&', ' and ');
    cleaned = cleaned.replaceAll('%', ' percent');
    cleaned = cleaned.replaceAll('@', ' at ');

    // 11. Handle common abbreviations
    cleaned = cleaned.replaceAll(
      RegExp(r'\betc\.', caseSensitive: false),
      'etcetera',
    );

    // 12. Fix letter-by-letter OCR issues
    cleaned = _fixLetterByLetter(cleaned);

    // 13. Final cleanup
    final lines = cleaned.split('\n');
    final cleanedLines = lines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    cleaned = cleanedLines.join('\n');
    cleaned = cleaned.replaceAll(RegExp(r' {2,}'), ' ');

    return cleaned.trim();
  }

  /// Fix common handwriting OCR errors
  String _fixHandwritingOCRErrors(String text) {
    var result = text;

    // Fix common word misreads in handwriting
    final corrections = {
      // Soil-related terms (from the sample)
      r'\bsandy\s*soll\b': 'sandy soil',
      r'\bsandy\s*sod\b': 'sandy soil',
      r'\bclay\s*soll\b': 'clay soil',
      r'\bclay\s*sod\b': 'clay soil',
      r'\bloamy\s*soll\b': 'loamy soil',
      r'\bloamy\s*sod\b': 'loamy soil',
      r'\bsod\b': 'soil',
      r'\bsoll\b': 'soil',

      // Common misreads
      r'\brn\b': 'm', // "rn" often misread as "m"
      r'\bspecirnen\b': 'specimen',
      r'\bspecirnan\b': 'specimen',
      r'\bspeclmen\b': 'specimen',
      r'\bfarrners\b': 'farmers',
      r'\bfarrner\b': 'farmer',
      r'\bwaler\b': 'water',
      r'\bwafer\b': 'water',
      r'\babsorb\b': 'absorb',
      r'\babsord\b': 'absorb',
      r'\bretain\b': 'retain',
      r'\bretian\b': 'retain',
      r'\bdrains\b': 'drains',
      r'\bdralns\b': 'drains',
      r'\bfertilizers?\b': 'fertilizers',
      r'\bfertllizers?\b': 'fertilizers',
      r'\bmanure\b': 'manure',
      r'\brnoisture\b': 'moisture',
      r'\bmolsture\b': 'moisture',
      r'\bacidity\b': 'acidity',
      r'\bacldity\b': 'acidity',

      // Fix "11)" being read as "eleven" when it's Roman numeral "ii)"
      r'\b11\)\s': 'ii) ',
      r'\b111\)\s': 'iii) ',

      // Common letter confusions
      r'\bl\b(?=[a-z])': 'I', // standalone "l" before word likely "I"
      r'(?<=[a-z])0(?=[a-z])': 'o', // 0 between letters is likely o
    };

    for (final entry in corrections.entries) {
      result = result.replaceAll(
        RegExp(entry.key, caseSensitive: false),
        entry.value,
      );
    }

    // Fix words with extra spaces (common in handwriting OCR)
    // e.g., "p o r e" → "pore", "s t i c k y" → "sticky"
    result = _fixSpacedWords(result);

    return result;
  }

  /// Fix words that got split with spaces
  String _fixSpacedWords(String text) {
    var result = text;

    // Common words that might get spaced out in handwriting
    final spacedWords = [
      'sticky',
      'pore',
      'spaces',
      'water',
      'roots',
      'crops',
      'easily',
      'retain',
      'drains',
      'absorb',
      'value',
      'farmers',
      'because',
      'allows',
      'penetrate',
      'improve',
      'moisture',
      'manure',
      'acidity',
      'fertilizers',
      'specimen',
      'physical',
      'properties',
      'considered',
      'greater',
      'possess',
      'good',
    ];

    for (final word in spacedWords) {
      // Create pattern like "s t i c k y" or "s  t  i  c  k  y"
      final spaced = word.split('').join(r'\s+');
      result = result.replaceAll(RegExp(spaced, caseSensitive: false), word);
    }

    return result;
  }

  /// Format specimen labels for clear TTS reading
  String _formatSpecimenLabels(String text) {
    var result = text;

    // "Specimen B" → "Specimen B:"
    // "specimen c -" → "Specimen C:"
    result = result.replaceAllMapped(
      RegExp(r'specimen\s*([a-z])\s*[-:.]?\s*', caseSensitive: false),
      (m) => '\nSpecimen ${m.group(1)!.toUpperCase()}: ',
    );

    return result;
  }

  /// Format MCQ options for natural TTS reading
  String _formatMCQOptions(String text) {
    var result = text;

    // Pattern: (a) text (b) text (c) text (d) text
    // Convert to: A: text. B: text. C: text. D: text.
    result = result.replaceAllMapped(
      RegExp(r'\(([a-d])\)\s*([^(]+?)(?=\s*\([a-d]\)|$)', caseSensitive: false),
      (m) {
        final letter = m.group(1)!.toUpperCase();
        final content = m.group(2)!.trim();
        // Add period if content doesn't end with punctuation
        final ending = RegExp(r'[.!?]$').hasMatch(content) ? '' : '.';
        return '$letter: $content$ending ';
      },
    );

    return result;
  }

  /// Expand Roman numerals for TTS
  String _expandRomanNumerals(String text) {
    var result = text;

    final romanMap = {
      'i': '1',
      'ii': '2',
      'iii': '3',
      'iv': '4',
      'v': '5',
      'vi': '6',
      'vii': '7',
      'viii': '8',
      'ix': '9',
      'x': '10',
      'xi': '11',
      'xii': '12',
    };

    // Replace (i), (ii), etc. with readable numbers
    result = result.replaceAllMapped(
      RegExp(r'\(([ivxlcdm]+)\)', caseSensitive: false),
      (m) {
        final roman = m.group(1)!.toLowerCase();
        final num = romanMap[roman];
        return num != null ? '($num)' : m.group(0)!;
      },
    );

    // Replace i), ii), iii) format (handwriting style)
    result = result.replaceAllMapped(
      RegExp(r'^([ivx]+)\)', multiLine: true, caseSensitive: false),
      (m) {
        final roman = m.group(1)!.toLowerCase();
        final num = romanMap[roman];
        return num != null ? '$num)' : m.group(0)!;
      },
    );

    // Replace i., ii., iii. format
    result = result.replaceAllMapped(
      RegExp(r'^([ivx]+)\.', multiLine: true, caseSensitive: false),
      (m) {
        final roman = m.group(1)!.toLowerCase();
        final num = romanMap[roman];
        return num != null ? '$num.' : m.group(0)!;
      },
    );

    return result;
  }

  /// Fix letter-by-letter OCR issues
  String _fixLetterByLetter(String text) {
    var result = text;
    final letterPattern = RegExp(r'\b([A-Za-z]) ([A-Za-z])(?: ([A-Za-z]))*\b');

    result = result.replaceAllMapped(letterPattern, (match) {
      final full = match.group(0) ?? '';
      final letters = full.replaceAll(' ', '');

      if (letters.length >= 2 && letters.length <= 5) {
        final allUpper = full.split(' ').every((l) => l == l.toUpperCase());
        if (allUpper && letters.length <= 4) {
          return letters;
        } else {
          return letters.toLowerCase();
        }
      }
      return full;
    });

    return result;
  }

  /// Process raw text string (when RecognizedText is not available)
  String processRawText(String rawText) {
    if (rawText.trim().isEmpty) return '';
    return _cleanForTTS(rawText);
  }
}

/// Helper class to track line positions
class _PositionedLine {
  final String text;
  final double top;
  final double left;
  final double bottom;

  _PositionedLine({
    required this.text,
    required this.top,
    required this.left,
    required this.bottom,
  });
}
