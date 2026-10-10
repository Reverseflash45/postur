import 'package:flutter/material.dart';

import '../data/riwayat.dart';
import 'beranda.dart';
import 'ringkasan.dart';

class LayarRiwayat extends StatefulWidget {
  const LayarRiwayat({super.key});

  @override
  State<LayarRiwayat> createState() => _LayarRiwayatState();
}

class _LayarRiwayatState extends State<LayarRiwayat> {
  late Future<List<CatatanLatihan>> _data = Riwayat.semua();

  Future<void> _hapus(CatatanLatihan c) async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus catatan ini?'),
        content: Text(
          '${c.repetisi.length} repetisi akan dihapus dari riwayat.',
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
    if (ya != true) return;
    await Riwayat.hapus(c.id);
    setState(() => _data = Riwayat.semua());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat latihan')),
      body: FutureBuilder(
        future: _data,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final daftar = snap.data!;
          if (daftar.isEmpty) {
            return const Center(child: Text('Belum ada latihan yang tercatat'));
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              4,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final c in daftar)
                      BarisRiwayat(
                        c: c,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LayarRingkasan(catatan: c),
                          ),
                        ),
                        onHapus: () => _hapus(c),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tekan lama untuk menghapus.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 12,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
