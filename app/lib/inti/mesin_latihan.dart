import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'fitur.dart';
import 'gerakan.dart';
import 'klasifikasi/klasifikasi.dart';
import 'pose.dart';
import 'repetisi.dart';
import 'sinyal.dart';

/// Hasil satu repetisi selama latihan.
class HasilRepetisi {
  const HasilRepetisi({
    required this.nomor,
    required this.kelas,
    required this.peluang,
    required this.durasi,
    required this.rom,
    required this.msFitur,
    required this.msKlasifikasi,
  });

  final int nomor;

  /// Indeks kelas; -1 bila tidak diklasifikasikan (mode rekam).
  final int kelas;
  final List<double> peluang;
  final double durasi;
  final double rom;
  final double msFitur;
  final double msKlasifikasi;

  bool get benar => kelas == 0;
  double get yakin => kelas < 0 ? 0 : peluang[kelas];

  Map<String, dynamic> keJson() => {
    'nomor': nomor,
    'kelas': kelas,
    'peluang': [for (final p in peluang) double.parse(p.toStringAsFixed(4))],
    'durasi': double.parse(durasi.toStringAsFixed(2)),
    'rom': double.parse(rom.toStringAsFixed(1)),
    'ms_fitur': double.parse(msFitur.toStringAsFixed(3)),
    'ms_klasifikasi': double.parse(msKlasifikasi.toStringAsFixed(3)),
  };

  factory HasilRepetisi.dariJson(Map<String, dynamic> js) => HasilRepetisi(
    nomor: js['nomor'] as int,
    kelas: js['kelas'] as int,
    peluang: [for (final p in js['peluang'] as List) (p as num).toDouble()],
    durasi: (js['durasi'] as num).toDouble(),
    rom: (js['rom'] as num).toDouble(),
    msFitur: (js['ms_fitur'] as num? ?? 0).toDouble(),
    msKlasifikasi: (js['ms_klasifikasi'] as num? ?? 0).toDouble(),
  );
}

enum Kesiapan {
  tidakAdaOrang('Belum ada orang di depan kamera'),
  sebagian('Seluruh badan belum terlihat. Mundurkan ponsel sedikit'),
  siap('Posisi siap');

  const Kesiapan(this.pesan);

  final String pesan;
}

/// Menerima frame pose satu per satu, menghitung repetisi, lalu
/// mengklasifikasikan setiap repetisi yang selesai.
class MesinLatihan extends ChangeNotifier {
  MesinLatihan({
    required this.gerakan,
    this.klasifikasi,
    this.rekamSemua = false,
  }) : _hitung = PenghitungRepetisi(gerakan);

  final Gerakan gerakan;

  /// Null di mode rekam data: repetisi tetap dihitung tapi tidak dinilai.
  final Pengklasifikasi? klasifikasi;

  /// Simpan semua frame untuk berkas sesi (mode rekam data).
  final bool rekamSemua;

  final PenghitungRepetisi _hitung;
  final ListQueue<FramePose> _penyangga = ListQueue();
  int _indeks = 0;
  int _awalPenyangga = 0;
  static const _maksPenyangga = 900;

  final List<HasilRepetisi> hasil = [];
  final List<FramePose> semuaFrame = [];

  /// Frame terakhir yang berisi orang, untuk digambar. Frame kosong sesekali
  /// (deteksi gagal satu frame) tidak membuat kerangka berkedip.
  FramePose? terakhir;
  FramePose? _terakhirMasuk;

  /// Status posisi yang ditampilkan. Baru berubah ke "belum siap" setelah
  /// bertahan [_tahanMs], supaya pesan tidak berkedip.
  Kesiapan kesiapan = Kesiapan.tidakAdaOrang;
  Kesiapan? _calon;
  double _tCalon = 0;
  static const _tahanMs = 600.0;
  static const _tahanKerangkaMs = 400.0;

  /// Sudut sendi utama yang sudah dihaluskan.
  double? get sudut => _hitung.halus;
  double? get puncak => _hitung.puncak;
  bool get sedangTurun => _hitung.turun;

  int get jumlah => hasil.length;
  int get jumlahBenar => hasil.where((h) => h.benar).length;

  /// Dipanggil setiap repetisi selesai dinilai.
  void Function(HasilRepetisi)? diRepetisi;

  void masukkan(FramePose f) {
    final i = _indeks++;
    _penyangga.addLast(f);
    if (_penyangga.length > _maksPenyangga) {
      _penyangga.removeFirst();
      _awalPenyangga++;
    }
    if (rekamSemua) semuaFrame.add(f);
    _terakhirMasuk = f;
    final sebelum = terakhir;
    if (!f.kosong || sebelum == null || f.t - sebelum.t > _tahanKerangkaMs) {
      terakhir = f;
    }
    _perbaruiKesiapan(_cekKesiapan(f), f.t);

    final p = _hitung.proses(i, f.t, sinyalUtama(f, gerakan));
    if (p != null && p.mulai >= _awalPenyangga) {
      _nilai(p);
    }
    notifyListeners();
  }

  void _nilai(Potongan p) {
    final daftar = _penyangga.toList();
    final potong = daftar.sublist(
      p.mulai - _awalPenyangga,
      p.selesai - _awalPenyangga + 1,
    );
    final sw = Stopwatch()..start();
    final f = prosesRepetisi(potong, gerakan);
    final msFitur = sw.elapsedMicroseconds / 1000;
    sw.reset();
    final pr = klasifikasi?.prediksi(f);
    final msKlas = sw.elapsedMicroseconds / 1000;
    final h = HasilRepetisi(
      nomor: hasil.length + 1,
      kelas: pr?.indeks ?? -1,
      peluang: pr?.peluang ?? const [],
      durasi: f.durasiDetik,
      rom: p.rom,
      msFitur: msFitur,
      msKlasifikasi: msKlas,
    );
    hasil.add(h);
    diRepetisi?.call(h);
  }

  void _perbaruiKesiapan(Kesiapan k, double t) {
    if (k == Kesiapan.siap || kesiapan != Kesiapan.siap) {
      kesiapan = k;
      _calon = null;
      return;
    }
    if (_calon != k) {
      _calon = k;
      _tCalon = t;
    } else if (t - _tCalon >= _tahanMs) {
      kesiapan = k;
      _calon = null;
    }
  }

  /// Waktu frame terbaru (termasuk frame kosong).
  double get waktu => _terakhirMasuk?.t ?? 0;

  Kesiapan _cekKesiapan(FramePose f) {
    if (f.kosong) return Kesiapan.tidakAdaOrang;
    for (final kelompok in gerakan.wajibTerlihat) {
      if (kelompok.every((j) => f.v[j] >= ambangVis)) return Kesiapan.siap;
    }
    return Kesiapan.sebagian;
  }

  /// Statistik kelas: jumlah repetisi per indeks kelas.
  List<int> get sebaran {
    final s = List.filled(gerakan.kelas.length, 0);
    for (final h in hasil) {
      if (h.kelas >= 0) s[h.kelas]++;
    }
    return s;
  }
}
