# TextVision - Exam Assistant for Blind Students

A Flutter mobile application that assists blind students during exams by scanning exam papers and reading both printed and handwritten text aloud using on-device OCR and text-to-speech.

## Features

### ✅ Core Features

1. **Camera Scanning**
   - Live camera preview with scanning guide
   - Support for both printed and handwritten text
   - High-resolution image capture
   - Haptic feedback for interactions

2. **OCR (Optical Character Recognition)**
   - On-device text recognition using Google ML Kit
   - Works completely offline
   - Supports multiple languages (Latin, Chinese, Japanese, Korean, Devanagari)
   - Image preprocessing for better accuracy
   - Handwriting recognition with quality scoring

3. **Text-to-Speech**
   - Read extracted text aloud
   - Adjustable speech rate, pitch, and volume
   - Play, pause, resume, and stop controls
   - Language selection support
   - Works offline

4. **Accessibility**
   - Full screen reader support (VoiceOver/TalkBack)
   - Semantic labels for all interactive elements
   - Minimum touch target sizes (48x48dp)
   - Haptic feedback patterns
   - Text scaling support
   - Screen reader announcements

5. **Storage & History**
   - Save transcripts to local storage
   - Export transcripts as text files
   - Scan history tracking
   - Storage usage information

6. **Confidence Scoring**
   - Confidence scores for recognized text
   - Visual indicators for confidence levels
   - Warnings for low-confidence text

## Requirements

- Flutter SDK 3.9.0 or higher
- Dart 3.0.0 or higher
- Android SDK 21+ (Android 5.0+)
- iOS 12.0+
- Physical device with camera (camera not available on emulators)

## Installation

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd textvision
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

## Project Structure

```
lib/
├── main.dart                          # App entry point
├── models/
│   └── ocr_result.dart               # OCR result model
├── screens/
│   ├── home_screen.dart              # Main home screen
│   ├── camera_scan_screen.dart       # Camera scanning interface
│   ├── ocr_processing_screen.dart   # OCR processing screen
│   └── text_display_screen.dart     # Text display with TTS
└── services/
    ├── camera_service.dart           # Camera operations
    ├── ocr_service.dart              # OCR for printed text
    ├── handwriting_recognition_service.dart  # Handwriting OCR
    ├── image_preprocessing_service.dart      # Image enhancement
    ├── tts_service.dart              # Text-to-speech
    ├── permission_service.dart       # Permission handling
    ├── accessibility_service.dart    # Accessibility features
    └── storage_service.dart          # Storage operations
```

## Usage

### Scanning Exam Papers

1. **Open the app** and tap "Scan Printed Text" or "Scan Handwriting"
2. **Grant camera permission** when prompted
3. **Position the exam paper** within the scanning guide frame
4. **Tap the capture button** to take a photo
5. **Wait for OCR processing** to complete
6. **Review the extracted text** on the display screen
7. **Tap "Read Aloud"** to hear the text spoken
8. **Adjust speech settings** using the expandable settings panel
9. **Save the transcript** for later reference

### Text-to-Speech Controls

- **Read Aloud**: Start reading the extracted text
- **Pause**: Pause the current speech
- **Resume**: Resume paused speech
- **Stop**: Stop reading completely
- **Speech Settings**: Adjust rate, pitch, and volume

### Saving Transcripts

- Tap the **Save** button to save the current transcript
- Transcripts are saved to local storage
- Access saved transcripts from the app's storage directory

## Technical Details

### OCR Technology

- **Google ML Kit Text Recognition**: On-device OCR engine
- **Image Preprocessing**: Grayscale conversion, contrast adjustment, sharpening
- **Handwriting Support**: Specialized preprocessing for handwritten text
- **Offline Processing**: All OCR processing happens on-device

### Text-to-Speech

- **flutter_tts**: Cross-platform TTS engine
- **Offline Support**: Uses device's built-in TTS engine
- **Customizable**: Adjustable rate, pitch, and volume

### Accessibility

- **Screen Reader Support**: Full VoiceOver/TalkBack compatibility
- **Semantic Labels**: All UI elements properly labeled
- **Haptic Feedback**: Tactile feedback for interactions
- **Touch Targets**: Minimum 48x48dp for easy interaction

## Permissions

The app requires the following permissions:

- **Camera**: For scanning exam papers
- **Storage**: For saving transcripts (Android 12 and below)
- **Photos**: For saving transcripts (Android 13+)
- **Microphone**: Optional, for future voice commands

## Offline Support

All core features work offline:

- ✅ OCR processing (on-device)
- ✅ Text-to-speech (device TTS engine)
- ✅ Image preprocessing
- ✅ Transcript storage

## Known Limitations

1. **Handwriting Recognition**
   - Accuracy depends on handwriting clarity
   - Works best with thick-lined paper
   - May require multiple attempts for poor handwriting

2. **TTS Pause/Resume**
   - Pause/resume may not be supported on all platforms
   - Falls back to stop on unsupported platforms

3. **Confidence Scores**
   - Google ML Kit may not always provide confidence scores
   - Current implementation includes placeholder confidence estimation

## Testing

Run tests with:
```bash
flutter test
```

## Building for Release

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License.

## Support

For issues, questions, or feature requests, please open an issue on the repository.

## Acknowledgments

- Google ML Kit for OCR capabilities
- flutter_tts for text-to-speech functionality
- Flutter team for the excellent framework
