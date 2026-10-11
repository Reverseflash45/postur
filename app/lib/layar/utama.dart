import 'package:flutter/material.dart';

import '../data/pengaturan.dart';
import '../tema.dart';
import 'panduan.dart';
import 'tab_lab.dart';
import 'tab_latih.dart';
import 'tab_progres.dart';

/// Kerangka aplikasi: tiga tab dengan bar bawah buatan sendiri.
class LayarUtama extends StatefulWidget {
  const LayarUtama({super.key});

  @override
  State<LayarUtama> createState() => _LayarUtamaState();
}

class _LayarUtamaState extends State<LayarUtama> {
  int _tab = 0;

  /// Naik setiap kembali dari layar lain, supaya tab memuat ulang datanya.
  int _versi = 0;

  void segarkan() => setState(() => _versi++);

  @override
  void initState() {
    super.initState();
    if (!Pengaturan.instance.sudahPanduan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const LayarPanduan()));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Di layar lebar (mendatar, tablet) isi tidak melar selebar layar.
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: IndexedStack(
            index: _tab,
            children: [
              TabLatih(key: ValueKey('latih$_versi'), onKembali: segarkan),
              TabProgres(key: ValueKey('progres$_versi'), onKembali: segarkan),
              TabLab(key: ValueKey('lab$_versi'), onKembali: segarkan),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _Bar(
        tab: _tab,
        onPilih: (i) => setState(() {
          _tab = i;
          _versi++;
        }),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.tab, required this.onPilih});

  final int tab;
  final ValueChanged<int> onPilih;

  static const _isi = [
    (Icons.accessibility_new, 'Latih'),
    (Icons.show_chart, 'Progres'),
    (Icons.science_outlined, 'Lab'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Pal.latar,
        border: Border(top: BorderSide(color: Pal.garis)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < _isi.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onPilih(i),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 2,
                          width: tab == i ? 40 : 0,
                          color: Pal.sinyal,
                        ),
                        const Spacer(),
                        Icon(
                          _isi[i].$1,
                          size: 22,
                          color: tab == i ? Pal.kapur : Pal.samar,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isi[i].$2.toUpperCase(),
                          style: Huruf.label(
                            ukuran: 10,
                            warna: tab == i ? Pal.kapur : Pal.samar,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
