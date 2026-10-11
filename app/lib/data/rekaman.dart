import 'dart:convert';

import 'package:flutter/services.dart';

import '../inti/pose.dart';
import 'penyimpanan.dart';

/// Ringkasan satu berkas sesi rekaman data (tanpa memuat semua frame).
class InfoRekaman {
  InfoRekaman({
    required this.path,
    required this.id,
    required this.subjek,
    required this.gerakan,
    required this.label,
    required this.repetisi,
    required this.repetisiOtomatis,
    required this.detik,
    required this.dibuat,
    required this.ukuran,
    this.ditinjau = 0,
    this.labelRep = const [],
  });

  final String path;
  final String id;
  final String subjek;
  final String gerakan;
  final String label;
  final int? repetisi;
  final int? repetisiOtomatis;
  final double detik;
  final DateTime dibuat;
  final int ukuran;

  /// Jumlah repetisi yang labelnya diubah atau dibuang di layar Tinjau.
  final int ditinjau;

  /// Label per repetisi dari tinjauan (null = label set, 'BUANG').
  final List<String?> labelRep;

  /// Jumlah repetisi per label setelah tinjauan; tanpa tinjauan semua
  /// repetisi (hitungan manual) masuk ke label set.
  Map<String, int> get sebaranLabel {
    if (labelRep.isEmpty) return {label: repetisi ?? repetisiOtomatis ?? 0};
    final hasil = <String, int>{};
    for (final l in labelRep) {
      final efektif = l ?? label;
      if (efektif == 'BUANG') continue;
      hasil[efektif] = (hasil[efektif] ?? 0) + 1;
    }
    return hasil;
  }
}

/// Berkas sesi berformat sama dengan ml/postur/data.py (format "postur-sesi").
class Rekaman {
  static const folder = 'rekaman';

  static String buatId(
    String subjek,
    String gerakan,
    String label,
    DateTime w,
  ) {
    String dua(int n) => n.toString().padLeft(2, '0');
    final cap =
        '${w.year}${dua(w.month)}${dua(w.day)}T${dua(w.hour)}${dua(w.minute)}${dua(w.second)}';
    return '$subjek-$gerakan-$label-$cap';
  }

  static Future<String> simpan({
    required String subjek,
    required String gerakan,
    required String label,
    required int repetisiManual,
    required int repetisiOtomatis,
    required List<FramePose> frame,
    required String sumberPose,
    required String kamera,
    String catatan = '',
  }) async {
    final w = DateTime.now();
    final id = buatId(subjek, gerakan, label, w);
    final lebar = frame.isEmpty ? 0.0 : frame.first.lebar;
    final tinggi = frame.isEmpty ? 0.0 : frame.first.tinggi;
    final js = {
      'format': 'postur-sesi',
      'versi': 1,
      'id': id,
      'subjek': subjek,
      'gerakan': gerakan,
      'label': label,
      'repetisi_manual': repetisiManual,
      'repetisi_otomatis': repetisiOtomatis,
      'sumber_pose': sumberPose,
      'kamera': kamera,
      'lebar': lebar,
      'tinggi': tinggi,
      'dibuat': w.toIso8601String(),
      'catatan': catatan,
      't': [for (final f in frame) double.parse(f.t.toStringAsFixed(1))],
      'pose': [for (final f in frame) f.keJson()],
    };
    final path = '$folder/$id.json';
    await Penyimpanan.instance.tulis(path, jsonEncode(js));
    return path;
  }

  static Future<List<InfoRekaman>> semua() async {
    final hasil = <InfoRekaman>[];
    for (final n in await Penyimpanan.instance.daftar(folder)) {
      final isi = await Penyimpanan.instance.baca(n);
      if (isi == null) continue;
      try {
        final js = jsonDecode(isi) as Map<String, dynamic>;
        final t = js['t'] as List;
        hasil.add(
          InfoRekaman(
            path: n,
            id: js['id'] as String,
            subjek: js['subjek'] as String,
            gerakan: js['gerakan'] as String,
            label: js['label'] as String,
            repetisi: js['repetisi_manual'] as int?,
            repetisiOtomatis: js['repetisi_otomatis'] as int?,
            detik: t.isEmpty ? 0 : ((t.last as num) - (t.first as num)) / 1000,
            dibuat:
                DateTime.tryParse(js['dibuat'] as String? ?? '') ??
                DateTime(2000),
            ukuran: isi.length,
            ditinjau: (js['label_rep'] as List? ?? const [])
                .where((l) => l != null)
                .length,
            labelRep: (js['label_rep'] as List? ?? const []).cast<String?>(),
          ),
        );
      } catch (_) {
        // Lewati berkas yang rusak.
      }
    }
    hasil.sort((a, b) => b.dibuat.compareTo(a.dibuat));
    return hasil;
  }

  static Future<void> hapus(String path) => Penyimpanan.instance.hapus(path);

  /// Salin rekaman demo bawaan ke daftar rekaman, untuk mencoba alur
  /// tinjau dan ekspor tanpa merekam orang sungguhan.
  static Future<void> imporContoh() async {
    for (final g in ['squat', 'pushup']) {
      final js = jsonDecode(
        await rootBundle.loadString('assets/demo/$g.json'),
      ) as Map<String, dynamic>;
      js['subjek'] = 'CONTOH';
      js['id'] = 'CONTOH-$g';
      js['repetisi_manual'] = (js['label_rep'] as List?)?.length;
      js['repetisi_otomatis'] = js['repetisi_manual'];
      js['dibuat'] = DateTime.now().toIso8601String();
      // label_rep demo berisi label sebenarnya tiap repetisi; dikosongkan
      // supaya tinjauan dimulai dari label set, seperti rekaman asli.
      js['label_rep_asli'] = js.remove('label_rep');
      await Penyimpanan.instance.tulis(
        '$folder/CONTOH-$g.json',
        jsonEncode(js),
      );
    }
  }

  /// Isi lengkap berkas sesi.
  static Future<Map<String, dynamic>?> baca(String path) async {
    final isi = await Penyimpanan.instance.baca(path);
    return isi == null ? null : jsonDecode(isi) as Map<String, dynamic>;
  }

  /// Simpan label per repetisi hasil tinjauan. null = ikut label set,
  /// 'BUANG' = repetisi tidak dipakai. Dibaca ml/postur/data.py.
  static Future<void> simpanLabel(String path, List<String?> labelRep) async {
    final js = await baca(path);
    if (js == null) return;
    js['label_rep'] = labelRep.every((l) => l == null) ? null : labelRep;
    await Penyimpanan.instance.tulis(path, jsonEncode(js));
  }
}
