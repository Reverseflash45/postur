import 'dart:math' as math;
import 'dart:typed_data';

import 'landmark.dart';

/// Praproses deret landmark — salinan ml/postur/sinyal.py.
///
/// Urutan operasi aritmetika sengaja disamakan dengan versi numpy supaya
/// hasilnya identik sampai pembulatan terakhir (lihat test/paritas_test.dart).

const double ambangVis = 0.5;
const int panjangDeret = 64;

const List<double> _sg7 = [
  -2 / 21.0,
  3 / 21.0,
  6 / 21.0,
  7 / 21.0,
  6 / 21.0,
  3 / 21.0,
  -2 / 21.0,
];

/// Setara np.interp untuk xp yang naik.
double interp(double x, List<double> xp, List<double> fp) {
  final n = xp.length;
  if (x < xp[0]) return fp[0];
  if (x > xp[n - 1]) return fp[n - 1];
  // Indeks terbesar j dengan xp[j] <= x.
  var lo = 0, hi = n - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (xp[mid] <= x) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  final j = lo;
  if (j == n - 1) return fp[j];
  if (xp[j] == x) return fp[j];
  final slope = (fp[j + 1] - fp[j]) / (xp[j + 1] - xp[j]);
  var r = slope * (x - xp[j]) + fp[j];
  if (r.isNaN) {
    r = slope * (x - xp[j + 1]) + fp[j + 1];
    if (r.isNaN && fp[j] == fp[j + 1]) r = fp[j];
  }
  return r;
}

/// Koordinat satu potongan waktu: xs[i][j], ys[i][j], vs[i][j].
class Deret {
  Deret(this.t, this.xs, this.ys, this.vs);

  final List<double> t;
  final List<Float64List> xs, ys, vs;

  int get n => t.length;
}

/// Ganti titik dengan visibilitas rendah memakai interpolasi linear antar-frame.
Deret isiHilang(Deret d, {double ambang = ambangVis}) {
  final xs = [for (final r in d.xs) Float64List.fromList(r)];
  final ys = [for (final r in d.ys) Float64List.fromList(r)];
  final n = d.n;
  for (var j = 0; j < Lm.jumlah; j++) {
    final okIdx = <double>[];
    final okX = <double>[], okY = <double>[];
    for (var i = 0; i < n; i++) {
      if (d.vs[i][j] >= ambang) {
        okIdx.add(i.toDouble());
        okX.add(xs[i][j]);
        okY.add(ys[i][j]);
      }
    }
    if (okIdx.isEmpty || okIdx.length == n) continue;
    for (var i = 0; i < n; i++) {
      if (d.vs[i][j] >= ambang) continue;
      xs[i][j] = interp(i.toDouble(), okIdx, okX);
      ys[i][j] = interp(i.toDouble(), okIdx, okY);
    }
  }
  return Deret(d.t, xs, ys, d.vs);
}

/// Savitzky–Golay (7, 2) pada satu deret; tepi diisi nilai ujung.
Float64List haluskanDeret(List<double> x) {
  final n = x.length;
  final pad = Float64List(n + 6);
  for (var i = 0; i < n + 6; i++) {
    pad[i] = x[math.min(math.max(i - 3, 0), n - 1)];
  }
  final hasil = Float64List(n);
  for (var i = 0; i < n; i++) {
    var h = 0.0;
    for (var k = 0; k < 7; k++) {
      h = h + _sg7[k] * pad[k + i];
    }
    hasil[i] = h;
  }
  return hasil;
}

Deret haluskan(Deret d) {
  final n = d.n;
  final xs = List.generate(n, (_) => Float64List(Lm.jumlah));
  final ys = List.generate(n, (_) => Float64List(Lm.jumlah));
  final kolom = Float64List(n);
  for (var j = 0; j < Lm.jumlah; j++) {
    for (var i = 0; i < n; i++) {
      kolom[i] = d.xs[i][j];
    }
    final hx = haluskanDeret(kolom);
    for (var i = 0; i < n; i++) {
      kolom[i] = d.ys[i][j];
    }
    final hy = haluskanDeret(kolom);
    for (var i = 0; i < n; i++) {
      xs[i][j] = hx[i];
      ys[i][j] = hy[i];
    }
  }
  return Deret(d.t, xs, ys, d.vs);
}

double median(List<double> a) {
  final s = [...a]..sort();
  final n = s.length;
  return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}

/// Titik asal di tengah pinggul, skala = median panjang torso.
Deret normalisasi(Deret d) {
  final n = d.n;
  final torso = <double>[];
  for (var i = 0; i < n; i++) {
    final px = (d.xs[i][Lm.pinggulKi] + d.xs[i][Lm.pinggulKa]) / 2.0;
    final py = (d.ys[i][Lm.pinggulKi] + d.ys[i][Lm.pinggulKa]) / 2.0;
    final bx = (d.xs[i][Lm.bahuKi] + d.xs[i][Lm.bahuKa]) / 2.0;
    final by = (d.ys[i][Lm.bahuKi] + d.ys[i][Lm.bahuKa]) / 2.0;
    final dx = bx - px, dy = by - py;
    torso.add(math.sqrt(dx * dx + dy * dy));
  }
  final skala = math.max(median(torso), 1e-6);
  final xs = List.generate(n, (_) => Float64List(Lm.jumlah));
  final ys = List.generate(n, (_) => Float64List(Lm.jumlah));
  for (var i = 0; i < n; i++) {
    final px = (d.xs[i][Lm.pinggulKi] + d.xs[i][Lm.pinggulKa]) / 2.0;
    final py = (d.ys[i][Lm.pinggulKi] + d.ys[i][Lm.pinggulKa]) / 2.0;
    for (var j = 0; j < Lm.jumlah; j++) {
      xs[i][j] = (d.xs[i][j] - px) / skala;
      ys[i][j] = (d.ys[i][j] - py) / skala;
    }
  }
  return Deret(d.t, xs, ys, d.vs);
}

/// Interpolasi linear (T × F) menjadi (n × F) dengan jarak waktu seragam.
List<Float64List> sampelUlang(
  List<Float64List> x,
  List<double> t, {
  int n = panjangDeret,
}) {
  final f = x.first.length;
  if (t.last <= t.first) {
    return List.generate(n, (_) => Float64List.fromList(x.first));
  }
  final langkah = (t.last - t.first) / (n - 1);
  final tb = List<double>.generate(n, (i) => i * langkah + t.first);
  tb[n - 1] = t.last;
  final hasil = List.generate(n, (_) => Float64List(f));
  final kolom = List<double>.filled(x.length, 0);
  for (var k = 0; k < f; k++) {
    for (var i = 0; i < x.length; i++) {
      kolom[i] = x[i][k];
    }
    for (var i = 0; i < n; i++) {
      hasil[i][k] = interp(tb[i], t, kolom);
    }
  }
  return hasil;
}
