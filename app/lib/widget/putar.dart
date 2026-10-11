import 'dart:async';

import 'package:flutter/material.dart';

import '../tema.dart';
import 'grafik.dart';
import 'kerangka.dart';

/// Pemutar kerangka satu repetisi yang berulang terus, dengan kurva sudut
/// dan penanda posisi. Data dari HasilRepetisi.pose / dataPutar().
class PemutarRepetisi extends StatefulWidget {
  const PemutarRepetisi({
    super.key,
    required this.pose,
    required this.kurva,
    required this.durasi,
    this.namaSudut = 'Sudut',
    this.warna = Pal.kapur,
    this.warnaKurva = Pal.sinyal,
    this.sorot = const [],
    this.warnaSorot = Pal.salah,
    this.rasio = 1.15,
  });

  final List<double> pose;
  final List<double> kurva;
  final double durasi;
  final String namaSudut;
  final Color warna;
  final Color warnaKurva;
  final List<int> sorot;
  final Color warnaSorot;
  final double rasio;

  @override
  State<PemutarRepetisi> createState() => _PemutarRepetisiState();
}

class _PemutarRepetisiState extends State<PemutarRepetisi> {
  double _t = 0;
  Timer? _pewaktu;

  @override
  void initState() {
    super.initState();
    _pewaktu = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted) return;
      final langkah = 40 / (widget.durasi * 1000).clamp(600, 6000);
      setState(() => _t = (_t + langkah) % 1.2);
    });
  }

  @override
  void didUpdateWidget(PemutarRepetisi old) {
    super.didUpdateWidget(old);
    if (old.pose != widget.pose) _t = 0;
  }

  @override
  void dispose() {
    _pewaktu?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langkah = widget.pose.length ~/ 24;
    if (langkah < 2) return const SizedBox.shrink();
    final posisi = _t.clamp(0.0, 1.0);
    final k = (posisi * (langkah - 1)).round();
    final sudut = widget.kurva.isEmpty
        ? null
        : widget.kurva[(posisi * (widget.kurva.length - 1)).round()];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: widget.rasio,
          child: Container(
            decoration: BoxDecoration(
              color: Pal.latar,
              border: Border.all(color: Pal.garis),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: KerangkaRingkasPainter(
                      pose: widget.pose.sublist(k * 24, k * 24 + 24),
                      batas: KerangkaRingkasPainter.batasDari(widget.pose),
                      warna: widget.warna,
                      sorot: widget.sorot,
                      warnaSorot: widget.warnaSorot,
                      bayangan: widget.pose.sublist(0, 24),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Label(widget.namaSudut),
                      Text(
                        sudut == null ? '—' : '${sudut.round()}°',
                        style: Huruf.angka(30),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.kurva.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  KurvaMini(
                    kurva: widget.kurva,
                    warna: widget.warnaKurva,
                    lebar: c.maxWidth,
                    tinggi: 36,
                  ),
                  Positioned(
                    left: posisi * (c.maxWidth - 2),
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: Pal.sinyal),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
