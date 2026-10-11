import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/riwayat.dart';
import '../inti/gerakan.dart';
import '../inti/klasifikasi/klasifikasi.dart';
import '../tema.dart';
import '../widget/grafik.dart';
import 'bersama.dart';
import 'ringkasan.dart';

/// Statistik, tren skor form, rekor, dan riwayat sesi.
class TabProgres extends StatefulWidget {
  const TabProgres({super.key, required this.onKembali});

  final VoidCallback onKembali;

  @override
  State<TabProgres> createState() => _TabProgresState();
}

class _TabProgresState extends State<TabProgres> {
  late Future<List<CatatanLatihan>> _data = Riwayat.semua();

  Future<void> _buka(CatatanLatihan c) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => LayarRingkasan(catatan: c)));
    setState(() => _data = Riwayat.semua());
  }

  Future<void> _hapus(CatatanLatihan c) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('HAPUS CATATAN?'),
        content: Text(
          '${c.repetisi.length} repetisi ${gerakanDari(c.gerakan).nama.toLowerCase()} akan dihapus.',
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
    if (ya != true) return;
    await Riwayat.hapus(c.id);
    setState(() => _data = Riwayat.semua());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder(
        future: _data,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final semua = snap.data!;
          final asli = semua.where((c) => !c.demo).toList();
          // Tanpa data asli, statistik memakai sesi demo supaya tampilan bisa
          // dicoba — ditandai jelas sebagai data demo.
          final statistik = asli.isNotEmpty ? asli : semua;
          final hanyaDemo = asli.isEmpty && semua.isNotEmpty;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            children: [
              Row(
                children: [
                  const Label('Postur', warna: Pal.sinyal),
                  const Spacer(),
                  if (hanyaDemo) const Lencana('Data demo'),
                ],
              ),
              const SizedBox(height: 22),
              Text('PROGRES', style: Huruf.angka(64)),
              if (semua.isEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Belum ada latihan. Selesaikan satu sesi (atau coba demo) dan grafiknya muncul di sini.',
                  style: Huruf.teks(warna: Pal.redup),
                ),
              ] else ...[
                const SizedBox(height: 18),
                _Ringkas(daftar: statistik),
                const JudulBagian('Repetisi 14 hari'),
                _Harian(daftar: statistik),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(width: 10, height: 10, color: Pal.benar),
                    const SizedBox(width: 6),
                    const Label('Benar', ukuran: 10),
                    const SizedBox(width: 16),
                    Container(width: 10, height: 10, color: Pal.salah),
                    const SizedBox(width: 6),
                    const Label('Perlu perbaikan', ukuran: 10),
                  ],
                ),
                const JudulBagian('Skor form per sesi'),
                GarisTren(
                  nilai: [
                    for (final c in statistik.reversed.toList().sublist(
                      math.max(0, statistik.length - 14),
                    ))
                      if (c.skor != null) c.skor!.toDouble(),
                  ],
                ),
                const JudulBagian('Rekor'),
                for (final g in semuaGerakan)
                  _Rekor(gerakan: g, daftar: statistik),
                JudulBagian('Riwayat · ${semua.length} sesi'),
                for (final c in semua)
                  _BarisSesi(
                    c: c,
                    onTap: () => _buka(c),
                    onHapus: () => _hapus(c),
                  ),
                const SizedBox(height: 10),
                Text(
                  'Tekan lama untuk menghapus.',
                  style: Huruf.label(ukuran: 10, warna: Pal.samar),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Ringkas extends StatelessWidget {
  const _Ringkas({required this.daftar});

  final List<CatatanLatihan> daftar;

  @override
  Widget build(BuildContext context) {
    final batas = DateTime.now().subtract(const Duration(days: 7));
    final pekan = daftar.where((c) => c.mulai.isAfter(batas)).toList();
    final rep = pekan.fold(0, (a, c) => a + c.repetisi.length);
    final benar = pekan.fold(0, (a, c) => a + c.benar);
    final skor = [for (final c in pekan) ?c.skor];
    final rerata = skor.isEmpty
        ? null
        : (skor.reduce((a, b) => a + b) / skor.length).round();
    return Container(
      decoration: const BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: Pal.garis)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Bacaan(label: 'Rep 7 hari', nilai: '$rep', ukuran: 44),
            ),
            const VerticalDivider(width: 20),
            Expanded(
              child: Bacaan(
                label: 'Skor rata',
                nilai: rerata == null ? '—' : '$rerata',
                ukuran: 44,
                warna: Pal.sinyal,
              ),
            ),
            const VerticalDivider(width: 20),
            Expanded(
              child: Bacaan(
                label: 'Benar',
                nilai: rep == 0 ? '—' : '${(benar * 100 / rep).round()}',
                satuan: rep == 0 ? null : '%',
                ukuran: 44,
                warna: Pal.benar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Harian extends StatelessWidget {
  const _Harian({required this.daftar});

  final List<CatatanLatihan> daftar;

  @override
  Widget build(BuildContext context) {
    final kini = DateTime.now();
    final awal = DateTime(
      kini.year,
      kini.month,
      kini.day,
    ).subtract(const Duration(days: 13));
    final total = List.filled(14, 0), benar = List.filled(14, 0);
    for (final c in daftar) {
      final i = DateTime(
        c.mulai.year,
        c.mulai.month,
        c.mulai.day,
      ).difference(awal).inDays;
      if (i < 0 || i > 13) continue;
      total[i] += c.repetisi.length;
      benar[i] += c.benar;
    }
    return BatangHarian(
      total: total,
      benar: benar,
      label: [
        for (var i = 0; i < 14; i++)
          i % 2 == 1 ? '${awal.add(Duration(days: i)).day}' : '',
      ],
    );
  }
}

class _Rekor extends StatelessWidget {
  const _Rekor({required this.gerakan, required this.daftar});

  final Gerakan gerakan;
  final List<CatatanLatihan> daftar;

  @override
  Widget build(BuildContext context) {
    final milik = daftar.where((c) => c.gerakan == gerakan.id).toList();
    var repSet = 0;
    var skor = 0;
    var total = 0;
    for (final c in milik) {
      total += c.repetisi.length;
      final perSet = <int, int>{};
      for (final r in c.repetisi) {
        perSet[r.set] = (perSet[r.set] ?? 0) + 1;
      }
      repSet = math.max(repSet, perSet.values.fold(0, math.max));
      skor = math.max(skor, c.skor ?? 0);
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Pal.garis)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(gerakan.nama.toUpperCase(), style: Huruf.angka(28)),
          ),
          Expanded(
            flex: 2,
            child: Bacaan(
              label: 'Rep/set',
              nilai: milik.isEmpty ? '—' : '$repSet',
              ukuran: 26,
            ),
          ),
          Expanded(
            flex: 2,
            child: Bacaan(
              label: 'Skor',
              nilai: milik.isEmpty ? '—' : '$skor',
              ukuran: 26,
              warna: Pal.sinyal,
            ),
          ),
          Expanded(
            flex: 2,
            child: Bacaan(label: 'Total', nilai: '$total', ukuran: 26),
          ),
        ],
      ),
    );
  }
}

class _BarisSesi extends StatelessWidget {
  const _BarisSesi({
    required this.c,
    required this.onTap,
    required this.onHapus,
  });

  final CatatanLatihan c;
  final VoidCallback onTap;
  final VoidCallback onHapus;

  @override
  Widget build(BuildContext context) {
    final g = gerakanDari(c.gerakan);
    final skor = c.skor;
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(g.nama.toUpperCase(), style: Huruf.judul(22)),
                      if (c.demo) ...[
                        const SizedBox(width: 8),
                        const Lencana('Demo'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${tanggalJam(c.mulai)} · ${c.repetisi.length} REP · ${c.jumlahSet} SET · '
                    '${(namaPendek[c.model] ?? c.model).toUpperCase()}',
                    style: Huruf.label(ukuran: 10),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 5,
                    child: Row(
                      children: [
                        for (final r in c.repetisi)
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(right: 1.5),
                              color: Pal.kelas(r.kelas),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Label('Skor', ukuran: 9.5),
                Text(
                  skor == null ? '—' : '$skor',
                  style: Huruf.angka(34, warna: Pal.sinyal),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
