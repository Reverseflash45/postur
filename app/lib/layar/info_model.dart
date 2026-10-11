import 'package:flutter/material.dart';

import '../inti/gerakan.dart';
import '../inti/klasifikasi/aturan.dart';
import '../inti/klasifikasi/klasifikasi.dart';
import '../inti/paket_model.dart';
import '../tema.dart';
import 'bersama.dart';

/// Ringkasan model yang terpasang: asal data, hasil validasi, ambang aturan.
class LayarInfoModel extends StatelessWidget {
  const LayarInfoModel({super.key});

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
            const KepalaLayar(kembali: true, atas: 'Lab', judul: 'Info model'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final g in semuaGerakan) _KartuPaket(gerakan: g),
                  const SizedBox(height: 16),
                  Text(
                    'Model dibuat dengan `python -m postur latih`, lalu folder model/ disalin ke '
                    'app/assets/model/<gerakan>/. F1 = macro-F1 rerata validasi silang per subjek.',
                    style: Huruf.teks(warna: Pal.samar, ukuran: 12.5),
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

class _KartuPaket extends StatelessWidget {
  const _KartuPaket({required this.gerakan});

  final Gerakan gerakan;

  Future<(PaketModel, List<String>)> _muat() async {
    final p = await PaketModel.muat(gerakan);
    final at = await p.buat('aturan') as KlasifikasiAturan;
    return (p, at.uraian([for (final k in gerakan.kelas) k.kode]));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _muat(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final (p, aturan) = snap.data!;
        final aktif = modelAktif(p);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JudulBagian(gerakan.nama),
            Row(
              children: [
                Lencana(
                  p.sintetis ? 'Data sintetis' : 'Data asli',
                  warna: p.sintetis ? Pal.sinyal : Pal.benar,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Label('${p.nRepetisi} rep · ${p.nSubjek} subjek'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Label(
              'Dilatih ${p.dibuat.replaceFirst('T', ' ').split('+').first}',
              warna: Pal.samar,
              ukuran: 10,
            ),
            const SizedBox(height: 14),
            for (final id in urutanModel)
              _BarisF1(
                nama: namaModel[id]!,
                f1: p.f1(id),
                aktif: id == aktif,
                tersedia: p.tersedia.contains(id),
              ),
            const SizedBox(height: 14),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Label('Ambang aturan', warna: Pal.kapur),
                  const SizedBox(height: 8),
                  for (final a in aturan)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        a.toUpperCase(),
                        style: Huruf.label(ukuran: 11),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BarisF1 extends StatelessWidget {
  const _BarisF1({
    required this.nama,
    required this.f1,
    required this.aktif,
    required this.tersedia,
  });

  final String nama;
  final double? f1;
  final bool aktif;
  final bool tersedia;

  @override
  Widget build(BuildContext context) {
    final nilai = f1 ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(
              nama.toUpperCase(),
              style: Huruf.label(
                ukuran: 10.5,
                warna: aktif ? Pal.kapur : (tersedia ? Pal.redup : Pal.samar),
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  Container(height: 8, color: Pal.lapis2),
                  Container(
                    height: 8,
                    width: c.maxWidth * nilai,
                    color: aktif ? Pal.sinyal : Pal.garisKuat,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 46,
            child: Text(
              f1 == null ? '—' : f1!.toStringAsFixed(3),
              textAlign: TextAlign.end,
              style: Huruf.angka(20, warna: aktif ? Pal.sinyal : Pal.kapur),
            ),
          ),
        ],
      ),
    );
  }
}
