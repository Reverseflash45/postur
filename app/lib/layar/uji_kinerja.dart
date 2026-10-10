import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/pengaturan.dart';
import '../inti/fitur.dart';
import '../inti/gerakan.dart';
import '../inti/klasifikasi/klasifikasi.dart';
import '../inti/paket_model.dart';
import '../inti/repetisi.dart';
import '../sumber/sumber_rekaman.dart';
import '../tema.dart';

/// Hasil pengukuran satu model.
class _Ukur {
  _Ukur(this.id);

  final String id;
  double? msMuat;
  double? median;
  double? p95;
  int? ukuran;

  /// Kesesuaian dengan keluaran Python ("8/8 sama", "Δ 2e-6").
  String? setia;
  String? galat;
}

/// Mengukur latensi tiap model di ponsel ini, untuk Bab IV.
///
/// Klasifikasi dijalankan pada repetisi contoh yang disertakan bersama model
/// (contoh.json), sekaligus memeriksa keluarannya sama dengan Python.
class LayarUjiKinerja extends StatefulWidget {
  const LayarUjiKinerja({super.key});

  @override
  State<LayarUjiKinerja> createState() => _LayarUjiKinerjaState();
}

class _LayarUjiKinerjaState extends State<LayarUjiKinerja> {
  Gerakan _g = squat;
  bool _jalan = false;
  List<_Ukur> _hasil = [];
  double? _msFitur;
  static const _ulang = 50;

  Future<void> _uji() async {
    setState(() {
      _jalan = true;
      _hasil = [];
      _msFitur = null;
    });
    final paket = await PaketModel.muat(_g);
    final contoh = await paket.contoh();
    _msFitur = await _ukurFitur();
    setState(() {});

    for (final id in paket.tersedia) {
      final u = _Ukur(id);
      setState(() => _hasil = [..._hasil, u]);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      try {
        final sw = Stopwatch()..start();
        final m = await paket.buat(id);
        u.msMuat = sw.elapsedMicroseconds / 1000;
        u.ukuran = paket.ukuran(id);
        for (var i = 0; i < 5; i++) {
          m.prediksi(contoh[i % contoh.length].fitur);
        }
        final waktu = <double>[];
        // Satu sampel = rata-rata satu putaran semua contoh. Pengukuran per
        // panggilan tunggal terlalu kasar di jam yang resolusinya rendah.
        for (var r = 0; r < _ulang; r++) {
          sw.reset();
          for (final c in contoh) {
            m.prediksi(c.fitur);
          }
          waktu.add(sw.elapsedMicroseconds / 1000 / contoh.length);
        }
        waktu.sort();
        u.median = waktu[waktu.length ~/ 2];
        u.p95 =
            waktu[math.min(waktu.length - 1, (waktu.length * 0.95).floor())];
        u.setia = _periksa(id, m, contoh);
      } catch (e) {
        u.galat = '$e';
      }
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => _jalan = false);
  }

  /// Bandingkan keluaran Dart dengan keluaran Python dari contoh.json.
  String _periksa(String id, Pengklasifikasi m, List<ContohRepetisi> contoh) {
    if (id == 'aturan') {
      final sama = contoh
          .where((c) => m.prediksi(c.fitur).indeks == c.harapAturan)
          .length;
      return '$sama/${contoh.length} sama';
    }
    final jenis = id.split('_').first;
    var selisih = 0.0;
    var samaKelas = 0;
    for (final c in contoh) {
      final p = m.prediksi(c.fitur).peluang;
      final h = c.harap[jenis]!;
      for (var k = 0; k < p.length; k++) {
        selisih = math.max(selisih, (p[k] - h[k]).abs());
      }
      if (argmax(p) == argmax(h)) samaKelas++;
    }
    if (id.endsWith('_int8')) {
      return '$samaKelas/${contoh.length} kelas sama dgn f32';
    }
    return 'Δ maks ${selisih.toStringAsExponential(1)}';
  }

  /// Waktu ekstraksi fitur per repetisi, diukur pada rekaman demo.
  Future<double> _ukurFitur() async {
    final s = await SumberRekaman.dariAset(
      'assets/demo/${_g.id}.json',
      ulang: false,
    );
    final hitung = PenghitungRepetisi(_g);
    final potong = <Potongan>[];
    for (var i = 0; i < s.frame.length; i++) {
      final p = hitung.proses(i, s.frame[i].t, sinyalUtama(s.frame[i], _g));
      if (p != null) potong.add(p);
    }
    if (potong.isEmpty) return 0;
    final sw = Stopwatch()..start();
    var n = 0;
    for (var r = 0; r < 5; r++) {
      for (final p in potong) {
        prosesRepetisi(s.frame.sublist(p.mulai, p.selesai + 1), _g);
        n++;
      }
    }
    return sw.elapsedMicroseconds / 1000 / n;
  }

  String _tabel() {
    final pose = Pengaturan.instance.statistikPose;
    final b = StringBuffer()
      ..writeln('Uji kinerja ${_g.nama} ($_ulang × contoh per model)')
      ..writeln()
      ..writeln('| Model | Median (ms) | P95 (ms) | Ukuran (KB) | Kesetiaan |')
      ..writeln('|---|---|---|---|---|');
    for (final u in _hasil) {
      b.writeln(
        '| ${namaModel[u.id]} | ${u.median?.toStringAsFixed(3) ?? '-'} | '
        '${u.p95?.toStringAsFixed(3) ?? '-'} | '
        '${u.ukuran == null ? '-' : (u.ukuran! / 1024).toStringAsFixed(1)} | ${u.setia ?? u.galat ?? '-'} |',
      );
    }
    b.writeln();
    if (_msFitur != null) {
      b.writeln(
        'Ekstraksi fitur: ${_msFitur!.toStringAsFixed(2)} ms per repetisi',
      );
    }
    if (pose != null) {
      b.writeln(
        'Pose estimation (sesi kamera terakhir): ${pose.ms.toStringAsFixed(1)} ms/frame, '
        '${pose.fps.toStringAsFixed(1)} fps',
      );
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final pose = Pengaturan.instance.statistikPose;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Uji kinerja'),
        actions: [
          if (_hasil.isNotEmpty && !_jalan)
            IconButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _tabel()));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tabel disalin (format Markdown)'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded),
              tooltip: 'Salin tabel',
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          SegmentedButton<String>(
            segments: [
              for (final g in semuaGerakan)
                ButtonSegment(value: g.id, label: Text(g.nama)),
            ],
            selected: {_g.id},
            onSelectionChanged: _jalan
                ? null
                : (s) => setState(() {
                    _g = gerakanDari(s.first);
                    _hasil = [];
                    _msFitur = null;
                  }),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _jalan ? null : _uji,
            icon: _jalan
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.speed_rounded),
            label: Text(_jalan ? 'Mengukur…' : 'Jalankan uji'),
          ),
          const SizedBox(height: 8),
          Text(
            'Setiap model menilai repetisi contoh $_ulang kali. Hasilnya juga dicocokkan '
            'dengan keluaran Python untuk memastikan model di ponsel sama dengan yang dievaluasi.',
            style: TextStyle(color: skema.onSurfaceVariant, fontSize: 12.5),
          ),
          if (_hasil.isNotEmpty) ...[
            const JudulBagian('Klasifikasi per repetisi'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [for (final u in _hasil) _BarisUkur(u: u)],
              ),
            ),
          ],
          const JudulBagian('Tahap lain'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.functions_rounded),
                  title: const Text('Ekstraksi fitur'),
                  subtitle: const Text(
                    'Praproses + 38 fitur × 64 langkah + 72 ringkasan',
                  ),
                  trailing: Text(
                    _msFitur == null
                        ? '–'
                        : '${_msFitur!.toStringAsFixed(2)} ms',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.accessibility_new_rounded),
                  title: const Text('Pose estimation (ML Kit)'),
                  subtitle: Text(
                    pose == null
                        ? 'Diukur saat latihan dengan kamera. Belum ada data.'
                        : 'Sesi kamera terakhir · ${pose.fps.toStringAsFixed(1)} fps',
                  ),
                  trailing: Text(
                    pose == null ? '–' : '${pose.ms.toStringAsFixed(1)} ms',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarisUkur extends StatelessWidget {
  const _BarisUkur({required this.u});

  final _Ukur u;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final selesai = u.median != null || u.galat != null;
    return ListTile(
      title: Text(
        namaModel[u.id]!,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        u.galat ??
            [
              if (u.ukuran != null)
                '${(u.ukuran! / 1024).toStringAsFixed(1)} KB',
              if (u.msMuat != null) 'muat ${u.msMuat!.toStringAsFixed(0)} ms',
              if (u.setia != null) u.setia!,
            ].join(' · '),
        style: TextStyle(color: u.galat != null ? skema.error : null),
      ),
      trailing: !selesai
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : u.median == null
          ? const Icon(Icons.error_outline)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${u.median!.toStringAsFixed(3)} ms',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Warna.utama,
                  ),
                ),
                Text(
                  'p95 ${u.p95!.toStringAsFixed(3)}',
                  style: TextStyle(fontSize: 11, color: skema.onSurfaceVariant),
                ),
              ],
            ),
    );
  }
}
