import 'dart:typed_data';

import 'landmark.dart';

/// Satu frame hasil pose estimation.
///
/// Koordinat dalam piksel gambar yang sudah tegak (rotasi sensor sudah
/// diterapkan), sama dengan yang disimpan di berkas sesi. [v] adalah
/// visibilitas/likelihood 0–1; frame tanpa orang punya v = 0 semua.
class FramePose {
  FramePose({
    required this.t,
    required this.x,
    required this.y,
    required this.v,
    required this.lebar,
    required this.tinggi,
  });

  factory FramePose.kosong(double t, double lebar, double tinggi) => FramePose(
    t: t,
    x: Float64List(Lm.jumlah),
    y: Float64List(Lm.jumlah),
    v: Float64List(Lm.jumlah),
    lebar: lebar,
    tinggi: tinggi,
  );

  /// Dari isi berkas sesi: 99 angka (x, y, v berselang) atau null.
  factory FramePose.dariJson(
    double t,
    List<dynamic>? p,
    double lebar,
    double tinggi,
  ) {
    final f = FramePose.kosong(t, lebar, tinggi);
    if (p == null) return f;
    for (var j = 0; j < Lm.jumlah; j++) {
      f.x[j] = (p[3 * j] as num).toDouble();
      f.y[j] = (p[3 * j + 1] as num).toDouble();
      f.v[j] = (p[3 * j + 2] as num).toDouble();
    }
    return f;
  }

  /// Waktu dalam milidetik sejak sesi dimulai.
  final double t;
  final Float64List x, y, v;

  /// Ukuran gambar tegak, untuk menggambar kerangka di atas pratinjau.
  final double lebar, tinggi;

  bool get kosong {
    for (final n in v) {
      if (n > 0) return false;
    }
    return true;
  }

  List<double>? keJson() {
    if (kosong) return null;
    double b(double n) => (n * 100).roundToDouble() / 100;
    return [
      for (var j = 0; j < Lm.jumlah; j++) ...[b(x[j]), b(y[j]), b(v[j])],
    ];
  }
}
