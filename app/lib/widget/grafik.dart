import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../inti/mesin_latihan.dart';
import '../tema.dart';

/// Rentang gerak tiap repetisi sebagai batang, berwarna sesuai penilaian.
/// Garis putus-putus memisahkan set.
class GrafikRepetisi extends StatelessWidget {
  const GrafikRepetisi({
    super.key,
    required this.repetisi,
    this.tinggi = 140,
    this.onTap,
    this.terpilih,
  });

  final List<HasilRepetisi> repetisi;
  final double tinggi;
  final void Function(int)? onTap;
  final int? terpilih;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => GestureDetector(
        onTapUp: onTap == null || repetisi.isEmpty
            ? null
            : (d) => onTap!(
                (d.localPosition.dx / c.maxWidth * repetisi.length)
                    .floor()
                    .clamp(0, repetisi.length - 1),
              ),
        child: CustomPaint(
          size: Size(c.maxWidth, tinggi),
          painter: _LukisRepetisi(repetisi, terpilih),
        ),
      ),
    );
  }
}

class _LukisRepetisi extends CustomPainter {
  _LukisRepetisi(this.r, this.terpilih);

  final List<HasilRepetisi> r;
  final int? terpilih;

  @override
  void paint(Canvas canvas, Size size) {
    if (r.isEmpty) return;
    const bawah = 18.0;
    const atas = 14.0;
    final tinggi = size.height - bawah;
    final maks = r.map((h) => h.rom).reduce(math.max).clamp(60.0, 180.0);
    final grid = Paint()
      ..color = Pal.garis
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = atas + (tinggi - atas) * (1 - f);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final lebar = size.width / r.length;
    final batang = math.max(2.0, math.min(lebar * 0.62, 22.0));
    for (var i = 0; i < r.length; i++) {
      final h = r[i];
      final x = lebar * (i + 0.5);
      final y = atas + (tinggi - atas) * (1 - h.rom / maks);
      final aktif = terpilih == null || terpilih == i;
      canvas.drawRect(
        Rect.fromLTRB(x - batang / 2, y, x + batang / 2, tinggi),
        Paint()..color = Pal.kelas(h.kelas).withValues(alpha: aktif ? 1 : 0.3),
      );
      if (i > 0 && r[i - 1].set != h.set) {
        final xs = lebar * i;
        for (var yy = 0.0; yy < tinggi; yy += 6) {
          canvas.drawLine(
            Offset(xs, yy),
            Offset(xs, yy + 3),
            Paint()..color = Pal.garisKuat,
          );
        }
      }
      final tampilLabel = r.length <= 16 || (i + 1) % 5 == 0 || i == 0;
      if (tampilLabel) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${h.nomor}',
            style: Huruf.label(ukuran: 9, warna: Pal.samar),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, tinggi + 4));
      }
    }
    final tp = TextPainter(
      text: TextSpan(
        text: '${maks.round()}°',
        style: Huruf.label(ukuran: 9, warna: Pal.samar),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(0, 2));
  }

  @override
  bool shouldRepaint(_LukisRepetisi old) =>
      old.r != r || old.terpilih != terpilih;
}

/// Garis tren nilai 0–100 dengan titik akhir ditonjolkan.
class GarisTren extends StatelessWidget {
  const GarisTren({super.key, required this.nilai, this.tinggi = 110});

  final List<double> nilai;
  final double tinggi;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(double.infinity, tinggi),
    painter: _LukisTren(nilai),
  );
}

class _LukisTren extends CustomPainter {
  _LukisTren(this.v);

  final List<double> v;

  @override
  void paint(Canvas canvas, Size size) {
    const kiri = 26.0;
    final grid = Paint()
      ..color = Pal.garis
      ..strokeWidth = 1;
    for (final n in [0, 50, 100]) {
      final y = size.height * (1 - n / 100) * 0.9 + size.height * 0.05;
      canvas.drawLine(Offset(kiri, y), Offset(size.width, y), grid);
      final tp = TextPainter(
        text: TextSpan(
          text: '$n',
          style: Huruf.label(ukuran: 9, warna: Pal.samar),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }
    if (v.isEmpty) return;
    Offset titik(int i) => Offset(
      kiri +
          (v.length == 1
              ? (size.width - kiri) / 2
              : (size.width - kiri - 8) * i / (v.length - 1)),
      size.height * (1 - v[i] / 100) * 0.9 + size.height * 0.05,
    );
    final jalur = Path()..moveTo(titik(0).dx, titik(0).dy);
    for (var i = 1; i < v.length; i++) {
      jalur.lineTo(titik(i).dx, titik(i).dy);
    }
    final isi = Path.from(jalur)
      ..lineTo(titik(v.length - 1).dx, size.height)
      ..lineTo(titik(0).dx, size.height)
      ..close();
    canvas.drawPath(
      isi,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Pal.sinyal.withValues(alpha: 0.22),
            Pal.sinyal.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      jalur,
      Paint()
        ..color = Pal.sinyal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < v.length; i++) {
      canvas.drawCircle(
        titik(i),
        i == v.length - 1 ? 4.5 : 2.5,
        Paint()..color = Pal.sinyal,
      );
    }
    canvas.drawCircle(
      titik(v.length - 1),
      8,
      Paint()..color = Pal.sinyal.withValues(alpha: 0.2),
    );
  }

  @override
  bool shouldRepaint(_LukisTren old) => old.v != v;
}

/// Batang harian bertumpuk: bagian bawah repetisi benar, atas yang salah.
class BatangHarian extends StatelessWidget {
  const BatangHarian({
    super.key,
    required this.total,
    required this.benar,
    required this.label,
    this.tinggi = 120,
  });

  final List<int> total;
  final List<int> benar;
  final List<String> label;
  final double tinggi;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(double.infinity, tinggi),
    painter: _LukisHarian(total, benar, label),
  );
}

class _LukisHarian extends CustomPainter {
  _LukisHarian(this.total, this.benar, this.label);

  final List<int> total;
  final List<int> benar;
  final List<String> label;

  @override
  void paint(Canvas canvas, Size size) {
    const bawah = 16.0;
    final tinggi = size.height - bawah;
    final maks = math.max(1, total.fold(0, math.max));
    final lebar = size.width / total.length;
    final b = math.min(lebar * 0.55, 18.0);
    canvas.drawLine(
      Offset(0, tinggi),
      Offset(size.width, tinggi),
      Paint()
        ..color = Pal.garisKuat
        ..strokeWidth = 1,
    );
    for (var i = 0; i < total.length; i++) {
      final x = lebar * (i + 0.5);
      final yt = tinggi * (1 - total[i] / maks);
      final yb = tinggi * (1 - benar[i] / maks);
      if (total[i] > 0) {
        canvas.drawRect(
          Rect.fromLTRB(x - b / 2, yt, x + b / 2, yb),
          Paint()..color = Pal.salah.withValues(alpha: 0.85),
        );
        canvas.drawRect(
          Rect.fromLTRB(x - b / 2, yb, x + b / 2, tinggi),
          Paint()..color = Pal.benar,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTRB(x - b / 2, tinggi - 2, x + b / 2, tinggi),
          Paint()..color = Pal.garisKuat,
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: label[i],
          style: Huruf.label(
            ukuran: 9,
            warna: i == total.length - 1 ? Pal.kapur : Pal.samar,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, tinggi + 4));
    }
  }

  @override
  bool shouldRepaint(_LukisHarian old) => old.total != total;
}

/// Garis kecil kurva sudut satu repetisi.
class KurvaMini extends StatelessWidget {
  const KurvaMini({
    super.key,
    required this.kurva,
    required this.warna,
    this.lebar = 64,
    this.tinggi = 26,
  });

  final List<double> kurva;
  final Color warna;
  final double lebar;
  final double tinggi;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(lebar, tinggi),
    painter: _LukisKurva(kurva, warna),
  );
}

class _LukisKurva extends CustomPainter {
  _LukisKurva(this.k, this.warna);

  final List<double> k;
  final Color warna;

  @override
  void paint(Canvas canvas, Size size) {
    if (k.length < 2) return;
    final mn = k.reduce(math.min), mx = k.reduce(math.max);
    final rentang = math.max(mx - mn, 1.0);
    final jalur = Path();
    for (var i = 0; i < k.length; i++) {
      final p = Offset(
        size.width * i / (k.length - 1),
        size.height * (1 - (k[i] - mn) / rentang),
      );
      i == 0 ? jalur.moveTo(p.dx, p.dy) : jalur.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      jalur,
      Paint()
        ..color = warna
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LukisKurva old) => old.k != k;
}

/// Durasi turun (bawah, kuning) dan naik (atas, abu) tiap repetisi.
class GrafikTempo extends StatelessWidget {
  const GrafikTempo({super.key, required this.repetisi, this.tinggi = 110});

  final List<HasilRepetisi> repetisi;
  final double tinggi;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(double.infinity, tinggi),
    painter: _LukisTempo(repetisi),
  );
}

class _LukisTempo extends CustomPainter {
  _LukisTempo(this.r);

  final List<HasilRepetisi> r;

  @override
  void paint(Canvas canvas, Size size) {
    if (r.isEmpty) return;
    const bawah = 16.0;
    const atas = 14.0;
    final tinggi = size.height - bawah;
    final maks = math.max(1.0, r.map((h) => h.durasi).reduce(math.max));
    canvas.drawLine(
      Offset(0, tinggi),
      Offset(size.width, tinggi),
      Paint()..color = Pal.garisKuat,
    );
    final lebar = size.width / r.length;
    final b = math.max(2.0, math.min(lebar * 0.6, 20.0));
    for (var i = 0; i < r.length; i++) {
      final t = r[i].tempo;
      if (t == null) continue;
      final x = lebar * (i + 0.5);
      final yTurun = atas + (tinggi - atas) * (1 - t.turun / maks);
      final yNaik = atas + (tinggi - atas) * (1 - (t.turun + t.naik) / maks);
      canvas.drawRect(
        Rect.fromLTRB(x - b / 2, yTurun, x + b / 2, tinggi),
        Paint()..color = Pal.sinyal.withValues(alpha: 0.85),
      );
      canvas.drawRect(
        Rect.fromLTRB(x - b / 2, yNaik, x + b / 2, yTurun - 1),
        Paint()..color = Pal.redup,
      );
      if (r.length <= 16 || (i + 1) % 5 == 0 || i == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${r[i].nomor}',
            style: Huruf.label(ukuran: 9, warna: Pal.samar),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, tinggi + 4));
      }
    }
    final tp = TextPainter(
      text: TextSpan(
        text: '${maks.toStringAsFixed(1)} DTK',
        style: Huruf.label(ukuran: 9, warna: Pal.samar),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, const Offset(0, 0));
  }

  @override
  bool shouldRepaint(_LukisTempo old) => old.r != r;
}
