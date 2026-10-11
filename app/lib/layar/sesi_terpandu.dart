import 'dart:async';

import 'package:flutter/material.dart';

import '../data/pengaturan.dart';
import '../data/rekaman.dart';
import '../data/subjek.dart';
import '../data/suara.dart';
import '../inti/gerakan.dart';
import '../inti/protokol.dart';
import '../sumber/sumber_kamera.dart';
import '../tema.dart';
import '../widget/gerak.dart';
import 'latihan.dart';
import 'tinjau.dart';

/// Lama istirahat yang disarankan antar-set di sesi terpandu (detik).
const istirahatTerpandu = 60;

/// Memandu satu subjek melewati seluruh set sesuai rencana: instruksi,
/// perekaman yang berhenti otomatis, istirahat, lalu set berikutnya.
class LayarSesiTerpandu extends StatefulWidget {
  const LayarSesiTerpandu({super.key, required this.subjek});

  final String subjek;

  @override
  State<LayarSesiTerpandu> createState() => _LayarSesiTerpanduState();
}

class _LayarSesiTerpanduState extends State<LayarSesiTerpandu> {
  RencanaSesi? _r;
  ProfilSubjek? _profil;
  int? _dipilih;
  Timer? _pewaktu;
  int _sisaIstirahat = 0;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    final r = await DataSubjek.bacaSesi(widget.subjek);
    final p = await DataSubjek.baca(widget.subjek);
    if (!mounted) return;
    setState(() {
      _r = r;
      _profil = p;
      _dipilih = r?.berikutnya;
    });
    _bacakan();
  }

  @override
  void dispose() {
    _pewaktu?.cancel();
    Suara.instance.diam();
    super.dispose();
  }

  LangkahRekam? get _langkah => _dipilih == null ? null : _r!.langkah[_dipilih!];

  Future<void> _simpan() async => DataSubjek.simpanSesi(_r!);

  void _bacakan() {
    final l = _langkah;
    if (l == null || !Pengaturan.instance.suara) return;
    final g = gerakanDari(l.gerakan);
    final k = g.kelasDari(l.kelas);
    Suara.instance.ucapkan(
      'Set ${angkaKeKata(_dipilih! + 1)}. ${g.nama}, ${k.nama}. '
      '${caraPeragaan[l.kelas] ?? k.arahan} '
      '${angkaKeKata(l.target)} repetisi.',
    );
  }

  /// Gerakan berganti dari langkah sebelumnya: posisi ponsel perlu diatur ulang.
  bool _gantiPosisi(int i) =>
      i == 0 || _r!.langkah[i - 1].gerakan != _r!.langkah[i].gerakan;

  Future<void> _rekam() async {
    final l = _langkah!;
    final g = gerakanDari(l.gerakan);
    _hentikanIstirahat();
    Suara.instance.diam();
    final hasil = await Navigator.of(context).push<HasilRekam>(
      MaterialPageRoute(
        builder: (_) => LayarLatihan(
          gerakan: g,
          mode: ModeLatihan.rekam,
          subjek: widget.subjek,
          kelasRekam: g.kelasDari(l.kelas),
          targetRekam: l.target,
          catatan: 'terpandu ${_dipilih! + 1}/${_r!.langkah.length}',
        ),
      ),
    );
    if (hasil == null || !mounted) return;
    // Rekam ulang menggantikan rekaman lama langkah ini.
    final lama = l.path;
    l
      ..path = hasil.path
      ..repetisi = hasil.repetisi
      ..dilewati = false;
    await _simpan();
    if (lama != null && lama != hasil.path) await Rekaman.hapus(lama);
    if (!mounted) return;
    final lanjut = _r!.berikutnya;
    setState(() => _dipilih = lanjut);
    if (lanjut != null) {
      _mulaiIstirahat();
    } else if (Pengaturan.instance.suara) {
      Suara.instance.ucapkan('Semua set selesai. Terima kasih.');
    }
  }

  void _mulaiIstirahat() {
    _pewaktu?.cancel();
    setState(() => _sisaIstirahat = istirahatTerpandu);
    if (Pengaturan.instance.suara) {
      Suara.instance.ucapkan('Istirahat ${angkaKeKata(istirahatTerpandu)} detik.');
    }
    _pewaktu = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _sisaIstirahat--);
      if (_sisaIstirahat <= 0) {
        t.cancel();
        _bacakan();
      }
    });
  }

  void _hentikanIstirahat() {
    _pewaktu?.cancel();
    if (_sisaIstirahat > 0) setState(() => _sisaIstirahat = 0);
  }

  Future<void> _lewati() async {
    _hentikanIstirahat();
    _langkah!.dilewati = true;
    await _simpan();
    setState(() => _dipilih = _r!.berikutnya);
    _bacakan();
  }

  Future<void> _aksiLangkah(int i) async {
    final l = _r!.langkah[i];
    if (!l.tuntas) {
      _hentikanIstirahat();
      setState(() => _dipilih = i);
      _bacakan();
      return;
    }
    final pilihan = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('${l.kelas} · ${gerakanDari(l.gerakan).kelasDari(l.kelas).nama}'.toUpperCase(), style: Huruf.judul(20)),
              subtitle: Text(l.selesai ? '${l.repetisi ?? '?'} repetisi tersimpan' : 'Dilewati'),
            ),
            if (l.selesai)
              ListTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: const Text('Tinjau dan beri label per repetisi'),
                onTap: () => Navigator.pop(ctx, 'tinjau'),
              ),
            ListTile(
              leading: const Icon(Icons.fiber_manual_record, color: Pal.rekam),
              title: Text(l.selesai ? 'Rekam ulang (rekaman lama dihapus)' : 'Rekam sekarang'),
              onTap: () => Navigator.pop(ctx, 'ulang'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || pilihan == null) return;
    if (pilihan == 'tinjau') {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LayarTinjau(path: l.path!)));
    } else {
      _hentikanIstirahat();
      setState(() => _dipilih = i);
      await _rekam();
    }
  }

  Future<void> _mundur() async {
    final ya = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('SUBJEK MENGUNDURKAN DIRI?'),
        content: Text(
          'Profil, rencana, dan semua rekaman ${widget.subjek} akan dihapus dari ponsel ini. Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('BATAL')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Pal.salah),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('HAPUS SEMUA'),
          ),
        ],
      ),
    );
    if (ya != true) return;
    final n = await DataSubjek.hapusSemua(widget.subjek);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data ${widget.subjek} dihapus · $n rekaman')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: r == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.fromLTRB(0, 0, 0, 32 + MediaQuery.paddingOf(context).bottom),
                children: [
                  KepalaLayar(
                    kembali: true,
                    atas: 'Sesi terpandu',
                    judul: widget.subjek,
                    aksi: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Pal.kapur),
                      onSelected: (_) => _mundur(),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'mundur', child: Text('Subjek mengundurkan diri')),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        _Ringkas(rencana: r, profil: _profil),
                        const SizedBox(height: 12),
                        _BatangKemajuan(rencana: r, dipilih: _dipilih),
                        const SizedBox(height: 16),
                        if (_sisaIstirahat > 0) ...[
                          _Istirahat(sisa: _sisaIstirahat, onLewati: () {
                            _hentikanIstirahat();
                            _bacakan();
                          }),
                          const SizedBox(height: 12),
                        ],
                        if (_dipilih != null)
                          _KartuLangkah(
                            langkah: _langkah!,
                            nomor: _dipilih! + 1,
                            jumlah: r.langkah.length,
                            gantiPosisi: _gantiPosisi(_dipilih!),
                            onRekam: bisaRekamData ? _rekam : null,
                            onBacakan: _bacakan,
                            onLewati: _langkah!.tuntas ? null : _lewati,
                          )
                        else
                          _Selesai(
                            rencana: r,
                            // true = pemanggil langsung membuka pendaftaran subjek baru.
                            onSubjekBaru: () => Navigator.of(context).pop(true),
                          ),
                        if (!bisaRekamData)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Perekaman data penelitian hanya di aplikasi Android, supaya pose estimator-nya sama dengan saat aplikasi dipakai.',
                              textAlign: TextAlign.center,
                              style: Huruf.teks(warna: Pal.salah, ukuran: 13),
                            ),
                          ),
                        JudulBagian('Urutan set · ${r.jumlahTuntas}/${r.langkah.length}'),
                        for (var i = 0; i < r.langkah.length; i++)
                          _BarisLangkah(
                            langkah: r.langkah[i],
                            nomor: i + 1,
                            aktif: i == _dipilih,
                            onTap: () => _aksiLangkah(i),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          'Urutan kelas mengikuti baris ${r.barisUrutan % 4 + 1} bujur sangkar latin Williams. Ketuk set yang sudah direkam untuk meninjau atau merekam ulang.',
                          style: Huruf.teks(warna: Pal.samar, ukuran: 12.5),
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

class _Ringkas extends StatelessWidget {
  const _Ringkas({required this.rencana, required this.profil});

  final RencanaSesi rencana;
  final ProfilSubjek? profil;

  @override
  Widget build(BuildContext context) {
    final rep = rencana.langkah.fold(0, (a, l) => a + (l.repetisi ?? 0));
    final p = profil;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: Pal.garis))),
      child: Row(
        children: [
          Expanded(child: Bacaan(label: 'Set', nilai: '${rencana.jumlahSelesai}', satuan: '/${rencana.langkah.length}')),
          Expanded(child: Bacaan(label: 'Repetisi', nilai: '$rep', warna: Pal.sinyal)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Label('Profil'),
                const SizedBox(height: 4),
                Text(
                  p == null ? '—' : '${p.jenisKelamin} · ${p.usia}\n${ProfilSubjek.tingkatPengalaman[p.pengalaman]}',
                  style: Huruf.teks(ukuran: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BatangKemajuan extends StatelessWidget {
  const _BatangKemajuan({required this.rencana, required this.dipilih});

  final RencanaSesi rencana;
  final int? dipilih;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < rencana.langkah.length; i++) ...[
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: rencana.langkah[i].selesai
                    ? Pal.kelas(int.parse(rencana.langkah[i].kelas.split('-').last))
                    : Pal.lapis2,
                border: i == dipilih ? Border.all(color: Pal.sinyal, width: 2) : null,
              ),
            ),
          ),
          if (i < rencana.langkah.length - 1) SizedBox(width: _gantiGerakan(i) ? 10 : 3),
        ],
      ],
    );
  }

  bool _gantiGerakan(int i) => rencana.langkah[i].gerakan != rencana.langkah[i + 1].gerakan;
}

class _KartuLangkah extends StatelessWidget {
  const _KartuLangkah({
    required this.langkah,
    required this.nomor,
    required this.jumlah,
    required this.gantiPosisi,
    required this.onRekam,
    required this.onBacakan,
    required this.onLewati,
  });

  final LangkahRekam langkah;
  final int nomor;
  final int jumlah;
  final bool gantiPosisi;
  final VoidCallback? onRekam;
  final VoidCallback onBacakan;
  final VoidCallback? onLewati;

  @override
  Widget build(BuildContext context) {
    final g = gerakanDari(langkah.gerakan);
    final k = g.kelasDari(langkah.kelas);
    final warna = Pal.kelas(g.indeks(k.kode));
    return Panel(
      padding: EdgeInsets.zero,
      garis: warna,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 5, color: warna),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Label('Set $nomor/$jumlah · ${g.nama}', warna: Pal.sinyal),
                    const Spacer(),
                    Lencana(k.kode, warna: warna),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k.nama.toUpperCase(), style: Huruf.angka(36)),
                          const SizedBox(height: 6),
                          Text(caraPeragaan[k.kode] ?? k.arahan, style: Huruf.teks(ukuran: 15)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(width: 84, height: 96, child: GerakAnimasi(g, key: ValueKey(g.id))),
                  ],
                ),
                if (gantiPosisi) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Pal.sinyal.withValues(alpha: 0.08),
                      border: Border.all(color: Pal.sinyal.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.screen_rotation_alt, color: Pal.sinyal, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Atur posisi ponsel: ${g.posisiKamera}.',
                            style: Huruf.teks(ukuran: 13.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  '${langkah.target} REPETISI · BERHENTI OTOMATIS · HITUNG MANUAL SAMBIL MENONTON',
                  style: Huruf.label(ukuran: 10),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onRekam,
                  icon: const Icon(Icons.fiber_manual_record),
                  label: Text(langkah.selesai ? 'REKAM ULANG ${k.kode}' : 'REKAM ${k.kode}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Pal.rekam,
                    foregroundColor: Pal.kapur,
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onBacakan,
                        icon: const Icon(Icons.volume_up_outlined, size: 18),
                        label: const Text('BACAKAN'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(onPressed: onLewati, child: const Text('LEWATI SET')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Istirahat extends StatelessWidget {
  const _Istirahat({required this.sisa, required this.onLewati});

  final int sisa;
  final VoidCallback onLewati;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: sisa / istirahatTerpandu,
                  strokeWidth: 4,
                  color: Pal.benar,
                  backgroundColor: Pal.garis,
                ),
                Text('$sisa', style: Huruf.angka(20)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ISTIRAHAT', style: Huruf.judul(20)),
                Text('Supaya kelelahan tidak memengaruhi set berikutnya.', style: Huruf.teks(warna: Pal.redup, ukuran: 13)),
              ],
            ),
          ),
          TextButton(onPressed: onLewati, child: const Text('LEWATI')),
        ],
      ),
    );
  }
}

class _BarisLangkah extends StatelessWidget {
  const _BarisLangkah({required this.langkah, required this.nomor, required this.aktif, required this.onTap});

  final LangkahRekam langkah;
  final int nomor;
  final bool aktif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = gerakanDari(langkah.gerakan);
    final k = g.kelasDari(langkah.kelas);
    final warna = Pal.kelas(g.indeks(k.kode));
    final String status;
    final Color warnaStatus;
    if (langkah.selesai) {
      status = '✓ ${langkah.repetisi ?? '?'} REP';
      warnaStatus = Pal.benar;
    } else if (langkah.dilewati) {
      status = 'DILEWATI';
      warnaStatus = Pal.samar;
    } else if (aktif) {
      status = 'SEKARANG';
      warnaStatus = Pal.sinyal;
    } else {
      status = 'BELUM';
      warnaStatus = Pal.samar;
    }
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Pal.garis))),
        child: Row(
          children: [
            SizedBox(width: 30, child: Text('$nomor', style: Huruf.angka(20, warna: aktif ? Pal.sinyal : Pal.samar))),
            Container(width: 3, height: 30, color: warna),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${k.kode} ${k.nama}'.toUpperCase(), style: Huruf.judul(18)),
                  Text(g.nama.toUpperCase(), style: Huruf.label(ukuran: 9.5)),
                ],
              ),
            ),
            Text(status, style: Huruf.label(warna: warnaStatus, ukuran: 10.5)),
          ],
        ),
      ),
    );
  }
}

class _Selesai extends StatelessWidget {
  const _Selesai({required this.rencana, required this.onSubjekBaru});

  final RencanaSesi rencana;
  final VoidCallback onSubjekBaru;

  @override
  Widget build(BuildContext context) {
    final rep = rencana.langkah.fold(0, (a, l) => a + (l.repetisi ?? 0));
    final lewat = rencana.langkah.where((l) => l.dilewati).length;
    return Panel(
      garis: Pal.benar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle_outline, color: Pal.benar, size: 36),
          const SizedBox(height: 8),
          Text('SESI ${rencana.subjek} SELESAI', style: Huruf.angka(32)),
          const SizedBox(height: 4),
          Text(
            '${rencana.jumlahSelesai} set · $rep repetisi${lewat > 0 ? ' · $lewat set dilewati' : ''}. '
            'Tinjau tiap set di daftar rekaman untuk membuang repetisi yang salah peraga.',
            style: Huruf.teks(warna: Pal.redup, ukuran: 14),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: onSubjekBaru, child: const Text('SUBJEK BERIKUTNYA')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('KE DAFTAR REKAMAN')),
        ],
      ),
    );
  }
}
