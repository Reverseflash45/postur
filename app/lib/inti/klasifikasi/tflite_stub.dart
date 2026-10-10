import 'dart:typed_data';

import 'klasifikasi.dart';

const bool tfliteTersedia = false;

Pengklasifikasi buatTflite(
  String id,
  Uint8List isi, {
  required List<double> rerata,
  required List<double> sb,
}) => throw UnsupportedError('TFLite hanya tersedia di aplikasi Android');
