import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/pengaturan.dart';
import '../inti/gerakan.dart';
import '../sumber/sumber_kamera.dart';
import '../tema.dart';
import '../widget/ilustrasi.dart';
import 'latihan.dart';

/// Persiapan satu set rekaman: subjek, gerakan, kelas yang diperagakan.
class LayarRekamForm extends StatefulWidget {
  const LayarRekamForm({super.key});

  @override
  State<LayarRekamForm> createState() => _LayarRekamFormState();
}

class _LayarRekamFormState extends State<LayarRekamForm> {
  late final _subjek = TextEditingController(
    text: Pengaturan.instance.subjekTerakhir,
  );
  final _catatan = TextEditingController();
  Gerakan _g = squat;
  late Kelas _kelas = _g.kelas.first;

  bool get _valid =>
      RegExp(r'^[A-Za-z0-9]{1,8}$').hasMatch(_subjek.text.trim());

  Future<void> _mulai() async {
    final subjek = _subjek.text.trim().toUpperCase();
    Pengaturan.instance.subjekTerakhir = subjek;
    final tersimpan = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LayarLatihan(
          gerakan: _g,
          mode: ModeLatihan.rekam,
          subjek: subjek,
          kelasRekam: _kelas,
          catatan: _catatan.text.trim(),
        ),
      ),
    );
    // Setelah satu set tersimpan, pilih kelas berikutnya supaya sesi
    // perekaman satu subjek bisa berjalan tanpa banyak ketukan.
    if (tersimpan == true && mounted) {
      final i = _g.kelas.indexOf(_kelas);
      if (i < _g.kelas.length - 1) setState(() => _kelas = _g.kelas[i + 1]);
    }
  }

  @override
  void dispose() {
    _subjek.dispose();
    _catatan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skema = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Set baru')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          TextField(
            controller: _subjek,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            ],
            maxLength: 8,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Kode subjek',
              helperText: 'Tanpa nama asli, misalnya S01',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: [
              for (final g in semuaGerakan)
                ButtonSegment(value: g.id, label: Text(g.nama)),
            ],
            selected: {_g.id},
            onSelectionChanged: (s) => setState(() {
              _g = gerakanDari(s.first);
              _kelas = _g.kelas.first;
            }),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IlustrasiGerakan(_g, warna: Warna.utama, ukuran: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Posisi kamera',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          _g.posisiKamera,
                          style: TextStyle(color: skema.onSurfaceVariant),
                        ),
                        Text(
                          'Jangan putar ponsel selama merekam',
                          style: TextStyle(
                            color: skema.onSurfaceVariant,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const JudulBagian('Kelas yang diperagakan'),
          RadioGroup<String>(
            groupValue: _kelas.kode,
            onChanged: (v) => setState(() => _kelas = _g.kelasDari(v!)),
            child: Column(
              children: [
                for (var i = 0; i < _g.kelas.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      color: _kelas == _g.kelas[i]
                          ? Warna.kelas(i).withValues(alpha: 0.1)
                          : null,
                      child: RadioListTile<String>(
                        value: _g.kelas[i].kode,
                        title: Text(
                          '${_g.kelas[i].kode} · ${_g.kelas[i].nama}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(_g.kelas[i].arahan),
                        activeColor: Warna.kelas(i),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _catatan,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              hintText: 'Pencahayaan, pakaian, kendala',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _valid && kameraTersedia ? _mulai : null,
            style: FilledButton.styleFrom(
              backgroundColor: Warna.rekam,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.fiber_manual_record_rounded),
            label: Text('Rekam ${_kelas.kode}'),
          ),
          if (!kameraTersedia)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Perekaman hanya bisa dilakukan di aplikasi Android.',
                textAlign: TextAlign.center,
                style: TextStyle(color: skema.error),
              ),
            ),
        ],
      ),
    );
  }
}
