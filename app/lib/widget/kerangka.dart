import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../inti/landmark.dart';
import '../inti/pose.dart';
import '../inti/sinyal.dart';

/// Menggambar kerangka di ruang koordinat gambar (lebar × tinggi frame).
///
/// Dibungkus SizedBox seukuran gambar di dalam FittedBox bersama pratinjau
/// kamera, sehingga keduanya ikut diskalakan bersama.
class KerangkaPainter extends CustomPainter {
  KerangkaPainter(
    this.f, {
    required this.warna,
    this.cermin = false,
    this.sorot = const [],
  });

  final FramePose? f;
  final Color warna;
  final bool cermin;

  /// Sendi yang diberi lingkaran sorot (sendi utama gerakan).
  final List<int> sorot;

  @override
  void paint(Canvas canvas, Size size) {
    final f = this.f;
    if (f == null || f.kosong) return;
    final skala = math.max(size.width, size.height);
    Offset p(int j) => Offset(cermin ? size.width - f.x[j] : f.x[j], f.y[j]);
    bool ada(int j) => f.v[j] >= ambangVis;

    final bayang = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = skala * 0.016
      ..strokeCap = StrokeCap.round;
    final garis = Paint()
      ..color = warna
      ..strokeWidth = skala * 0.009
      ..strokeCap = StrokeCap.round;
    for (final t in Lm.tulang) {
      if (!ada(t[0]) || !ada(t[1])) continue;
      canvas.drawLine(p(t[0]), p(t[1]), bayang);
    }
    for (final t in Lm.tulang) {
      if (!ada(t[0]) || !ada(t[1])) continue;
      canvas.drawLine(p(t[0]), p(t[1]), garis);
    }
    final titik = Paint()..color = Colors.white;
    final tepi = Paint()
      ..color = warna
      ..style = PaintingStyle.stroke
      ..strokeWidth = skala * 0.005;
    for (final j in Lm.sendi) {
      if (!ada(j)) continue;
      final r = skala * (j == Lm.hidung ? 0.012 : 0.008);
      canvas.drawCircle(p(j), r, titik);
      canvas.drawCircle(p(j), r, tepi);
    }
    final cincin = Paint()
      ..color = warna.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = skala * 0.006;
    for (final j in sorot) {
      if (ada(j)) canvas.drawCircle(p(j), skala * 0.03, cincin);
    }
  }

  @override
  bool shouldRepaint(KerangkaPainter old) =>
      old.f != f || old.warna != warna || old.cermin != cermin;
}
