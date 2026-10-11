import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../inti/fitur.dart';
import '../inti/gerakan.dart';
import '../inti/repetisi.dart';
import '../sumber/sumber_rekaman.dart';
import '../tema.dart';
import 'kerangka.dart';

/// Animasi kerangka satu repetisi benar, diambil dari rekaman demo.
///
/// Dipakai di kartu gerakan supaya pengguna langsung melihat gerakannya,
/// bukan ikon statis.
class GerakAnimasi extends StatefulWidget {
  const GerakAnimasi(this.gerakan, {super.key, this.warna = Pal.kapur});

  final Gerakan gerakan;
  final Color warna;

  @override
  State<GerakAnimasi> createState() => _GerakAnimasiState();
}

class _GerakAnimasiState extends State<GerakAnimasi>
    with SingleTickerProviderStateMixin {
  static final Map<String, Future<List<List<double>>>> _cache = {};

  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();
  List<List<double>>? _pose;
  Rect? _batas;

  @override
  void initState() {
    super.initState();
    _cache.putIfAbsent(widget.gerakan.id, () => _muat(widget.gerakan)).then((
      p,
    ) {
      if (!mounted || p.isEmpty) return;
      setState(() {
        _pose = p;
        _batas = KerangkaRingkasPainter.batasDari([for (final q in p) ...q]);
      });
    });
  }

  static Future<List<List<double>>> _muat(Gerakan g) async {
    try {
      final s = await SumberRekaman.dariAset(
        'assets/demo/${g.id}.json',
        ulang: false,
      );
      final hitung = PenghitungRepetisi(g);
      for (var i = 0; i < s.frame.length; i++) {
        final p = hitung.proses(i, s.frame[i].t, sinyalUtama(s.frame[i], g));
        if (p == null) continue;
        final f = prosesRepetisi(s.frame.sublist(p.mulai, p.selesai + 1), g);
        return [for (final b in f.seq) b.sublist(14, jumlahFitur)];
      }
    } on PlatformException catch (_) {
      // Aset tidak ada: biarkan kosong.
    }
    return [];
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pose = _pose, batas = _batas;
    if (pose == null || batas == null) return const SizedBox.expand();
    return AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        // Jeda sebentar di posisi atas sebelum mengulang.
        final t = (_a.value * 1.25).clamp(0.0, 1.0);
        final i = (t * (pose.length - 1)).round();
        return CustomPaint(
          painter: KerangkaRingkasPainter(
            pose: pose[i],
            batas: batas,
            warna: widget.warna,
            bayangan: pose.first,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}
