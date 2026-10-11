import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../data/pengaturan.dart';
import '../inti/gerakan.dart';
import '../inti/paket_model.dart';
import '../sumber/sumber_kamera.dart';
import '../tema.dart';
import '../widget/gerak.dart';
import 'bersama.dart';
import 'info_model.dart';
import 'latihan.dart';

/// Tab utama: pilih gerakan dan atur target sesi.
class TabLatih extends StatelessWidget {
  const TabLatih({super.key, required this.onKembali});

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
          Row(
            children: [
              const Label('Postur', warna: Pal.sinyal),
              const Spacer(),
              Label(tanggalSingkat(DateTime.now())),
            ],
          ),
          const SizedBox(height: 22),
          Text('PILIH\nGERAKAN', style: Huruf.angka(64)),
          const SizedBox(height: 10),
          Text(
            kIsWeb
                ? 'Kamera menghitung repetisi dan menilai bentuk setiap gerakan, langsung di browser. Video tidak pernah diunggah.'
                : 'Kamera menghitung repetisi dan menilai bentuk setiap gerakan, langsung di ponsel.',
            style: Huruf.teks(warna: Pal.redup),
          ),
          const SizedBox(height: 22),
          for (final g in semuaGerakan) ...[
            _BayGerakan(
              gerakan: g,
              onMulai: () => _buka(
                context,
                LayarLatihan(gerakan: g, mode: ModeLatihan.latihan),
              ),
              onDemo: () => _buka(
                context,
                LayarLatihan(gerakan: g, mode: ModeLatihan.demo),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const JudulBagian('Target sesi'),
          const _PengaturTarget(),
          const SizedBox(height: 12),
          FutureBuilder(
            future: Future.wait([
              for (final g in semuaGerakan) PaketModel.muat(g),
            ]),
            builder: (context, snap) {
              if (!(snap.data?.any((p) => p.sintetis) ?? false)) {
                return const SizedBox.shrink();
              }
              return _CatatanModel(
                onTap: () => _buka(context, const LayarInfoModel()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BayGerakan extends StatelessWidget {
  const _BayGerakan({
    required this.gerakan,
    required this.onMulai,
    required this.onDemo,
  });

  final Gerakan gerakan;
  final VoidCallback onMulai;
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 130,
                  constraints: const BoxConstraints(minHeight: 170),
                  decoration: const BoxDecoration(
                    color: Pal.latar,
                    border: Border(right: BorderSide(color: Pal.garis)),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(child: CustomPaint(painter: _Grid())),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: GerakAnimasi(gerakan),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gerakan.nama.toUpperCase(),
                          style: Huruf.angka(40),
                        ),
                        const SizedBox(height: 10),
                        Label('Mendeteksi', warna: Pal.samar, ukuran: 10),
                        const SizedBox(height: 4),
                        for (var i = 1; i < gerakan.kelas.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  color: Pal.kelas(i),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    gerakan.kelas[i].nama,
                                    style: Huruf.teks(
                                      ukuran: 13.5,
                                      warna: Pal.redup,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        const SizedBox(height: 8),
                        Text(
                          gerakan.posisiKamera.toUpperCase(),
                          style: Huruf.label(ukuran: 9.5, warna: Pal.samar),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: kameraTersedia ? onMulai : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('MULAI'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: OutlinedButton(
                    onPressed: onDemo,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    child: const Text('DEMO'),
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

/// Grid tipis di belakang animasi, seperti kertas ukur.
class _Grid extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Pal.garis
      ..strokeWidth = 1;
    const langkah = 16.0;
    for (var x = langkah; x < size.width; x += langkah) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = langkah; y < size.height; y += langkah) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_Grid old) => false;
}

class _PengaturTarget extends StatelessWidget {
  const _PengaturTarget();

  @override
  Widget build(BuildContext context) {
    final p = Pengaturan.instance;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) => Panel(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: _Langkah(
                  label: 'Set',
                  nilai: '${p.jumlahSet}',
                  kurang: p.jumlahSet > 1
                      ? () => p.jumlahSet = p.jumlahSet - 1
                      : null,
                  tambah: p.jumlahSet < 8
                      ? () => p.jumlahSet = p.jumlahSet + 1
                      : null,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _Langkah(
                  label: 'Rep / set',
                  nilai: '${p.target}',
                  kurang: p.target > 3 ? () => p.target = p.target - 1 : null,
                  tambah: p.target < 40 ? () => p.target = p.target + 1 : null,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _Langkah(
                  label: 'Istirahat',
                  nilai: '${p.istirahat}',
                  satuan: 'dtk',
                  kurang: p.istirahat > 15
                      ? () => p.istirahat = p.istirahat - 15
                      : null,
                  tambah: p.istirahat < 300
                      ? () => p.istirahat = p.istirahat + 15
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Langkah extends StatelessWidget {
  const _Langkah({
    required this.label,
    required this.nilai,
    this.satuan,
    this.kurang,
    this.tambah,
  });

  final String label;
  final String nilai;
  final String? satuan;
  final VoidCallback? kurang;
  final VoidCallback? tambah;

  @override
  Widget build(BuildContext context) {
    Widget tombol(IconData ikon, VoidCallback? aksi, String tip) => InkWell(
      onTap: aksi,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(
          ikon,
          size: 18,
          color: aksi == null ? Pal.garisKuat : Pal.redup,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Label(label, ukuran: 10),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(nilai, style: Huruf.angka(34)),
              if (satuan != null) ...[
                const SizedBox(width: 2),
                Text(satuan!, style: Huruf.label(ukuran: 9)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              tombol(Icons.remove, kurang, 'Kurangi'),
              const SizedBox(width: 4),
              tombol(Icons.add, tambah, 'Tambah'),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatatanModel extends StatelessWidget {
  const _CatatanModel({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      garis: Pal.sinyal.withValues(alpha: 0.4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Lencana('Sintetis'),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Model penilai masih dilatih dengan data sintetis. Hitungan repetisi sudah bisa dipakai; '
              'penilaian bentuk menunggu model dari rekaman asli.',
              style: Huruf.teks(warna: Pal.redup, ukuran: 13),
            ),
          ),
        ],
      ),
    );
  }
}
