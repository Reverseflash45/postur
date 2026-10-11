import 'package:flutter/material.dart';

import '../data/rekaman.dart';
import '../inti/gerakan.dart';
import '../inti/klasifikasi/klasifikasi.dart';
import '../inti/paket_model.dart';
import '../tema.dart';
import 'bersama.dart';
import 'info_model.dart';
import 'panduan.dart';
import 'pengaturan.dart';
import 'rekam_daftar.dart';
import 'uji_kinerja.dart';

/// Alat penelitian: rekam dataset, ukur latensi, lihat model.
class TabLab extends StatelessWidget {
  const TabLab({super.key, required this.onKembali});

  final VoidCallback onKembali;

  Future<void> _buka(BuildContext context, Widget layar) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => layar));
    onKembali();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        children: [
          const Row(
            children: [
              Label('Postur', warna: Pal.sinyal),
              Spacer(),
              Label('Penelitian'),
            ],
          ),
          const SizedBox(height: 22),
          Text('LAB', style: Huruf.angka(64)),
          const SizedBox(height: 10),
          Text(
            'Kumpulkan dataset, ukur kinerja model di perangkat ini, dan periksa hasil pelatihan.',
            style: Huruf.teks(warna: Pal.redup),
          ),
          const SizedBox(height: 18),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                FutureBuilder(
                  future: Rekaman.semua(),
                  builder: (context, snap) => _Alat(
                    judul: 'Rekam data',
                    sub: 'Dataset berlabel per subjek dan kelas, ekspor .zip',
                    nilai: snap.hasData ? '${snap.data!.length}' : null,
                    satuan: 'sesi',
                    onTap: () => _buka(context, const LayarRekamDaftar()),
                  ),
                ),
                const Divider(),
                _Alat(
                  judul: 'Uji kinerja',
                  sub: 'Latensi tiap model dan kesetiaan terhadap Python',
                  onTap: () => _buka(context, const LayarUjiKinerja()),
                ),
                const Divider(),
                _Alat(
                  judul: 'Info model',
                  sub: 'Macro-F1 validasi, ambang aturan, asal data',
                  onTap: () => _buka(context, const LayarInfoModel()),
                ),
                const Divider(),
                _Alat(
                  judul: 'Panduan',
                  sub: 'Posisi kamera dan cara membaca hasil',
                  onTap: () => _buka(context, const LayarPanduan()),
                ),
                const Divider(),
                _Alat(
                  judul: 'Pengaturan',
                  sub: 'Model penilai, suara, kamera',
                  onTap: () => _buka(context, const LayarPengaturan()),
                ),
              ],
            ),
          ),
          const JudulBagian('Model terpasang'),
          for (final g in semuaGerakan)
            FutureBuilder(
              future: PaketModel.muat(g),
              builder: (context, snap) {
                final p = snap.data;
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Pal.garis)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          g.nama.toUpperCase(),
                          style: Huruf.angka(26),
                        ),
                      ),
                      if (p != null) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Label(namaModel[modelAktif(p)]!, warna: Pal.kapur),
                            const SizedBox(height: 2),
                            Label(
                              'F1 ${p.f1(modelAktif(p))?.toStringAsFixed(3) ?? '—'} · ${p.nRepetisi} rep',
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Lencana(
                          p.sintetis ? 'Sintetis' : 'Asli',
                          warna: p.sintetis ? Pal.sinyal : Pal.benar,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _Alat extends StatelessWidget {
  const _Alat({
    required this.judul,
    required this.sub,
    required this.onTap,
    this.nilai,
    this.satuan,
  });

  final String judul;
  final String sub;
  final VoidCallback onTap;
  final String? nilai;
  final String? satuan;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(judul.toUpperCase(), style: Huruf.judul(24)),
                  const SizedBox(height: 2),
                  Text(sub, style: Huruf.teks(warna: Pal.redup, ukuran: 13)),
                ],
              ),
            ),
            if (nilai != null) ...[
              Text(nilai!, style: Huruf.angka(28)),
              const SizedBox(width: 3),
              Label(satuan ?? '', ukuran: 9),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, color: Pal.samar),
          ],
        ),
      ),
    );
  }
}
