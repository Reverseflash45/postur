import 'dart:typed_data';

import '../fitur.dart';
import 'klasifikasi.dart';

/// Random Forest dari hutan.json (dibuat ml/postur/hutan.py), dijalankan di Dart.
///
/// scikit-learn membandingkan fitur sebagai float32 (x <= ambang → kiri),
/// jadi nilai fitur dibulatkan ke float32 dulu agar jalurnya sama persis.
class KlasifikasiHutan extends Pengklasifikasi {
  KlasifikasiHutan.dariJson(Map<String, dynamic> js)
    : nKelas = js['n_kelas'] as int,
      _kelas = (js['kelas'] as List).cast<int>(),
      _pohon = [
        for (final p in js['pohon'] as List)
          _Pohon.dariJson(p as Map<String, dynamic>),
      ];

  final int nKelas;
  final List<int> _kelas;
  final List<_Pohon> _pohon;
  final Float32List _f32 = Float32List(1);

  int get jumlahPohon => _pohon.length;
  int get jumlahSimpul => _pohon.fold(0, (a, p) => a + p.f.length);

  @override
  String get id => 'rf';

  List<double> proba(Float64List ring) {
    final x = Float64List(ring.length);
    for (var i = 0; i < ring.length; i++) {
      _f32[0] = ring[i];
      x[i] = _f32[0];
    }
    final hasil = List<double>.filled(nKelas, 0);
    for (final p in _pohon) {
      var i = 0;
      while (p.l[i] != -1) {
        i = x[p.f[i]] <= p.t[i] ? p.l[i] : p.r[i];
      }
      final daun = p.p[i]!;
      for (var k = 0; k < _kelas.length; k++) {
        hasil[_kelas[k]] += daun[k];
      }
    }
    for (var k = 0; k < nKelas; k++) {
      hasil[k] /= _pohon.length;
    }
    return hasil;
  }

  @override
  Prediksi prediksi(FiturRepetisi f) {
    final p = proba(f.ring);
    return Prediksi(argmax(p), p);
  }
}

class _Pohon {
  _Pohon.dariJson(Map<String, dynamic> js)
    : f = Int32List.fromList((js['f'] as List).cast<int>()),
      t = Float64List.fromList([
        for (final v in js['t'] as List) (v as num).toDouble(),
      ]),
      l = Int32List.fromList((js['l'] as List).cast<int>()),
      r = Int32List.fromList((js['r'] as List).cast<int>()),
      p = [
        for (final v in js['p'] as List)
          v == null
              ? null
              : Float64List.fromList([
                  for (final x in v as List) (x as num).toDouble(),
                ]),
      ];

  final Int32List f;
  final Float64List t;
  final Int32List l;
  final Int32List r;
  final List<Float64List?> p;
}
