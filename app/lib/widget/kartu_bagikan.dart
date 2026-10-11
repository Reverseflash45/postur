import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../data/riwayat.dart';
import '../inti/gerakan.dart';
import '../inti/klasifikasi/klasifikasi.dart';
import '../layar/bersama.dart';
import '../tema.dart';
import 'grafik.dart';
import 'kerangka.dart';

/// Tampilkan pratinjau kartu hasil lalu bagikan sebagai PNG 1080 × 1350.
Future<void> bagikanHasil(BuildContext context, CatatanLatihan c) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DialogBagikan(catatan: c),
  );
}

class _DialogBagikan extends StatefulWidget {
  const _DialogBagikan({required this.catatan});

  final CatatanLatihan catatan;

  @override
  State<_DialogBagikan> createState() => _DialogBagikanState();
}

class _DialogBagikanState extends State<_DialogBagikan> {
  final _kunci = GlobalKey();
  bool _sibuk = false;

  Future<void> _bagikan() async {
    setState(() => _sibuk = true);
    try {
      final obj =
          _kunci.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final gambar = await obj.toImage(pixelRatio: 1080 / KartuHasil.lebar);
      final data = await gambar.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final c = widget.catatan;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              data.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'postur-${c.gerakan}-${c.id}.png',
            ),
          ],
          fileNameOverrides: ['postur-${c.gerakan}-${c.id}.png'],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal membagikan: $e')));
      }
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      backgroundColor: Pal.lapis,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FittedBox(
              child: RepaintBoundary(
                key: _kunci,
                child: KartuHasil(catatan: widget.catatan),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _sibuk ? null : _bagikan,
              child: Text(_sibuk ? 'MENYIAPKAN…' : 'BAGIKAN GAMBAR'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('TUTUP'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu ringkasan sesi berukuran tetap (rasio 4:5) untuk diekspor.
class KartuHasil extends StatelessWidget {
  const KartuHasil({super.key, required this.catatan});

  static const double lebar = 360;
  static const double tinggi = 450;

  final CatatanLatihan catatan;

  @override
  Widget build(BuildContext context) {
    final c = catatan;
    final g = gerakanDari(c.gerakan);
    // Pose terdalam dari repetisi dengan skor tertinggi, sebagai siluet.
    final dengan = c.repetisi.where((r) => r.pose.isNotEmpty).toList()
      ..sort((a, b) => b.skor.compareTo(a.skor));
    final terbaik = dengan.isEmpty ? null : dengan.first;
    List<double>? siluet;
    if (terbaik != null && terbaik.kurva.isNotEmpty) {
      var iMin = 0;
      for (var i = 1; i < terbaik.kurva.length; i++) {
        if (terbaik.kurva[i] < terbaik.kurva[iMin]) iMin = i;
      }
      siluet = terbaik.pose.sublist(iMin * 24, iMin * 24 + 24);
    }
    final menit =
        '${c.detik ~/ 60}:${(c.detik % 60).toString().padLeft(2, '0')}';
    return Container(
      width: lebar,
      height: tinggi,
      color: Pal.latar,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _Grid())),
          if (siluet != null)
            Positioned(
              right: -10,
              top: 54,
              width: 200,
              height: 200,
              child: Opacity(
                opacity: 0.9,
                child: CustomPaint(
                  painter: KerangkaRingkasPainter(
                    pose: siluet,
                    batas: KerangkaRingkasPainter.batasDari(terbaik!.pose),
                    warna: Pal.garisKuat,
                    bayangan: terbaik.pose.sublist(0, 24),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Label('Postur', warna: Pal.sinyal, ukuran: 10),
                    const Spacer(),
                    Label(tanggalJam(c.mulai), ukuran: 10),
                  ],
                ),
                const SizedBox(height: 18),
                Text(g.nama.toUpperCase(), style: Huruf.angka(46)),
                const SizedBox(height: 12),
                const Label('Skor form', ukuran: 10),
                Text(
                  c.skor == null ? '—' : '${c.skor}',
                  style: Huruf.angka(104, warna: Pal.sinyal),
                ),
                const Spacer(),
                GrafikRepetisi(repetisi: c.repetisi, tinggi: 70),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Pal.garis)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Bacaan(
                          label: 'Rep',
                          nilai: '${c.repetisi.length}',
                          ukuran: 26,
                        ),
                      ),
                      Expanded(
                        child: Bacaan(
                          label: 'Benar',
                          nilai: '${c.benar}',
                          ukuran: 26,
                          warna: Pal.benar,
                        ),
                      ),
                      Expanded(
                        child: Bacaan(
                          label: 'Set',
                          nilai: '${c.jumlahSet}',
                          ukuran: 26,
                        ),
                      ),
                      Expanded(
                        child: Bacaan(
                          label: 'Durasi',
                          nilai: menit,
                          ukuran: 26,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Dinilai di perangkat · ${namaModel[c.model] ?? c.model}${c.demo ? ' · demo' : ''}'
                      .toUpperCase(),
                  style: Huruf.label(ukuran: 8.5, warna: Pal.samar),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Grid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF15191B)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_Grid old) => false;
}
