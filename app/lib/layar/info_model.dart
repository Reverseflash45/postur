import 'package:flutter/material.dart';

import '../inti/gerakan.dart';
import '../inti/klasifikasi/aturan.dart';
import '../inti/klasifikasi/klasifikasi.dart';
import '../inti/paket_model.dart';
import '../tema.dart';
import 'beranda.dart';

/// Ringkasan model yang terpasang: asal data, hasil validasi, ambang aturan.
class LayarInfoModel extends StatelessWidget {
  const LayarInfoModel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Info model')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          for (final g in semuaGerakan) _KartuPaket(gerakan: g),
          const SizedBox(height: 8),
          Text(
            'Model dibuat dengan `python -m postur latih`, lalu folder model/ disalin ke '
            'app/assets/model/<gerakan>/. F1 = macro-F1 rerata validasi silang per subjek.',
            style: TextStyle(
              color: Theme.of(context).hintColor,
              fontSize: 12.5,
            ),
          ),
        ],
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
    final skema = Theme.of(context).colorScheme;
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Lencana(
                          teks: p.sintetis ? 'Data sintetis' : 'Data asli',
                          warna: p.sintetis ? Warna.salah : Warna.benar,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${p.nRepetisi} repetisi · ${p.nSubjek} subjek',
                            style: TextStyle(color: skema.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dilatih ${p.dibuat.replaceFirst('T', ' ').split('+').first}',
                      style: TextStyle(
                        color: skema.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final id in urutanModel)
                      _BarisF1(
                        nama: namaModel[id]!,
                        f1: p.f1(id),
                        aktif: id == aktif,
                        tersedia: p.tersedia.contains(id),
                      ),
                    const Divider(height: 24),
                    const Text(
                      'Ambang aturan',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    for (final a in aturan)
                      Text(
                        a,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: skema.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
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
    final skema = Theme.of(context).colorScheme;
    final nilai = f1 ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            child: Text(
              nama,
              style: TextStyle(
                fontWeight: aktif ? FontWeight.w800 : FontWeight.w500,
                color: tersedia
                    ? null
                    : skema.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: nilai,
                minHeight: 8,
                color: aktif
                    ? Warna.utama
                    : Warna.utama.withValues(alpha: 0.45),
                backgroundColor: skema.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 40,
            child: Text(
              f1 == null ? '–' : f1!.toStringAsFixed(3),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Lencana extends StatelessWidget {
  const _Lencana({required this.teks, required this.warna});

  final String teks;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        teks,
        style: TextStyle(
          color: warna,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
