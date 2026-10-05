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

# Google Play Core — deferred components, which this app does not use.
#
# Flutter's embedding always references PlayStoreDeferredComponentManager and
# FlutterPlayStoreSplitApplication, whether or not an app declares
# `deferred-components` in pubspec.yaml. The Play Core library that provides
# them is only pulled in when it does. This one does not, so R8 sees the
# references, cannot resolve the classes, and fails the release build outright:
#
#   ERROR: R8: Missing class com.google.android.play.core.splitcompat.
#          SplitCompatApplication
#
# `com.google.android.play` is a DIFFERENT package from
# `com.google.android.gms` above — the existing rule does not cover it, which
# is why release built fine until it did not.
#
# -dontwarn rather than -keep: there is nothing to keep. The code paths that
# touch these are unreachable in an app with no deferred components, and
# adding the Play Core dependency to satisfy R8 would ship a library for a
# feature that is not used.
-dontwarn com.google.android.play.core.**

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
