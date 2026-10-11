import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
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

/// Nama pose estimator yang dipakai platform ini.
const _penaksir = kIsWeb ? 'MediaPipe web' : 'ML Kit';

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
    if (id.endsWith('_int8')) return '$samaKelas/${contoh.length} kelas = f32';
    return 'Δ ${selisih.toStringAsExponential(1)}';
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
    final pose = Pengaturan.instance.statistikPose;
    final maks = _hasil.fold<double>(
      0.001,
      (a, u) => math.max(a, u.median ?? 0),
    );
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            0,
            0,
            0,
            32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            KepalaLayar(
              kembali: true,
              atas: 'Lab',
              judul: 'Uji kinerja',
              aksi: _hasil.isNotEmpty && !_jalan
                  ? IconButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: _tabel()));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tabel disalin (Markdown)'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.content_copy, color: Pal.kapur),
                      tooltip: 'Salin tabel',
                    )
                  : null,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 14),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      for (final g in semuaGerakan)
                        ButtonSegment(
                          value: g.id,
                          label: Text(g.nama.toUpperCase()),
                        ),
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
                  FilledButton(
                    onPressed: _jalan ? null : _uji,
                    child: Text(_jalan ? 'MENGUKUR…' : 'JALANKAN UJI'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Setiap model menilai repetisi contoh $_ulang kali. Keluarannya juga dicocokkan dengan '
                    'Python untuk memastikan model di ${kIsWeb ? 'browser' : 'ponsel'} sama dengan yang dievaluasi.',
                    style: Huruf.teks(warna: Pal.samar, ukuran: 13),
                  ),
                  if (_hasil.isNotEmpty) ...[
                    const JudulBagian('Klasifikasi per repetisi'),
                    for (final u in _hasil) _BarisUkur(u: u, maks: maks),
                  ],
                  const JudulBagian('Tahap lain'),
                  _BarisTahap(
                    judul: 'Ekstraksi fitur',
                    sub: 'Praproses · 38 fitur × 64 langkah · 72 ringkasan',
                    nilai: _msFitur == null
                        ? '—'
                        : _msFitur!.toStringAsFixed(2),
                  ),
                  _BarisTahap(
                    judul: 'Pose estimation',
                    sub: pose == null
                        ? '$_penaksir · diukur saat latihan dengan kamera'
                        : '$_penaksir · sesi kamera terakhir · ${pose.fps.toStringAsFixed(1)} fps',
                    nilai: pose == null ? '—' : pose.ms.toStringAsFixed(1),
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

class _BarisUkur extends StatelessWidget {
  const _BarisUkur({required this.u, required this.maks});

  final _Ukur u;
  final double maks;

  @override
  Widget build(BuildContext context) {
    final selesai = u.median != null || u.galat != null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Pal.garis)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  namaModel[u.id]!.toUpperCase(),
                  style: Huruf.judul(22),
                ),
              ),
              if (!selesai)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (u.median != null) ...[
                Text(
                  u.median!.toStringAsFixed(3),
                  style: Huruf.angka(26, warna: Pal.sinyal),
                ),
                const SizedBox(width: 3),
                Text('MS', style: Huruf.label(ukuran: 9)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          if (u.median != null)
            LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  Container(height: 4, color: Pal.lapis2),
                  Container(
                    height: 4,
                    width: c.maxWidth * (u.median! / maks).clamp(0.02, 1.0),
                    color: Pal.sinyal,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            (u.galat ??
                    [
                      if (u.ukuran != null)
                        '${(u.ukuran! / 1024).toStringAsFixed(1)} KB',
                      if (u.p95 != null) 'P95 ${u.p95!.toStringAsFixed(3)}',
                      if (u.msMuat != null)
                        'MUAT ${u.msMuat!.toStringAsFixed(0)} MS',
                      if (u.setia != null) u.setia!,
                    ].join(' · '))
                .toUpperCase(),
            style: Huruf.label(
              ukuran: 10,
              warna: u.galat != null ? Pal.salah : Pal.redup,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarisTahap extends StatelessWidget {
  const _BarisTahap({
    required this.judul,
    required this.sub,
    required this.nilai,
  });

  final String judul;
  final String sub;
  final String nilai;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Pal.garis)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul.toUpperCase(), style: Huruf.judul(22)),
                const SizedBox(height: 2),
                Text(sub.toUpperCase(), style: Huruf.label(ukuran: 10)),
              ],
            ),
          ),
          Text(nilai, style: Huruf.angka(26)),
          const SizedBox(width: 3),
          Text('MS', style: Huruf.label(ukuran: 9)),
        ],
      ),
    );
  }
}
