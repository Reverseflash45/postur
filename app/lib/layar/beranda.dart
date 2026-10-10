import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/pengaturan.dart';
import '../data/riwayat.dart';
import '../inti/gerakan.dart';
import '../inti/klasifikasi/klasifikasi.dart';
import '../inti/paket_model.dart';
import '../sumber/sumber_kamera.dart';
import '../tema.dart';
import '../widget/ilustrasi.dart';
import 'info_model.dart';
import 'latihan.dart';
import 'pengaturan.dart';
import 'rekam_daftar.dart';
import 'riwayat.dart';
import 'ringkasan.dart';
import 'uji_kinerja.dart';

class LayarBeranda extends StatefulWidget {
  const LayarBeranda({super.key});

  @override
  State<LayarBeranda> createState() => _LayarBerandaState();
}

class _LayarBerandaState extends State<LayarBeranda> {
  late Future<List<CatatanLatihan>> _riwayat = Riwayat.semua();
  late final Future<List<PaketModel>> _paket = Future.wait([
    for (final g in semuaGerakan) PaketModel.muat(g),
  ]);

  void _segarkan() => setState(() => _riwayat = Riwayat.semua());

  Future<void> _buka(Widget layar) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => layar));
    _segarkan();
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Postur',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          color: skema.onSurface,
                        ),
                      ),
                      Text(
                        'Hitung repetisi dan cek postur lewat kamera',
                        style: TextStyle(color: skema.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => _buka(const LayarPengaturan()),
                  icon: const Icon(Icons.tune_rounded),
                  tooltip: 'Pengaturan',
                ),
              ],
            ),
            const SizedBox(height: 20),
            for (final g in semuaGerakan) ...[
              _KartuGerakan(
                gerakan: g,
                onMulai: () =>
                    _buka(LayarLatihan(gerakan: g, mode: ModeLatihan.latihan)),
                onDemo: () =>
                    _buka(LayarLatihan(gerakan: g, mode: ModeLatihan.demo)),
              ),
              const SizedBox(height: 12),
            ],
            FutureBuilder(
              future: _paket,
              builder: (context, snap) {
                final sintetis = snap.data?.any((p) => p.sintetis) ?? false;
                if (!sintetis) return const SizedBox.shrink();
                return _Pemberitahuan(
                  onTap: () => _buka(const LayarInfoModel()),
                );
              },
            ),
            FutureBuilder(
              future: _riwayat,
              builder: (context, snap) {
                final daftar = snap.data ?? const [];
                if (daftar.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    JudulBagian(
                      'Latihan terakhir',
                      aksi: 'Semua',
                      onAksi: () => _buka(const LayarRiwayat()),
                    ),
                    if (daftar.any((c) => !c.demo)) ...[
                      _PekanIni(daftar: daftar),
                      const SizedBox(height: 10),
                    ],
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (final c in daftar.take(3))
                            BarisRiwayat(
                              c: c,
                              onTap: () => _buka(LayarRingkasan(catatan: c)),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const JudulBagian('Untuk penelitian'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _Menu(
                    ikon: Icons.fiber_manual_record_rounded,
                    warna: Warna.rekam,
                    judul: 'Rekam data',
                    sub: 'Kumpulkan dataset berlabel per subjek dan kelas',
                    onTap: () => _buka(const LayarRekamDaftar()),
                  ),
                  _Menu(
                    ikon: Icons.speed_rounded,
                    warna: Warna.utama,
                    judul: 'Uji kinerja',
                    sub: 'Latensi tiap model di ponsel ini',
                    onTap: () => _buka(const LayarUjiKinerja()),
                  ),
                  _Menu(
                    ikon: Icons.insights_rounded,
                    warna: const Color(0xFF8F5BD8),
                    judul: 'Info model',
                    sub: 'Hasil validasi, ambang aturan, ukuran berkas',
                    onTap: () => _buka(const LayarInfoModel()),
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

class _KartuGerakan extends StatelessWidget {
  const _KartuGerakan({
    required this.gerakan,
    required this.onMulai,
    required this.onDemo,
  });

  final Gerakan gerakan;
  final VoidCallback onMulai;
  final VoidCallback onDemo;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final kesalahan = gerakan.kelas
        .skip(1)
        .map((k) => k.nama.toLowerCase())
        .join(', ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: kameraTersedia ? onMulai : onDemo,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: Warna.utama.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: IlustrasiGerakan(
                      gerakan,
                      warna: Warna.utama,
                      ukuran: 104,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gerakan.nama,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mendeteksi $kesalahan',
                          style: TextStyle(
                            color: skema.onSurfaceVariant,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.videocam_outlined,
                              size: 15,
                              color: skema.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                gerakan.posisiKamera,
                                style: TextStyle(
                                  color: skema.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: kameraTersedia ? onMulai : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Mulai'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onDemo,
                    icon: const Icon(Icons.smart_display_outlined, size: 20),
                    label: const Text('Demo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pemberitahuan extends StatelessWidget {
  const _Pemberitahuan({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: skema.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.science_outlined, color: skema.onTertiaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Model bawaan masih dilatih dengan data sintetis. Penilaiannya belum '
                    'bisa dipercaya sampai dilatih ulang dengan rekaman asli.',
                    style: TextStyle(
                      color: skema.onTertiaryContainer,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Jumlah repetisi tujuh hari terakhir, satu batang per hari.
class _PekanIni extends StatelessWidget {
  const _PekanIni({required this.daftar});

  final List<CatatanLatihan> daftar;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final hariIni = DateTime.now();
    final awal = DateTime(
      hariIni.year,
      hariIni.month,
      hariIni.day,
    ).subtract(const Duration(days: 6));
    final total = List.filled(7, 0), benar = List.filled(7, 0);
    for (final c in daftar) {
      if (c.demo) continue;
      final i = DateTime(
        c.mulai.year,
        c.mulai.month,
        c.mulai.day,
      ).difference(awal).inDays;
      if (i < 0 || i > 6) continue;
      total[i] += c.repetisi.length;
      benar[i] += c.benar;
    }
    final maks = total.fold(0, (a, b) => a > b ? a : b);
    final jumlah = total.fold(0, (a, b) => a + b);
    final persen = jumlah == 0
        ? 0
        : (benar.fold(0, (a, b) => a + b) * 100 / jumlah).round();
    final hari = DateFormat.E('id');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$jumlah',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'repetisi, 7 hari',
                  style: TextStyle(color: skema.onSurfaceVariant),
                ),
                const Spacer(),
                if (jumlah > 0)
                  Text(
                    '$persen% benar',
                    style: const TextStyle(
                      color: Warna.benar,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 70,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: maks == 0
                                      ? 0.04
                                      : (total[i] / maks).clamp(0.04, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: total[i] == 0
                                          ? skema.surfaceContainerHighest
                                          : Warna.utama,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              hari
                                  .format(awal.add(Duration(days: i)))
                                  .substring(0, 3),
                              style: TextStyle(
                                fontSize: 11,
                                color: i == 6
                                    ? skema.onSurface
                                    : skema.onSurfaceVariant,
                                fontWeight: i == 6
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
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

/// Satu baris catatan latihan; dipakai juga di layar Riwayat.
class BarisRiwayat extends StatelessWidget {
  const BarisRiwayat({
    super.key,
    required this.c,
    required this.onTap,
    this.onHapus,
  });

  final CatatanLatihan c;
  final VoidCallback onTap;
  final VoidCallback? onHapus;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    final g = gerakanDari(c.gerakan);
    final persen = (c.persenBenar * 100).round();
    return ListTile(
      onTap: onTap,
      onLongPress: onHapus,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Warna.utama.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IlustrasiGerakan(g, warna: Warna.utama, ukuran: 44),
      ),
      title: Text(
        '${c.repetisi.length} ${g.nama.toLowerCase()}${c.demo ? ' · demo' : ''}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${DateFormat('d MMM, HH.mm', 'id').format(c.mulai)} · ${namaModel[c.model] ?? c.model}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$persen%',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: persen >= 70 ? Warna.benar : Warna.salah,
            ),
          ),
          Text(
            'benar',
            style: TextStyle(fontSize: 11, color: skema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.ikon,
    required this.warna,
    required this.judul,
    required this.sub,
    required this.onTap,
  });

  final IconData ikon;
  final Color warna;
  final String judul;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: warna,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(ikon, color: Colors.white, size: 20),
      ),
      title: Text(judul, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(sub),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

/// Dipakai Pengaturan untuk menampilkan pilihan model.
String labelModel(PaketModel p, String id) {
  final f1 = p.f1(id);
  return '${namaModel[id]}${f1 == null ? '' : ' · F1 ${f1.toStringAsFixed(2)}'}';
}

/// Model yang dipakai saat ini untuk sebuah gerakan.
String modelAktif(PaketModel p) {
  final id = Pengaturan.instance.model(p.gerakan.id);
  return id != null && p.tersedia.contains(id) ? id : p.terbaik;
}
