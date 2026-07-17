# Reglas básicas para Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Preservar firmas de tipos genéricos y anotaciones para deserialización JSON
-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod

# Reglas para HTTP y deserialización (usadas por InsForge/HTTP)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-keep class com.google.gson.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Reglas para WebView Flutter (evita que se elimine el puente JS)
-keep class io.flutter.plugins.webviewflutter.** { *; }

# Reglas para Notificaciones Locales
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Reglas para Audio Players
-keep class xyz.luan.audioplayers.** { *; }

# Evitar advertencias sobre la librería de Google Play Core (deferred components no utilizados)
-dontwarn com.google.android.play.core.**

