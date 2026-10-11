import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'fitur.dart';
import 'gerakan.dart';
import 'klasifikasi/klasifikasi.dart';
import 'pose.dart';
import 'repetisi.dart';
import 'sinyal.dart';

/// Jumlah langkah waktu yang disimpan per repetisi untuk diputar ulang.
const langkahPutar = 32;

/// Koordinat 12 landmark ([langkahPutar] × 24) dan kurva sudut utama dari
/// fitur repetisi, untuk diputar ulang tanpa menyimpan semua frame.
(List<double>, List<double>) dataPutar(FiturRepetisi f, Gerakan g) {
  final ku = namaKanal.indexOf(g.kanalUtama);
  final pose = <double>[];
  final kurva = <double>[];
  for (var k = 0; k < langkahPutar; k++) {
    final baris = f.seq[(k * (f.seq.length - 1) / (langkahPutar - 1)).round()];
    kurva.add(baris[ku]);
    for (var c = 14; c < jumlahFitur; c++) {
      pose.add(baris[c]);
    }
  }
  return (pose, kurva);
}

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
    this.set = 1,
    this.pose = const [],
    this.kurva = const [],
    this.pendapat = const {},
  });

  final int nomor;

  /// Indeks kelas; -1 bila tidak diklasifikasikan (mode rekam).
  final int kelas;
  final List<double> peluang;
  final double durasi;
  final double rom;
  final double msFitur;
  final double msKlasifikasi;
  final int set;

  /// Koordinat ternormalisasi 12 landmark terpilih, [langkahPutar] × 24,
  /// untuk memutar ulang repetisi. Kosong pada catatan lama.
  final List<double> pose;

  /// Sudut sendi utama sepanjang repetisi ([langkahPutar] nilai).
  final List<double> kurva;

  /// Penilaian model pembanding: id model → indeks kelas.
  final Map<String, int> pendapat;

  /// Waktu fase turun (eksentrik) dan naik (konsentrik), dipisah di titik
  /// terdalam kurva sudut.
  ({double turun, double naik})? get tempo {
    if (kurva.length < 2) return null;
    var iMin = 0;
    for (var i = 1; i < kurva.length; i++) {
      if (kurva[i] < kurva[iMin]) iMin = i;
    }
    final turun = durasi * iMin / (kurva.length - 1);
    return (turun: turun, naik: durasi - turun);
  }

  bool get benar => kelas == 0;
  double get yakin => kelas < 0 ? 0 : peluang[kelas];

  /// Skor form 0–100: peluang kelas "benar" menurut model.
  int get skor => kelas < 0 || peluang.isEmpty ? 0 : (peluang[0] * 100).round();

  /// Sudut terdalam yang dicapai.
  double? get sudutTerdalam => kurva.isEmpty ? null : kurva.reduce(math.min);

  Map<String, dynamic> keJson() => {
    'nomor': nomor,
    'kelas': kelas,
    'set': set,
    'peluang': [for (final p in peluang) double.parse(p.toStringAsFixed(4))],
    'durasi': double.parse(durasi.toStringAsFixed(2)),
    'rom': double.parse(rom.toStringAsFixed(1)),
    'ms_fitur': double.parse(msFitur.toStringAsFixed(3)),
    'ms_klasifikasi': double.parse(msKlasifikasi.toStringAsFixed(3)),
    if (pose.isNotEmpty)
      'pose': [for (final v in pose) double.parse(v.toStringAsFixed(3))],
    if (kurva.isNotEmpty)
      'kurva': [for (final v in kurva) double.parse(v.toStringAsFixed(1))],
    if (pendapat.isNotEmpty) 'pendapat': pendapat,
  };

  factory HasilRepetisi.dariJson(Map<String, dynamic> js) => HasilRepetisi(
    nomor: js['nomor'] as int,
    kelas: js['kelas'] as int,
    set: js['set'] as int? ?? 1,
    peluang: [for (final p in js['peluang'] as List) (p as num).toDouble()],
    durasi: (js['durasi'] as num).toDouble(),
    rom: (js['rom'] as num).toDouble(),
    msFitur: (js['ms_fitur'] as num? ?? 0).toDouble(),
    msKlasifikasi: (js['ms_klasifikasi'] as num? ?? 0).toDouble(),
    pose: [
      for (final v in js['pose'] as List? ?? const []) (v as num).toDouble(),
    ],
    kurva: [
      for (final v in js['kurva'] as List? ?? const []) (v as num).toDouble(),
    ],
    pendapat: {
      for (final e in (js['pendapat'] as Map? ?? const {}).entries)
        e.key as String: e.value as int,
    },
  );
}

enum Kesiapan {
  tidakAdaOrang('Belum ada orang di depan kamera'),
  sebagian('Seluruh badan belum terlihat'),
  siap('Posisi siap');

  const Kesiapan(this.pesan);

  final String pesan;
}

/// Menerima frame pose satu per satu, menghitung repetisi, lalu
/// mengklasifikasikan setiap repetisi yang selesai.
///
/// Saat [aktif] false (persiapan, istirahat) sinyal tetap diikuti supaya
/// pengukur sudut hidup, tetapi repetisi tidak dicatat.
class MesinLatihan extends ChangeNotifier {
  MesinLatihan({
    required this.gerakan,
    this.klasifikasi,
    this.rekamSemua = false,
    this.aktif = true,
    this.pembanding = const [],
  }) : _hitung = PenghitungRepetisi(gerakan);

  final Gerakan gerakan;

  /// Null di mode rekam data: repetisi tetap dihitung tapi tidak dinilai.
  final Pengklasifikasi? klasifikasi;

  /// Simpan semua frame untuk berkas sesi (mode rekam data).
  final bool rekamSemua;

  /// Model lain yang ikut menilai setiap repetisi, untuk dibandingkan.
  final List<Pengklasifikasi> pembanding;

  bool aktif;
  int set = 1;

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

  /// Jejak titik tengah pinggul untuk menilai apakah pengguna diam.
  final ListQueue<(double, double, double)> _jejak = ListQueue();

  /// Sudut sendi utama yang sudah dihaluskan.
  double? get sudut => _hitung.halus;
  double? get puncak => _hitung.puncak;
  bool get sedangTurun => _hitung.turun;

  int get jumlah => hasil.length;
  int get jumlahBenar => hasil.where((h) => h.benar).length;
  int get jumlahSetIni => hasil.where((h) => h.set == set).length;

  /// Dipanggil setiap repetisi selesai dinilai.
  void Function(HasilRepetisi)? diRepetisi;

  /// Mulai (atau lanjutkan dengan set baru) penghitungan dari posisi diam.
  void mulaiHitung({int set = 1}) {
    this.set = set;
    _hitung.reset();
    aktif = true;
    if (rekamSemua) semuaFrame.clear();
    notifyListeners();
  }

  void jeda() {
    aktif = false;
    notifyListeners();
  }

  void masukkan(FramePose f) {
    final i = _indeks++;
    _penyangga.addLast(f);
    if (_penyangga.length > _maksPenyangga) {
      _penyangga.removeFirst();
      _awalPenyangga++;
    }
    if (rekamSemua && aktif) semuaFrame.add(f);
    _terakhirMasuk = f;
    final sebelum = terakhir;
    if (!f.kosong || sebelum == null || f.t - sebelum.t > _tahanKerangkaMs) {
      terakhir = f;
    }
    _perbaruiKesiapan(_cekKesiapan(f), f.t);
    _catatJejak(f);

    final p = _hitung.proses(i, f.t, sinyalUtama(f, gerakan));
    if (aktif && p != null && p.mulai >= _awalPenyangga) {
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

    final (pose, kurva) = dataPutar(f, gerakan);
    final h = HasilRepetisi(
      nomor: hasil.length + 1,
      kelas: pr?.indeks ?? -1,
      peluang: pr?.peluang ?? const [],
      durasi: f.durasiDetik,
      rom: p.rom,
      msFitur: msFitur,
      msKlasifikasi: msKlas,
      set: set,
      pose: pose,
      kurva: kurva,
      pendapat: {for (final m in pembanding) m.id: m.prediksi(f).indeks},
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

  void _catatJejak(FramePose f) {
    if (f.kosong) return;
    const ki = 23, ka = 24;
    _jejak.addLast((f.t, (f.x[ki] + f.x[ka]) / 2, (f.y[ki] + f.y[ka]) / 2));
    while (_jejak.length > 2 && f.t - _jejak.first.$1 > 900) {
      _jejak.removeFirst();
    }
  }

  /// Pinggul hampir tidak bergerak selama ±0,8 detik terakhir.
  bool get diam {
    final f = terakhir;
    if (f == null || f.kosong || _jejak.length < 4) return false;
    if (_jejak.last.$1 - _jejak.first.$1 < 700) return false;
    var minX = double.infinity,
        maxX = -double.infinity,
        minY = double.infinity,
        maxY = -double.infinity;
    for (final (_, x, y) in _jejak) {
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }
    final batas = 0.035 * math.max(f.lebar, f.tinggi);
    return maxX - minX < batas && maxY - minY < batas;
  }

  /// Bagian bingkai yang terisi badan (0–1), dari landmark wajib yang terlihat.
  double? get proporsi {
    final f = terakhir;
    if (f == null || f.kosong) return null;
    final titik = {for (final k in gerakan.wajibTerlihat) ...k}
        .where((j) => f.v[j] >= ambangVis);
    if (titik.length < 3) return null;
    var minX = double.infinity,
        maxX = -double.infinity,
        minY = double.infinity,
        maxY = -double.infinity;
    for (final j in titik) {
      minX = math.min(minX, f.x[j]);
      maxX = math.max(maxX, f.x[j]);
      minY = math.min(minY, f.y[j]);
      maxY = math.max(maxY, f.y[j]);
    }
    return math.max((maxX - minX) / f.lebar, (maxY - minY) / f.tinggi);
  }

  /// Jarak kamera wajar: badan tidak terlalu kecil maupun terpotong.
  bool get jarakPas {
    final p = proporsi;
    return p != null && p >= 0.3 && p <= 0.95;
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

  /// Rerata skor form semua repetisi yang dinilai.
  int? get skorRerata {
    final dinilai = hasil.where((h) => h.kelas >= 0).toList();
    if (dinilai.isEmpty) return null;
    return (dinilai.fold(0, (a, h) => a + h.skor) / dinilai.length).round();
  }
}
