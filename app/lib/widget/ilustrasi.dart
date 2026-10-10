import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../inti/gerakan.dart';

/// Ilustrasi gerakan: posisi atas (tipis) dan posisi bawah (tebal), plus
/// busur di sendi utama. Koordinat diambil dari kerangka generator sintetis
/// (ml/postur/sintetis.py) supaya proporsinya sama dengan yang dikenali model.
class IlustrasiGerakan extends StatelessWidget {
  const IlustrasiGerakan(
    this.gerakan, {
    super.key,
    required this.warna,
    this.ukuran = 96,
  });

  final Gerakan gerakan;
  final Color warna;
  final double ukuran;

  @override
  Widget build(BuildContext context) {
    final squat = gerakan.id == 'squat';
    return SizedBox(
      width: ukuran,
      height: ukuran,
      child: CustomPaint(
        painter: _Lukis(
          atas: squat ? _squat0 : _pushup0,
          bawah: squat ? _squat1 : _pushup1,
          sendi: squat ? const [23, 25, 27] : const [11, 13, 15],
          warna: warna,
          lantai: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
    );
  }
}

class _Lukis extends CustomPainter {
  _Lukis({
    required this.atas,
    required this.bawah,
    required this.sendi,
    required this.warna,
    required this.lantai,
  });

  final Map<int, Offset> atas, bawah;
  final List<int> sendi;
  final Color warna, lantai;

  static const _tulang = [
    [11, 13],
    [13, 15],
    [11, 23],
    [23, 25],
    [25, 27],
    [27, 31],
    [27, 29],
    [29, 31],
    [0, 11],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Hanya sisi kanan tubuh + kepala, supaya siluetnya bersih.
    final s = size.shortestSide * 0.86;
    final semua = [...atas.values, ...bawah.values];
    final lebar = semua.map((o) => o.dx).reduce(math.max);
    final tinggi = semua.map((o) => o.dy).reduce(math.max);
    final geser = Offset(
      (size.width - lebar * s) / 2,
      (size.height - tinggi * s) / 2,
    );
    Offset p(Map<int, Offset> m, int j) => m[j]! * s + geser;

    canvas.drawLine(
      Offset(0, geser.dy + tinggi * s + 2),
      Offset(size.width, geser.dy + tinggi * s + 2),
      Paint()
        ..color = lantai
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    void gambar(Map<int, Offset> m, Color c, double tebal) {
      final cat = Paint()
        ..color = c
        ..strokeWidth = tebal
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final t in _tulang) {
        canvas.drawLine(p(m, t[0]), p(m, t[1]), cat);
      }
      canvas.drawCircle(p(m, 0), tebal * 1.7, Paint()..color = c);
    }

    gambar(atas, warna.withValues(alpha: 0.22), s * 0.035);
    gambar(bawah, warna, s * 0.045);

    // Busur sudut di sendi utama posisi bawah.
    final a = p(bawah, sendi[0]),
        b = p(bawah, sendi[1]),
        c = p(bawah, sendi[2]);
    final s1 = math.atan2(a.dy - b.dy, a.dx - b.dx);
    final s2 = math.atan2(c.dy - b.dy, c.dx - b.dx);
    var sapu = s2 - s1;
    if (sapu > math.pi) sapu -= 2 * math.pi;
    if (sapu < -math.pi) sapu += 2 * math.pi;
    final r = s * 0.11;
    canvas.drawArc(
      Rect.fromCircle(center: b, radius: r),
      s1,
      sapu,
      false,
      Paint()
        ..color = warna
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Lukis old) => old.warna != warna;
}

// Indeks ganjil = sisi kiri subjek; ilustrasi memakai sisi kiri (11, 13, ...).
const _squat0 = <int, Offset>{
  0: Offset(0.237, 0.000),
  11: Offset(0.189, 0.120),
  12: Offset(0.150, 0.120),
  13: Offset(0.250, 0.289),
  14: Offset(0.210, 0.289),
  15: Offset(0.304, 0.441),
  16: Offset(0.265, 0.441),
  23: Offset(0.157, 0.431),
  24: Offset(0.139, 0.431),
  25: Offset(0.164, 0.700),
  26: Offset(0.132, 0.700),
  27: Offset(0.164, 0.958),
  28: Offset(0.132, 0.958),
  29: Offset(0.128, 0.994),
  30: Offset(0.097, 0.994),
  31: Offset(0.267, 1.000),
  32: Offset(0.230, 1.000),
};
const _squat1 = <int, Offset>{
  0: Offset(0.294, 0.359),
  11: Offset(0.192, 0.461),
  12: Offset(0.152, 0.461),
  13: Offset(0.369, 0.467),
  14: Offset(0.329, 0.467),
  15: Offset(0.528, 0.473),
  16: Offset(0.489, 0.473),
  23: Offset(0.019, 0.725),
  24: Offset(0.000, 0.725),
  25: Offset(0.290, 0.735),
  26: Offset(0.259, 0.735),
  27: Offset(0.164, 0.958),
  28: Offset(0.132, 0.958),
  29: Offset(0.128, 0.994),
  30: Offset(0.097, 0.994),
  31: Offset(0.267, 1.000),
  32: Offset(0.230, 1.000),
};
const _pushup0 = <int, Offset>{
  0: Offset(0.890, 0.000),
  11: Offset(0.774, 0.017),
  12: Offset(0.774, 0.017),
  13: Offset(0.751, 0.185),
  14: Offset(0.751, 0.185),
  15: Offset(0.774, 0.336),
  16: Offset(0.774, 0.336),
  23: Offset(0.499, 0.123),
  24: Offset(0.499, 0.123),
  25: Offset(0.267, 0.212),
  26: Offset(0.267, 0.212),
  27: Offset(0.034, 0.302),
  28: Offset(0.034, 0.302),
  29: Offset(0.000, 0.291),
  30: Offset(0.000, 0.291),
  31: Offset(0.006, 0.342),
  32: Offset(0.006, 0.342),
};
const _pushup1 = <int, Offset>{
  0: Offset(1.000, 0.253),
  11: Offset(0.876, 0.234),
  12: Offset(0.876, 0.234),
  13: Offset(0.710, 0.197),
  14: Offset(0.710, 0.197),
  15: Offset(0.774, 0.336),
  16: Offset(0.774, 0.336),
  23: Offset(0.563, 0.260),
  24: Offset(0.563, 0.260),
  25: Offset(0.299, 0.281),
  26: Offset(0.299, 0.281),
  27: Offset(0.034, 0.302),
  28: Offset(0.034, 0.302),
  29: Offset(0.000, 0.291),
  30: Offset(0.000, 0.291),
  31: Offset(0.006, 0.342),
  32: Offset(0.006, 0.342),
};
