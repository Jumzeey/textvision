/// Service for parsing OCR text into structured questions and answer options
///
/// Handles:
/// - Extracting numbered questions from raw OCR text
/// - Identifying and pairing answer options (a, b, c, d)
/// - Cleaning OCR errors and junk text
/// - Formatting for natural TTS reading
class QuestionParserService {
  /// Parse raw OCR text into structured questions with options
  ///
  /// Returns a list of Question objects, each containing:
  /// - Question number
  /// - Question text
  /// - List of answer options
  List<Question> parseQuestions(String rawText) {
    if (rawText.trim().isEmpty) return [];

    // Step 1: Clean and normalize the text
    final cleaned = _cleanOCRText(rawText);

    // Step 2: Remove non-question content (instructions, headers, etc.)
    final questionText = _extractQuestionSection(cleaned);

    // Step 3: Split into individual questions
    final questions = _extractQuestions(questionText);

    return questions;
  }

  /// Clean OCR text - fix common errors and remove junk
  String _cleanOCRText(String text) {
    var cleaned = text;

    // Remove common OCR junk patterns
    cleaned = cleaned.replaceAll(RegExp(r'\b(signi|sign|sig|si)\b', caseSensitive: false), '');
    
    // Fix spacing issues
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    
    // Fix common OCR character errors for option markers
    // OCR often reads "(a)" as "$a", "$1", "a)", "(a", etc.
    // CRITICAL: Replace these BEFORE any other processing to prevent TTS from saying "one dollar"
    
    // Handle $1, $2, $3, $4 FIRST (most common OCR error)
    // Use word boundaries and ensure we're matching option markers, not random $1 in text
    cleaned = cleaned.replaceAll(RegExp(r'\$1(?:\s|\)|,|\.|$)', caseSensitive: false), '(a)');
    cleaned = cleaned.replaceAll(RegExp(r'\$2(?:\s|\)|,|\.|$)', caseSensitive: false), '(b)');
    cleaned = cleaned.replaceAll(RegExp(r'\$3(?:\s|\)|,|\.|$)', caseSensitive: false), '(c)');
    cleaned = cleaned.replaceAll(RegExp(r'\$4(?:\s|\)|,|\.|$)', caseSensitive: false), '(d)');
    
    // Handle dollar sign variations: $a, $b, $c, $d
    cleaned = cleaned.replaceAll(RegExp(r'\$([a-d])(?:\s|\)|,|\.|$)', caseSensitive: false), r'($1)');
    
    // Handle missing opening parenthesis: a), b), c), d)
    cleaned = cleaned.replaceAll(RegExp(r'\b([a-d])\)', caseSensitive: false), r'($1)');
    
    // Handle missing closing parenthesis: (a, (b, (c, (d
    cleaned = cleaned.replaceAll(RegExp(r'\(([a-d])(?:\s|,|$)', caseSensitive: false), r'($1) ');
    
    // Normalize option markers - ensure (a), (b), (c), (d) format
    cleaned = cleaned.replaceAll(RegExp(r'\(([a-d])\)', caseSensitive: false), r'($1)');
    
    // Fix common OCR character errors (but be careful not to break option markers)
    // Only replace 0 and 1 when they're not part of option markers
    cleaned = cleaned.replaceAll(RegExp(r'\b0\b(?!\))'), 'O'); // 0 -> O in words (not before ))
    cleaned = cleaned.replaceAll(RegExp(r'\b1\b(?!\))'), 'I'); // 1 -> I in words (not before ))
    
    // Fix punctuation spacing
    cleaned = cleaned.replaceAll(RegExp(r'\s+([.,!?;:])'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'([.,!?;:])([A-Za-z])'), r'$1 $2');
    
    return cleaned.trim();
  }

  /// Extract the question section, removing instructions and headers
  String _extractQuestionSection(String text) {
    // Look for section markers like "SECTION A", "Answer all questions", etc.
    final sectionPattern = RegExp(
      r'(?:SECTION\s+[A-Z]|Answer\s+all\s+questions?|Questions?|Part\s+[A-Z\d])',
      caseSensitive: false,
    );
    
    final sectionMatch = sectionPattern.firstMatch(text);
    if (sectionMatch != null) {
      // Start from after the section marker
      return text.substring(sectionMatch.end).trim();
    }
    
    return text;
  }

  /// Extract individual questions from text
  List<Question> _extractQuestions(String text) {
    final questions = <Question>[];
    
    // Pattern to match question numbers: 1., 2., 3., etc.
    final questionNumberPattern = RegExp(
      r'(?:^|\n)\s*(\d+)[\.\):]\s*',
      multiLine: true,
    );
    
    final matches = questionNumberPattern.allMatches(text);
    
    if (matches.isEmpty) {
      // No numbered questions found, try to parse as single question
      return _parseSingleQuestion(text, 1);
    }
    
    // Extract each question
    for (int i = 0; i < matches.length; i++) {
      final match = matches.elementAt(i);
      final questionNumber = int.tryParse(match.group(1) ?? '1') ?? 1;
      
      // Determine the end of this question (start of next question or end of text)
      final questionStart = match.end;
      final questionEnd = i < matches.length - 1
          ? matches.elementAt(i + 1).start
          : text.length;
      
      final questionText = text.substring(questionStart, questionEnd).trim();
      
      // Parse the question and its options
      final question = _parseQuestionContent(questionNumber, questionText);
      if (question != null) {
        questions.add(question);
      }
    }
    
    return questions;
  }

  /// Parse a single question's content (text + options)
  Question? _parseQuestionContent(int number, String content) {
    // Extract options - look for (a), (b), (c), (d) patterns
    // Also handle OCR errors like $a, $1, a), etc. (should be cleaned by _cleanOCRText)
    final optionPattern = RegExp(
      r'\(([a-d])\)\s*([^(]+?)(?=\([a-d]\)|$)',
      caseSensitive: false,
    );
    
    // Also try to match if options weren't properly cleaned
    // Look for patterns like: $a, $b, $1, $2, etc.
    if (optionPattern.allMatches(content).isEmpty) {
      // Try alternative patterns for OCR errors
      final altPattern = RegExp(
        r'[\$\(]?([a-d1-4])[\)]?\s*([^$\(]+?)(?=[\$\(][a-d1-4]\)?|$)',
        caseSensitive: false,
      );
      final altMatches = altPattern.allMatches(content);
      if (altMatches.isNotEmpty) {
        // Found options with OCR errors, clean them up
        final options = <String>[];
        String questionText = content;
        
        for (final match in altMatches) {
          final optionMarker = match.group(1) ?? '';
          final optionText = match.group(2)?.trim() ?? '';
          
          // Convert $1, $2, etc. to a, b, c, d
          String optionLetter = optionMarker.toLowerCase();
          if (optionLetter == '1') optionLetter = 'a';
          else if (optionLetter == '2') optionLetter = 'b';
          else if (optionLetter == '3') optionLetter = 'c';
          else if (optionLetter == '4') optionLetter = 'd';
          
          if (optionText.isNotEmpty && ['a', 'b', 'c', 'd'].contains(optionLetter)) {
            options.add(_cleanOptionText(optionText));
            // Update question text to exclude this option
            if (match.start < questionText.length) {
              questionText = questionText.substring(0, match.start).trim();
            }
          }
        }
        
        if (options.isNotEmpty) {
          questionText = _cleanQuestionText(questionText);
          questionText = questionText.replaceFirst(RegExp(r'^\d+[\.\):]\s*'), '');
          
          return Question(
            number: number,
            text: questionText,
            options: options,
          );
        }
      }
    }
    
    final optionMatches = optionPattern.allMatches(content);
    final options = <String>[];
    
    // Extract all options
    for (final match in optionMatches) {
      final optionLetter = match.group(1)?.toLowerCase() ?? '';
      final optionText = match.group(2)?.trim() ?? '';
      if (optionText.isNotEmpty && ['a', 'b', 'c', 'd'].contains(optionLetter)) {
        // Clean up the option text
        final cleaned = _cleanOptionText(optionText);
        if (cleaned.isNotEmpty) {
          options.add(cleaned);
        }
      }
    }
    
    // If no options found with standard pattern, try more aggressive matching
    if (options.isEmpty) {
      // Try matching any pattern that looks like an option
      final aggressivePattern = RegExp(
        r'(?:\(|\[|\$|^|\s)([a-d1-4])(?:\)|\]|\)|,|\.|\s)\s*([A-Z][^\(\)\[\$]+?)(?=(?:\(|\[|\$|^|\s)[a-d1-4]|$)',
        caseSensitive: false,
        multiLine: true,
      );
      
      final aggressiveMatches = aggressivePattern.allMatches(content);
      for (final match in aggressiveMatches) {
        String optionMarker = match.group(1)?.toLowerCase() ?? '';
        final optionText = match.group(2)?.trim() ?? '';
        
        // Convert 1,2,3,4 to a,b,c,d
        if (optionMarker == '1') optionMarker = 'a';
        else if (optionMarker == '2') optionMarker = 'b';
        else if (optionMarker == '3') optionMarker = 'c';
        else if (optionMarker == '4') optionMarker = 'd';
        
        if (optionText.isNotEmpty && 
            optionText.length > 2 && 
            ['a', 'b', 'c', 'd'].contains(optionMarker) &&
            !options.any((opt) => opt.toLowerCase() == optionText.toLowerCase())) {
          options.add(_cleanOptionText(optionText));
        }
      }
    }
    
    // Extract question text (everything before the first option)
    String questionText = content;
    if (optionMatches.isNotEmpty) {
      questionText = content.substring(0, optionMatches.first.start).trim();
    }
    
    // Clean question text
    questionText = _cleanQuestionText(questionText);
    
    // Remove question number if it appears in the text
    questionText = questionText.replaceFirst(RegExp(r'^\d+[\.\):]\s*'), '');
    
    if (questionText.isEmpty && options.isEmpty) {
      return null; // Invalid question
    }
    
    return Question(
      number: number,
      text: questionText,
      options: options,
    );
  }

  /// Parse text as a single question (fallback when no numbering found)
  List<Question> _parseSingleQuestion(String text, int number) {
    final question = _parseQuestionContent(number, text);
    if (question != null) {
      return [question];
    }
    return [];
  }

  /// Clean question text
  String _cleanQuestionText(String text) {
    var cleaned = text;
    
    // Remove dollar sign patterns that cause TTS to say "one dollar"
    cleaned = _removeDollarSigns(cleaned);
    
    // Remove extra whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    
    // Ensure proper sentence ending
    if (cleaned.isNotEmpty && !cleaned.endsWith('.') && 
        !cleaned.endsWith('?') && !cleaned.endsWith('!')) {
      cleaned = '$cleaned.';
    }
    
    return cleaned.trim();
  }

  /// Clean option text
  String _cleanOptionText(String text) {
    var cleaned = text;
    
    // Remove option markers that might be duplicated
    cleaned = cleaned.replaceAll(RegExp(r'^\([a-d]\)\s*', caseSensitive: false), '');
    
    // Remove dollar sign patterns ($1, $2, $a, $b, etc.) - these cause TTS to say "one dollar"
    cleaned = cleaned.replaceAll(RegExp(r'\$[1-4a-d]\b', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\$\s*'), '');
    
    // Remove extra whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    
    // Remove trailing punctuation that doesn't belong
    cleaned = cleaned.replaceAll(RegExp(r'[.,;]+$'), '');
    
    return cleaned.trim();
  }

  /// Format a question for natural TTS reading
  ///
  /// Example: "Question one. Another name for white blood cell is. Option a, Erythrocyte. Option b, Thrombocyte..."
  String formatForTTS(Question question) {
    final buffer = StringBuffer();
    
    // Add question number
    buffer.write('Question ${_numberToWords(question.number)}. ');
    
    // Add question text (clean any remaining $1, $2, etc.)
    if (question.text.isNotEmpty) {
      var questionText = _removeDollarSigns(question.text);
      buffer.write(questionText);
      if (!questionText.endsWith('.') && !questionText.endsWith('?')) {
        buffer.write('.');
      }
      buffer.write(' ');
    }
    
    // Add options - always use explicit "Option a", "Option b", etc.
    final optionLabels = ['a', 'b', 'c', 'd'];
    for (int i = 0; i < question.options.length && i < optionLabels.length; i++) {
      buffer.write('Option ${optionLabels[i]}, ');
      // Clean any remaining $1, $2, etc. from option text
      var optionText = _removeDollarSigns(question.options[i]);
      buffer.write(optionText);
      buffer.write('. ');
    }
    
    var result = buffer.toString().trim();
    
    // Final cleanup - remove any remaining $1, $2, $3, $4 patterns
    result = _removeDollarSigns(result);
    
    return result;
  }

  /// Remove dollar sign patterns that TTS reads as "one dollar", "two dollar", etc.
  String _removeDollarSigns(String text) {
    var cleaned = text;
    
    // Remove $1, $2, $3, $4 patterns (TTS reads these as "one dollar", etc.)
    cleaned = cleaned.replaceAll(RegExp(r'\$1\b'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\$2\b'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\$3\b'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\$4\b'), '');
    
    // Remove $a, $b, $c, $d patterns
    cleaned = cleaned.replaceAll(RegExp(r'\$([a-d])\b', caseSensitive: false), '');
    
    // Remove standalone dollar signs
    cleaned = cleaned.replaceAll(RegExp(r'\$\s*'), '');
    
    // Clean up extra spaces
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    
    return cleaned.trim();
  }

  /// Convert number to words (1 -> one, 2 -> two, etc.)
  String _numberToWords(int number) {
    const words = [
      'zero', 'one', 'two', 'three', 'four', 'five',
      'six', 'seven', 'eight', 'nine', 'ten',
      'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen',
      'sixteen', 'seventeen', 'eighteen', 'nineteen', 'twenty',
    ];
    
    if (number >= 0 && number < words.length) {
      return words[number];
    }
    
    // For numbers beyond 20, use numeric representation
    return number.toString();
  }
}

/// Represents a parsed question with its options
class Question {
  final int number;
  final String text;
  final List<String> options;

  Question({
    required this.number,
    required this.text,
    required this.options,
  });

  /// Check if question has options
  bool get hasOptions => options.isNotEmpty;

  /// Get total number of options
  int get optionCount => options.length;
}

