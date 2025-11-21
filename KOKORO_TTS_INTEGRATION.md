# Kokoro TTS Integration Guide

## Overview

This app has been enhanced to use **Kokoro TTS** for high-quality, natural-sounding offline speech synthesis, specifically optimized for reading exam questions and answer options to blind users.

## Architecture

### 1. Question Parser Service (`question_parser_service.dart`)

**Purpose**: Parses raw OCR text into structured questions with answer options.

**Key Features**:
- Extracts numbered questions (1., 2., 3., etc.)
- Identifies and pairs answer options (a, b, c, d)
- Cleans OCR errors and removes junk text (e.g., "signi")
- Handles parentheses properly - `(a)` reads as "a" not "bracket open a bracket close"
- Formats questions for natural TTS reading

**Example Output**:
```
Question one. Another name for white blood cell is. Option a, Erythrocyte. Option b, Thrombocyte. Option c, Platelet. Option d, Leucocyte.
```

### 2. Kokoro TTS Service (`kokoro_tts_service.dart`)

**Purpose**: Wraps Kokoro TTS engine for speech synthesis.

**Key Features**:
- Initializes Kokoro TTS with model files
- Converts text to phonemes for better pronunciation
- Generates high-quality audio output
- Supports multiple voices

**Note**: Requires model files:
- `kokoro-v1.0.onnx`
- `voices-v1.0.bin`

### 3. Hybrid TTS Service (`hybrid_tts_service.dart`)

**Purpose**: Provides a unified interface that uses Kokoro TTS when available, falls back to flutter_tts if Kokoro is unavailable.

**Key Features**:
- Automatic fallback mechanism
- Unified API for both TTS engines
- Optimized text formatting for natural reading
- Proper pause handling between questions and options

## Setup Instructions

### 1. Install Dependencies

The `kokoro_tts_flutter` package has been added to `pubspec.yaml`:

```yaml
dependencies:
  kokoro_tts_flutter: ^0.2.0+1
```

Run:
```bash
flutter pub get
```

### 2. Download Model Files

Download the Kokoro TTS model files:
- `kokoro-v1.0.onnx`
- `voices-v1.0.bin`

Place them in the `assets/` directory.

### 3. Update Assets Configuration

Uncomment the asset paths in `pubspec.yaml`:

```yaml
assets:
  - .env
  - assets/kokoro-v1.0.onnx
  - assets/voices-v1.0.bin
```

### 4. Build and Run

```bash
flutter run
```

## How It Works

1. **OCR Processing**: Raw text is extracted from scanned exam papers using Google ML Kit.

2. **Question Parsing**: The `QuestionParserService` processes the OCR text:
   - Identifies numbered questions
   - Extracts question text
   - Finds and pairs answer options
   - Cleans OCR errors

3. **TTS Formatting**: Questions are formatted for natural reading:
   - Question numbers converted to words ("1" → "one")
   - Options clearly labeled ("Option a, ...")
   - Proper punctuation and pauses

4. **Speech Synthesis**: The `HybridTTSService`:
   - Tries to use Kokoro TTS first
   - Falls back to flutter_tts if Kokoro is unavailable
   - Handles pauses and natural speech flow

## Kokoro TTS Advantages

### 1. **Natural Sounding Speech**
- More human-like intonation and pronunciation
- Better handling of technical terms and scientific vocabulary
- Improved clarity for blind users

### 2. **Offline Operation**
- Works completely offline (no internet required)
- Privacy-focused (all processing on-device)
- Reliable in exam environments

### 3. **Multi-Language Support**
- Supports various languages through the `malsami` G2P engine
- Accurate phonemization for better pronunciation

### 4. **Customizable Voices**
- Multiple voice options available
- Can be tuned for optimal clarity

## Troubleshooting

### Kokoro TTS Not Initializing

If Kokoro TTS fails to initialize:
1. Check that model files are in the `assets/` directory
2. Verify asset paths in `pubspec.yaml`
3. Ensure files are properly included in the build
4. The app will automatically fall back to flutter_tts

### Audio Playback Issues

Currently, Kokoro TTS generates audio data but requires an audio player for playback. The `HybridTTSService` uses flutter_tts for actual playback while leveraging Kokoro's text formatting.

For full Kokoro audio playback, integrate `audioplayers` package:
```yaml
dependencies:
  audioplayers: ^5.0.0
```

## Future Enhancements

1. **Full Audio Playback**: Integrate `audioplayers` for direct Kokoro audio playback
2. **Voice Selection**: Add UI for users to select preferred voice
3. **Speed Control**: Adjustable speech rate for Kokoro TTS
4. **SSML Support**: If Kokoro supports SSML, add emphasis and prosody controls

## Code Structure

```
lib/
├── services/
│   ├── question_parser_service.dart    # Parses OCR text into questions
│   ├── kokoro_tts_service.dart         # Kokoro TTS wrapper
│   ├── hybrid_tts_service.dart          # Unified TTS interface
│   └── ocr_service.dart                 # OCR text extraction
└── screens/
    └── camera_scan_screen.dart           # Main UI using new services
```

## Testing

Test with sample exam papers:
1. Scan a question paper with numbered questions
2. Verify questions are correctly parsed
3. Check that all options (a, b, c, d) are read
4. Ensure no junk text ("signi", etc.) is spoken
5. Verify natural pauses between questions and options

## Support

For issues or questions:
- Check Kokoro TTS documentation: https://pub.dev/packages/kokoro_tts_flutter
- Review error logs in console
- Verify model files are correctly placed

