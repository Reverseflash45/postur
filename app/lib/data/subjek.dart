import 'dart:convert';

import '../inti/protokol.dart';
import 'penyimpanan.dart';
import 'rekaman.dart';

/// Profil subjek penelitian. Anonim: hanya kode dan rentang, tanpa nama.
///
/// Disimpan sebagai `subjek/subjek-<kode>.json` (format "postur-subjek") dan
/// ikut diekspor bersama rekaman; dibaca ml/postur/subjek.py untuk tabel
/// karakteristik subjek.
class ProfilSubjek {
  ProfilSubjek({
    required this.kode,
    required this.usia,
    required this.jenisKelamin,
    required this.pengalaman,
    required this.setuju,
    required this.dibuat,
    this.tinggiCm,
    this.catatan = '',
  });

  final String kode;

  /// Rentang usia, misalnya "18-24".
  final String usia;

  /// "L" atau "P".
  final String jenisKelamin;

  /// "pemula", "kadang", atau "rutin".
  final String pengalaman;
  final int? tinggiCm;

  /// Subjek sudah membaca lembar informasi dan menandatangani persetujuan.
  final bool setuju;
  final DateTime dibuat;
  final String catatan;

  static const format = 'postur-subjek';
  static const rentangUsia = ['18-24', '25-34', '35-44', '45+'];
  static const tingkatPengalaman = {
    'pemula': 'Pemula',
    'kadang': 'Kadang-kadang',
    'rutin': 'Rutin',
  };

  Map<String, dynamic> keJson() => {
    'format': format,
    'versi': 1,
    'kode': kode,
    'usia': usia,
    'jenis_kelamin': jenisKelamin,
    'pengalaman': pengalaman,
    'tinggi_cm': tinggiCm,
    'persetujuan': setuju,
    'dibuat': dibuat.toIso8601String(),
    'catatan': catatan,
  };

  factory ProfilSubjek.dariJson(Map<String, dynamic> j) => ProfilSubjek(
    kode: j['kode'] as String,
    usia: j['usia'] as String,
    jenisKelamin: j['jenis_kelamin'] as String,
    pengalaman: j['pengalaman'] as String,
    tinggiCm: j['tinggi_cm'] as int?,
    setuju: j['persetujuan'] as bool? ?? false,
    dibuat: DateTime.tryParse(j['dibuat'] as String? ?? '') ?? DateTime(2000),
    catatan: j['catatan'] as String? ?? '',
  );
}

/// Penyimpanan profil subjek dan rencana sesi terpandu.
class DataSubjek {
  static const folder = 'subjek';
  static const folderSesi = 'terpandu';

  static String _path(String kode) => '$folder/subjek-$kode.json';
  static String _pathSesi(String kode) => '$folderSesi/terpandu-$kode.json';

  static Future<void> simpan(ProfilSubjek p) =>
      Penyimpanan.instance.tulis(_path(p.kode), jsonEncode(p.keJson()));

  static Future<ProfilSubjek?> baca(String kode) async {
    final isi = await Penyimpanan.instance.baca(_path(kode));
    return isi == null
        ? null
        : ProfilSubjek.dariJson(jsonDecode(isi) as Map<String, dynamic>);
  }

  static Future<List<ProfilSubjek>> semua() async {
    final hasil = <ProfilSubjek>[];
    for (final n in await Penyimpanan.instance.daftar(folder)) {
      final isi = await Penyimpanan.instance.baca(n);
      if (isi == null) continue;
      try {
        hasil.add(ProfilSubjek.dariJson(jsonDecode(isi) as Map<String, dynamic>));
      } catch (_) {}
    }
    hasil.sort((a, b) => nomorSubjek(a.kode).compareTo(nomorSubjek(b.kode)));
    return hasil;
  }

  /// Path berkas profil, untuk ikut diekspor.
  static Future<List<String>> semuaPath() async => [
    ...await Penyimpanan.instance.daftar(folder),
    ...await Penyimpanan.instance.daftar(folderSesi),
  ];

  /// Kode berikutnya yang belum dipakai: S01, S02, …
  static Future<String> kodeBerikutnya() async {
    final dipakai = {
      for (final p in await semua()) p.kode,
      for (final r in await Rekaman.semua()) r.subjek,
    };
    for (var i = 1; ; i++) {
      final k = 'S${i.toString().padLeft(2, '0')}';
      if (!dipakai.contains(k)) return k;
    }
  }

  static Future<void> simpanSesi(RencanaSesi r) =>
      Penyimpanan.instance.tulis(_pathSesi(r.subjek), jsonEncode(r.keJson()));

  static Future<RencanaSesi?> bacaSesi(String kode) async {
    final isi = await Penyimpanan.instance.baca(_pathSesi(kode));
    return isi == null
        ? null
        : RencanaSesi.dariJson(jsonDecode(isi) as Map<String, dynamic>);
  }

  static Future<List<RencanaSesi>> semuaSesi() async {
    final hasil = <RencanaSesi>[];
    for (final n in await Penyimpanan.instance.daftar(folderSesi)) {
      final isi = await Penyimpanan.instance.baca(n);
      if (isi == null) continue;
      try {
        hasil.add(RencanaSesi.dariJson(jsonDecode(isi) as Map<String, dynamic>));
      } catch (_) {}
    }
    return hasil;
  }

  /// Subjek mengundurkan diri: hapus profil, rencana, dan semua rekamannya.
  static Future<int> hapusSemua(String kode) async {
    var n = 0;
    for (final r in await Rekaman.semua()) {
      if (r.subjek == kode) {
        await Rekaman.hapus(r.path);
        n++;
      }
    }
    await Penyimpanan.instance.hapus(_path(kode));
    await Penyimpanan.instance.hapus(_pathSesi(kode));
    return n;
  }
}
