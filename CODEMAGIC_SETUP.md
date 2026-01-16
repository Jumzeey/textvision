# Codemagic Setup Guide - Gemini API Key

## ✅ Recommended: Use --dart-define (Production-Safe)

This is the correct, production-safe way to pass secrets into Flutter builds.

### Step 1: Set Environment Variable in Codemagic

1. **Go to your Codemagic project settings**
   - Navigate to your app in Codemagic
   - Click on **"Environment variables"** or **"Variables"** in the left sidebar

2. **Add the environment variable**
   - Click **"Add variable"** or **"Add new"**
   - **Variable name**: `GEMINI_API_KEY`
   - **Variable value**: Your Gemini API key (get it from https://aistudio.google.com/app/apikey)
   - **Group**: Choose "All workflows" or your specific workflow
   - **Secure**: ✅ Check this box to encrypt the value

### Step 2: Update Build Script in Codemagic

In your Codemagic build configuration, update the Flutter build command to include `--dart-define`:

**For Android:**
```bash
flutter build apk --release --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
```

**For iOS:**
```bash
flutter build ipa --release --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
```

**For App Bundle:**
```bash
flutter build appbundle --release --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
```

### Step 3: Using codemagic.yaml (Alternative)

If you use `codemagic.yaml`, add the dart-define to your build script:

```yaml
workflows:
  android-workflow:
    environment:
      groups:
        - app_store_credentials
      vars:
        GEMINI_API_KEY: Encrypted(...)  # Encrypt in Codemagic UI first
    scripts:
      - name: Build Android
        script: |
          flutter build appbundle --release --dart-define=GEMINI_API_KEY=$GEMINI_API_KEY
```

## Local Development

For local development, create a `.env` file in the project root:

```bash
GEMINI_API_KEY=your_api_key_here
```

The app will automatically use the `.env` file if `--dart-define` is not provided.

## Testing Locally with --dart-define

To test the CI/CD setup locally:

```bash
flutter run --dart-define=GEMINI_API_KEY=your_test_key_here
```

## How It Works

The app checks in this order:
1. **`--dart-define=GEMINI_API_KEY=...`** (for CI/CD builds) ✅
2. **`.env` file** (for local development) ✅

This ensures:
- ✅ Production builds use secure `--dart-define` (compiled into the app)
- ✅ Local development uses convenient `.env` file
- ✅ No secrets in source code or git history

## Verification

After building, check the logs for:
- `GeminiVisionService: Using API key from --dart-define` ✅ (CI/CD success)
- `GeminiVisionService: Using API key from .env file` ✅ (local dev)

## Common Issues

1. **Variable not found**
   - Make sure `--dart-define=GEMINI_API_KEY=$GEMINI_API_KEY` is in your build command
   - Verify the environment variable is set in Codemagic UI

2. **Variable name mismatch**
   - Must be exactly: `GEMINI_API_KEY` (case-sensitive)
   - Both the env var name and dart-define name must match

3. **Build script not updated**
   - The default Codemagic build script might not include `--dart-define`
   - You need to customize the build script to add it
