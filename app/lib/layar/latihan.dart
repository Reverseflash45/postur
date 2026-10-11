import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/pengaturan.dart';
import '../data/rekaman.dart';
import '../data/riwayat.dart';
import '../data/suara.dart';
import '../inti/gerakan.dart';
import '../inti/klasifikasi/klasifikasi.dart';
import '../inti/mesin_latihan.dart';
import '../inti/paket_model.dart';
import '../sumber/sumber_kamera.dart';
import '../sumber/sumber_pose.dart';
import '../sumber/sumber_rekaman.dart';
import '../tema.dart';
import '../widget/kerangka.dart';
import '../widget/pengukur.dart';
import 'ringkasan.dart';

enum ModeLatihan { latihan, demo, rekam }

/// Hasil mode rekam yang dikembalikan lewat Navigator.pop.
typedef HasilRekam = ({String path, int repetisi});

enum _Fase { posisi, hitungMundur, aktif, istirahat }

/// Layar kamera: cek posisi, hitung mundur, set latihan, dan istirahat.
///
/// Dipakai untuk tiga keperluan: latihan biasa, demo tanpa kamera (rekaman
/// sintetis diputar ulang), dan rekam data penelitian.
class LayarLatihan extends StatefulWidget {
  const LayarLatihan({
    super.key,
    required this.gerakan,
    required this.mode,
    this.subjek,
    this.kelasRekam,
    this.targetRekam,
    this.catatan = '',
  });

  final Gerakan gerakan;
  final ModeLatihan mode;

  /// Diisi di mode rekam.
  final String? subjek;
  final Kelas? kelasRekam;

  /// Mode rekam terpandu: rekaman berhenti sendiri setelah sekian repetisi.
  final int? targetRekam;
  final String catatan;

  @override
  State<LayarLatihan> createState() => _LayarLatihanState();
}

class _LayarLatihanState extends State<LayarLatihan> {
  SumberPose? _sumber;
  MesinLatihan? _mesin;
  Pengklasifikasi? _klas;
  final List<Pengklasifikasi> _pembanding = [];
  StreamSubscription? _langganan;
  String? _galat;
  final _jam = Stopwatch();
  DateTime? _mulai;

  _Fase _fase = _Fase.posisi;
  int _set = 1;
  int _mundur = 3;
  double? _siapSejak;
  Timer? _pewaktu;
  double _sisaIstirahat = 0;
  bool _selesai = false;

  /// Waktu (ms, jam frame) repetisi terakhir selesai — untuk kilatan warna.
  double _tRepetisi = -1e9;

  Gerakan get g => widget.gerakan;
  bool get _rekam => widget.mode == ModeLatihan.rekam;
  int get _target => Pengaturan.instance.target;
  int get _jumlahSet => _rekam ? 1 : Pengaturan.instance.jumlahSet;

  @override
  void initState() {
    super.initState();
    _siapkan();
  }

  Future<void> _siapkan() async {
    try {
      if (!_rekam) {
        final paket = await PaketModel.muat(g);
        var id = Pengaturan.instance.model(g.id) ?? paket.terbaik;
        if (!paket.tersedia.contains(id)) id = paket.terbaik;
        _klas = await paket.buat(id);
        if (Pengaturan.instance.bandingkan) {
          for (final lain in paket.tersedia) {
            if (lain != id) _pembanding.add(await paket.buat(lain));
          }
        }
      }
      final SumberPose sumber = widget.mode == ModeLatihan.demo
          ? await SumberRekaman.dariAset('assets/demo/${g.id}.json')
          : SumberKamera(depan: Pengaturan.instance.kameraDepan);
      final mesin =
          MesinLatihan(
              gerakan: g,
              klasifikasi: _klas,
              rekamSemua: _rekam,
              aktif: false,
              pembanding: _pembanding,
            )
            ..diRepetisi = _diRepetisi
            ..addListener(_periksaFase);
      _langganan = sumber.aliran.listen(mesin.masukkan);
      await sumber.mulai();
      if (!mounted) {
        await sumber.dispose();
        return;
      }
      _mulai = DateTime.now();
      _jam.start();
      try {
        await WakelockPlus.enable();
      } catch (_) {}
      setState(() {
        _sumber = sumber;
        _mesin = mesin;
      });
    } catch (e) {
      if (mounted) setState(() => _galat = '$e');
    }
  }

  // ------------------------------------------------------------------ fase

  void _periksaFase() {
    final m = _mesin;
    if (m == null || _fase != _Fase.posisi) return;
    final siap = m.kesiapan == Kesiapan.siap && m.jarakPas && m.diam;
    if (!siap) {
      _siapSejak = null;
    } else if (_siapSejak == null) {
      _siapSejak = m.waktu;
    } else if (m.waktu - _siapSejak! >= 900) {
      _mulaiHitungMundur();
    }
  }

  void _mulaiHitungMundur() {
    if (_fase == _Fase.hitungMundur) return;
    _pewaktu?.cancel();
    setState(() {
      _fase = _Fase.hitungMundur;
      _mundur = 3;
    });
    _ucap(angkaKeKata(3));
    HapticFeedback.selectionClick();
    _pewaktu = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_mundur > 1) {
        setState(() => _mundur--);
        _ucap(angkaKeKata(_mundur));
        HapticFeedback.selectionClick();
      } else {
        t.cancel();
        setState(() => _fase = _Fase.aktif);
        _mesin?.mulaiHitung(set: _set);
        _ucap(_rekam ? 'Rekam' : 'Mulai');
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _mulaiIstirahat() {
    _mesin?.jeda();
    _pewaktu?.cancel();
    final total = Pengaturan.instance.istirahat.toDouble();
    setState(() {
      _fase = _Fase.istirahat;
      _sisaIstirahat = total;
    });
    _ucap('Set ${angkaKeKata(_set)} selesai. Istirahat.');
    _pewaktu = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) return;
      setState(() => _sisaIstirahat -= 0.1);
      if ((_sisaIstirahat - 3).abs() < 0.05) _ucap('Bersiap');
      if (_sisaIstirahat <= 0) {
        t.cancel();
        _lanjutSet();
      }
    });
  }

  void _lanjutSet() {
    _pewaktu?.cancel();
    setState(() {
      _set++;
      _fase = _Fase.posisi;
      _siapSejak = null;
    });
  }

  void _diRepetisi(HasilRepetisi h) {
    _tRepetisi = _mesin?.waktu ?? 0;
    HapticFeedback.mediumImpact();
    final angka = angkaKeKata(_rekam ? h.nomor : _mesin!.jumlahSetIni);
    if (h.kelas <= 0) {
      _ucap(angka);
    } else {
      _ucap('$angka. ${g.kelas[h.kelas].ucapan}');
    }
    if (_rekam) {
      final t = widget.targetRekam;
      if (t != null && h.nomor >= t) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted || _selesai) return;
          _ucap('Selesai');
          _akhiri();
        });
      }
      return;
    }
    if (_mesin!.jumlahSetIni >= _target) {
      if (_set < _jumlahSet) {
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted && _fase == _Fase.aktif) _mulaiIstirahat();
        });
      } else {
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) _akhiri();
        });
      }
    }
  }

  void _ucap(String teks) {
    if (Pengaturan.instance.suara) Suara.instance.ucapkan(teks);
  }

  // ---------------------------------------------------------------- selesai

  Future<void> _akhiri() async {
    if (_selesai) return;
    final mesin = _mesin, sumber = _sumber;
    if (mesin == null || sumber == null) {
      Navigator.of(context).pop();
      return;
    }
    _selesai = true;
    _pewaktu?.cancel();
    await sumber.berhenti();
    _jam.stop();
    final msPose = sumber.msPose, fps = sumber.fps;
    if (msPose != null && fps != null) {
      await Pengaturan.instance.simpanStatistikPose(msPose, fps);
    }
    if (!mounted) return;

    if (_rekam) {
      await _simpanRekaman(mesin, sumber);
      return;
    }
    if (mesin.hasil.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final c = CatatanLatihan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      gerakan: g.id,
      model: _klas?.id ?? '-',
      mulai: _mulai ?? DateTime.now(),
      detik: _jam.elapsed.inSeconds,
      target: _target,
      jumlahSet: _set,
      demo: widget.mode == ModeLatihan.demo,
      msPose: msPose,
      fps: fps,
      repetisi: List.of(mesin.hasil),
    );
    await Riwayat.simpan(c);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LayarRingkasan(catatan: c, baru: true)),
    );
  }

  Future<void> _simpanRekaman(MesinLatihan mesin, SumberPose sumber) async {
    final kontrol = TextEditingController(text: '${mesin.jumlah}');
    final jumlah = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('SIMPAN REKAMAN?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Label(
              '${widget.subjek} · ${widget.kelasRekam!.kode} ${widget.kelasRekam!.nama}',
              warna: Pal.kapur,
            ),
            const SizedBox(height: 10),
            Text(
              'Terhitung otomatis ${mesin.jumlah} repetisi dari ${mesin.semuaFrame.length} frame. '
              'Isi jumlah sebenarnya (hitungan manual) untuk evaluasi penghitung repetisi.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: kontrol,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: Huruf.angka(32),
              decoration: const InputDecoration(
                labelText: 'REPETISI SEBENARNYA',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, -1),
            child: const Text('BUANG'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(kontrol.text) ?? mesin.jumlah),
            child: const Text('SIMPAN'),
          ),
        ],
      ),
    );
    HasilRekam? hasil;
    if (jumlah != null && jumlah >= 0) {
      final path = await Rekaman.simpan(
        subjek: widget.subjek!,
        gerakan: g.id,
        label: widget.kelasRekam!.kode,
        repetisiManual: jumlah,
        repetisiOtomatis: mesin.jumlah,
        frame: mesin.semuaFrame,
        sumberPose: sumber.nama,
        kamera: Pengaturan.instance.kameraDepan ? 'depan' : 'belakang',
        catatan: widget.catatan,
      );
      hasil = (path: path, repetisi: jumlah);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rekaman ${widget.kelasRekam!.kode} disimpan · $jumlah repetisi',
            ),
          ),
        );
      }
    }
    if (mounted) Navigator.of(context).pop(hasil);
  }

  @override
  void dispose() {
    _pewaktu?.cancel();
    _langganan?.cancel();
    _sumber?.dispose();
    _mesin?.dispose();
    Suara.instance.diam();
    try {
      WakelockPlus.disable();
    } catch (_) {}
    super.dispose();
  }

  // ------------------------------------------------------------------ tampil

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: _mesin == null || _selesai,
        onPopInvokedWithResult: (sudah, _) {
          if (!sudah) _akhiri();
        },
        child: Scaffold(
          backgroundColor: Pal.latar,
          body: _galat != null
              ? _Galat(pesan: _galat!)
              : _mesin == null
              ? const Center(child: CircularProgressIndicator())
              : ListenableBuilder(
                  listenable: _mesin!,
                  builder: (context, _) => _isi(context, _mesin!),
                ),
        ),
      ),
    );
  }

  Widget _isi(BuildContext context, MesinLatihan m) {
    final f = m.terakhir;
    final terakhir = m.hasil.isEmpty ? null : m.hasil.last;
    final baru = terakhir != null && m.waktu - _tRepetisi < 1600;
    final sumber = _sumber!;
    final pratinjau = sumber.pratinjau();
    final mq = MediaQuery.of(context);
    final mendatar = mq.orientation == Orientation.landscape;
    final cukupDalam =
        m.sudut != null && m.sudut! <= g.targetSudut && _fase == _Fase.aktif;

    final kelasBaru = baru && terakhir.kelas > 0 ? terakhir.kelas : 0;
    final warnaTulang = (baru && terakhir.kelas == 0) || cukupDalam
        ? Pal.benar
        : Pal.kapur.withValues(alpha: 0.92);
    final adegan = f == null
        ? (pratinjau == null
              ? const SizedBox.expand()
              : Center(child: pratinjau))
        : FittedBox(
            fit: pratinjau == null ? BoxFit.contain : BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: f.lebar,
              height: f.tinggi,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ?pratinjau,
                  CustomPaint(
                    painter: KerangkaPainter(
                      f,
                      warna: warnaTulang,
                      cermin: sumber.cermin,
                      sendiUtama: [for (final s in g.sendiUtama) s[1]],
                      sorot: kelasBaru > 0
                          ? g.kelas[kelasBaru].bagian
                          : const [],
                      warnaSorot: Pal.kelas(kelasBaru),
                    ),
                  ),
                ],
              ),
            ),
          );

    final ruangBawah = pratinjau == null && !mendatar ? 250.0 : 0.0;
    final atasPita = mq.padding.top + 74;

    return Stack(
      children: [
        if (pratinjau == null) const Positioned.fill(child: _LantaiDemo()),
        Positioned.fill(
          top: pratinjau == null ? mq.padding.top + 70 : 0,
          bottom: ruangBawah,
          // Di demo, sisakan ruang untuk pengukur sudut di kanan.
          right: pratinjau == null ? (mendatar ? 330 : 96) : 0,
          child: adegan,
        ),
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 150,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            bottom: false,
            child: _BarAtas(
              gerakan: g,
              mode: widget.mode,
              keterangan: _rekam
                  ? '${widget.subjek} · ${widget.kelasRekam!.kode} ${widget.kelasRekam!.nama}'
                  : 'Set $_set/$_jumlahSet · ${namaModel[_klas?.id] ?? '-'}',
              onTutup: _akhiri,
            ),
          ),
        ),
        if (sumber.galat != null)
          Positioned(
            left: 16,
            right: mendatar ? 450 : 16,
            top: atasPita,
            child: _Pita(
              teks: 'Deteksi pose gagal',
              sub: sumber.galat!,
              warna: Pal.salah,
            ),
          )
        else if (_fase == _Fase.aktif && baru && terakhir.kelas > 0)
          Positioned(
            left: 16,
            right: mendatar ? 450 : 16,
            top: atasPita,
            child: _Pita(
              teks: g.kelas[terakhir.kelas].nama,
              sub: g.kelas[terakhir.kelas].ucapan,
              warna: Pal.kelas(terakhir.kelas),
            ),
          )
        else if (_fase == _Fase.aktif && m.kesiapan != Kesiapan.siap)
          Positioned(
            left: 16,
            right: mendatar ? 450 : 16,
            top: atasPita,
            child: _Pita(
              teks: m.kesiapan.pesan,
              sub: g.posisiKamera,
              warna: Pal.sinyal,
            ),
          ),
        if (Pengaturan.instance.infoTeknis)
          Positioned(
            left: 16,
            top: mq.padding.top + 150,
            child: _InfoTeknis(sumber: sumber, mesin: m),
          ),
        if (_fase == _Fase.aktif || _fase == _Fase.posisi)
          Positioned(
            right: mendatar ? 346 : 12,
            top: mendatar ? mq.padding.top + 70 : mq.size.height * 0.2,
            // Latar gelap supaya skala tetap terbaca di atas gambar kamera yang terang.
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
              decoration: BoxDecoration(
                color: const Color(0xB30C0E0F),
                border: Border.all(color: Colors.white12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: PengukurSudut(
                sudut: m.sudut,
                target: g.targetSudut,
                label: g.namaSudut.toUpperCase(),
                tinggi: mendatar ? mq.size.height * 0.4 : mq.size.height * 0.24,
              ),
            ),
          ),
        if (_fase == _Fase.hitungMundur)
          Positioned.fill(child: _HitungMundur(angka: _mundur)),
        if (_fase == _Fase.istirahat)
          Positioned.fill(
            child: _Istirahat(
              sisa: _sisaIstirahat,
              total: Pengaturan.instance.istirahat.toDouble(),
              setBerikut: _set + 1,
              jumlahSet: _jumlahSet,
              mesin: m,
              setSelesai: _set,
              onLewati: _lanjutSet,
              onAkhiri: _akhiri,
            ),
          ),
        if (_fase == _Fase.posisi || _fase == _Fase.aktif)
          Positioned(
            left: mendatar ? null : 0,
            right: 0,
            bottom: 0,
            top: mendatar ? 0 : null,
            width: mendatar ? 330 : null,
            child: SafeArea(
              top: mendatar,
              left: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _fase == _Fase.posisi
                    ? _PanelPosisi(
                        mesin: m,
                        gerakan: g,
                        onMulai: _mulaiHitungMundur,
                        set: _set,
                      )
                    : _PanelAktif(
                        mesin: m,
                        gerakan: g,
                        rekam: _rekam,
                        target: _target,
                        detik: _jam.elapsed.inSeconds,
                        sorot: baru,
                        onAkhiri: _akhiri,
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bagian layar
// ---------------------------------------------------------------------------

class _BarAtas extends StatelessWidget {
  const _BarAtas({
    required this.gerakan,
    required this.mode,
    required this.keterangan,
    required this.onTutup,
  });

  final Gerakan gerakan;
  final ModeLatihan mode;
  final String keterangan;
  final VoidCallback onTutup;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 14, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onTutup,
            icon: const Icon(Icons.close, color: Pal.kapur),
            tooltip: 'Akhiri',
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gerakan.nama.toUpperCase(), style: Huruf.angka(26)),
                const SizedBox(height: 2),
                Text(
                  keterangan.toUpperCase(),
                  style: Huruf.label(warna: Colors.white70, ukuran: 10.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (mode == ModeLatihan.demo) const Lencana('Demo', isi: true),
          if (mode == ModeLatihan.rekam)
            const Lencana('● Rec', warna: Pal.rekam, isi: true),
        ],
      ),
    );
  }
}

/// Pita pesan di bawah bar atas: kesalahan terakhir atau masalah posisi.
class _Pita extends StatelessWidget {
  const _Pita({required this.teks, required this.sub, required this.warna});

  final String teks;
  final String sub;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE6101315),
        border: Border.all(color: warna.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: warna),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      teks.toUpperCase(),
                      style: Huruf.judul(21, warna: warna),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: Huruf.teks(warna: Colors.white70, ukuran: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelPosisi extends StatelessWidget {
  const _PanelPosisi({
    required this.mesin,
    required this.gerakan,
    required this.onMulai,
    required this.set,
  });

  final MesinLatihan mesin;
  final Gerakan gerakan;
  final VoidCallback onMulai;
  final int set;

  @override
  Widget build(BuildContext context) {
    final terlihat = mesin.kesiapan == Kesiapan.siap;
    final p = mesin.proporsi;
    final jarak = mesin.jarakPas;
    final diam = mesin.diam;
    String ketJarak() {
      if (p == null) return 'Menunggu badan terdeteksi';
      if (p < 0.3) {
        return kIsWeb
            ? 'Terlalu jauh, mendekat ke kamera'
            : 'Terlalu jauh, majukan ponsel';
      }
      if (p > 0.95) {
        return kIsWeb
            ? 'Terlalu dekat, mundur dari kamera'
            : 'Terlalu dekat, mundurkan ponsel';
      }
      return 'Badan mengisi ${(p * 100).round()}% bingkai';
    }

    return _Kaca(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  set > 1 ? 'KEMBALI KE POSISI' : 'SIAPKAN POSISI',
                  style: Huruf.angka(30),
                ),
              ),
              if (!kIsWeb)
                Label('Ponsel ${gerakan.orientasi}', warna: Colors.white60),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            gerakan.posisiKamera,
            style: Huruf.teks(warna: Colors.white60, ukuran: 13),
          ),
          const SizedBox(height: 14),
          _Cek(
            ok: terlihat,
            judul: 'Seluruh badan terlihat',
            sub: terlihat
                ? 'Bahu sampai kaki terdeteksi'
                : mesin.kesiapan.pesan,
          ),
          _Cek(ok: jarak, judul: 'Jarak kamera pas', sub: ketJarak()),
          _Cek(
            ok: diam && terlihat,
            judul: 'Diam sejenak',
            sub: 'Mulai otomatis dengan hitung mundur',
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onMulai,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
            child: const Text('MULAI SEKARANG'),
          ),
        ],
      ),
    );
  }
}

class _Cek extends StatelessWidget {
  const _Cek({required this.ok, required this.judul, required this.sub});

  final bool ok;
  final String judul;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: ok ? Pal.benar : Colors.transparent,
              border: Border.all(
                color: ok ? Pal.benar : Colors.white38,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
            child: ok
                ? const Icon(Icons.check, size: 16, color: Pal.latar)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  style: Huruf.teks(
                    tebal: FontWeight.w600,
                    warna: ok ? Pal.kapur : Colors.white70,
                  ),
                ),
                Text(
                  sub,
                  style: Huruf.teks(ukuran: 12.5, warna: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelAktif extends StatelessWidget {
  const _PanelAktif({
    required this.mesin,
    required this.gerakan,
    required this.rekam,
    required this.target,
    required this.detik,
    required this.sorot,
    required this.onAkhiri,
  });

  final MesinLatihan mesin;
  final Gerakan gerakan;
  final bool rekam;
  final int target;
  final int detik;
  final bool sorot;
  final VoidCallback onAkhiri;

  @override
  Widget build(BuildContext context) {
    final setIni = mesin.hasil.where((h) => h.set == mesin.set).toList();
    final terakhir = setIni.isEmpty ? null : setIni.last;
    final waktu =
        '${(detik ~/ 60).toString().padLeft(2, '0')}:${(detik % 60).toString().padLeft(2, '0')}';
    return _Kaca(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                (rekam ? mesin.jumlah : setIni.length).toString().padLeft(
                  2,
                  '0',
                ),
                style: Huruf.angka(92),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rekam ? 'REP' : '/ $target',
                      style: Huruf.angka(26, warna: Colors.white54),
                    ),
                    const SizedBox(height: 4),
                    Text(waktu, style: Huruf.label(warna: Colors.white54)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Expanded: nama kelas yang panjang turun baris, tidak menimpa waktu.
              if (!rekam)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _SkorTerakhir(
                      h: terakhir,
                      gerakan: gerakan,
                      sorot: sorot,
                    ),
                  ),
                )
              else ...[
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Label('Frame', warna: Colors.white54),
                      Text(
                        '${mesin.semuaFrame.length}',
                        style: Huruf.angka(30),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (!rekam) ...[
            const SizedBox(height: 14),
            _Slot(setIni: setIni, target: target),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Jangan putar ponsel selama merekam.',
              style: Huruf.teks(warna: Colors.white54, ukuran: 12.5),
            ),
          ],
          const SizedBox(height: 14),
          rekam
              ? FilledButton(
                  onPressed: onAkhiri,
                  style: FilledButton.styleFrom(
                    backgroundColor: Pal.rekam,
                    foregroundColor: Pal.kapur,
                  ),
                  child: const Text('BERHENTI & SIMPAN'),
                )
              : OutlinedButton(
                  onPressed: onAkhiri,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text('AKHIRI LATIHAN'),
                ),
        ],
      ),
    );
  }
}

class _SkorTerakhir extends StatelessWidget {
  const _SkorTerakhir({
    required this.h,
    required this.gerakan,
    required this.sorot,
  });

  final HasilRepetisi? h;
  final Gerakan gerakan;
  final bool sorot;

  @override
  Widget build(BuildContext context) {
    final h = this.h;
    if (h == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Label('Skor form', warna: Colors.white54),
          Text('—', style: Huruf.angka(44, warna: Colors.white38)),
        ],
      );
    }
    final warna = Pal.kelas(h.kelas);
    return AnimatedScale(
      scale: sorot ? 1.08 : 1,
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.bottomRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Label('Skor rep ${h.nomor}', warna: Colors.white54),
          Text('${h.skor}', style: Huruf.angka(44, warna: warna)),
          Text(
            gerakan.kelas[h.kelas].nama.toUpperCase(),
            style: Huruf.label(warna: warna, ukuran: 10),
            textAlign: TextAlign.end,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

/// Satu kotak per repetisi target; terisi warna penilaian.
class _Slot extends StatelessWidget {
  const _Slot({required this.setIni, required this.target});

  final List<HasilRepetisi> setIni;
  final int target;

  @override
  Widget build(BuildContext context) {
    final n = setIni.length > target ? setIni.length : target;
    return SizedBox(
      height: 10,
      child: Row(
        children: [
          for (var i = 0; i < n; i++)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                color: i < setIni.length
                    ? Pal.kelas(setIni[i].kelas)
                    : Colors.white12,
              ),
            ),
        ],
      ),
    );
  }
}

class _HitungMundur extends StatelessWidget {
  const _HitungMundur({required this.angka});

  final int angka;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0x99000000),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Label('Bersiap', warna: Pal.sinyal, ukuran: 13),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (c, a) => ScaleTransition(
                scale: Tween(begin: 1.4, end: 1.0).animate(a),
                child: FadeTransition(opacity: a, child: c),
              ),
              child: Text(
                '$angka',
                key: ValueKey(angka),
                style: Huruf.angka(220, warna: Pal.sinyal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Istirahat extends StatelessWidget {
  const _Istirahat({
    required this.sisa,
    required this.total,
    required this.setBerikut,
    required this.jumlahSet,
    required this.mesin,
    required this.setSelesai,
    required this.onLewati,
    required this.onAkhiri,
  });

  final double sisa;
  final double total;
  final int setBerikut;
  final int jumlahSet;
  final MesinLatihan mesin;
  final int setSelesai;
  final VoidCallback onLewati;
  final VoidCallback onAkhiri;

  @override
  Widget build(BuildContext context) {
    final r = mesin.hasil.where((h) => h.set == setSelesai).toList();
    final benar = r.where((h) => h.benar).length;
    final skor = r.isEmpty
        ? 0
        : (r.fold(0, (a, h) => a + h.skor) / r.length).round();
    return ColoredBox(
      color: const Color(0xF20C0E0F),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
          child: Column(
            children: [
              Label(
                'Set $setSelesai dari $jumlahSet selesai',
                warna: Pal.sinyal,
                ukuran: 12,
              ),
              const SizedBox(height: 6),
              Text('ISTIRAHAT', style: Huruf.angka(54)),
              const Spacer(),
              CincinWaktu(sisa: sisa, total: total),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Bacaan(label: 'Repetisi', nilai: '${r.length}'),
                  ),
                  Expanded(
                    child: Bacaan(
                      label: 'Benar',
                      nilai: '$benar',
                      warna: Pal.benar,
                    ),
                  ),
                  Expanded(
                    child: Bacaan(
                      label: 'Skor form',
                      nilai: '$skor',
                      warna: Pal.sinyal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onLewati,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                child: Text('LANJUT KE SET $setBerikut'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onAkhiri,
                child: const Text('AKHIRI LATIHAN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Panel bawah gelap tembus pandang.
class _Kaca extends StatelessWidget {
  const _Kaca({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xEB0E1112),
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

class _InfoTeknis extends StatelessWidget {
  const _InfoTeknis({required this.sumber, required this.mesin});

  final SumberPose sumber;
  final MesinLatihan mesin;

  @override
  Widget build(BuildContext context) {
    final h = mesin.hasil.isEmpty ? null : mesin.hasil.last;
    String ms(double? v) => v == null ? '–' : v.toStringAsFixed(1);
    final p = mesin.proporsi;
    final baris = [
      'POSE ${ms(sumber.msPose)}MS · ${ms(sumber.fps)}FPS',
      'FITUR ${ms(h?.msFitur)}MS · KLAS ${ms(h?.msKlasifikasi)}MS',
      'PROPORSI ${p == null ? '–' : (p * 100).round()}% · DIAM ${mesin.diam ? 'Y' : 'T'}',
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.black54,
      child: Text(
        baris.join('\n'),
        style: Huruf.label(warna: Colors.white, ukuran: 10),
      ),
    );
  }
}

/// Latar mode demo: grid tipis seperti lantai studio pengukuran.
class _LantaiDemo extends StatelessWidget {
  const _LantaiDemo();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _LukisLantai());
}

class _LukisLantai extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0F1213),
    );
    final garis = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    final langkah = size.shortestSide / 12;
    for (var x = 0.0; x <= size.width; x += langkah) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), garis);
    }
    for (var y = 0.0; y <= size.height; y += langkah) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), garis);
    }
  }

  @override
  bool shouldRepaint(_LukisLantai old) => false;
}

class _Galat extends StatelessWidget {
  const _Galat({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Label('Kamera', warna: Pal.salah),
            const SizedBox(height: 8),
            Text(
              kameraTersedia
                  ? 'KAMERA TIDAK BISA DIBUKA'
                  : 'KAMERA TIDAK TERSEDIA',
              style: Huruf.angka(40),
            ),
            const SizedBox(height: 12),
            Text(
              kameraTersedia
                  ? 'Pastikan izin kamera diberikan, lalu coba lagi.\n\n$pesan'
                  : 'Di browser, coba mode demo untuk melihat cara kerjanya.',
              style: Huruf.teks(warna: Pal.redup),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('KEMBALI'),
            ),
          ],
        ),
      ),
    );
  }
}
