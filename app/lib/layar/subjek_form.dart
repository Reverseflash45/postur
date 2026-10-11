import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/subjek.dart';
import '../inti/gerakan.dart';
import '../inti/protokol.dart';
import '../tema.dart';

/// Pendaftaran subjek untuk sesi terpandu: lembar informasi, persetujuan,
/// data demografi anonim, dan rencana rekaman. Mengembalikan kode subjek
/// yang dibuat lewat Navigator.pop.
class LayarSubjekBaru extends StatefulWidget {
  const LayarSubjekBaru({super.key});

  @override
  State<LayarSubjekBaru> createState() => _LayarSubjekBaruState();
}

class _LayarSubjekBaruState extends State<LayarSubjekBaru> {
  final _kode = TextEditingController();
  final _tinggi = TextEditingController();
  final _catatan = TextEditingController();
  String? _usia;
  String? _jk;
  String? _pengalaman;
  bool _setuju = false;
  final _gerakan = <String>{'squat', 'pushup'};
  int _target = 10;
  bool _sibuk = false;
  String? _galatKode;

  @override
  void initState() {
    super.initState();
    DataSubjek.kodeBerikutnya().then((k) {
      if (mounted && _kode.text.isEmpty) setState(() => _kode.text = k);
    });
  }

  @override
  void dispose() {
    _kode.dispose();
    _tinggi.dispose();
    _catatan.dispose();
    super.dispose();
  }

  bool get _lengkap =>
      RegExp(r'^[A-Z0-9]{1,8}$').hasMatch(_kode.text.trim()) &&
      _usia != null &&
      _jk != null &&
      _pengalaman != null &&
      _setuju &&
      _gerakan.isNotEmpty;

  Future<void> _mulai() async {
    final kode = _kode.text.trim().toUpperCase();
    setState(() {
      _sibuk = true;
      _galatKode = null;
    });
    if (await DataSubjek.baca(kode) != null) {
      setState(() {
        _sibuk = false;
        _galatKode = 'Kode $kode sudah dipakai. Lanjutkan sesinya dari daftar rekaman.';
      });
      return;
    }
    final profil = ProfilSubjek(
      kode: kode,
      usia: _usia!,
      jenisKelamin: _jk!,
      pengalaman: _pengalaman!,
      tinggiCm: int.tryParse(_tinggi.text),
      setuju: _setuju,
      dibuat: DateTime.now(),
      catatan: _catatan.text.trim(),
    );
    final rencana = RencanaSesi.buat(
      subjek: kode,
      gerakan: [for (final g in semuaGerakan) if (_gerakan.contains(g.id)) g],
      target: _target,
    );
    await DataSubjek.simpan(profil);
    await DataSubjek.simpanSesi(rencana);
    // Layar pemanggil yang membuka sesi terpandu, supaya ia tahu kapan
    // sesi berakhir dan bisa menyegarkan daftarnya.
    if (mounted) Navigator.of(context).pop(kode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(0, 0, 0, 32 + MediaQuery.paddingOf(context).bottom),
          children: [
            const KepalaLayar(kembali: true, atas: 'Sesi terpandu', judul: 'Subjek baru'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 14),
                  const _LembarInformasi(),
                  const JudulBagian('Identitas anonim'),
                  TextField(
                    controller: _kode,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                      TextInputFormatter.withFunction(
                        (_, b) => b.copyWith(text: b.text.toUpperCase()),
                      ),
                    ],
                    maxLength: 8,
                    onChanged: (_) => setState(() => _galatKode = null),
                    style: Huruf.angka(28),
                    decoration: InputDecoration(
                      labelText: 'KODE SUBJEK',
                      helperText: 'Jangan pakai nama. Kode berikutnya diisi otomatis.',
                      errorText: _galatKode,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Pilihan(
                    label: 'Rentang usia',
                    nilai: _usia,
                    opsi: {for (final u in ProfilSubjek.rentangUsia) u: u},
                    onPilih: (v) => setState(() => _usia = v),
                  ),
                  _Pilihan(
                    label: 'Jenis kelamin',
                    nilai: _jk,
                    opsi: const {'L': 'Laki-laki', 'P': 'Perempuan'},
                    onPilih: (v) => setState(() => _jk = v),
                  ),
                  _Pilihan(
                    label: 'Pengalaman latihan',
                    nilai: _pengalaman,
                    opsi: ProfilSubjek.tingkatPengalaman,
                    onPilih: (v) => setState(() => _pengalaman = v),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _tinggi,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'TINGGI BADAN (CM, OPSIONAL)',
                      helperText: 'Membantu menjelaskan sebaran ukuran tubuh di skripsi.',
                    ),
                  ),
                  const JudulBagian('Rencana rekaman'),
                  Row(
                    children: [
                      for (final g in semuaGerakan) ...[
                        Expanded(
                          child: FilterChip(
                            label: SizedBox(
                              width: double.infinity,
                              child: Text(g.nama.toUpperCase(), textAlign: TextAlign.center),
                            ),
                            selected: _gerakan.contains(g.id),
                            onSelected: (v) => setState(
                              () => v ? _gerakan.add(g.id) : _gerakan.remove(g.id),
                            ),
                          ),
                        ),
                        if (g != semuaGerakan.last) const SizedBox(width: 10),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Panel(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Label('Repetisi per kelas'),
                              const SizedBox(height: 2),
                              Text(
                                '${_gerakan.length * 4} set · ${_gerakan.length * 4 * _target} repetisi',
                                style: Huruf.teks(warna: Pal.redup, ukuran: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _target > 5 ? () => setState(() => _target--) : null,
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text('$_target', textAlign: TextAlign.center, style: Huruf.angka(30)),
                        ),
                        IconButton(
                          onPressed: _target < 20 ? () => setState(() => _target++) : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Urutan kelas diacak seimbang per subjek (bujur sangkar latin Williams) supaya kelelahan tidak selalu jatuh di kelas yang sama.',
                    style: Huruf.teks(warna: Pal.samar, ukuran: 12.5),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _catatan,
                    decoration: const InputDecoration(
                      labelText: 'CATATAN (OPSIONAL)',
                      hintText: 'Lokasi, pencahayaan, alas kaki',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Panel(
                    onTap: () => setState(() => _setuju = !_setuju),
                    garis: _setuju ? Pal.benar : Pal.garisKuat,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(value: _setuju, onChanged: (v) => setState(() => _setuju = v ?? false)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Subjek sudah membaca lembar informasi, bertanya bila perlu, dan menandatangani formulir persetujuan.',
                            style: Huruf.teks(ukuran: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _lengkap && !_sibuk ? _mulai : null,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    child: Text(_sibuk ? 'MENYIAPKAN…' : 'BUAT SESI'),
                  ),
                  if (!_lengkap)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _setuju ? 'Lengkapi usia, jenis kelamin, dan pengalaman.' : 'Persetujuan subjek wajib sebelum merekam.',
                        textAlign: TextAlign.center,
                        style: Huruf.teks(warna: Pal.samar, ukuran: 12.5),
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

class _Pilihan extends StatelessWidget {
  const _Pilihan({required this.label, required this.nilai, required this.opsi, required this.onPilih});

  final String label;
  final String? nilai;
  final Map<String, String> opsi;
  final ValueChanged<String> onPilih;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Label(label),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in opsi.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: nilai == e.key,
                  onSelected: (_) => onPilih(e.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ringkasan lembar informasi yang dibacakan atau ditunjukkan ke subjek.
class _LembarInformasi extends StatelessWidget {
  const _LembarInformasi();

  static const _poin = [
    ('Apa yang dilakukan', 'Squat dan/atau push-up tanpa beban, beberapa set pendek. Sebagian set memperagakan kesalahan ringan secara sengaja.'),
    ('Apa yang direkam', 'Hanya koordinat 33 titik tubuh dari kamera. Video dan foto tidak disimpan, nama tidak dicatat.'),
    ('Waktu', 'Sekitar 20–30 menit, dengan istirahat di antara set.'),
    ('Keamanan', 'Peragaan kesalahan dibuat ringan. Boleh berhenti kapan saja bila lelah atau tidak nyaman.'),
    ('Hak subjek', 'Boleh mengundurkan diri kapan pun; seluruh rekamannya akan dihapus.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        initiallyExpanded: true,
        title: Text('LEMBAR INFORMASI', style: Huruf.judul(20)),
        subtitle: Text('TUNJUKKAN ATAU BACAKAN KE SUBJEK', style: Huruf.label(ukuran: 10)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (judul, isi) in _poin)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Label(judul, warna: Pal.sinyal),
                  const SizedBox(height: 2),
                  Text(isi, style: Huruf.teks(warna: Pal.kapur, ukuran: 14)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
