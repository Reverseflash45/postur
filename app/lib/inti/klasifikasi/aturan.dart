import '../fitur.dart';
import 'klasifikasi.dart';

/// Pendekatan berbasis aturan dari aturan.json (dibuat ml/postur/aturan.py).
///
/// Aturan diperiksa berurutan; yang pertama terpenuhi menentukan label,
/// dan bila tidak ada, labelnya kelas "benar".
class KlasifikasiAturan extends Pengklasifikasi {
  KlasifikasiAturan.dariJson(Map<String, dynamic> js, this.kode)
    : _aturan = [
        for (final a in js['aturan'] as List)
          (
            indeks: kode.indexOf(a['label'] as String),
            fitur: a['indeks_fitur'] as int,
            lebihBesar: a['op'] == '>',
            ambang: (a['ambang'] as num).toDouble(),
          ),
      ],
      _bawaan = kode.indexOf(js['bawaan'] as String);

  final List<String> kode;
  final List<({int indeks, int fitur, bool lebihBesar, double ambang})> _aturan;
  final int _bawaan;

  @override
  String get id => 'aturan';

  @override
  Prediksi prediksi(FiturRepetisi f) {
    var hasil = _bawaan;
    for (final a in _aturan) {
      final v = f.ring[a.fitur];
      if (a.lebihBesar ? v > a.ambang : v < a.ambang) {
        hasil = a.indeks;
        break;
      }
    }
    return Prediksi(hasil, [
      for (var k = 0; k < kode.length; k++) k == hasil ? 1.0 : 0.0,
    ]);
  }

  /// Ambang yang dipakai, untuk ditampilkan di layar info model.
  List<String> uraian(List<String> namaKelas) => [
    for (final a in _aturan)
      '${namaKelas[a.indeks]}: ${namaRingkasan[a.fitur]} '
          '${a.lebihBesar ? '>' : '<'} ${a.ambang.toStringAsFixed(2)}',
  ];
}
