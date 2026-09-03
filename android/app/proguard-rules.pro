# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Adivery ProGuard Rules
-keep class com.adivery.** { *; }
-keepinterface com.adivery.** { *; }
-dontwarn com.adivery.**

# Serialization and Reflection
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
