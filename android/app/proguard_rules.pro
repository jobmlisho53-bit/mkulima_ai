# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# TensorFlow Lite
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.support.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# Keep model classes
-keep class * implements org.tensorflow.lite.Interpreter
-keep class * implements org.tensorflow.lite.Tensor
-keep class * implements org.tensorflow.lite.support.model.Model
