import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../data/penyimpanan.dart';
import '../data/rekaman.dart';
import '../inti/gerakan.dart';
import '../tema.dart';
import 'rekam_form.dart';

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
      final w = DateTime.now();
      final nama =
          'postur-rekaman-${DateFormat('yyyyMMdd-HHmm').format(w)}.zip';
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
        title: const Text('Hapus rekaman?'),
        content: Text(
          '${r.subjek} · ${r.label} · ${r.repetisi ?? '?'} repetisi',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
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
        return Scaffold(
          appBar: AppBar(
            title: const Text('Rekam data'),
            actions: [
              if (Penyimpanan.bisaEkspor)
                IconButton(
                  onPressed: daftar.isEmpty || _mengekspor
                      ? null
                      : () => _ekspor(daftar),
                  icon: _mengekspor
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_rounded),
                  tooltip: 'Ekspor semua (.zip)',
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const LayarRekamForm()));
              _segarkan();
            },
            backgroundColor: Warna.rekam,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.fiber_manual_record_rounded),
            label: const Text('Rekam set'),
          ),
          body: !snap.hasData
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    100 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    _Protokol(terbuka: daftar.isEmpty),
                    if (daftar.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.folder_open_rounded,
                              size: 44,
                              color: Theme.of(context).hintColor,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Belum ada rekaman',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ketuk Rekam set untuk merekam set pertama. Target: '
                              '$targetPerKelas repetisi per kelas untuk setiap subjek.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (daftar.isNotEmpty) ...[
                      const JudulBagian('Kemajuan per subjek'),
                      _Kemajuan(daftar: daftar),
                      JudulBagian('${daftar.length} sesi terekam'),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final r in daftar)
                              ListTile(
                                onLongPress: () => _hapus(r),
                                leading: CircleAvatar(
                                  backgroundColor: Warna.kelas(
                                    int.parse(r.label.split('-').last),
                                  ).withValues(alpha: 0.15),
                                  child: Text(
                                    r.label.split('-').last,
                                    style: TextStyle(
                                      color: Warna.kelas(
                                        int.parse(r.label.split('-').last),
                                      ),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  '${r.subjek} · ${r.label} '
                                  '${gerakanDari(r.gerakan).kelasDari(r.label).nama.toLowerCase()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${r.repetisi ?? '?'} repetisi (otomatis ${r.repetisiOtomatis ?? '?'}) · '
                                  '${r.detik.toStringAsFixed(0)} dtk · ${(r.ukuran / 1024).round()} KB',
                                ),
                                trailing: Text(
                                  DateFormat('d/M HH.mm').format(r.dibuat),
                                  style: TextStyle(
                                    color: Theme.of(context).hintColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tekan lama untuk menghapus. Rekaman tersimpan di ponsel sampai diekspor.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).hintColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _Protokol extends StatelessWidget {
  const _Protokol({required this.terbuka});

  final bool terbuka;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    const langkah = [
      'Isi kode subjek (S01, S02, …) dan minta persetujuan subjek.',
      'Pilih gerakan dan kelas, lalu bacakan arahannya ke subjek.',
      'Pasang ponsel sesuai petunjuk posisi kamera, lalu mulai merekam.',
      'Subjek melakukan $targetPerKelas repetisi; hitung manual sambil menonton.',
      'Berhenti, isi hitungan manual, simpan. Ulangi untuk kelas berikutnya.',
      'Ekspor .zip ke laptop, lalu: python -m postur latih --data <folder>.',
    ];
    return Card(
      color: skema.surfaceContainerLow,
      child: ExpansionTile(
        shape: const Border(),
        initiallyExpanded: terbuka,
        leading: const Icon(Icons.checklist_rounded),
        title: const Text(
          'Protokol perekaman',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text('Satu set = satu kelas, satu subjek'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (var i = 0; i < langkah.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${i + 1}.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(child: Text(langkah[i])),
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
    final skema = Theme.of(context).colorScheme;
    final subjek = {for (final r in daftar) r.subjek}.toList()..sort();
    final kode = [for (final g in semuaGerakan) ...g.kode];
    int jumlah(String s, String k) => daftar
        .where((r) => r.subjek == s && r.label == k)
        .fold(0, (a, r) => a + (r.repetisi ?? r.repetisiOtomatis ?? 0));
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: Table(
          defaultColumnWidth: const FixedColumnWidth(46),
          columnWidths: const {0: FixedColumnWidth(56)},
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
                      style: TextStyle(
                        fontSize: 11,
                        color: skema.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            for (final s in subjek)
              TableRow(
                children: [
                  Text(s, style: const TextStyle(fontWeight: FontWeight.w700)),
                  for (final k in kode)
                    Padding(
                      padding: const EdgeInsets.all(3),
                      child: _Sel(n: jumlah(s, k)),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Sel extends StatelessWidget {
  const _Sel({required this.n});

  final int n;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final penuh = n >= targetPerKelas;
    return Container(
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: n == 0
            ? skema.surfaceContainerHighest.withValues(alpha: 0.5)
            : penuh
            ? Warna.benar
            : Warna.benar.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        n == 0 ? '·' : '$n',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
          color: penuh ? Colors.white : skema.onSurface,
        ),
      ),
    );
  }
}
