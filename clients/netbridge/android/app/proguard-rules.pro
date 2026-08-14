# Flutter / embedding (Flutter tools also ship flutter_proguard_rules.pro)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# WireGuard (tunnel + Go backend VpnService + Klaxon JSON)
-keep class com.wireguard.** { *; }
-keep class com.wireguard.android.** { *; }
-keep class com.wireguard.crypto.** { *; }
-keep class billion.group.wireguard_flutter.** { *; }
-keep class com.beust.klaxon.** { *; }
-keepclassmembers class * implements com.wireguard.android.backend.Tunnel {
    *;
}

# flutter_secure_storage + Tink / EncryptedSharedPreferences
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }

# mobile_scanner / ML Kit barcode (consumer rules exist; keep entry points)
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep native method names used by JNI (.so)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Gson / reflection-friendly enums if any plugin uses them
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Flutter deferred components / Play Store split APIs (not used; avoid R8 missing-class errors)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
