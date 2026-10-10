import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import 'fitur.dart';
import 'gerakan.dart';
import 'klasifikasi/aturan.dart';
import 'klasifikasi/hutan.dart';
import 'klasifikasi/klasifikasi.dart';
import 'klasifikasi/tflite.dart';

/// Semua model satu gerakan dari `assets/model/<gerakan>/`, hasil
/// `python -m postur latih`.
class PaketModel {
  PaketModel._(this.gerakan, this.meta);

  static final Map<String, Future<PaketModel>> _cache = {};

  static Future<PaketModel> muat(Gerakan g) =>
      _cache.putIfAbsent(g.id, () async {
        final meta = jsonDecode(
          await rootBundle.loadString('${_folder(g)}/meta.json'),
        ) as Map<String, dynamic>;
        return PaketModel._(g, meta);
      });

  static String _folder(Gerakan g) => 'assets/model/${g.id}';

  final Gerakan gerakan;
  final Map<String, dynamic> meta;
  final Map<String, Pengklasifikasi> _siap = {};
  final Map<String, int> _ukuran = {};

  bool get sintetis => meta['sumber_data'] == 'sintetis';
  String get dibuat => meta['dibuat'] as String? ?? '';
  int get nRepetisi => meta['n_repetisi'] as int? ?? 0;
  int get nSubjek => meta['n_subjek'] as int? ?? 0;

  /// Model yang bisa dijalankan di platform ini.
  List<String> get tersedia => [
    for (final id in urutanModel)
      if (tfliteTersedia || id == 'aturan' || id == 'rf') id,
  ];

  /// Macro-F1 validasi silang per model (dari pelatihan).
  double? f1(String id) {
    final m = meta['macro_f1_validasi'] as Map<String, dynamic>? ?? {};
    final kunci = switch (id) {
      'cnn' => 'cnn_tfl',
      'lstm' => 'lstm_tfl',
      _ => id,
    };
    return (m[kunci] ?? m[id] as num?)?.toDouble();
  }

  /// Model dengan macro-F1 validasi tertinggi di antara yang tersedia.
  String get terbaik {
    var pilih = tersedia.first;
    for (final id in tersedia) {
      if ((f1(id) ?? 0) > (f1(pilih) ?? 0)) pilih = id;
    }
    return pilih;
  }

  String _berkas(String id) =>
      (meta['berkas'] as Map<String, dynamic>)[id] as String;

  Future<Uint8List> _bytes(String id) async {
    final b = await rootBundle.load('${_folder(gerakan)}/${_berkas(id)}');
    final hasil = b.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
    _ukuran[id] = hasil.length;
    return hasil;
  }

  int? ukuran(String id) => _ukuran[id];

  Future<Pengklasifikasi> buat(String id) async {
    final ada = _siap[id];
    if (ada != null) return ada;
    final Pengklasifikasi m;
    switch (id) {
      case 'aturan':
        final js =
            jsonDecode(utf8.decode(await _bytes(id))) as Map<String, dynamic>;
        m = KlasifikasiAturan.dariJson(js, gerakan.kode);
      case 'rf':
        final js =
            jsonDecode(utf8.decode(await _bytes(id))) as Map<String, dynamic>;
        m = KlasifikasiHutan.dariJson(js);
      default:
        final jenis = id.split('_').first;
        final st =
            (meta['standarisasi'] as Map<String, dynamic>)[jenis]
                as Map<String, dynamic>;
        m = buatTflite(
          id,
          await _bytes(id),
          rerata: [for (final v in st['rerata'] as List) (v as num).toDouble()],
          sb: [for (final v in st['sb'] as List) (v as num).toDouble()],
        );
    }
    _siap[id] = m;
    return m;
  }

  /// Repetisi contoh beserta keluaran Python, untuk uji kinerja dan kesetiaan.
  Future<List<ContohRepetisi>> contoh() async {
    final js = jsonDecode(
      await rootBundle.loadString('${_folder(gerakan)}/contoh.json'),
    ) as List;
    return [
      for (final c in js)
        ContohRepetisi.dariJson(c as Map<String, dynamic>, gerakan),
    ];
  }
}

class ContohRepetisi {
  ContohRepetisi.dariJson(Map<String, dynamic> js, Gerakan g)
    : label = js['label'] as String,
      fitur = FiturRepetisi(
        [
          for (final r in js['seq'] as List)
            Float64List.fromList([
              for (final v in r as List) (v as num).toDouble(),
            ]),
        ],
        Float64List.fromList([
          for (final v in js['ring'] as List) (v as num).toDouble(),
        ]),
        0,
      ),
      harapAturan = g.indeks(js['aturan'] as String),
      harap = {
        for (final id in ['rf', 'cnn', 'lstm'])
          if (js[id] != null)
            id: [for (final v in js[id] as List) (v as num).toDouble()],
      };

  final String label;
  final FiturRepetisi fitur;
  final int harapAturan;

  /// Peluang keluaran Python per model ('rf', 'cnn', 'lstm').
  final Map<String, List<double>> harap;
}
