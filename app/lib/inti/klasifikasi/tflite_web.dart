import 'dart:js_interop';
import 'dart:typed_data';

import '../fitur.dart';
import '../sinyal.dart';
import 'klasifikasi.dart';

const bool tfliteTersedia = true;

@JS('posturTflite')
external _PosturTflite get _tflite;

extension type _PosturTflite._(JSObject _) implements JSObject {
  external JSPromise<JSObject> muat(JSUint8Array isi);
  external JSFloat64Array jalankan(
    JSObject model,
    JSFloat32Array data,
    int n,
    int k,
  );
}

Future<Pengklasifikasi> buatTflite(
  String id,
  Uint8List isi, {
  required List<double> rerata,
  required List<double> sb,
}) async {
  final model = await _tflite.muat(isi.toJS).toDart;
  return KlasifikasiTfliteWeb(id, model, rerata: rerata, sb: sb);
}

/// 1D-CNN atau LSTM di peramban: berkas .tflite yang sama dengan aplikasi
/// Android, dijalankan TensorFlow.js TFLite (WebAssembly).
class KlasifikasiTfliteWeb extends Pengklasifikasi {
  KlasifikasiTfliteWeb(
    this.id,
    this._model, {
    required this.rerata,
    required this.sb,
  });

  @override
  final String id;
  final List<double> rerata;
  final List<double> sb;
  final JSObject _model;

  @override
  Prediksi prediksi(FiturRepetisi f) {
    final data = Float32List(panjangDeret * jumlahFitur);
    for (var i = 0; i < panjangDeret; i++) {
      for (var k = 0; k < jumlahFitur; k++) {
        data[i * jumlahFitur + k] = (f.seq[i][k] - rerata[k]) / sb[k];
      }
    }
    final p = _tflite
        .jalankan(_model, data.toJS, panjangDeret, jumlahFitur)
        .toDart
        .toList();
    return Prediksi(argmax(p), p);
  }
}
