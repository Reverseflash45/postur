import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../data/penyimpanan.dart';
import '../data/rekaman.dart';
import '../inti/gerakan.dart';
import '../tema.dart';
import 'bersama.dart';
import 'rekam_form.dart';
import 'tinjau.dart';

/// Target repetisi per kelas per subjek, sesuai protokol di proposal.
const targetPerKelas = 10;

/// Daftar rekaman data penelitian dan kemajuan per subjek.
class LayarRekamDaftar extends StatefulWidget {
  const LayarRekamDaftar({super.key});

  @override
  State<LayarRekamDaftar> createState() => _LayarRekamDaftarState();
}

class _LayarRekamDaftarState extends State<LayarRekamDaftar> {
  late Future<List<InfoRekaman>> _data = Rekaman.semua();
  bool _mengekspor = false;

  void _segarkan() => setState(() => _data = Rekaman.semua());

  Future<void> _ekspor(List<InfoRekaman> daftar) async {
    if (daftar.isEmpty) return;
    setState(() => _mengekspor = true);
    try {
      final nama =
          'postur-rekaman-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.zip';
      final path = await Penyimpanan.instance.zip([
        for (final r in daftar) r.path,
      ], nama);
      if (path == null) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'application/zip')],
          subject: 'Rekaman Postur (${daftar.length} sesi)',
          text: 'Ekstrak lalu jalankan: python -m postur latih --data <folder>',
        ),
      );
    } finally {
      if (mounted) setState(() => _mengekspor = false);
    }
  }

  Future<void> _hapus(InfoRekaman r) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('HAPUS REKAMAN?'),
        content: Text(
          '${r.subjek} · ${r.label} · ${r.repetisi ?? '?'} repetisi',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('BATAL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
    if (ya == true) {
      await Rekaman.hapus(r.path);
      _segarkan();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _data,
      builder: (context, snap) {
        final daftar = snap.data ?? const <InfoRekaman>[];
        // Repetisi yang dibuang saat tinjauan tidak ikut dihitung.
        final totalRep = daftar.fold(
          0,
          (a, r) => a + r.sebaranLabel.values.fold(0, (x, y) => x + y),
        );
        final subjek = {for (final r in daftar) r.subjek}.length;
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const LayarRekamForm()));
              _segarkan();
            },
            backgroundColor: Pal.rekam,
            foregroundColor: Pal.kapur,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            icon: const Icon(Icons.fiber_manual_record),
            label: Text('REKAM SET', style: Huruf.judul(19)),
          ),
          body: SafeArea(
            bottom: false,
            child: !snap.hasData
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: EdgeInsets.fromLTRB(
                      0,
                      0,
                      0,
                      110 + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: [
                      KepalaLayar(
                        kembali: true,
                        atas: 'Lab',
                        judul: 'Rekam data',
                        aksi: Penyimpanan.bisaEkspor
                            ? IconButton(
                                onPressed: daftar.isEmpty || _mengekspor
                                    ? null
                                    : () => _ekspor(daftar),
                                icon: _mengekspor
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.ios_share,
                                        color: Pal.kapur,
                                      ),
                                tooltip: 'Ekspor semua (.zip)',
                              )
                            : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 14),
                            Container(
                              decoration: const BoxDecoration(
                                border: Border.symmetric(
                                  horizontal: BorderSide(color: Pal.garis),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: IntrinsicHeight(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Bacaan(
                                        label: 'Sesi',
                                        nilai: '${daftar.length}',
                                      ),
                                    ),
                                    const VerticalDivider(width: 20),
                                    Expanded(
                                      child: Bacaan(
                                        label: 'Subjek',
                                        nilai: '$subjek',
                                      ),
                                    ),
                                    const VerticalDivider(width: 20),
                                    Expanded(
                                      child: Bacaan(
                                        label: 'Repetisi',
                                        nilai: '$totalRep',
                                        warna: Pal.sinyal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _Protokol(terbuka: daftar.isEmpty),
                            if (daftar.isEmpty) ...[
                              const SizedBox(height: 14),
                              OutlinedButton(
                                onPressed: () async {
                                  await Rekaman.imporContoh();
                                  _segarkan();
                                },
                                child: const Text('MUAT REKAMAN CONTOH'),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Dua rekaman demo untuk mencoba alur tinjau dan ekspor. Hapus sebelum merekam data asli.',
                                style: Huruf.teks(
                                  warna: Pal.samar,
                                  ukuran: 12.5,
                                ),
                              ),
                            ],
                            if (daftar.isNotEmpty) ...[
                              const JudulBagian('Kemajuan per subjek'),
                              _Kemajuan(daftar: daftar),
                              JudulBagian('Sesi · ${daftar.length}'),
                              for (final r in daftar)
                                _BarisRekaman(
                                  r: r,
                                  onHapus: () => _hapus(r),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            LayarTinjau(path: r.path),
                                      ),
                                    );
                                    _segarkan();
                                  },
                                ),
                              const SizedBox(height: 10),
                              Text(
                                'Ketuk sesi untuk meninjau dan memberi label ulang tiap repetisi. Tekan lama untuk menghapus.',
                                style: Huruf.teks(
                                  warna: Pal.samar,
                                  ukuran: 12.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _BarisRekaman extends StatelessWidget {
  const _BarisRekaman({
    required this.r,
    required this.onHapus,
    required this.onTap,
  });

  final InfoRekaman r;
  final VoidCallback onHapus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final indeks = int.tryParse(r.label.split('-').last) ?? 0;
    final warna = Pal.kelas(indeks);
    final g = gerakanDari(r.gerakan);
    return InkWell(
      onTap: onTap,
      onLongPress: onHapus,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Pal.garis)),
        ),
        child: Row(
          children: [
            Container(width: 3, height: 34, color: warna),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${r.subjek} · ${r.label} ${g.kelasDari(r.label).nama}'
                              .toUpperCase(),
                          style: Huruf.judul(19),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (r.ditinjau > 0) ...[
                        const SizedBox(width: 8),
                        Lencana('Ditinjau ${r.ditinjau}', warna: Pal.benar),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${tanggalJam(r.dibuat)} · ${r.detik.toStringAsFixed(0)} DTK · ${(r.ukuran / 1024).round()} KB · '
                    'OTOMATIS ${r.repetisiOtomatis ?? '?'}',
                    style: Huruf.label(ukuran: 10),
                  ),
                ],
              ),
            ),
            Text('${r.repetisi ?? '?'}', style: Huruf.angka(28)),
            const SizedBox(width: 3),
            Text('REP', style: Huruf.label(ukuran: 9)),
          ],
        ),
      ),
    );
  }
}

class _Protokol extends StatelessWidget {
  const _Protokol({required this.terbuka});

  final bool terbuka;

  @override
  Widget build(BuildContext context) {
    const langkah = [
      'Isi kode subjek (S01, S02, …) dan minta persetujuan subjek.',
      'Pilih gerakan dan kelas, lalu bacakan arahannya ke subjek.',
      'Pasang ponsel sesuai petunjuk posisi kamera, lalu mulai merekam.',
      'Subjek melakukan $targetPerKelas repetisi; hitung manual sambil menonton.',
      'Berhenti, isi hitungan manual, simpan. Ulangi untuk kelas berikutnya.',
      'Ketuk sesi untuk meninjau: ganti label atau buang repetisi yang salah peraga.',
      'Ekspor .zip ke laptop, lalu: python -m postur latih --data <folder>.',
    ];
    return Panel(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        initiallyExpanded: terbuka,
        title: Text('PROTOKOL PEREKAMAN', style: Huruf.judul(20)),
        subtitle: Text(
          'SATU SET = SATU KELAS, SATU SUBJEK',
          style: Huruf.label(ukuran: 10),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (var i = 0; i < langkah.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${i + 1}',
                      style: Huruf.angka(20, warna: Pal.sinyal),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      langkah[i],
                      style: Huruf.teks(warna: Pal.redup, ukuran: 14),
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

/// Matriks subjek × kelas: jumlah repetisi (hitungan manual) yang sudah terekam.
class _Kemajuan extends StatelessWidget {
  const _Kemajuan({required this.daftar});

  final List<InfoRekaman> daftar;

  @override
  Widget build(BuildContext context) {
    final subjek = {for (final r in daftar) r.subjek}.toList()..sort();
    final kode = [for (final g in semuaGerakan) ...g.kode];
    int jumlah(String s, String k) => daftar
        .where((r) => r.subjek == s)
        .fold(0, (a, r) => a + (r.sebaranLabel[k] ?? 0));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(44),
        columnWidths: const {0: FixedColumnWidth(54)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              const SizedBox(),
              for (final k in kode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    k,
                    textAlign: TextAlign.center,
                    style: Huruf.label(ukuran: 9.5),
                  ),
                ),
            ],
          ),
          for (final s in subjek)
            TableRow(
              children: [
                Text(s, style: Huruf.judul(18)),
                for (final k in kode)
                  Padding(
                    padding: const EdgeInsets.all(2),
                    child: _Sel(n: jumlah(s, k)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Sel extends StatelessWidget {
  const _Sel({required this.n});

  final int n;

  @override
  Widget build(BuildContext context) {
    final penuh = n >= targetPerKelas;
    return Container(
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: n == 0
            ? Pal.lapis
            : (penuh ? Pal.benar : Pal.benar.withValues(alpha: 0.22)),
        border: Border.all(color: n == 0 ? Pal.garis : Colors.transparent),
      ),
      child: Text(
        n == 0 ? '·' : '$n',
        style: Huruf.angka(17, warna: penuh ? Pal.latar : Pal.kapur),
      ),
    );
  }
}
