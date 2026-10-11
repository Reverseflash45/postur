import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../inti/landmark.dart';
import '../inti/pose.dart';
import '../inti/sinyal.dart';
import '../tema.dart';

/// Menggambar kerangka di ruang koordinat gambar (lebar × tinggi frame).
///
/// Dibungkus SizedBox seukuran gambar di dalam FittedBox bersama pratinjau
/// kamera, sehingga keduanya ikut diskalakan bersama. Tulang yang kedua
/// ujungnya ada di [sorot] digambar dengan [warnaSorot] dan berpendar —
/// dipakai untuk menunjukkan bagian tubuh yang salah.
class KerangkaPainter extends CustomPainter {
  KerangkaPainter(
    this.f, {
    required this.warna,
    this.cermin = false,
    this.sendiUtama = const [],
    this.sorot = const [],
    this.warnaSorot = Pal.salah,
  });

  final FramePose? f;
  final Color warna;
  final bool cermin;

  /// Sendi yang diberi cincin (lutut atau siku).
  final List<int> sendiUtama;
  final List<int> sorot;
  final Color warnaSorot;

  @override
  void paint(Canvas canvas, Size size) {
    final f = this.f;
    if (f == null || f.kosong) return;
    final skala = math.max(size.width, size.height);
    Offset p(int j) => Offset(cermin ? size.width - f.x[j] : f.x[j], f.y[j]);
    bool ada(int j) => f.v[j] >= ambangVis;
    final set = sorot.toSet();
    bool salah(List<int> t) => set.contains(t[0]) && set.contains(t[1]);

    final bayang = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..strokeWidth = skala * 0.014
      ..strokeCap = StrokeCap.round;
    final garis = Paint()
      ..color = warna
      ..strokeWidth = skala * 0.0065
      ..strokeCap = StrokeCap.round;
    final pendar = Paint()
      ..color = warnaSorot.withValues(alpha: 0.55)
      ..strokeWidth = skala * 0.03
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, skala * 0.012);
    final garisSalah = Paint()
      ..color = warnaSorot
      ..strokeWidth = skala * 0.011
      ..strokeCap = StrokeCap.round;

    for (final t in Lm.tulang) {
      if (ada(t[0]) && ada(t[1])) canvas.drawLine(p(t[0]), p(t[1]), bayang);
    }
    for (final t in Lm.tulang) {
      if (ada(t[0]) && ada(t[1]) && salah(t)) {
        canvas.drawLine(p(t[0]), p(t[1]), pendar);
      }
    }
    for (final t in Lm.tulang) {
      if (!ada(t[0]) || !ada(t[1])) continue;
      canvas.drawLine(p(t[0]), p(t[1]), salah(t) ? garisSalah : garis);
    }

    final isi = Paint()..color = Pal.latar;
    for (final j in Lm.sendi) {
      if (!ada(j)) continue;
      final kena = set.contains(j);
      final r = skala * (j == Lm.hidung ? 0.011 : 0.0065);
      canvas.drawCircle(p(j), r, isi);
      canvas.drawCircle(
        p(j),
        r,
        Paint()
          ..color = kena ? warnaSorot : warna
          ..style = PaintingStyle.stroke
          ..strokeWidth = skala * 0.0045,
      );
    }
    // Sendi utama: cincin dengan tanda silang kecil, seperti titik bidik alat ukur.
    final bidik = Paint()
      ..color = Pal.sinyal
      ..style = PaintingStyle.stroke
      ..strokeWidth = skala * 0.004;
    for (final j in sendiUtama) {
      if (!ada(j)) continue;
      final c = p(j);
      final r = skala * 0.026;
      canvas.drawCircle(c, r, bidik);
      for (final a in [0.0, math.pi / 2, math.pi, 3 * math.pi / 2]) {
        final d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + d * (r * 0.75), c + d * (r * 1.3), bidik);
      }
    }
  }

  @override
  bool shouldRepaint(KerangkaPainter old) =>
      old.f != f ||
      old.warna != warna ||
      old.cermin != cermin ||
      old.sorot != sorot;
}

/// Kerangka 12 landmark dari data putar ulang (koordinat ternormalisasi).
///
/// [pose] berisi x, y berselang untuk Lm.terpilih; titik asal di tengah
/// pinggul, satuan panjang torso.
class KerangkaRingkasPainter extends CustomPainter {
  KerangkaRingkasPainter({
    required this.pose,
    required this.batas,
    this.warna = Pal.kapur,
    this.sorot = const [],
    this.warnaSorot = Pal.salah,
    this.bayangan,
  });

  final List<double> pose;

  /// Kotak pembatas seluruh repetisi (minX, minY, maxX, maxY) agar skala tetap.
  final Rect batas;
  final Color warna;
  final List<int> sorot;
  final Color warnaSorot;

  /// Pose lain yang digambar tipis di belakang (mis. posisi awal).
  final List<double>? bayangan;

  static const _tulang = [
    [11, 12],
    [11, 13],
    [13, 15],
    [12, 14],
    [14, 16],
    [11, 23],
    [12, 24],
    [23, 24], //
    [23, 25], [25, 27], [24, 26], [26, 28],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s =
        math.min(size.width / batas.width, size.height / batas.height) * 0.86;
    final geser = Offset(
      (size.width - batas.width * s) / 2 - batas.left * s,
      (size.height - batas.height * s) / 2 - batas.top * s,
    );
    final indeks = {
      for (var k = 0; k < Lm.terpilih.length; k++) Lm.terpilih[k]: k,
    };
    Offset titik(List<double> q, int j) =>
        Offset(q[2 * indeks[j]!], q[2 * indeks[j]! + 1]) * s + geser;
    final set = sorot.toSet();

    // Garis lantai di bawah titik terendah.
    final lantai = batas.bottom * s + geser.dy + 6;
    canvas.drawLine(
      Offset(0, lantai),
      Offset(size.width, lantai),
      Paint()
        ..color = Pal.garisKuat
        ..strokeWidth = 1,
    );

    void gambar(
      List<double> q,
      Color c,
      double tebal, {
      bool pakaiSorot = false,
    }) {
      for (final t in _tulang) {
        final kena = pakaiSorot && set.contains(t[0]) && set.contains(t[1]);
        canvas.drawLine(
          titik(q, t[0]),
          titik(q, t[1]),
          Paint()
            ..color = kena ? warnaSorot : c
            ..strokeWidth = kena ? tebal * 1.5 : tebal
            ..strokeCap = StrokeCap.round,
        );
      }
      for (final j in Lm.terpilih) {
        canvas.drawCircle(titik(q, j), tebal * 0.9, Paint()..color = Pal.latar);
        canvas.drawCircle(
          titik(q, j),
          tebal * 0.9,
          Paint()
            ..color = pakaiSorot && set.contains(j) ? warnaSorot : c
            ..style = PaintingStyle.stroke
            ..strokeWidth = tebal * 0.6,
        );
      }
      // Kepala: di atas titik tengah bahu, searah torso.
      final bahu = (titik(q, 11) + titik(q, 12)) / 2;
      final pinggul = (titik(q, 23) + titik(q, 24)) / 2;
      final arah = bahu - pinggul;
      final kepala =
          bahu + arah / math.max(arah.distance, 1e-6) * (arah.distance * 0.32);
      canvas.drawCircle(kepala, tebal * 1.9, Paint()..color = c);
    }

    final b = bayangan;
    if (b != null) {
      gambar(b, warna.withValues(alpha: 0.18), size.shortestSide * 0.012);
    }
    gambar(pose, warna, size.shortestSide * 0.018, pakaiSorot: true);
  }

  @override
  bool shouldRepaint(KerangkaRingkasPainter old) =>
      old.pose != pose || old.warna != warna;

  /// Kotak pembatas dari deretan pose (langkah × 24).
  static Rect batasDari(List<double> semua) {
    var minX = double.infinity,
        maxX = -double.infinity,
        minY = double.infinity,
        maxY = -double.infinity;
    for (var i = 0; i + 1 < semua.length; i += 2) {
      minX = math.min(minX, semua[i]);
      maxX = math.max(maxX, semua[i]);
      minY = math.min(minY, semua[i + 1]);
      maxY = math.max(maxY, semua[i + 1]);
    }
    // Ruang untuk kepala di atas bahu.
    return Rect.fromLTRB(minX - 0.2, minY - 0.55, maxX + 0.2, maxY + 0.05);
  }
}
