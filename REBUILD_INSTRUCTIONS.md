# Rebuild Instructions for Android 4.4 Support

## ⚠️ Important: You Must Rebuild the APK

The parse error you're seeing is because the APK was built **before** we made the Android 4.4 compatibility changes. You need to rebuild the APK with the new configuration.

## Steps to Fix the Parse Error

### 1. Clean Previous Builds
```bash
cd /Users/macuser/Development/textvision
flutter clean
```

### 2. Get Dependencies
```bash
flutter pub get
```

### 3. Rebuild for Android 4.4
```bash
# For release APK
flutter build apk --release

# OR for debug (faster to test)
flutter build apk --debug
```

### 4. Install on Your Android 4.4 Device
```bash
# Connect your device via USB and enable USB debugging
# Then install:
flutter install

# OR manually install the APK:
# The APK will be at: build/app/outputs/flutter-apk/app-release.apk
```

## What We Changed

1. ✅ **minSdk set to 19** (Android 4.4 KitKat)
2. ✅ **Java 8 compatibility** (required for Android 4.4)
3. ✅ **Forced dependency compatibility** (all plugins now support API 19)
4. ✅ **Updated manifest** for pre-Marshmallow permissions

## Troubleshooting

### If Parse Error Still Occurs

1. **Check Flutter Version**
   ```bash
   flutter --version
   ```
   - Flutter 3.9 should support API 19
   - Flutter 3.22+ does NOT support API 19

2. **Verify Build Configuration**
   ```bash
   # Check the minSdk in build.gradle.kts
   grep "minSdk" android/app/build.gradle.kts
   ```
   Should show: `minSdk = 19`

3. **Check for Dependency Conflicts**
   Some dependencies may still require API 21+:
   - `google_mlkit_text_recognition` might require API 21+
   - If this is the case, the app may install but ML Kit features won't work

4. **Try Debug Build First**
   ```bash
   flutter build apk --debug
   ```
   Debug builds are less optimized and may reveal compatibility issues.

### If ML Kit Requires API 21+

If `google_mlkit_text_recognition` requires API 21+, you have two options:

**Option 1: Make ML Kit Optional (Recommended)**
- The app will install on Android 4.4
- OCR will fall back to Gemini API (if online) or show an error
- Other features (TTS, camera) will still work

**Option 2: Raise minSdk to 21**
- Better compatibility with all features
- But won't work on Android 4.4

## Expected Behavior After Rebuild

✅ **APK should install** on Android 4.4.4  
✅ **App should launch** without parse errors  
⚠️ **ML Kit OCR** may not work (if it requires API 21+)  
✅ **Camera** should work  
✅ **TTS** should work  
✅ **Gemini API** should work (if online)

## Verification

After rebuilding and installing:

1. **Check if app launches** - No parse error
2. **Test camera** - Should open camera preview
3. **Test OCR** - May fail if ML Kit requires API 21+
4. **Test TTS** - Should read text aloud
5. **Check logs** - Look for any API level errors

## Next Steps

If the parse error is fixed but ML Kit doesn't work, we can:
1. Add runtime API level checks
2. Make ML Kit optional with graceful fallback
3. Use Gemini API as primary OCR on Android 4.4
