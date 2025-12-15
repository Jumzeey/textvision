# Troubleshooting Sherpa-ONNX TTS Issues

## Error: "Please initialize sherpa-onnx first"

This error indicates that the native sherpa-onnx library is not properly initialized. This is a **native plugin initialization issue**, not a Dart code issue.

### Solution Steps

#### 1. Full Rebuild (REQUIRED)
**DO NOT use hot restart** - native plugins require a full rebuild:

```bash
# Stop the app completely, then:
flutter clean
flutter pub get
flutter run
```

#### 2. iOS Specific Setup
If you're on iOS, ensure CocoaPods are installed:

```bash
cd ios
pod install
cd ..
flutter run
```

#### 3. Verify Plugin Installation
Check that `sherpa_onnx` is properly listed in:
- `pubspec.yaml` (should have `sherpa_onnx: ^1.12.5`)
- `pubspec.lock` (should show the package)

#### 4. Check Model Files
The app should find:
- Model: `vits-ljs.onnx` (should be ~114MB)
- Tokens: `tokens.txt`

These are automatically copied from `lib/vits-ljs/` to the app's documents directory on first run.

### Common Causes

1. **Hot Restart Instead of Full Rebuild**
   - ❌ Hot restart doesn't initialize native plugins
   - ✅ Use full rebuild: `flutter clean && flutter run`

2. **iOS Pods Not Installed**
   - Run `pod install` in the `ios/` directory
   - Then rebuild the app

3. **Plugin Not Linked**
   - Ensure `sherpa_onnx` is in `pubspec.yaml`
   - Run `flutter pub get`
   - Full rebuild required

### Verification

After a full rebuild, you should see in the logs:
```
flutter: Model file found: /path/to/vits-ljs.onnx (114124456 bytes)
flutter: Using tokens file: /path/to/tokens.txt
flutter: Sherpa-ONNX TTS initialized successfully
```

If you still see the error after a full rebuild, check:
- iOS: Verify pods are installed (`ios/Podfile.lock` should exist)
- Android: Check that native libraries are included in the build

### Additional Notes

- The `audioplayers` plugin also requires a full rebuild (not hot restart)
- Both errors will be resolved with a proper full rebuild
- Model files are automatically copied from assets on first run



