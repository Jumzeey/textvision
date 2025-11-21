# Google ML Kit Text Recognition - ProGuard/R8 Rules
# Suppress errors about missing language-specific text recognizer classes
# These are optional modules that may not be included in the build

# Ignore all warnings (including missing class warnings)
-ignorewarnings

# IMPORTANT: Put -dontwarn rules to suppress missing class errors
# Suppress warnings for missing language-specific recognizer classes
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Suppress warnings for inner classes (Builder classes)
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# Keep all ML Kit text recognition classes that are actually used
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google.mlkit.vision.text.**$* { *; }

# Keep Google ML Kit common classes
-keep class com.google.mlkit.common.** { *; }

# Keep Google ML Kit vision classes
-keep class com.google.mlkit.vision.** { *; }

# Keep the plugin classes
-keep class com.google_mlkit_text_recognition.** { *; }
