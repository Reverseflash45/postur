import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/pengaturan.dart';
import '../inti/gerakan.dart';
import '../tema.dart';
import '../widget/gerak.dart';

/// Panduan singkat saat aplikasi pertama dibuka: posisi kamera, cara
/// latihan, dan cara membaca hasil.
class LayarPanduan extends StatefulWidget {
  const LayarPanduan({super.key});

  @override
  State<LayarPanduan> createState() => _LayarPanduanState();
}

class _LayarPanduanState extends State<LayarPanduan> {
  final _halaman = PageController();
  int _i = 0;

  static const _jumlah = 3;

  void _selesai() {
    Pengaturan.instance.sudahPanduan = true;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _halaman.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Label('Panduan ${_i + 1}/$_jumlah', warna: Pal.sinyal),
                  const Spacer(),
                  TextButton(onPressed: _selesai, child: const Text('LEWATI')),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _halaman,
                onPageChanged: (i) => setState(() => _i = i),
                children: const [
                  _HalamanKamera(),
                  _HalamanGerak(),
                  _HalamanHasil(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  for (var k = 0; k < _jumlah; k++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 6),
                      width: k == _i ? 26 : 10,
                      height: 4,
                      color: k == _i ? Pal.sinyal : Pal.garisKuat,
                    ),
                  const Spacer(),
                  SizedBox(
                    width: 150,
                    child: FilledButton(
                      onPressed: _i == _jumlah - 1
                          ? _selesai
                          : () => _halaman.nextPage(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                            ),
                      child: Text(_i == _jumlah - 1 ? 'MULAI' : 'LANJUT'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Kerangka extends StatelessWidget {
  const _Kerangka({
    required this.judul,
    required this.isi,
    required this.gambar,
  });

  final String judul;
  final List<String> isi;
  final Widget gambar;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      children: [
        Text(judul, style: Huruf.angka(54)),
        const SizedBox(height: 18),
        Container(
          height: 260,
          decoration: BoxDecoration(
            color: Pal.lapis,
            border: Border.all(color: Pal.garis),
            borderRadius: BorderRadius.circular(6),
          ),
          child: gambar,
        ),
        const SizedBox(height: 18),
        for (var k = 0; k < isi.length; k++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${k + 1}',
                    style: Huruf.angka(22, warna: Pal.sinyal),
                  ),
                ),
                Expanded(
                  child: Text(isi[k], style: Huruf.teks(warna: Pal.redup)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HalamanKamera extends StatelessWidget {
  const _HalamanKamera();

  @override
  Widget build(BuildContext context) {
    return _Kerangka(
      judul: kIsWeb ? 'TARUH\nKAMERA' : 'TARUH\nPONSEL',
      gambar: CustomPaint(painter: _DenahKamera()),
      isi: const [
        kIsWeb
            ? 'Squat: kamera setinggi pinggang (laptop di meja atau ponsel disandarkan), depan-serong ±45°, jarak 2–3 meter.'
            : 'Squat: ponsel tegak setinggi pinggang, depan-serong ±45°, jarak 2–3 meter.',
        kIsWeb
            ? 'Push-up: kamera dekat lantai, dari samping, jarak 2–3 meter.'
            : 'Push-up: ponsel mendatar di lantai, dari samping, jarak 2–3 meter.',
        'Seluruh badan dari kepala sampai kaki harus masuk bingkai. Aplikasi memeriksa ini sebelum mulai.',
      ],
    );
  }
}

class _HalamanGerak extends StatelessWidget {
  const _HalamanGerak();

  @override
  Widget build(BuildContext context) {
    return const _Kerangka(
      judul: 'BERGERAK\nSEPERTI BIASA',
      gambar: Padding(padding: EdgeInsets.all(24), child: GerakAnimasi(squat)),
      isi: [
        'Diam sejenak di posisi awal; hitung mundur 3-2-1 berjalan otomatis.',
        'Repetisi dihitung dari sudut lutut (squat) atau siku (push-up).',
        'Setiap repetisi dinilai begitu selesai. Bagian tubuh yang salah menyala, dan koreksinya diucapkan.',
      ],
    );
  }
}

class _HalamanHasil extends StatelessWidget {
  const _HalamanHasil();

  @override
  Widget build(BuildContext context) {
    return _Kerangka(
      judul: 'BACA\nHASILNYA',
      gambar: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Label('Skor form'),
            Text('86', style: Huruf.angka(96, warna: Pal.sinyal)),
            const Spacer(),
            SizedBox(
              height: 40,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (h, k) in [
                    (0.7, 0),
                    (0.45, 1),
                    (0.85, 0),
                    (0.75, 0),
                    (0.6, 2),
                    (0.9, 0),
                    (0.8, 0),
                  ])
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        height: 40 * h,
                        color: Pal.kelas(k),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      isi: const [
        'Skor form 0–100 per repetisi adalah peluang "benar" menurut model.',
        'Di ringkasan, ketuk repetisi untuk memutar ulang gerakannya.',
        'Model bawaan masih dilatih dengan data sintetis; penilaian bentuk akan lebih tepat setelah dilatih ulang dengan rekaman asli.',
      ],
    );
  }
}

/// Denah tampak atas: subjek, ponsel, garis pandang 45°, dan jarak.
class _DenahKamera extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final orang = Offset(size.width * 0.66, size.height * 0.36);
    final sudut = math.pi * 0.75; // ponsel di kiri-bawah, 45° dari arah hadap
    final jarak = size.height * 0.52;
    final ponsel = orang + Offset(math.cos(sudut), math.sin(sudut)) * jarak;
    final garis = Paint()
      ..color = Pal.garisKuat
      ..strokeWidth = 1;

    // Grid lantai.
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()..color = Pal.garis,
      );
    }
    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()..color = Pal.garis,
      );
    }

    // Arah hadap subjek (ke bawah) dan garis pandang kamera.
    _putus(canvas, orang, orang + const Offset(0, 1) * (jarak * 0.9), garis);
    _putus(
      canvas,
      ponsel,
      orang,
      Paint()
        ..color = Pal.sinyal
        ..strokeWidth = 1.5,
    );
    // Busur 45°.
    canvas.drawArc(
      Rect.fromCircle(center: orang, radius: 44),
      math.pi / 2,
      math.pi / 4,
      false,
      Paint()
        ..color = Pal.sinyal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _teks(canvas, '45°', orang + const Offset(-36, 52), Pal.sinyal, 12);

    // Subjek: kepala dan bahu dari atas.
    canvas.drawLine(
      orang + const Offset(-26, 0),
      orang + const Offset(26, 0),
      Paint()
        ..color = Pal.kapur
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(orang, 11, Paint()..color = Pal.kapur);
    _teks(canvas, 'SUBJEK', orang + const Offset(-24, -34), Pal.redup, 10);

    // Ponsel.
    canvas.save();
    canvas.translate(ponsel.dx, ponsel.dy);
    canvas.rotate(sudut - math.pi / 2 + math.pi);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 30, height: 16),
        const Radius.circular(3),
      ),
      Paint()..color = Pal.sinyal,
    );
    canvas.restore();
    _teks(
      canvas,
      kIsWeb ? 'KAMERA' : 'PONSEL',
      ponsel + const Offset(-22, 16),
      Pal.redup,
      10,
    );

    // Label jarak di tengah garis pandang.
    final tengah = (orang + ponsel) / 2;
    _teks(canvas, '2–3 M', tengah + const Offset(-70, -26), Pal.kapur, 13);
  }

  void _putus(Canvas canvas, Offset a, Offset b, Paint p) {
    final d = b - a;
    final n = (d.distance / 8).floor();
    for (var i = 0; i < n; i += 2) {
      canvas.drawLine(a + d * (i / n), a + d * ((i + 1) / n), p);
    }
  }

  void _teks(Canvas canvas, String s, Offset o, Color c, double ukuran) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: Huruf.label(warna: c, ukuran: ukuran),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o);
  }

  @override
  bool shouldRepaint(_DenahKamera old) => false;
}
