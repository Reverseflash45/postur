import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/pengaturan.dart';
import '../inti/gerakan.dart';
import '../sumber/sumber_kamera.dart';
import '../tema.dart';
import '../widget/gerak.dart';
import 'latihan.dart';

/// Persiapan satu set rekaman: subjek, gerakan, kelas yang diperagakan.
class LayarRekamForm extends StatefulWidget {
  const LayarRekamForm({super.key});

  @override
  State<LayarRekamForm> createState() => _LayarRekamFormState();
}

class _LayarRekamFormState extends State<LayarRekamForm> {
  late final _subjek = TextEditingController(
    text: Pengaturan.instance.subjekTerakhir,
  );
  final _catatan = TextEditingController();
  Gerakan _g = squat;
  late Kelas _kelas = _g.kelas.first;

  bool get _valid =>
      RegExp(r'^[A-Za-z0-9]{1,8}$').hasMatch(_subjek.text.trim());

  Future<void> _mulai() async {
    final subjek = _subjek.text.trim().toUpperCase();
    Pengaturan.instance.subjekTerakhir = subjek;
    final tersimpan = await Navigator.of(context).push<HasilRekam>(
      MaterialPageRoute(
        builder: (_) => LayarLatihan(
          gerakan: _g,
          mode: ModeLatihan.rekam,
          subjek: subjek,
          kelasRekam: _kelas,
          catatan: _catatan.text.trim(),
        ),
      ),
    );
    // Setelah satu set tersimpan, pilih kelas berikutnya supaya sesi
    // perekaman satu subjek bisa berjalan tanpa banyak ketukan.
    if (tersimpan != null && mounted) {
      final i = _g.kelas.indexOf(_kelas);
      if (i < _g.kelas.length - 1) setState(() => _kelas = _g.kelas[i + 1]);
    }
  }

  @override
  void dispose() {
    _subjek.dispose();
    _catatan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            const KepalaLayar(
              kembali: true,
              atas: 'Rekam data',
              judul: 'Set baru',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  TextField(
                    controller: _subjek,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    ],
                    maxLength: 8,
                    onChanged: (_) => setState(() {}),
                    style: Huruf.angka(28),
                    decoration: const InputDecoration(
                      labelText: 'KODE SUBJEK',
                      helperText: 'Tanpa nama asli, misalnya S01',
                    ),
                  ),
                  const SizedBox(height: 12),
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
                    onSelectionChanged: (s) => setState(() {
                      _g = gerakanDari(s.first);
                      _kelas = _g.kelas.first;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Panel(
                    padding: EdgeInsets.zero,
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 84,
                            constraints: const BoxConstraints(minHeight: 96),
                            decoration: const BoxDecoration(
                              color: Pal.latar,
                              border: Border(
                                right: BorderSide(color: Pal.garis),
                              ),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: GerakAnimasi(_g, key: ValueKey(_g.id)),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Label(
                                    'Ponsel ${_g.orientasi}',
                                    warna: Pal.sinyal,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _g.posisiKamera,
                                    style: Huruf.teks(ukuran: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Jangan putar ponsel selama merekam.',
                                    style: Huruf.teks(
                                      warna: Pal.samar,
                                      ukuran: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const JudulBagian('Kelas yang diperagakan'),
                  for (var i = 0; i < _g.kelas.length; i++) ...[
                    _PilihKelas(
                      kelas: _g.kelas[i],
                      warna: Pal.kelas(i),
                      dipilih: _kelas == _g.kelas[i],
                      onTap: () => setState(() => _kelas = _g.kelas[i]),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 4),
                  TextField(
                    controller: _catatan,
                    decoration: const InputDecoration(
                      labelText: 'CATATAN (OPSIONAL)',
                      hintText: 'Pencahayaan, pakaian, kendala',
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _valid && kameraTersedia ? _mulai : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Pal.rekam,
                      foregroundColor: Pal.kapur,
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: Text('● REKAM ${_kelas.kode}'),
                  ),
                  if (!kameraTersedia)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Perekaman hanya bisa dilakukan di aplikasi Android.',
                        textAlign: TextAlign.center,
                        style: Huruf.teks(warna: Pal.salah, ukuran: 13),
                      ),
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

class _PilihKelas extends StatelessWidget {
  const _PilihKelas({
    required this.kelas,
    required this.warna,
    required this.dipilih,
    required this.onTap,
  });

  final Kelas kelas;
  final Color warna;
  final bool dipilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: EdgeInsets.zero,
      garis: dipilih ? warna : Pal.garis,
      warna: dipilih ? warna.withValues(alpha: 0.08) : Pal.lapis,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: dipilih ? 5 : 3, color: warna),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          kelas.kode,
                          style: Huruf.label(warna: warna, ukuran: 11),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            kelas.nama.toUpperCase(),
                            style: Huruf.judul(20),
                          ),
                        ),
                        if (dipilih) Icon(Icons.check, size: 18, color: warna),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      kelas.arahan,
                      style: Huruf.teks(warna: Pal.redup, ukuran: 13.5),
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
