import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/riwayat.dart';
import '../inti/gerakan.dart';
import '../inti/klasifikasi/klasifikasi.dart';
import '../inti/mesin_latihan.dart';
import '../tema.dart';
import '../widget/grafik.dart';
import '../widget/kartu_bagikan.dart';
import '../widget/kerangka.dart';
import 'latihan.dart';

/// Hasil satu sesi: skor form dulu, lalu rincian per repetisi.
class LayarRingkasan extends StatefulWidget {
  const LayarRingkasan({super.key, required this.catatan, this.baru = false});

  final CatatanLatihan catatan;

  /// Baru selesai latihan (tampilkan tombol "Latihan lagi").
  final bool baru;

  @override
  State<LayarRingkasan> createState() => _LayarRingkasanState();
}

class _LayarRingkasanState extends State<LayarRingkasan> {
  int? _terpilih;

  CatatanLatihan get c => widget.catatan;

  void _putar(int i) {
    if (c.repetisi[i].pose.isEmpty) return;
    setState(() => _terpilih = i);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LembarPutar(catatan: c, mulai: i),
    ).whenComplete(() {
      if (mounted) setState(() => _terpilih = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = gerakanDari(c.gerakan);
    final sebaran = List.filled(g.kelas.length, 0);
    for (final r in c.repetisi) {
      if (r.kelas >= 0) sebaran[r.kelas]++;
    }
    final total = c.repetisi.length;
    var utama = -1;
    for (var i = 1; i < sebaran.length; i++) {
      if (sebaran[i] > 0 && (utama < 0 || sebaran[i] > sebaran[utama])) {
        utama = i;
      }
    }
    final skor = c.skor;
    final bawah = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 24 + bawah),
          children: [
            KepalaLayar(
              kembali: true,
              atas: DateFormat('EEE d MMM y · HH.mm', 'id').format(c.mulai),
              judul: 'Ringkasan',
              aksi: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (c.demo) const Lencana('Demo'),
                  IconButton(
                    onPressed: () => bagikanHasil(context, c),
                    icon: const Icon(Icons.ios_share, color: Pal.kapur),
                    tooltip: 'Bagikan hasil',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Label('Skor form'),
                          Text(
                            skor == null ? '—' : '$skor',
                            style: Huruf.angka(120, warna: Pal.sinyal),
                          ),
                        ],
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.nama.toUpperCase(),
                                style: Huruf.angka(34),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${c.benar} dari $total repetisi benar',
                                style: Huruf.teks(warna: Pal.redup),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _Strip(
                    isi: [
                      ('Repetisi', '$total'),
                      ('Set', '${c.jumlahSet}'),
                      ('Durasi', _durasi(c.detik)),
                      ('Model', namaPendek[c.model] ?? c.model),
                    ],
                  ),
                  const JudulBagian('Rentang gerak per repetisi'),
                  GrafikRepetisi(
                    repetisi: c.repetisi,
                    terpilih: _terpilih,
                    onTap: _putar,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < g.kelas.length; i++)
                        if (sebaran[i] > 0)
                          _Kunci(
                            warna: Pal.kelas(i),
                            teks: '${g.kelas[i].nama} ${sebaran[i]}',
                          ),
                    ],
                  ),
                  if (utama > 0) ...[
                    const JudulBagian('Temuan utama'),
                    _Temuan(
                      kelas: g.kelas[utama],
                      jumlah: sebaran[utama],
                      total: total,
                      warna: Pal.kelas(utama),
                    ),
                  ],
                  if (c.repetisi.any((r) => r.tempo != null)) ...[
                    const JudulBagian('Tempo'),
                    _Tempo(repetisi: c.repetisi),
                  ],
                  if (c.repetisi.any((r) => r.pendapat.isNotEmpty)) ...[
                    const JudulBagian('Kesepakatan model'),
                    _Kesepakatan(catatan: c, gerakan: g),
                  ],
                  const JudulBagian('Setiap repetisi'),
                  Text(
                    'Ketuk repetisi untuk memutar ulang gerakannya.',
                    style: Huruf.teks(warna: Pal.samar, ukuran: 13),
                  ),
                  const SizedBox(height: 4),
                  for (var i = 0; i < c.repetisi.length; i++)
                    _BarisRep(
                      r: c.repetisi[i],
                      g: g,
                      awalSet:
                          c.jumlahSet > 1 &&
                          (i == 0 ||
                              c.repetisi[i - 1].set != c.repetisi[i].set),
                      onTap: c.repetisi[i].pose.isEmpty
                          ? null
                          : () => _putar(i),
                    ),
                  if (widget.baru) ...[
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => LayarLatihan(
                            gerakan: g,
                            mode: c.demo
                                ? ModeLatihan.demo
                                : ModeLatihan.latihan,
                          ),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                      ),
                      child: const Text('LATIHAN LAGI'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('SELESAI'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _durasi(int detik) =>
      '${detik ~/ 60}:${(detik % 60).toString().padLeft(2, '0')}';
}

/// Deret pembacaan dengan garis pemisah tegak.
class _Strip extends StatelessWidget {
  const _Strip({required this.isi});

  final List<(String, String)> isi;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: Pal.garis)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < isi.length; i++) ...[
              if (i > 0) const VerticalDivider(width: 20),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Label(isi[i].$1),
                    const SizedBox(height: 4),
                    Text(
                      isi[i].$2.toUpperCase(),
                      style: Huruf.angka(26),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Kunci extends StatelessWidget {
  const _Kunci({required this.warna, required this.teks});

  final Color warna;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, color: warna),
        const SizedBox(width: 6),
        Text(teks.toUpperCase(), style: Huruf.label(ukuran: 10.5)),
      ],
    );
  }
}

class _Temuan extends StatelessWidget {
  const _Temuan({
    required this.kelas,
    required this.jumlah,
    required this.total,
    required this.warna,
  });

  final Kelas kelas;
  final int jumlah;
  final int total;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: warna),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            kelas.nama.toUpperCase(),
                            style: Huruf.judul(24, warna: warna),
                          ),
                        ),
                        Text(
                          '$jumlah/$total',
                          style: Huruf.angka(24, warna: warna),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      saranKelas(kelas.kode),
                      style: Huruf.teks(warna: Pal.redup, ukuran: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String saranKelas(String kode) => switch (kode) {
  'SQ-1' =>
    'Turunkan pinggul sampai paha sejajar lantai. Kalau belum kuat, turun pelan-pelan '
        'dan tahan sebentar di bawah.',
  'SQ-2' =>
    'Dorong lutut ke arah ujung jari kaki saat turun dan naik. Kuda-kuda yang sedikit '
        'lebih lebar biasanya membantu.',
  'SQ-3' =>
    'Jaga dada tetap tegak dan pandangan ke depan. Bayangkan duduk ke belakang di kursi, '
        'bukan membungkuk ke depan.',
  'PU-1' =>
    'Kencangkan perut dan bokong supaya badan lurus seperti papan. Kalau berat, mulai '
        'dari push-up lutut.',
  'PU-2' =>
    'Turunkan pinggul sampai bahu, pinggul, dan pergelangan kaki segaris.',
  'PU-3' =>
    'Turunkan dada sampai siku menekuk sekitar 90°. Lebih baik sedikit repetisi penuh '
        'daripada banyak setengah.',
  _ => '',
};

class _BarisRep extends StatelessWidget {
  const _BarisRep({
    required this.r,
    required this.g,
    required this.awalSet,
    this.onTap,
  });

  final HasilRepetisi r;
  final Gerakan g;
  final bool awalSet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final warna = Pal.kelas(r.kelas);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (awalSet)
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 2),
            child: Label('Set ${r.set}', warna: Pal.samar),
          ),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Pal.garis)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    r.nomor.toString().padLeft(2, '0'),
                    style: Huruf.angka(22, warna: Pal.samar),
                  ),
                ),
                Container(width: 3, height: 32, color: warna),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.kelas < 0 ? '—' : g.kelas[r.kelas].nama,
                        style: Huruf.teks(
                          tebal: FontWeight.w600,
                          warna: r.benar ? Pal.kapur : warna,
                        ),
                      ),
                      Text(
                        r.tempo == null
                            ? '${r.durasi.toStringAsFixed(1)} DTK · ROM ${r.rom.round()}°'
                            : '↓${r.tempo!.turun.toStringAsFixed(1)} ↑${r.tempo!.naik.toStringAsFixed(1)}S · ROM ${r.rom.round()}°'
                                  '${r.sudutTerdalam == null ? '' : ' · MIN ${r.sudutTerdalam!.round()}°'}',
                        style: Huruf.label(ukuran: 10),
                      ),
                    ],
                  ),
                ),
                if (r.kurva.isNotEmpty) ...[
                  KurvaMini(kurva: r.kurva, warna: warna),
                  const SizedBox(width: 12),
                ],
                SizedBox(
                  width: 34,
                  child: Text(
                    '${r.skor}',
                    textAlign: TextAlign.end,
                    style: Huruf.angka(24, warna: warna),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Putar ulang kerangka satu repetisi, dengan bagian yang salah disorot.
class _LembarPutar extends StatefulWidget {
  const _LembarPutar({required this.catatan, required this.mulai});

  final CatatanLatihan catatan;
  final int mulai;

  @override
  State<_LembarPutar> createState() => _LembarPutarState();
}

class _LembarPutarState extends State<_LembarPutar> {
  late int _i = widget.mulai;
  double _t = 0;
  bool _jalan = true;
  Timer? _pewaktu;

  @override
  void initState() {
    super.initState();
    _pewaktu = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!_jalan || !mounted) return;
      final r = widget.catatan.repetisi[_i];
      final langkah = 40 / (r.durasi * 1000).clamp(600, 6000);
      setState(() => _t = (_t + langkah) % 1.2);
    });
  }

  @override
  void dispose() {
    _pewaktu?.cancel();
    super.dispose();
  }

  void _pindah(int d) {
    final n = widget.catatan.repetisi.length;
    var j = _i;
    do {
      j = (j + d + n) % n;
    } while (widget.catatan.repetisi[j].pose.isEmpty && j != _i);
    setState(() {
      _i = j;
      _t = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = gerakanDari(widget.catatan.gerakan);
    final r = widget.catatan.repetisi[_i];
    final langkah = r.pose.length ~/ 24;
    final posisi = _t.clamp(0.0, 1.0);
    final k = (posisi * (langkah - 1)).round();
    final pose = r.pose.sublist(k * 24, k * 24 + 24);
    final warna = Pal.kelas(r.kelas);
    final sudut = r.kurva.isEmpty
        ? null
        : r.kurva[(posisi * (r.kurva.length - 1)).round()];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'REP ${r.nomor.toString().padLeft(2, '0')}',
                  style: Huruf.angka(36),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      r.kelas < 0 ? '' : g.kelas[r.kelas].nama.toUpperCase(),
                      style: Huruf.judul(20, warna: warna),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Label('Skor'),
                    Text('${r.skor}', style: Huruf.angka(36, warna: warna)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1.15,
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
                          pose: pose,
                          batas: KerangkaRingkasPainter.batasDari(r.pose),
                          warna: r.benar ? Pal.benar : Pal.kapur,
                          sorot: r.kelas > 0
                              ? g.kelas[r.kelas].bagian
                              : const [],
                          warnaSorot: warna,
                          bayangan: r.pose.sublist(0, 24),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Label(g.namaSudut),
                          Text(
                            sudut == null ? '—' : '${sudut.round()}°',
                            style: Huruf.angka(32),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (r.kurva.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: LayoutBuilder(
                  builder: (context, c) => Stack(
                    children: [
                      KurvaMini(
                        kurva: r.kurva,
                        warna: warna,
                        lebar: c.maxWidth,
                        tinggi: 40,
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
            const SizedBox(height: 10),
            Row(
              children: [
                IconButton(
                  onPressed: () => _pindah(-1),
                  icon: const Icon(Icons.skip_previous),
                  tooltip: 'Sebelumnya',
                ),
                IconButton.filled(
                  onPressed: () => setState(() => _jalan = !_jalan),
                  style: IconButton.styleFrom(
                    backgroundColor: Pal.sinyal,
                    foregroundColor: Pal.latar,
                  ),
                  icon: Icon(_jalan ? Icons.pause : Icons.play_arrow),
                  tooltip: _jalan ? 'Jeda' : 'Putar',
                ),
                IconButton(
                  onPressed: () => _pindah(1),
                  icon: const Icon(Icons.skip_next),
                  tooltip: 'Berikutnya',
                ),
                const Spacer(),
                Text(
                  '${r.durasi.toStringAsFixed(1)} DTK · ROM ${r.rom.round()}°',
                  style: Huruf.label(),
                ),
              ],
            ),
            if (r.pendapat.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Label('Penilaian model lain'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _ChipPendapat(
                    model:
                        '${namaPendek[widget.catatan.model] ?? widget.catatan.model} ★',
                    kelas: r.kelas,
                    gerakan: g,
                  ),
                  for (final e in r.pendapat.entries)
                    _ChipPendapat(
                      model: namaPendek[e.key] ?? e.key,
                      kelas: e.value,
                      gerakan: g,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChipPendapat extends StatelessWidget {
  const _ChipPendapat({
    required this.model,
    required this.kelas,
    required this.gerakan,
  });

  final String model;
  final int kelas;
  final Gerakan gerakan;

  @override
  Widget build(BuildContext context) {
    final warna = Pal.kelas(kelas);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: warna.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            model.toUpperCase(),
            style: Huruf.label(ukuran: 10, warna: Pal.kapur),
          ),
          const SizedBox(width: 6),
          Container(width: 7, height: 7, color: warna),
          const SizedBox(width: 4),
          Text(
            kelas < 0 ? '—' : gerakan.kelas[kelas].nama.toUpperCase(),
            style: Huruf.label(ukuran: 10, warna: warna),
          ),
        ],
      ),
    );
  }
}

/// Durasi turun dan naik tiap repetisi, plus rata-rata dan konsistensi.
class _Tempo extends StatelessWidget {
  const _Tempo({required this.repetisi});

  final List<HasilRepetisi> repetisi;

  @override
  Widget build(BuildContext context) {
    final r = repetisi.where((h) => h.tempo != null).toList();
    double rerata(Iterable<double> v) =>
        v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
    final turun = rerata(r.map((h) => h.tempo!.turun));
    final naik = rerata(r.map((h) => h.tempo!.naik));
    final rom = r.map((h) => h.rom).toList();
    final romRata = rerata(rom);
    final sb = rom.isEmpty
        ? 0.0
        : math.sqrt(rerata(rom.map((x) => (x - romRata) * (x - romRata))));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Bacaan(
                label: 'Turun',
                nilai: turun.toStringAsFixed(1),
                satuan: 'dtk',
                ukuran: 30,
              ),
            ),
            Expanded(
              child: Bacaan(
                label: 'Naik',
                nilai: naik.toStringAsFixed(1),
                satuan: 'dtk',
                ukuran: 30,
              ),
            ),
            Expanded(
              child: Bacaan(
                label: 'Konsistensi ROM',
                nilai: '±${sb.round()}',
                satuan: '°',
                ukuran: 30,
                warna: sb <= 10 ? Pal.benar : Pal.sinyal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GrafikTempo(repetisi: r),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              color: Pal.sinyal.withValues(alpha: 0.85),
            ),
            const SizedBox(width: 6),
            const Label('Turun', ukuran: 10),
            const SizedBox(width: 16),
            Container(width: 10, height: 10, color: Pal.redup),
            const SizedBox(width: 6),
            const Label('Naik', ukuran: 10),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Turun yang terkendali (lebih lama dari naik) umumnya lebih aman dan lebih efektif.',
          style: Huruf.teks(warna: Pal.samar, ukuran: 12.5),
        ),
      ],
    );
  }
}

/// Seberapa sering model lain setuju dengan model yang dipakai saat latihan.
class _Kesepakatan extends StatelessWidget {
  const _Kesepakatan({required this.catatan, required this.gerakan});

  final CatatanLatihan catatan;
  final Gerakan gerakan;

  @override
  Widget build(BuildContext context) {
    final r = catatan.repetisi.where((h) => h.pendapat.isNotEmpty).toList();
    final model = {for (final h in r) ...h.pendapat.keys}.toList()
      ..sort(
        (a, b) => urutanModel.indexOf(a).compareTo(urutanModel.indexOf(b)),
      );
    final semua = r
        .where((h) => h.pendapat.values.every((k) => k == h.kelas))
        .length;
    Widget baris(String nama, int sama, int benar, {bool utama = false}) =>
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Pal.garis)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  nama.toUpperCase() + (utama ? ' ★' : ''),
                  style: Huruf.judul(19, warna: utama ? Pal.sinyal : Pal.kapur),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  utama ? '—' : '${(sama * 100 / r.length).round()}%',
                  textAlign: TextAlign.end,
                  style: Huruf.angka(22),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  '$benar/${r.length}',
                  textAlign: TextAlign.end,
                  style: Huruf.angka(22, warna: Pal.benar),
                ),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Bacaan(
          label: 'Semua model sepakat',
          nilai: '$semua/${r.length}',
          warna: Pal.sinyal,
          ukuran: 34,
        ),
        const SizedBox(height: 10),
        Row(
          children: const [
            Expanded(flex: 3, child: Label('Model')),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Label('Sama ★', ukuran: 10),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Label('Benar', ukuran: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        baris(
          namaModel[catatan.model] ?? catatan.model,
          r.length,
          r.where((h) => h.kelas == 0).length,
          utama: true,
        ),
        for (final m in model)
          baris(
            namaModel[m] ?? m,
            r.where((h) => h.pendapat[m] == h.kelas).length,
            r.where((h) => h.pendapat[m] == 0).length,
          ),
        const SizedBox(height: 8),
        Text(
          '★ model yang dipakai saat latihan. Ketuk repetisi untuk melihat penilaian tiap model.',
          style: Huruf.teks(warna: Pal.samar, ukuran: 12.5),
        ),
      ],
    );
  }
}
