import 'dart:math' as math;
import 'dart:typed_data';

import 'gerakan.dart';
import 'landmark.dart';
import 'pose.dart';
import 'sinyal.dart';

/// Fitur per frame dan ringkasan per repetisi — salinan ml/postur/fitur.py.

const namaKanal = [
  'lutut_ki', 'lutut_ka', 'pinggul_ki', 'pinggul_ka', 'siku_ki', 'siku_ka', //
  'bahu_ki', 'bahu_ka', 'condong', 'lengkung', 'rasio_lutut', 'tinggi_pinggul',
  'lutut', 'siku',
];
const _stat = ['min', 'max', 'rerata', 'sb', 'rentang'];
final namaRingkasan = [
  for (final k in namaKanal)
    for (final s in _stat) '${k}_$s',
  'durasi',
  'posisi_terendah',
];
const jumlahFitur = 14 + 24;

const double _derajat = 180.0 / math.pi;
const double _jarakKakiMin = 0.05;

double sudut(double ax, double ay, double bx, double by, double cx, double cy) {
  final v1x = ax - bx, v1y = ay - by;
  final v2x = cx - bx, v2y = cy - by;
  final dot = v1x * v2x + v1y * v2y;
  final n = math.sqrt(v1x * v1x + v1y * v1y) * math.sqrt(v2x * v2x + v2y * v2y);
  final cos = (dot / math.max(n, 1e-9)).clamp(-1.0, 1.0);
  return math.acos(cos) * _derajat;
}

double _jarak(double ax, double ay, double bx, double by) {
  final dx = ax - bx, dy = ay - by;
  return math.sqrt(dx * dx + dy * dy);
}

/// 14 kanal untuk satu frame koordinat ternormalisasi.
Float64List kanal(Float64List x, Float64List y) {
  double s(int a, int b, int c) => sudut(x[a], y[a], x[b], y[b], x[c], y[c]);
  final lututKi = s(Lm.pinggulKi, Lm.lututKi, Lm.kakiKi);
  final lututKa = s(Lm.pinggulKa, Lm.lututKa, Lm.kakiKa);
  final pinggulKi = s(Lm.bahuKi, Lm.pinggulKi, Lm.lututKi);
  final pinggulKa = s(Lm.bahuKa, Lm.pinggulKa, Lm.lututKa);
  final sikuKi = s(Lm.bahuKi, Lm.sikuKi, Lm.tanganKi);
  final sikuKa = s(Lm.bahuKa, Lm.sikuKa, Lm.tanganKa);
  final bahuKi = s(Lm.sikuKi, Lm.bahuKi, Lm.pinggulKi);
  final bahuKa = s(Lm.sikuKa, Lm.bahuKa, Lm.pinggulKa);

  final bx = (x[Lm.bahuKi] + x[Lm.bahuKa]) / 2.0,
      by = (y[Lm.bahuKi] + y[Lm.bahuKa]) / 2.0;
  final px = (x[Lm.pinggulKi] + x[Lm.pinggulKa]) / 2.0;
  final py = (y[Lm.pinggulKi] + y[Lm.pinggulKa]) / 2.0;
  final kx = (x[Lm.kakiKi] + x[Lm.kakiKa]) / 2.0,
      ky = (y[Lm.kakiKi] + y[Lm.kakiKa]) / 2.0;

  final dx = bx - px, dy = by - py;
  final nd = math.max(math.sqrt(dx * dx + dy * dy), 1e-9);
  final condong = math.acos((-dy / nd).clamp(-1.0, 1.0)) * _derajat;

  final gx = kx - bx, gy = ky - by;
  final ng = math.max(math.sqrt(gx * gx + gy * gy), 1e-9);
  var nx = -gy / ng, ny = gx / ng;
  final tanda = ny < 0.0 ? -1.0 : 1.0;
  nx = nx * tanda;
  ny = ny * tanda;
  final lengkung = (px - bx) * nx + (py - by) * ny;

  final rasioLutut =
      _jarak(x[Lm.lututKi], y[Lm.lututKi], x[Lm.lututKa], y[Lm.lututKa]) /
      math.max(
        _jarak(x[Lm.kakiKi], y[Lm.kakiKi], x[Lm.kakiKa], y[Lm.kakiKa]),
        _jarakKakiMin,
      );
  final tinggiPinggul = ky - py;

  return Float64List.fromList([
    lututKi, lututKa, pinggulKi, pinggulKa, sikuKi, sikuKa, bahuKi, bahuKa, //
    condong, lengkung, rasioLutut, tinggiPinggul,
    (lututKi + lututKa) / 2.0, (sikuKi + sikuKa) / 2.0,
  ]);
}

Float64List fiturFrame(Float64List x, Float64List y) {
  final f = Float64List(jumlahFitur);
  f.setAll(0, kanal(x, y));
  var k = 14;
  for (final j in Lm.terpilih) {
    f[k++] = x[j];
    f[k++] = y[j];
  }
  return f;
}

/// 72 fitur ringkasan dari deret 64 × 38.
Float64List ringkasan(List<Float64List> seq, double durasiDetik, Gerakan g) {
  final hasil = <double>[];
  final n = seq.length;
  for (var k = 0; k < namaKanal.length; k++) {
    var mn = double.infinity, mx = double.negativeInfinity, jumlah = 0.0;
    for (final r in seq) {
      final v = r[k];
      if (v < mn) mn = v;
      if (v > mx) mx = v;
      jumlah += v;
    }
    final rerata = jumlah / n;
    var kuadrat = 0.0;
    for (final r in seq) {
      final d = r[k] - rerata;
      kuadrat += d * d;
    }
    hasil.addAll([mn, mx, rerata, math.sqrt(kuadrat / n), mx - mn]);
  }
  final ku = namaKanal.indexOf(g.kanalUtama);
  var iMin = 0;
  for (var i = 1; i < n; i++) {
    if (seq[i][ku] < seq[iMin][ku]) iMin = i;
  }
  hasil.addAll([durasiDetik, iMin / (n - 1)]);
  return Float64List.fromList(hasil);
}

/// Fitur siap pakai untuk satu repetisi.
class FiturRepetisi {
  FiturRepetisi(this.seq, this.ring, this.durasiDetik);

  /// 64 × 38, belum distandarkan.
  final List<Float64List> seq;

  /// 72 fitur ringkasan.
  final Float64List ring;
  final double durasiDetik;

  double ambil(String nama) => ring[namaRingkasan.indexOf(nama)];
}

FiturRepetisi prosesRepetisi(List<FramePose> frame, Gerakan g) {
  final d = Deret(
    [for (final f in frame) f.t],
    [for (final f in frame) f.x],
    [for (final f in frame) f.y],
    [for (final f in frame) f.v],
  );
  final n = normalisasi(haluskan(isiHilang(d)));
  final per = [for (var i = 0; i < n.n; i++) fiturFrame(n.xs[i], n.ys[i])];
  final seq = sampelUlang(per, d.t);
  final durasi = (d.t.last - d.t.first) / 1000.0;
  return FiturRepetisi(seq, ringkasan(seq, durasi, g), durasi);
}
