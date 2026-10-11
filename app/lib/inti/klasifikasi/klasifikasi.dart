import '../fitur.dart';

/// Hasil klasifikasi satu repetisi.
class Prediksi {
  const Prediksi(this.indeks, this.peluang);

  final int indeks;

  /// Peluang per kelas; untuk aturan berupa one-hot.
  final List<double> peluang;

  double get yakin => peluang[indeks];
}

/// Antarmuka bersama keempat pendekatan.
abstract class Pengklasifikasi {
  /// 'aturan', 'rf', 'cnn', 'cnn_int8', 'lstm', 'lstm_int8'.
  String get id;

  Prediksi prediksi(FiturRepetisi f);

  void tutup() {}
}

int argmax(List<double> p) {
  var i = 0;
  for (var k = 1; k < p.length; k++) {
    if (p[k] > p[i]) i = k;
  }
  return i;
}

/// Nama yang ditampilkan untuk tiap id model.
const namaModel = {
  'aturan': 'Aturan',
  'rf': 'Random Forest',
  'cnn': '1D-CNN',
  'cnn_int8': '1D-CNN int8',
  'lstm': 'LSTM',
  'lstm_int8': 'LSTM int8',
};

/// Nama pendek untuk ruang sempit (strip ringkasan, riwayat).
const namaPendek = {
  'aturan': 'Aturan',
  'rf': 'RF',
  'cnn': '1D-CNN',
  'cnn_int8': 'CNN-i8',
  'lstm': 'LSTM',
  'lstm_int8': 'LSTM-i8',
};

const urutanModel = ['aturan', 'rf', 'cnn', 'cnn_int8', 'lstm', 'lstm_int8'];
