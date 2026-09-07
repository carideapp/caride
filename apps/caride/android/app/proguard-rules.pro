# ============================================================
# CaRide – ProGuard / R8 rules
# ============================================================

# ---- Flutter -----------------------------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

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
