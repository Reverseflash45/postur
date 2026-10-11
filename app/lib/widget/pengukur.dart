import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema.dart';

/// Skala sudut tegak seperti goniometer: garis tiap 10°, zona target hijau,
/// dan penunjuk kuning di sudut saat ini.
///
/// Atas = posisi lurus (180°), bawah = sudut paling tertekuk yang ditampilkan.
class PengukurSudut extends StatelessWidget {
  const PengukurSudut({
    super.key,
    required this.sudut,
    required this.target,
    this.atas = 180,
    this.bawah = 50,
    this.tinggi = 240,
    this.label = 'LUTUT',
  });

  final double? sudut;
  final double target;
  final double atas;
  final double bawah;
  final double tinggi;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cukup = sudut != null && sudut! <= target;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: Huruf.label(warna: Colors.white70, ukuran: 10)),
        const SizedBox(height: 6),
        SizedBox(
          width: 74,
          height: tinggi,
          child: CustomPaint(
            painter: _LukisSkala(
              sudut: sudut,
              target: target,
              atas: atas,
              bawah: bawah,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          sudut == null ? '—' : '${sudut!.round()}°',
          style: Huruf.angka(30, warna: cukup ? Pal.benar : Pal.kapur),
        ),
      ],
    );
  }
}

class _LukisSkala extends CustomPainter {
  _LukisSkala({
    required this.sudut,
    required this.target,
    required this.atas,
    required this.bawah,
  });

  final double? sudut;
  final double target;
  final double atas;
  final double bawah;

  double _y(double a, Size s) =>
      ((atas - a) / (atas - bawah)).clamp(0.0, 1.0) * s.height;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width - 2;
    // Zona target.
    final yt = _y(target, size);
    canvas.drawRect(
      Rect.fromLTRB(x - 6, yt, x, size.height),
      Paint()..color = Pal.benar.withValues(alpha: 0.85),
    );
    canvas.drawLine(
      Offset(x - 26, yt),
      Offset(x, yt),
      Paint()
        ..color = Pal.benar
        ..strokeWidth = 1.5,
    );
    // Garis tiap 10°, label tiap 30°.
    final tipis = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var a = atas; a >= bawah - 0.1; a -= 10) {
      final y = _y(a, size);
      final besar = a.round() % 30 == 0;
      canvas.drawLine(Offset(x - (besar ? 16 : 9), y), Offset(x, y), tipis);
      if (besar) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${a.round()}',
            style: Huruf.label(warna: Colors.white60, ukuran: 9),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - 20 - tp.width, y - tp.height / 2));
      }
    }
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), tipis);
    // Penunjuk.
    final s = sudut;
    if (s != null) {
      final y = _y(s, size);
      final cukup = s <= target;
      final jalur = Path()
        ..moveTo(x - 10, y)
        ..lineTo(x - 24, y - 7)
        ..lineTo(x - 24, y + 7)
        ..close();
      canvas.drawPath(jalur, Paint()..color = cukup ? Pal.benar : Pal.sinyal);
      canvas.drawLine(
        Offset(x - 10, y),
        Offset(x, y),
        Paint()
          ..color = cukup ? Pal.benar : Pal.sinyal
          ..strokeWidth = 2.5,
      );
    }
  }

  @override
  bool shouldRepaint(_LukisSkala old) => old.sudut != sudut;
}

/// Cincin hitung mundur (istirahat).
class CincinWaktu extends StatelessWidget {
  const CincinWaktu({
    super.key,
    required this.sisa,
    required this.total,
    this.ukuran = 220,
  });

  final double sisa;
  final double total;
  final double ukuran;

  @override
  Widget build(BuildContext context) {
    final detik = sisa.ceil();
    return SizedBox(
      width: ukuran,
      height: ukuran,
      child: CustomPaint(
        painter: _LukisCincin(total <= 0 ? 0 : (sisa / total).clamp(0.0, 1.0)),
        child: Center(
          child: Text(
            '${detik ~/ 60}:${(detik % 60).toString().padLeft(2, '0')}',
            style: Huruf.angka(ukuran * 0.3),
          ),
        ),
      ),
    );
  }
}

class _LukisCincin extends CustomPainter {
  _LukisCincin(this.isi);

  final double isi;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 8;
    // 60 garis seperti jam stopwatch; yang tersisa menyala.
    for (var k = 0; k < 60; k++) {
      final a = -math.pi / 2 + k * 2 * math.pi / 60;
      final d = Offset(math.cos(a), math.sin(a));
      final nyala = k < (isi * 60).ceil();
      canvas.drawLine(
        c + d * (r - (k % 5 == 0 ? 16 : 10)),
        c + d * r,
        Paint()
          ..color = nyala ? Pal.sinyal : Pal.garisKuat
          ..strokeWidth = k % 5 == 0 ? 3 : 2
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_LukisCincin old) => old.isi != isi;
}
