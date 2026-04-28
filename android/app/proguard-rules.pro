# =====================================================================
# うちの子免許証 - ProGuard / R8 ルール
# 背景: image_background_remover が内部で flutter_onnxruntime を使う。
#       Android リリースビルド時の R8 で ai.onnxruntime.* が strip され、
#       JNI 呼び出しで java_class == null クラッシュが発生する。
# =====================================================================

# ---- 基本属性の保持 ----
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes Exceptions
-keepattributes SourceFile,LineNumberTable

# native メソッドはJNI経由で呼ばれるため必ず保持
-keepclasseswithmembernames class * {
    native <methods>;
}

# ---- Flutter ----
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ---- ONNX Runtime（背景自動削除）★クラッシュ原因 ----
-keep class ai.onnxruntime.** { *; }
-keepclassmembers class ai.onnxruntime.** { *; }
-keep class ai.onnxruntime.providers.** { *; }
-dontwarn ai.onnxruntime.**

# ---- Google Mobile Ads / Firebase ----
-keep class com.google.android.gms.** { *; }
-keep class com.google.firebase.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**

# ---- RevenueCat ----
-keep class com.revenuecat.** { *; }
-dontwarn com.revenuecat.**

# ---- NFC Manager ----
-keep class io.flutter.plugins.nfcmanager.** { *; }

# ---- リフレクションで使われるコンストラクタ保持 ----
-keepclassmembers class * {
    public <init>(android.content.Context);
}

# ---- enum の values()/valueOf() を保持（Kotlin/Java共通の地雷） ----
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ---- Parcelable の CREATOR を保持 ----
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}
