# Minimal ProGuard rules for Flutter Android release builds
# Keep Flutter embedding and plugin classes
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.app.** { *; }

# Keep annotations and signatures (useful for reflection)
-keepattributes *Annotation*
-keepattributes Signature

# Network stack warnings (OkHttp/Okio may be used by plugins)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Gson (if used by plugins)
-dontwarn com.google.gson.**
-keep class com.google.gson.** { *; }

# Kotlin coroutines (if used by plugins)
-dontwarn kotlinx.coroutines.**
