import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../fitur.dart';
import '../sinyal.dart';
import 'klasifikasi.dart';

const bool tfliteTersedia = true;

Future<Pengklasifikasi> buatTflite(
  String id,
  Uint8List isi, {
  required List<double> rerata,
  required List<double> sb,
}) async => KlasifikasiTflite(id, isi, rerata: rerata, sb: sb);

/// 1D-CNN atau LSTM lewat interpreter TFLite (float32 atau int8).
///
/// Model menerima fitur yang sudah distandarkan; rerata dan simpangan baku
/// diambil dari meta.json, sama dengan yang dipakai saat pelatihan.
class KlasifikasiTflite extends Pengklasifikasi {
  KlasifikasiTflite(
    this.id,
    Uint8List isi, {
    required this.rerata,
    required this.sb,
  }) : _it = Interpreter.fromBuffer(
         isi,
         options: InterpreterOptions()..threads = 2,
       ) {
    final keluar = _it.getOutputTensor(0).shape;
    _nKelas = keluar.last;
  }

  @override
  final String id;
  final List<double> rerata;
  final List<double> sb;
  final Interpreter _it;
  late final int _nKelas;

  @override
  Prediksi prediksi(FiturRepetisi f) {
    final masuk = [
      [
        for (var i = 0; i < panjangDeret; i++)
          [
            for (var k = 0; k < jumlahFitur; k++)
              (f.seq[i][k] - rerata[k]) / sb[k],
          ],
      ],
    ];
    final keluar = [List<double>.filled(_nKelas, 0)];
    _it.run(masuk, keluar);
    final p = keluar[0];
    return Prediksi(argmax(p), p);
  }

  @override
  void tutup() => _it.close();
}
