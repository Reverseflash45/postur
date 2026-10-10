import 'dart:convert';

import '../inti/mesin_latihan.dart';
import 'penyimpanan.dart';

/// Satu sesi latihan yang sudah selesai.
class CatatanLatihan {
  CatatanLatihan({
    required this.id,
    required this.gerakan,
    required this.model,
    required this.mulai,
    required this.detik,
    required this.target,
    required this.repetisi,
    this.demo = false,
    this.msPose,
    this.fps,
  });

  factory CatatanLatihan.dariJson(Map<String, dynamic> js) => CatatanLatihan(
    id: js['id'] as String,
    gerakan: js['gerakan'] as String,
    model: js['model'] as String,
    mulai: DateTime.parse(js['mulai'] as String),
    detik: js['detik'] as int,
    target: js['target'] as int,
    demo: js['demo'] as bool? ?? false,
    msPose: (js['ms_pose'] as num?)?.toDouble(),
    fps: (js['fps'] as num?)?.toDouble(),
    repetisi: [
      for (final r in js['repetisi'] as List)
        HasilRepetisi.dariJson(r as Map<String, dynamic>),
    ],
  );

  final String id;
  final String gerakan;
  final String model;
  final DateTime mulai;
  final int detik;
  final int target;
  final bool demo;
  final double? msPose;
  final double? fps;
  final List<HasilRepetisi> repetisi;

  int get benar => repetisi.where((r) => r.benar).length;
  double get persenBenar => repetisi.isEmpty ? 0 : benar / repetisi.length;

  Map<String, dynamic> keJson() => {
    'id': id,
    'gerakan': gerakan,
    'model': model,
    'mulai': mulai.toIso8601String(),
    'detik': detik,
    'target': target,
    'demo': demo,
    if (msPose != null) 'ms_pose': msPose,
    if (fps != null) 'fps': fps,
    'repetisi': [for (final r in repetisi) r.keJson()],
  };
}

class Riwayat {
  static const _folder = 'riwayat';

  static Future<void> simpan(CatatanLatihan c) => Penyimpanan.instance.tulis(
    '$_folder/${c.id}.json',
    jsonEncode(c.keJson()),
  );

  /// Semua catatan, terbaru dulu.
  static Future<List<CatatanLatihan>> semua() async {
    final hasil = <CatatanLatihan>[];
    for (final n in await Penyimpanan.instance.daftar(_folder)) {
      final isi = await Penyimpanan.instance.baca(n);
      if (isi == null) continue;
      try {
        hasil.add(
          CatatanLatihan.dariJson(jsonDecode(isi) as Map<String, dynamic>),
        );
      } catch (_) {
        // Berkas rusak dilewati, bukan menggagalkan seluruh daftar.
      }
    }
    hasil.sort((a, b) => b.mulai.compareTo(a.mulai));
    return hasil;
  }

  static Future<void> hapus(String id) =>
      Penyimpanan.instance.hapus('$_folder/$id.json');
}
