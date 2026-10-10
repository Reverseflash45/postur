# WorkManager (dibawa dependensi plugin) membuat WorkDatabase_Impl lewat
# refleksi Room. Tanpa aturan ini R8 membuang konstruktornya dan aplikasi
# langsung crash saat dibuka ("Failed to create an instance of WorkDatabase").
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }

# LiteRT/TFLite dipanggil lewat FFI dan JNI.
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**

# ML Kit menemukan komponennya lewat refleksi (ComponentRegistrar tanpa
# argumen). Tanpa aturan ini deteksi pose gagal diam-diam di build release.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }
-dontwarn com.google.mlkit.**
