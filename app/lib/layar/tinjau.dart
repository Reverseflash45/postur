import 'package:flutter/material.dart';

import '../data/rekaman.dart';
import '../inti/fitur.dart';
import '../inti/gerakan.dart';
import '../inti/mesin_latihan.dart';
import '../inti/repetisi.dart';
import '../sumber/sumber_rekaman.dart';
import '../tema.dart';
import '../widget/putar.dart';

const _buang = 'BUANG';

/// Satu repetisi yang terpotong dari berkas rekaman.
class _Rep {
  _Rep(this.pose, this.kurva, this.durasi, this.rom);

  final List<double> pose;
  final List<double> kurva;
  final double durasi;
  final double rom;
}

/// Tinjau rekaman data: putar ulang tiap repetisi, lalu ganti labelnya atau
/// buang repetisi yang salah diperagakan. Hasilnya disimpan sebagai
/// label_rep di berkas sesi dan dibaca saat pelatihan di Python.
///
/// Repetisi dipotong dengan penghitung yang sama dengan Python, jadi nomor
/// repetisi di sini sama dengan nomor di laporan pelatihan.
class LayarTinjau extends StatefulWidget {
  const LayarTinjau({super.key, required this.path});

  final String path;

  @override
  State<LayarTinjau> createState() => _LayarTinjauState();
}

class _LayarTinjauState extends State<LayarTinjau> {
  Map<String, dynamic>? _js;
  Gerakan? _g;
  List<_Rep> _rep = [];
  List<String?> _label = [];
  int _pilih = 0;
  bool _berubah = false;
  String? _galat;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    try {
      final js = await Rekaman.baca(widget.path);
      if (js == null) throw StateError('Berkas tidak ditemukan');
      final g = gerakanDari(js['gerakan'] as String);
      final frame = SumberRekaman.bacaFrame(js);
      final hitung = PenghitungRepetisi(g);
      final rep = <_Rep>[];
      for (var i = 0; i < frame.length; i++) {
        final p = hitung.proses(i, frame[i].t, sinyalUtama(frame[i], g));
        if (p == null) continue;
        final f = prosesRepetisi(frame.sublist(p.mulai, p.selesai + 1), g);
        final (pose, kurva) = dataPutar(f, g);
        rep.add(_Rep(pose, kurva, f.durasiDetik, p.rom));
      }
      final lama = (js['label_rep'] as List? ?? const []).cast<String?>();
      setState(() {
        _js = js;
        _g = g;
        _rep = rep;
        _label = [
          for (var k = 0; k < rep.length; k++) k < lama.length ? lama[k] : null,
        ];
      });
    } catch (e) {
      setState(() => _galat = '$e');
    }
  }

  String get _labelSet => _js!['label'] as String;

  String _efektif(int k) => _label[k] ?? _labelSet;

  Future<void> _simpan() async {
    await Rekaman.simpanLabel(widget.path, _label);
    if (!mounted) return;
    setState(() => _berubah = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Label repetisi disimpan')));
  }

  Future<bool> _bolehKeluar() async {
    if (!_berubah) return true;
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('BUANG PERUBAHAN?'),
        content: const Text('Label yang diubah belum disimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('BATAL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('KELUAR'),
          ),
        ],
      ),
    );
    return ya == true;
  }

  @override
  Widget build(BuildContext context) {
    final js = _js, g = _g;
    return PopScope(
      canPop: !_berubah,
      onPopInvokedWithResult: (sudah, _) async {
        if (sudah) return;
        if (await _bolehKeluar() && context.mounted) {
          setState(() => _berubah = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: _galat != null
              ? Center(
                  child: Text(_galat!, style: Huruf.teks(warna: Pal.salah)),
                )
              : js == null || g == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    0,
                    0,
                    32 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    KepalaLayar(
                      kembali: true,
                      atas:
                          '${js['subjek']} · ${g.nama} · ${g.kelasDari(_labelSet).nama}',
                      judul: 'Tinjau',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _isi(context, js, g),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _isi(BuildContext context, Map<String, dynamic> js, Gerakan g) {
    final manual = js['repetisi_manual'] as int?;
    final dibuang = [for (var k = 0; k < _rep.length; k++) _efektif(k)]
        .where((l) => l == _buang)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Container(
          decoration: const BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: Pal.garis)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Bacaan(label: 'Terpotong', nilai: '${_rep.length}'),
                ),
                const VerticalDivider(width: 20),
                Expanded(
                  child: Bacaan(
                    label: 'Manual',
                    nilai: manual == null ? '—' : '$manual',
                    warna: manual != null && manual != _rep.length
                        ? Pal.salah
                        : Pal.kapur,
                  ),
                ),
                const VerticalDivider(width: 20),
                Expanded(
                  child: Bacaan(
                    label: 'Dipakai',
                    nilai: '${_rep.length - dibuang}',
                    warna: Pal.sinyal,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (manual != null && manual != _rep.length) ...[
          const SizedBox(height: 10),
          Text(
            'Jumlah terpotong berbeda dari hitungan manual. Periksa repetisi yang terlewat atau '
            'terhitung ganda; selisih ini masuk ke evaluasi penghitung repetisi.',
            style: Huruf.teks(warna: Pal.salah, ukuran: 13),
          ),
        ],
        if (_rep.isEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Tidak ada repetisi yang terdeteksi di rekaman ini.',
            style: Huruf.teks(warna: Pal.redup),
          ),
        ] else ...[
          const SizedBox(height: 16),
          PemutarRepetisi(
            key: ValueKey(_pilih),
            pose: _rep[_pilih].pose,
            kurva: _rep[_pilih].kurva,
            durasi: _rep[_pilih].durasi,
            namaSudut: g.namaSudut,
            warna: _efektif(_pilih) == _buang ? Pal.samar : Pal.kapur,
            warnaKurva: _efektif(_pilih) == _buang
                ? Pal.samar
                : Pal.kelas(g.indeks(_efektif(_pilih))),
            sorot: _efektif(_pilih) == _buang
                ? const []
                : g.kelasDari(_efektif(_pilih)).bagian,
            warnaSorot: _efektif(_pilih) == _buang
                ? Pal.samar
                : Pal.kelas(g.indeks(_efektif(_pilih))),
          ),
          const SizedBox(height: 6),
          Text(
            'REP ${(_pilih + 1).toString().padLeft(2, '0')} · ${_rep[_pilih].durasi.toStringAsFixed(1)} DTK · '
            'ROM ${_rep[_pilih].rom.round()}°',
            style: Huruf.label(),
          ),
          const JudulBagian('Repetisi'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var k = 0; k < _rep.length; k++)
                _ChipRep(
                  nomor: k + 1,
                  warna: _efektif(k) == _buang
                      ? Pal.samar
                      : Pal.kelas(g.indeks(_efektif(k))),
                  dibuang: _efektif(k) == _buang,
                  diubah: _label[k] != null,
                  dipilih: k == _pilih,
                  onTap: () => setState(() => _pilih = k),
                ),
            ],
          ),
          JudulBagian('Label rep ${(_pilih + 1).toString().padLeft(2, '0')}'),
          for (var i = 0; i < g.kelas.length; i++)
            _PilihLabel(
              teks:
                  '${g.kelas[i].kode} · ${g.kelas[i].nama}${g.kelas[i].kode == _labelSet ? '  (label set)' : ''}',
              warna: Pal.kelas(i),
              dipilih: _efektif(_pilih) == g.kelas[i].kode,
              onTap: () => setState(() {
                _label[_pilih] = g.kelas[i].kode == _labelSet
                    ? null
                    : g.kelas[i].kode;
                _berubah = true;
              }),
            ),
          _PilihLabel(
            teks: 'Buang · salah peraga atau terpotong',
            warna: Pal.samar,
            dipilih: _efektif(_pilih) == _buang,
            onTap: () => setState(() {
              _label[_pilih] = _buang;
              _berubah = true;
            }),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _berubah ? _simpan : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            child: Text(_berubah ? 'SIMPAN LABEL' : 'TERSIMPAN'),
          ),
        ],
      ],
    );
  }
}

class _ChipRep extends StatelessWidget {
  const _ChipRep({
    required this.nomor,
    required this.warna,
    required this.dibuang,
    required this.diubah,
    required this.dipilih,
    required this.onTap,
  });

  final int nomor;
  final Color warna;
  final bool dibuang;
  final bool diubah;
  final bool dipilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: dipilih ? warna.withValues(alpha: 0.18) : Pal.lapis,
          border: Border.all(
            color: dipilih ? warna : Pal.garis,
            width: dipilih ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(width: 3, color: warna),
            ),
            Center(
              child: Text(
                nomor.toString().padLeft(2, '0'),
                style: Huruf.angka(20, warna: dibuang ? Pal.samar : Pal.kapur)
                    .copyWith(
                      decoration: dibuang ? TextDecoration.lineThrough : null,
                    ),
              ),
            ),
            if (diubah)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Pal.sinyal,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PilihLabel extends StatelessWidget {
  const _PilihLabel({
    required this.teks,
    required this.warna,
    required this.dipilih,
    required this.onTap,
  });

  final String teks;
  final Color warna;
  final bool dipilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Panel(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        garis: dipilih ? warna : Pal.garis,
        warna: dipilih ? warna.withValues(alpha: 0.1) : Pal.lapis,
        child: Row(
          children: [
            Container(width: 10, height: 10, color: warna),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                teks.toUpperCase(),
                style: Huruf.judul(18, warna: dipilih ? Pal.kapur : Pal.redup),
              ),
            ),
            if (dipilih) Icon(Icons.check, size: 18, color: warna),
          ],
        ),
      ),
    );
  }
}
