import 'dart:async';

import 'package:flutter/widgets.dart';

import '../inti/pose.dart';

/// Asal frame pose: kamera + ML Kit, atau rekaman yang diputar ulang.
abstract class SumberPose {
  Stream<FramePose> get aliran;

  Future<void> mulai();

  Future<void> berhenti();

  /// Pratinjau kamera, atau null bila tidak ada (mode demo).
  Widget? pratinjau() => null;

  /// Pratinjau dicerminkan (kamera depan), jadi kerangka juga dicerminkan.
  bool get cermin => false;

  /// Rerata waktu pose estimation per frame (ms), bila diukur.
  double? get msPose => null;

  /// Frame per detik yang benar-benar diproses.
  double? get fps => null;

  /// Pesan galat bila pose estimation terus gagal; null bila normal.
  String? get galat => null;

  /// Keterangan sumber untuk berkas sesi ('mlkit-accurate', 'demo', ...).
  String get nama;

  Future<void> dispose();
}
