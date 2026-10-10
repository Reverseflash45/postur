import 'package:flutter/material.dart';

import '../data/pengaturan.dart';
import '../inti/gerakan.dart';
import '../inti/klasifikasi/tflite.dart';
import '../inti/paket_model.dart';
import '../sumber/sumber_kamera.dart';
import '../tema.dart';
import 'beranda.dart';

class LayarPengaturan extends StatelessWidget {
  const LayarPengaturan({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pengaturan.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListenableBuilder(
        listenable: p,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            32 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const JudulBagian('Model penilai'),
            Card(
              child: Column(
                children: [
                  for (final g in semuaGerakan) _PilihModel(gerakan: g),
                ],
              ),
            ),
            if (!tfliteTersedia)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(
                  '1D-CNN dan LSTM (TFLite) hanya tersedia di aplikasi Android.',
                  style: TextStyle(
                    color: Theme.of(context).hintColor,
                    fontSize: 12.5,
                  ),
                ),
              ),
            const JudulBagian('Latihan'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: p.suara,
                    onChanged: (v) => p.suara = v,
                    title: const Text('Umpan balik suara'),
                    subtitle: const Text(
                      'Hitungan dan koreksi diucapkan setiap repetisi',
                    ),
                  ),
                  SwitchListTile(
                    value: p.kameraDepan,
                    onChanged: kameraTersedia ? (v) => p.kameraDepan = v : null,
                    title: const Text('Pakai kamera depan'),
                    subtitle: const Text(
                      'Layar terlihat, tapi kualitas gambar biasanya lebih rendah',
                    ),
                  ),
                  ListTile(
                    title: const Text('Target repetisi'),
                    subtitle: Slider(
                      value: p.target.toDouble(),
                      min: 5,
                      max: 30,
                      divisions: 25,
                      label: '${p.target}',
                      onChanged: (v) => p.target = v.round(),
                    ),
                    trailing: Text(
                      '${p.target}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const JudulBagian('Lanjutan'),
            Card(
              child: SwitchListTile(
                value: p.infoTeknis,
                onChanged: (v) => p.infoTeknis = v,
                title: const Text('Tampilkan info teknis'),
                subtitle: const Text(
                  'Latensi pose, fitur, dan klasifikasi di layar latihan',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PilihModel extends StatelessWidget {
  const _PilihModel({required this.gerakan});

  final Gerakan gerakan;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: PaketModel.muat(gerakan),
      builder: (context, snap) {
        final paket = snap.data;
        if (paket == null) return ListTile(title: Text(gerakan.nama));
        final aktif = modelAktif(paket);
        final otomatis = Pengaturan.instance.model(gerakan.id) == null;
        return ListTile(
          title: Text(
            gerakan.nama,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            otomatis
                ? 'Otomatis: ${labelModel(paket, aktif)}'
                : labelModel(paket, aktif),
          ),
          trailing: const Icon(Icons.expand_more_rounded),
          onTap: () => showModalBottomSheet(
            context: context,
            showDragHandle: true,
            builder: (ctx) => SafeArea(
              child: RadioGroup<String>(
                groupValue: otomatis ? '' : aktif,
                onChanged: (v) {
                  Pengaturan.instance.setModel(gerakan.id, v == '' ? null : v);
                  Navigator.pop(ctx);
                },
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        'Model untuk ${gerakan.nama.toLowerCase()}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    RadioListTile<String>(
                      value: '',
                      title: const Text('Otomatis'),
                      subtitle: Text(
                        'Pakai F1 validasi tertinggi (${labelModel(paket, paket.terbaik)})',
                      ),
                    ),
                    for (final id in paket.tersedia)
                      RadioListTile<String>(
                        value: id,
                        title: Text(labelModel(paket, id)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
