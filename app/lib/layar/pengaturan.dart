import 'package:flutter/material.dart';

import '../data/pengaturan.dart';
import '../inti/gerakan.dart';
import '../inti/klasifikasi/klasifikasi.dart';
import '../inti/klasifikasi/tflite.dart';
import '../inti/paket_model.dart';
import '../sumber/sumber_kamera.dart';
import '../tema.dart';
import 'bersama.dart';

class LayarPengaturan extends StatelessWidget {
  const LayarPengaturan({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Pengaturan.instance;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: p,
          builder: (context, _) => ListView(
            padding: EdgeInsets.fromLTRB(
              0,
              0,
              0,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              const KepalaLayar(
                kembali: true,
                atas: 'Lab',
                judul: 'Pengaturan',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const JudulBagian('Model penilai'),
                    Panel(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < semuaGerakan.length; i++) ...[
                            if (i > 0) const Divider(),
                            _PilihModel(gerakan: semuaGerakan[i]),
                          ],
                        ],
                      ),
                    ),
                    if (!tfliteTersedia)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '1D-CNN dan LSTM (TFLite) hanya tersedia di aplikasi Android.',
                          style: Huruf.teks(warna: Pal.samar, ukuran: 12.5),
                        ),
                      ),
                    const JudulBagian('Latihan'),
                    Panel(
                      padding: EdgeInsets.zero,
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
                          const Divider(),
                          SwitchListTile(
                            value: p.kameraDepan,
                            onChanged: kameraTersedia
                                ? (v) => p.kameraDepan = v
                                : null,
                            title: const Text('Pakai kamera depan'),
                            subtitle: const Text(
                              'Layar terlihat, tapi kualitas gambar biasanya lebih rendah',
                            ),
                          ),
                          const Divider(),
                          SwitchListTile(
                            value: p.bandingkan,
                            onChanged: (v) => p.bandingkan = v,
                            title: const Text('Bandingkan semua model'),
                            subtitle: const Text(
                              'Setiap repetisi juga dinilai model lain; hasilnya di ringkasan',
                            ),
                          ),
                          const Divider(),
                          SwitchListTile(
                            value: p.infoTeknis,
                            onChanged: (v) => p.infoTeknis = v,
                            title: const Text('Info teknis'),
                            subtitle: const Text(
                              'Latensi pose, fitur, dan klasifikasi di layar latihan',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          title: Text(gerakan.nama.toUpperCase(), style: Huruf.judul(22)),
          subtitle: Text(
            (otomatis
                    ? 'Otomatis · ${labelModel(paket, aktif)}'
                    : labelModel(paket, aktif))
                .toUpperCase(),
            style: Huruf.label(),
          ),
          trailing: const Icon(Icons.unfold_more, color: Pal.samar),
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
                        'MODEL ${gerakan.nama.toUpperCase()}',
                        style: Huruf.angka(30),
                      ),
                    ),
                    RadioListTile<String>(
                      value: '',
                      title: const Text('Otomatis'),
                      subtitle: Text(
                        'F1 validasi tertinggi · ${namaModel[paket.terbaik]}',
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
