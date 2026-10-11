import 'dart:typed_data';

import 'klasifikasi.dart';

const bool tfliteTersedia = false;

Future<Pengklasifikasi> buatTflite(
  String id,
  Uint8List isi, {
  required List<double> rerata,
  required List<double> sb,
}) async => throw UnsupportedError('TFLite tidak tersedia di platform ini');
