import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../data/penyimpanan.dart';
import '../data/rekaman.dart';
import '../data/subjek.dart';
import '../inti/gerakan.dart';
import '../inti/protokol.dart';
import '../tema.dart';
import 'bersama.dart';
import 'rekam_form.dart';
import 'sesi_terpandu.dart';
import 'subjek_form.dart';
import 'tinjau.dart';

typedef _DataLab = ({
  List<InfoRekaman> rekaman,
  List<ProfilSubjek> subjek,
  List<RencanaSesi> sesi,
});

Future<_DataLab> _muatSemua() async => (
  rekaman: await Rekaman.semua(),
  subjek: await DataSubjek.semua(),
  sesi: await DataSubjek.semuaSesi(),
);

/// Target repetisi per kelas per subjek, sesuai protokol di proposal.
const targetPerKelas = 10;

/// Daftar rekaman data penelitian dan kemajuan per subjek.
class LayarRekamDaftar extends StatefulWidget {
  const LayarRekamDaftar({super.key});

  @override
  State<LayarRekamDaftar> createState() => _LayarRekamDaftarState();
}

class _LayarRekamDaftarState extends State<LayarRekamDaftar> {
  late Future<_DataLab> _data = _muatSemua();
  bool _mengekspor = false;

  void _segarkan() => setState(() => _data = _muatSemua());

  Future<void> _buka(Widget layar) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => layar));
    _segarkan();
  }

  /// Daftarkan subjek baru (atau lanjutkan [kode]) lalu jalankan sesinya.
  /// Dari layar "sesi selesai", operator bisa langsung lanjut ke subjek
  /// berikutnya tanpa kembali ke daftar.
  Future<void> _sesi([String? kode]) async {
    final nav = Navigator.of(context);
    kode ??= await nav.push<String>(MaterialPageRoute(builder: (_) => const LayarSubjekBaru()));
    while (kode != null && mounted) {
      final lanjut = await nav.push<bool>(
        MaterialPageRoute(builder: (_) => LayarSesiTerpandu(subjek: kode!)),
      );
      _segarkan();
      if (lanjut != true || !mounted) break;
      kode = await nav.push<String>(MaterialPageRoute(builder: (_) => const LayarSubjekBaru()));
    }
    _segarkan();
  }

  Future<void> _ekspor(List<InfoRekaman> daftar) async {
    if (daftar.isEmpty) return;
    setState(() => _mengekspor = true);
    try {
      final nama =
          'postur-rekaman-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.zip';
      // Profil subjek dan rencana sesi ikut diekspor untuk tabel karakteristik.
      final path = await Penyimpanan.instance.zip([
        for (final r in daftar) r.path,
        ...await DataSubjek.semuaPath(),
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
        final daftar = snap.data?.rekaman ?? const <InfoRekaman>[];
        final profil = snap.data?.subjek ?? const <ProfilSubjek>[];
        final sesi = snap.data?.sesi ?? const <RencanaSesi>[];
        // Repetisi yang dibuang saat tinjauan tidak ikut dihitung.
        final totalRep = daftar.fold(
          0,
          (a, r) => a + r.sebaranLabel.values.fold(0, (x, y) => x + y),
        );
        final subjek = {for (final r in daftar) r.subjek}.length;
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _sesi(),
            backgroundColor: Pal.rekam,
            foregroundColor: Pal.kapur,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            icon: const Icon(Icons.person_add_alt_1),
            label: Text('SUBJEK BARU', style: Huruf.judul(19)),
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
                            _Protokol(terbuka: daftar.isEmpty && sesi.isEmpty),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: () => _buka(const LayarRekamForm()),
                              icon: const Icon(Icons.tune, size: 18),
                              label: const Text('REKAM SATU SET MANUAL'),
                            ),
                            if (sesi.isNotEmpty) ...[
                              JudulBagian('Subjek · ${sesi.length}'),
                              for (final r in sesi..sort((a, b) => nomorSubjek(a.subjek).compareTo(nomorSubjek(b.subjek))))
                                _BarisSubjek(
                                  rencana: r,
                                  profil: profil.where((p) => p.kode == r.subjek).firstOrNull,
                                  onTap: () => _sesi(r.subjek),
                                ),
                            ],
                            if (daftar.isNotEmpty) ...[
                              const JudulBagian('Kesehatan dataset'),
                              _Kesehatan(rekaman: daftar, profil: profil),
                            ],
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
      'Ketuk SUBJEK BARU. Tunjukkan lembar informasi, minta tanda tangan persetujuan, isi data anonim.',
      'Aplikasi menyusun urutan set yang seimbang untuk subjek itu dan membacakan instruksi tiap set.',
      'Pasang ponsel sesuai petunjuk posisi kamera, lalu tekan REKAM.',
      'Subjek melakukan $targetPerKelas repetisi; rekaman berhenti sendiri. Hitung manual sambil menonton.',
      'Isi hitungan manual, simpan, istirahat 60 detik, lanjut set berikutnya.',
      'Ketuk sesi rekaman untuk meninjau: ganti label atau buang repetisi yang salah peraga.',
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
          'SESI TERPANDU · SATU SET = SATU KELAS',
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


class _BarisSubjek extends StatelessWidget {
  const _BarisSubjek({required this.rencana, required this.profil, required this.onTap});

  final RencanaSesi rencana;
  final ProfilSubjek? profil;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = profil;
    final tamat = rencana.tamat;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Pal.garis))),
        child: Row(
          children: [
            SizedBox(width: 58, child: Text(rencana.subjek, style: Huruf.angka(24))),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (final l in rencana.langkah)
                        Expanded(
                          child: Container(
                            height: 6,
                            margin: const EdgeInsets.only(right: 2),
                            color: l.selesai
                                ? Pal.kelas(int.parse(l.kelas.split('-').last))
                                : (l.dilewati ? Pal.garisKuat : Pal.lapis2),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (p != null) '${p.jenisKelamin} · ${p.usia} · ${ProfilSubjek.tingkatPengalaman[p.pengalaman]}',
                      if (p == null) 'Profil tidak ditemukan',
                    ].join(),
                    style: Huruf.label(ukuran: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            tamat
                ? const Lencana('Selesai', warna: Pal.benar)
                : Text('${rencana.jumlahTuntas}/${rencana.langkah.length}', style: Huruf.angka(22, warna: Pal.sinyal)),
          ],
        ),
      ),
    );
  }
}

/// Ringkasan kesiapan dataset untuk skripsi: demografi, keseimbangan kelas,
/// dan hal yang perlu dibereskan sebelum pelatihan.
class _Kesehatan extends StatelessWidget {
  const _Kesehatan({required this.rekaman, required this.profil});

  final List<InfoRekaman> rekaman;
  final List<ProfilSubjek> profil;

  @override
  Widget build(BuildContext context) {
    final asli = rekaman.where((r) => r.subjek != 'CONTOH').toList();
    final subjekRekaman = {for (final r in asli) r.subjek};
    final kodeProfil = {for (final p in profil) p.kode};
    final tanpaProfil = subjekRekaman.difference(kodeProfil).toList()..sort();

    final peringatan = <String>[
      if (rekaman.any((r) => r.subjek == 'CONTOH')) 'Rekaman CONTOH masih ada. Hapus sebelum mengekspor data asli.',
      if (tanpaProfil.isNotEmpty) 'Tanpa profil/persetujuan: ${tanpaProfil.join(', ')}. Direkam lewat set manual.',
      if (subjekRekaman.length < 10) 'Baru ${subjekRekaman.length} subjek. Validasi silang 5-fold per subjek butuh minimal 10, idealnya 15–20.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in semuaGerakan) _Keseimbangan(gerakan: g, rekaman: asli),
        const SizedBox(height: 6),
        if (profil.isNotEmpty) _Demografi(profil: profil),
        for (final p in peringatan)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.warning_amber_rounded, size: 16, color: Pal.sinyal),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(p, style: Huruf.teks(warna: Pal.redup, ukuran: 13))),
              ],
            ),
          ),
      ],
    );
  }
}

class _Keseimbangan extends StatelessWidget {
  const _Keseimbangan({required this.gerakan, required this.rekaman});

  final Gerakan gerakan;
  final List<InfoRekaman> rekaman;

  @override
  Widget build(BuildContext context) {
    final n = {for (final k in gerakan.kode) k: 0};
    for (final r in rekaman.where((r) => r.gerakan == gerakan.id)) {
      r.sebaranLabel.forEach((k, v) => n[k] = (n[k] ?? 0) + v);
    }
    final total = n.values.fold(0, (a, b) => a + b);
    final maks = n.values.fold(1, (a, b) => a > b ? a : b);
    final min = n.values.fold(maks, (a, b) => a < b ? a : b);
    final timpang = total > 0 && min < maks * 0.7;
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Label(gerakan.nama),
            const Spacer(),
            Text('BELUM ADA DATA', style: Huruf.label(warna: Pal.samar, ukuran: 10)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Label(gerakan.nama),
              const Spacer(),
              if (timpang) const Lencana('Timpang', warna: Pal.sinyal),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < gerakan.kelas.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(width: 48, child: Text(gerakan.kelas[i].kode, style: Huruf.label(ukuran: 10))),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (_, c) => Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 12,
                          width: c.maxWidth * (n[gerakan.kelas[i].kode]! / maks),
                          color: Pal.kelas(i),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text('${n[gerakan.kelas[i].kode]}', textAlign: TextAlign.right, style: Huruf.angka(17)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Demografi extends StatelessWidget {
  const _Demografi({required this.profil});

  final List<ProfilSubjek> profil;

  @override
  Widget build(BuildContext context) {
    int hitung(bool Function(ProfilSubjek) f) => profil.where(f).length;
    final tinggi = [for (final p in profil) if (p.tinggiCm != null) p.tinggiCm!];
    final usia = {for (final u in ProfilSubjek.rentangUsia) u: hitung((p) => p.usia == u)}
      ..removeWhere((_, v) => v == 0);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Label('Karakteristik subjek'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Bacaan(label: 'Subjek', nilai: '${profil.length}')),
              Expanded(child: Bacaan(label: 'L / P', nilai: '${hitung((p) => p.jenisKelamin == 'L')}/${hitung((p) => p.jenisKelamin == 'P')}')),
              Expanded(
                child: Bacaan(
                  label: 'Tinggi',
                  nilai: tinggi.isEmpty ? '—' : '${tinggi.reduce((a, b) => a < b ? a : b)}–${tinggi.reduce((a, b) => a > b ? a : b)}',
                  satuan: tinggi.isEmpty ? null : 'cm',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Usia ${usia.entries.map((e) => '${e.key}: ${e.value}').join(' · ')}  ·  '
            '${ProfilSubjek.tingkatPengalaman.entries.map((e) => '${e.value} ${hitung((p) => p.pengalaman == e.key)}').join(' · ')}',
            style: Huruf.teks(warna: Pal.redup, ukuran: 12.5),
          ),
        ],
      ),
    );
  }
}
