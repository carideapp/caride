# ============================================================
# CaRide – ProGuard / R8 rules
# ============================================================

# ---- Flutter & Plugins (Pigeon & Method Channels) ----------
-keep class io.flutter.** { *; }
-keepclassmembers class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keepclassmembers class io.flutter.plugins.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class dev.flutter.** { *; }
-keepclassmembers class dev.flutter.** { *; }
-dontwarn io.flutter.**
-dontwarn dev.flutter.**

# Specifically for shared_preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keepclassmembers class io.flutter.plugins.sharedpreferences.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**

# ---- Firebase ----------------------------------------------
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ---- Kotlin coroutines -------------------------------------
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** { volatile <fields>; }

# ---- Mapbox ------------------------------------------------
-keep class com.mapbox.** { *; }
-dontwarn com.mapbox.**

# ---- Keep data/model classes (serialisation) ---------------
# Add specific keep rules for any classes used with Gson/Firebase if needed.

# ---- General Android ---------------------------------------
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
