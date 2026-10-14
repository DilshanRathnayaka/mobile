# ================================================================
# 🔒 R8 / PROGUARD OBFUSCATION RULES FOR ASSET MANAGER
# ================================================================

# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Security & Biometrics
-keep class androidx.biometric.** { *; }

# Prevent tampering with JSON models
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Remove debugging logs in release APK to prevent data leakage in logcat
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
}

-dontwarn okio.**
-dontwarn java.awt.**
-dontwarn com.google.android.play.core.**
