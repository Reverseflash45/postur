import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/riwayat.dart';
import '../inti/gerakan.dart';
import '../inti/klasifikasi/klasifikasi.dart';
import '../inti/mesin_latihan.dart';
import '../tema.dart';
import 'latihan.dart';

/// Hasil satu sesi latihan: jumlah, persentase benar, sebaran kesalahan.
class LayarRingkasan extends StatelessWidget {
  const LayarRingkasan({super.key, required this.catatan, this.baru = false});

  final CatatanLatihan catatan;

  /// Baru selesai latihan (tampilkan tombol "Latihan lagi").
  final bool baru;

  @override
  Widget build(BuildContext context) {
    final g = gerakanDari(catatan.gerakan);
    final skema = Theme.of(context).colorScheme;
    final sebaran = List.filled(g.kelas.length, 0);
    for (final r in catatan.repetisi) {
      if (r.kelas >= 0) sebaran[r.kelas]++;
    }
    final total = catatan.repetisi.length;
    final persen = (catatan.persenBenar * 100).round();

    // Kesalahan paling sering, untuk saran.
    var utama = -1;
    for (var i = 1; i < sebaran.length; i++) {
      if (sebaran[i] > 0 && (utama < 0 || sebaran[i] > sebaran[utama])) {
        utama = i;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ringkasan')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _Cincin(nilai: catatan.persenBenar, label: '$persen%'),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$total repetisi ${g.nama.toLowerCase()}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${catatan.benar} benar · ${total - catatan.benar} perlu diperbaiki',
                          style: TextStyle(color: skema.onSurfaceVariant),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _Chip(Icons.timer_outlined, _durasi(catatan.detik)),
                            _Chip(
                              Icons.memory_rounded,
                              namaModel[catatan.model] ?? catatan.model,
                            ),
                            if (catatan.demo)
                              const _Chip(Icons.smart_display_outlined, 'Demo'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (utama > 0) ...[
            const SizedBox(height: 12),
            Card(
              color: Warna.kelas(utama).withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: Warna.kelas(utama),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Paling sering: ${g.kelas[utama].nama.toLowerCase()} '
                            '(${sebaran[utama]}×)',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(_saran(g.kelas[utama].kode)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const JudulBagian('Sebaran penilaian'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  for (var i = 0; i < g.kelas.length; i++)
                    _BatangKelas(
                      nama: g.kelas[i].nama,
                      jumlah: sebaran[i],
                      total: total,
                      warna: Warna.kelas(i),
                    ),
                ],
              ),
            ),
          ),
          const JudulBagian('Per repetisi'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final r in catatan.repetisi) _BarisRepetisi(r: r, g: g),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            DateFormat('EEEE, d MMMM y · HH.mm', 'id').format(catatan.mulai),
            textAlign: TextAlign.center,
            style: TextStyle(color: skema.onSurfaceVariant, fontSize: 12.5),
          ),
          if (baru) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => LayarLatihan(
                    gerakan: g,
                    mode: catatan.demo ? ModeLatihan.demo : ModeLatihan.latihan,
                  ),
                ),
              ),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Latihan lagi'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Kembali ke beranda'),
            ),
          ],
        ],
      ),
    );
  }

  static String _durasi(int detik) =>
      detik < 60 ? '$detik detik' : '${detik ~/ 60} mnt ${detik % 60} dtk';

  static String _saran(String kode) => switch (kode) {
    'SQ-1' =>
      'Turunkan pinggul sampai paha sejajar lantai. Kalau belum kuat, '
          'turun pelan-pelan dan tahan sebentar di bawah.',
    'SQ-2' =>
      'Dorong lutut ke arah ujung jari kaki saat turun dan naik. Kuda-kuda '
          'yang sedikit lebih lebar biasanya membantu.',
    'SQ-3' =>
      'Jaga dada tetap tegak dan pandangan ke depan. Bayangkan duduk ke '
          'belakang di kursi, bukan membungkuk ke depan.',
    'PU-1' =>
      'Kencangkan perut dan bokong supaya badan lurus seperti papan. '
          'Kalau berat, mulai dari push-up lutut.',
    'PU-2' =>
      'Turunkan pinggul sampai bahu, pinggul, dan pergelangan kaki segaris.',
    'PU-3' =>
      'Turunkan dada sampai siku menekuk sekitar 90°. Lebih baik sedikit '
          'repetisi penuh daripada banyak setengah.',
    _ => '',
  };
}

class _Cincin extends StatelessWidget {
  const _Cincin({required this.nilai, required this.label});

  final double nilai;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: nilai,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              color: Warna.benar,
              backgroundColor: Warna.salah.withValues(alpha: 0.25),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'benar',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).hintColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.ikon, this.teks);

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: skema.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 14, color: skema.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            teks,
            style: TextStyle(fontSize: 12, color: skema.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _BatangKelas extends StatelessWidget {
  const _BatangKelas({
    required this.nama,
    required this.jumlah,
    required this.total,
    required this.warna,
  });

  final String nama;
  final int jumlah;
  final int total;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    final f = total == 0 ? 0.0 : jumlah / total;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nama,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '$jumlah',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: f,
              minHeight: 8,
              color: warna,
              backgroundColor: warna.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarisRepetisi extends StatelessWidget {
  const _BarisRepetisi({required this.r, required this.g});

  final HasilRepetisi r;
  final Gerakan g;

  @override
  Widget build(BuildContext context) {
    final warna = Warna.kelas(r.kelas);
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 15,
        backgroundColor: warna.withValues(alpha: 0.15),
        child: Text(
          '${r.nomor}',
          style: TextStyle(
            color: warna,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
      title: Text(
        r.kelas < 0 ? '–' : g.kelas[r.kelas].nama,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        '${r.durasi.toStringAsFixed(1)} detik · rentang ${r.rom.round()}°',
      ),
      trailing: Text(
        '${(r.yakin * 100).round()}%',
        style: TextStyle(color: Theme.of(context).hintColor),
      ),
    );
  }
}
