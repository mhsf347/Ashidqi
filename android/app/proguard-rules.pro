#Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Fonts
-keep class com.google.crypto.tink.** { *; }
-keep class net.sqlcipher.** { *; }

# Hijri
-keep class com.github.hijri.** { *; }

# General
-dontwarn io.flutter.**
-keepattributes Signature
