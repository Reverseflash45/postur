// TFLite native (dart:ffi) di Android; di web berkas .tflite yang sama
// dijalankan TensorFlow.js TFLite. Platform lain memakai stub.
export 'tflite_stub.dart'
    if (dart.library.ffi) 'tflite_io.dart'
    if (dart.library.js_interop) 'tflite_web.dart';
