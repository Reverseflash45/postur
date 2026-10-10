// TFLite hanya tersedia di platform native (dart:ffi). Di web, versi stub
// melaporkan tidak tersedia supaya antarmuka bisa menyembunyikan pilihannya.
export 'tflite_stub.dart' if (dart.library.ffi) 'tflite_io.dart';
