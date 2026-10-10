import 'dart:async';

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
import 'ringkasan.dart';

enum ModeLatihan { latihan, demo, rekam }

/// Layar kamera: kerangka, hitungan repetisi, dan penilaian tiap repetisi.
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
    this.catatan = '',
  });

  final Gerakan gerakan;
  final ModeLatihan mode;

  /// Diisi di mode rekam.
  final String? subjek;
  final Kelas? kelasRekam;
  final String catatan;

  @override
  State<LayarLatihan> createState() => _LayarLatihanState();
}

class _LayarLatihanState extends State<LayarLatihan> {
  SumberPose? _sumber;
  MesinLatihan? _mesin;
  Pengklasifikasi? _klas;
  StreamSubscription? _langganan;
  String? _galat;
  final _jam = Stopwatch();
  Timer? _detak;
  DateTime? _mulai;

  /// Waktu (ms, jam frame) repetisi terakhir selesai — untuk kilatan warna.
  double _tRepetisi = -1e9;
  bool _selesai = false;

  Gerakan get g => widget.gerakan;
  bool get _rekam => widget.mode == ModeLatihan.rekam;

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
      }
      final SumberPose sumber = widget.mode == ModeLatihan.demo
          ? await SumberRekaman.dariAset('assets/demo/${g.id}.json')
          : SumberKamera(depan: Pengaturan.instance.kameraDepan);
      final mesin = MesinLatihan(
        gerakan: g,
        klasifikasi: _klas,
        rekamSemua: _rekam,
      )..diRepetisi = _diRepetisi;
      _langganan = sumber.aliran.listen(mesin.masukkan);
      await sumber.mulai();
      if (!mounted) {
        await sumber.dispose();
        return;
      }
      _mulai = DateTime.now();
      _jam.start();
      _detak = Timer.periodic(
        const Duration(seconds: 1),
        (_) => setState(() {}),
      );
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

  void _diRepetisi(HasilRepetisi h) {
    _tRepetisi = _mesin?.waktu ?? 0;
    HapticFeedback.mediumImpact();
    if (!Pengaturan.instance.suara) return;
    final angka = angkaKeKata(h.nomor);
    if (h.kelas <= 0) {
      Suara.instance.ucapkan(angka);
    } else {
      Suara.instance.ucapkan('$angka. ${g.kelas[h.kelas].ucapan}');
    }
  }

  Future<void> _akhiri() async {
    if (_selesai) return;
    final mesin = _mesin, sumber = _sumber;
    if (mesin == null || sumber == null) {
      Navigator.of(context).pop();
      return;
    }
    _selesai = true;
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
      target: Pengaturan.instance.target,
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
        title: const Text('Simpan rekaman?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.subjek} · ${widget.kelasRekam!.kode} ${widget.kelasRekam!.nama}',
            ),
            const SizedBox(height: 4),
            Text(
              'Terhitung otomatis ${mesin.jumlah} repetisi. Isi jumlah sebenarnya '
              '(hitungan manual) untuk evaluasi penghitung repetisi.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: kontrol,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Repetisi sebenarnya',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, -1),
            child: const Text('Buang'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(kontrol.text) ?? mesin.jumlah),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (jumlah != null && jumlah >= 0) {
      await Rekaman.simpan(
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rekaman ${widget.kelasRekam!.kode} disimpan ($jumlah repetisi)',
            ),
          ),
        );
      }
    }
    if (mounted) Navigator.of(context).pop(jumlah != null && jumlah >= 0);
  }

  @override
  void dispose() {
    _detak?.cancel();
    _langganan?.cancel();
    _sumber?.dispose();
    _mesin?.dispose();
    Suara.instance.diam();
    try {
      WakelockPlus.disable();
    } catch (_) {}
    super.dispose();
  }

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
          backgroundColor: Warna.malam,
          body: _galat != null
              ? _Galat(pesan: _galat!)
              : _mesin == null
              ? const Center(
                  child: CircularProgressIndicator(color: Warna.kerangka),
                )
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
    final baru = f != null && m.waktu - _tRepetisi < 1400;
    final warna = !baru || terakhir == null || terakhir.kelas < 0
        ? Warna.kerangka
        : (terakhir.benar ? Warna.benar : Warna.salah);
    final sumber = _sumber!;
    final pratinjau = sumber.pratinjau();
    final mendatar =
        MediaQuery.of(context).orientation == Orientation.landscape;

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
                      warna: warna,
                      cermin: sumber.cermin,
                      sorot: [for (final s in g.sendiUtama) s[1]],
                    ),
                  ),
                ],
              ),
            ),
          );

    final panel = _PanelBawah(
      mesin: m,
      gerakan: g,
      rekam: _rekam,
      target: Pengaturan.instance.target,
      detik: _jam.elapsed.inSeconds,
      onSelesai: _akhiri,
      sorotTerakhir: baru,
    );

    // Di mode demo tidak ada gambar kamera: kerangka diletakkan di atas panel
    // bawah supaya kakinya tidak tertutup.
    final ruangPanel = pratinjau == null && !mendatar ? 230.0 : 0.0;

    return Stack(
      children: [
        if (pratinjau == null) const Positioned.fill(child: _LantaiDemo()),
        Positioned.fill(
          top: pratinjau == null ? MediaQuery.of(context).padding.top + 64 : 0,
          bottom: ruangPanel,
          right: mendatar && pratinjau == null ? 340 : 0,
          child: adegan,
        ),
        // Gradasi supaya teks putih tetap terbaca di atas gambar kamera.
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 140,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xAA000000), Color(0x00000000)],
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
              child: _BarAtas(
                judul: g.nama,
                mode: widget.mode,
                model: _klas == null ? null : namaModel[_klas!.id],
                label: widget.kelasRekam,
                onTutup: _akhiri,
              ),
            ),
          ),
        ),
        if (sumber.galat != null)
          Positioned(
            left: 24,
            right: 24,
            top: MediaQuery.of(context).padding.top + 72,
            child: _Pesan(teks: 'Deteksi pose gagal', petunjuk: sumber.galat!),
          )
        else if (m.kesiapan != Kesiapan.siap)
          Positioned(
            left: 24,
            right: 24,
            top: MediaQuery.of(context).padding.top + 72,
            child: _Pesan(teks: m.kesiapan.pesan, petunjuk: g.posisiKamera),
          ),
        if (Pengaturan.instance.infoTeknis)
          Positioned(
            left: 16,
            top: MediaQuery.of(context).padding.top + 64,
            child: _InfoTeknis(sumber: sumber, mesin: m),
          ),
        if (mendatar)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 340,
            child: SafeArea(
              left: false,
              child: Center(child: SingleChildScrollView(child: panel)),
            ),
          )
        else ...[
          Positioned(
            right: 14,
            top: MediaQuery.of(context).size.height * 0.24,
            child: _PengukurSudut(mesin: m, gerakan: g),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(top: false, child: panel),
          ),
        ],
      ],
    );
  }
}

class _BarAtas extends StatelessWidget {
  const _BarAtas({
    required this.judul,
    required this.mode,
    required this.model,
    required this.label,
    required this.onTutup,
  });

  final String judul;
  final ModeLatihan mode;
  final String? model;
  final Kelas? label;
  final VoidCallback onTutup;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onTutup,
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          tooltip: 'Selesai',
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                judul,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                switch (mode) {
                  ModeLatihan.rekam =>
                    'Rekam data · ${label!.kode} ${label!.nama}',
                  _ => 'Model: ${model ?? '-'}',
                },
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (mode == ModeLatihan.demo)
          const _Lencana(teks: 'DEMO', warna: Warna.utama),
        if (mode == ModeLatihan.rekam)
          const _Lencana(teks: '● REC', warna: Warna.rekam),
      ],
    );
  }
}

class _Lencana extends StatelessWidget {
  const _Lencana({required this.teks, required this.warna});

  final String teks;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: warna,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        teks,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Pesan extends StatelessWidget {
  const _Pesan({required this.teks, required this.petunjuk});

  final String teks;
  final String petunjuk;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(Icons.accessibility_new_rounded, color: Color(0xFFFFC266)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teks,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  petunjuk,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final baris = [
      'pose ${ms(sumber.msPose)} ms · ${ms(sumber.fps)} fps',
      'fitur ${ms(h?.msFitur)} ms · klasifikasi ${ms(h?.msKlasifikasi)} ms',
      'sudut ${ms(mesin.sudut)}° · puncak ${ms(mesin.puncak)}°',
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        baris.join('\n'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          height: 1.4,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Batang tegak yang mengisi seiring turunnya sudut sendi utama.
class _PengukurSudut extends StatelessWidget {
  const _PengukurSudut({required this.mesin, required this.gerakan});

  final MesinLatihan mesin;
  final Gerakan gerakan;

  @override
  Widget build(BuildContext context) {
    final sudut = mesin.sudut;
    final puncak = mesin.puncak;
    // Rentang tampilan: dari puncak (berdiri/lengan lurus) turun 100°.
    final isi = sudut == null || puncak == null
        ? 0.0
        : ((puncak - sudut) / 100).clamp(0.0, 1.0);
    const tinggi = 180.0;
    return Column(
      children: [
        Container(
          width: 14,
          height: tinggi,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(99),
          ),
          alignment: Alignment.topCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            width: 14,
            height: tinggi * isi,
            decoration: BoxDecoration(
              color: Warna.kerangka,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          sudut == null ? '–' : '${sudut.round()}°',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          gerakan.namaSudut,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }
}

class _PanelBawah extends StatelessWidget {
  const _PanelBawah({
    required this.mesin,
    required this.gerakan,
    required this.rekam,
    required this.target,
    required this.detik,
    required this.onSelesai,
    required this.sorotTerakhir,
  });

  final MesinLatihan mesin;
  final Gerakan gerakan;
  final bool rekam;
  final int target;
  final int detik;
  final VoidCallback onSelesai;
  final bool sorotTerakhir;

  @override
  Widget build(BuildContext context) {
    final terakhir = mesin.hasil.isEmpty ? null : mesin.hasil.last;
    final waktu =
        '${(detik ~/ 60).toString().padLeft(2, '0')}:${(detik % 60).toString().padLeft(2, '0')}';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xE6101614),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${mesin.jumlah}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  height: 0.95,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rekam ? 'repetisi' : 'dari $target',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      waktu,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (!rekam && mesin.jumlah > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(mesin.jumlahBenar * 100 / mesin.jumlah).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      'benar',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!rekam)
            _KartuPenilaian(
              gerakan: gerakan,
              hasil: terakhir,
              sorot: sorotTerakhir,
            )
          else
            _PetunjukRekam(mesin: mesin),
          if (mesin.hasil.isNotEmpty && !rekam) ...[
            const SizedBox(height: 12),
            _StripRepetisi(hasil: mesin.hasil),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onSelesai,
            style: FilledButton.styleFrom(
              backgroundColor: rekam ? Warna.rekam : Colors.white,
              foregroundColor: rekam ? Colors.white : Warna.malam,
            ),
            icon: Icon(rekam ? Icons.stop_rounded : Icons.flag_rounded),
            label: Text(rekam ? 'Berhenti & simpan' : 'Selesai'),
          ),
        ],
      ),
    );
  }
}

class _KartuPenilaian extends StatelessWidget {
  const _KartuPenilaian({
    required this.gerakan,
    required this.hasil,
    required this.sorot,
  });

  final Gerakan gerakan;
  final HasilRepetisi? hasil;
  final bool sorot;

  @override
  Widget build(BuildContext context) {
    final h = hasil;
    if (h == null) {
      return const _BarisPenilaian(
        ikon: Icons.play_arrow_rounded,
        warna: Colors.white24,
        judul: 'Mulai bergerak',
        sub: 'Setiap repetisi dinilai begitu selesai',
      );
    }
    final k = gerakan.kelas[h.kelas];
    return AnimatedScale(
      scale: sorot ? 1.0 : 0.98,
      duration: const Duration(milliseconds: 220),
      child: _BarisPenilaian(
        ikon: h.benar ? Icons.check_rounded : Icons.priority_high_rounded,
        warna: Warna.kelas(h.kelas),
        judul: 'Repetisi ${h.nomor}: ${k.nama}',
        sub: h.benar
            ? 'Yakin ${(h.yakin * 100).round()}% · ${h.durasi.toStringAsFixed(1)} detik'
            : '${k.ucapan} · yakin ${(h.yakin * 100).round()}%',
      ),
    );
  }
}

class _BarisPenilaian extends StatelessWidget {
  const _BarisPenilaian({
    required this.ikon,
    required this.warna,
    required this.judul,
    required this.sub,
  });

  final IconData ikon;
  final Color warna;
  final String judul;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: warna, shape: BoxShape.circle),
          child: Icon(ikon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                judul,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                sub,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PetunjukRekam extends StatelessWidget {
  const _PetunjukRekam({required this.mesin});

  final MesinLatihan mesin;

  @override
  Widget build(BuildContext context) {
    final detik = mesin.semuaFrame.isEmpty
        ? 0.0
        : mesin.semuaFrame.last.t / 1000;
    return _BarisPenilaian(
      ikon: Icons.fiber_manual_record_rounded,
      warna: Warna.rekam,
      judul: '${mesin.semuaFrame.length} frame terekam',
      sub:
          'Rata-rata ${(mesin.semuaFrame.length / (detik <= 0 ? 1 : detik)).toStringAsFixed(1)} '
          'fps. Jangan putar ponsel selama merekam.',
    );
  }
}

class _StripRepetisi extends StatelessWidget {
  const _StripRepetisi({required this.hasil});

  final List<HasilRepetisi> hasil;

  @override
  Widget build(BuildContext context) {
    final tampil = hasil.length > 14 ? hasil.sublist(hasil.length - 14) : hasil;
    return Row(
      children: [
        for (final h in tampil)
          Expanded(
            child: Container(
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Warna.kelas(h.kelas),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        for (var i = tampil.length; i < 10; i++)
          Expanded(
            child: Container(
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
      ],
    );
  }
}

/// Latar mode demo: lantai bergaris tipis supaya kerangka tidak melayang.
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
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14211E), Color(0xFF0A0F0E)],
        ).createShader(Offset.zero & size),
    );
    final garis = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.5;
    final langkah = size.shortestSide / 10;
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
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              kameraTersedia
                  ? 'Kamera tidak bisa dibuka'
                  : 'Kamera hanya tersedia di aplikasi Android',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              kameraTersedia
                  ? 'Pastikan izin kamera diberikan, lalu coba lagi.\n\n$pesan'
                  : 'Di browser, coba mode demo untuk melihat cara kerjanya.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }
}
