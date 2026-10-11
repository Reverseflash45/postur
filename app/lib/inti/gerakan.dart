import 'package:flutter/foundation.dart' show kIsWeb;

import 'landmark.dart';

/// Definisi gerakan dan kelasnya — salinan ml/postur/gerakan.py.
///
/// Urutan kelas = indeks keluaran model. Kalau mengubah salah satu, ubah
/// keduanya; uji paritas akan gagal bila tidak sinkron.
class Kelas {
  const Kelas(
    this.kode,
    this.nama,
    this.arahan,
    this.ucapan, {
    this.bagian = const [],
  });

  final String kode;
  final String nama;

  /// Arahan untuk subjek saat merekam data.
  final String arahan;

  /// Kalimat pendek yang diucapkan setelah repetisi.
  final String ucapan;

  /// Landmark yang disorot di kerangka saat kesalahan ini terdeteksi.
  final List<int> bagian;

  bool get benar => kode.endsWith('-0');
}

class Aturan {
  const Aturan(this.label, this.fitur, this.op);

  final String label;
  final String fitur;
  final String op;
}

class Gerakan {
  const Gerakan({
    required this.id,
    required this.nama,
    required this.kelas,
    required this.sendiUtama,
    required this.kanalUtama,
    required this.namaSudut,
    required this.romMin,
    required this.aturan,
    required this.wajibTerlihat,
    required this.posisiKamera,
    required this.orientasi,
    required this.targetSudut,
  });

  /// Sudut sendi utama (derajat) yang dianggap sudah cukup dalam. Hanya
  /// untuk petunjuk visual di pengukur; penilaian tetap oleh model.
  final double targetSudut;

  final String id;
  final String nama;
  final List<Kelas> kelas;

  /// Tiga landmark sendi utama, kiri lalu kanan, untuk menghitung repetisi.
  final List<List<int>> sendiUtama;
  final String kanalUtama;

  /// Nama sudut utama untuk ditampilkan ("lutut", "siku").
  final String namaSudut;
  final double romMin;
  final List<Aturan> aturan;

  /// Kelompok landmark yang harus terlihat sebelum mulai; cukup salah satu
  /// kelompok terpenuhi (push-up dari samping hanya menampakkan satu sisi).
  final List<List<int>> wajibTerlihat;

  /// Petunjuk penempatan ponsel.
  final String posisiKamera;

  /// Orientasi ponsel yang disarankan saat merekam.
  final String orientasi;

  List<String> get kode => [for (final k in kelas) k.kode];

  int indeks(String kode) => this.kode.indexOf(kode);

  Kelas kelasDari(String kode) => kelas.firstWhere((k) => k.kode == kode);
}

const squat = Gerakan(
  id: 'squat',
  nama: 'Squat',
  kelas: [
    Kelas(
      'SQ-0',
      'Benar',
      'Turun sampai paha sejajar lantai, lutut searah ujung kaki, punggung netral.',
      'Bagus',
    ),
    Kelas(
      'SQ-1',
      'Kurang dalam',
      'Turun hanya setengah jalan, paha tidak sampai sejajar lantai.',
      'Turun lebih dalam',
      bagian: [Lm.pinggulKi, Lm.pinggulKa, Lm.lututKi, Lm.lututKa],
    ),
    Kelas(
      'SQ-2',
      'Lutut masuk ke dalam',
      'Saat turun, biarkan kedua lutut bergerak saling mendekat.',
      'Dorong lutut ke luar',
      bagian: [Lm.lututKi, Lm.lututKa, Lm.kakiKi, Lm.kakiKa],
    ),
    Kelas(
      'SQ-3',
      'Badan terlalu condong',
      'Saat turun, condongkan badan jauh ke depan.',
      'Dada lebih tegak',
      bagian: [Lm.bahuKi, Lm.bahuKa, Lm.pinggulKi, Lm.pinggulKa],
    ),
  ],
  sendiUtama: [
    [Lm.pinggulKi, Lm.lututKi, Lm.kakiKi],
    [Lm.pinggulKa, Lm.lututKa, Lm.kakiKa],
  ],
  kanalUtama: 'lutut',
  namaSudut: 'Lutut',
  romMin: 30,
  aturan: [
    Aturan('SQ-1', 'lutut_min', '>'),
    Aturan('SQ-2', 'rasio_lutut_min', '<'),
    Aturan('SQ-3', 'condong_max', '>'),
  ],
  wajibTerlihat: [
    [
      Lm.bahuKi, Lm.bahuKa, Lm.pinggulKi, Lm.pinggulKa, //
      Lm.lututKi, Lm.lututKa, Lm.kakiKi, Lm.kakiKa,
    ],
  ],
  posisiKamera: kIsWeb
      ? 'Kamera setinggi pinggang, depan-serong ±45°, jarak 2–3 m'
      : 'Ponsel tegak, depan-serong ±45°, jarak 2–3 m',
  orientasi: 'Tegak',
  targetSudut: 100,
);

const _pinggul = [
  Lm.bahuKi, Lm.bahuKa, Lm.pinggulKi, Lm.pinggulKa, Lm.lututKi, Lm.lututKa, //
];

const pushup = Gerakan(
  id: 'pushup',
  nama: 'Push-up',
  kelas: [
    Kelas(
      'PU-0',
      'Benar',
      'Bahu, pinggul, dan pergelangan kaki segaris; dada turun sampai siku sekitar 90°.',
      'Bagus',
    ),
    Kelas(
      'PU-1',
      'Pinggul turun',
      'Biarkan pinggul melengkung turun di bawah garis badan.',
      'Kencangkan perut, pinggul naik sedikit',
      bagian: _pinggul,
    ),
    Kelas(
      'PU-2',
      'Pinggul terangkat',
      'Angkat pinggul tinggi sehingga badan membentuk huruf V terbalik.',
      'Turunkan pinggul, badan lurus',
      bagian: _pinggul,
    ),
    Kelas(
      'PU-3',
      'Kurang dalam',
      'Turunkan dada hanya setengah jalan.',
      'Turun lebih dalam',
      bagian: [
        Lm.bahuKi,
        Lm.bahuKa,
        Lm.sikuKi,
        Lm.sikuKa,
        Lm.tanganKi,
        Lm.tanganKa,
      ],
    ),
  ],
  sendiUtama: [
    [Lm.bahuKi, Lm.sikuKi, Lm.tanganKi],
    [Lm.bahuKa, Lm.sikuKa, Lm.tanganKa],
  ],
  kanalUtama: 'siku',
  namaSudut: 'Siku',
  romMin: 30,
  aturan: [
    Aturan('PU-3', 'siku_min', '>'),
    Aturan('PU-1', 'lengkung_max', '>'),
    Aturan('PU-2', 'lengkung_min', '<'),
  ],
  wajibTerlihat: [
    [Lm.bahuKi, Lm.sikuKi, Lm.tanganKi, Lm.pinggulKi, Lm.kakiKi],
    [Lm.bahuKa, Lm.sikuKa, Lm.tanganKa, Lm.pinggulKa, Lm.kakiKa],
  ],
  posisiKamera: kIsWeb
      ? 'Kamera dekat lantai, dari samping, jarak 2–3 m'
      : 'Ponsel mendatar di lantai, dari samping, jarak 2–3 m',
  orientasi: 'Mendatar',
  targetSudut: 95,
);

const semuaGerakan = [squat, pushup];

Gerakan gerakanDari(String id) => semuaGerakan.firstWhere((g) => g.id == id);
