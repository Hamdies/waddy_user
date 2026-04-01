# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Google Maps
-keep class com.google.android.gms.maps.** { *; }
-keep interface com.google.android.gms.maps.** { *; }

# Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# GetX
-keep class get.** { *; }
-keepclassmembers class * {
    @get.* <methods>;
}

# Facebook SDK
-keep class com.facebook.** { *; }
-dontwarn com.facebook.**

# Keep model classes for JSON serialization
-keepclassmembers class * {
    public <init>(...);
}
-keepattributes *Annotation*
-keepattributes Signature
