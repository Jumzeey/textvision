# Google ML Kit Text Recognition - Keep all text recognizer classes
# These classes are referenced by the plugin but may be removed by R8 during minification

# Keep Chinese text recognizer classes
-keep class com.google.mlkit.vision.text.chinese.** { *; }

# Keep Devanagari text recognizer classes
-keep class com.google.mlkit.vision.text.devanagari.** { *; }

# Keep Japanese text recognizer classes
-keep class com.google.mlkit.vision.text.japanese.** { *; }

# Keep Korean text recognizer classes
-keep class com.google.mlkit.vision.text.korean.** { *; }

# Keep all ML Kit text recognition classes
-keep class com.google.mlkit.vision.text.** { *; }

# Keep Google ML Kit common classes
-keep class com.google.mlkit.common.** { *; }

# Keep Google ML Kit vision classes
-keep class com.google.mlkit.vision.** { *; }

