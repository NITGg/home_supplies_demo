# ── Flutter ────────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# ── Play Core (Flutter engine references these; not used in standard apps) ─────
-dontwarn com.google.android.play.core.**

# ── Firebase ───────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ── OkHttp / Dio networking ────────────────────────────────────────────────────
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ── Your app classes ───────────────────────────────────────────────────────────
-keep class com.nit.tawreedat.courier.** { *; }

# ── Kotlin ─────────────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# ── Prevent stripping serializable/data classes (used by Dio/JSON) ─────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod