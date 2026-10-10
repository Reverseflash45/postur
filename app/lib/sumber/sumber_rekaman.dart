import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../inti/pose.dart';
import 'sumber_pose.dart';

/// Memutar ulang berkas sesi dengan kecepatan aslinya.
///
/// Dipakai untuk mode demo (tanpa kamera) dan untuk memutar rekaman data.
class SumberRekaman extends SumberPose {
  SumberRekaman(this.frame, {this.ulang = true});

  static Future<SumberRekaman> dariAset(
    String path, {
    bool ulang = true,
  }) async {
    final js =
        jsonDecode(await rootBundle.loadString(path)) as Map<String, dynamic>;
    return SumberRekaman(bacaFrame(js), ulang: ulang);
  }

  static List<FramePose> bacaFrame(Map<String, dynamic> js) {
    final t = js['t'] as List;
    final pose = js['pose'] as List;
    final lebar = (js['lebar'] as num? ?? 720).toDouble();
    final tinggi = (js['tinggi'] as num? ?? 1280).toDouble();
    return [
      for (var i = 0; i < t.length; i++)
        FramePose.dariJson(
          (t[i] as num).toDouble(),
          pose[i] as List?,
          lebar,
          tinggi,
        ),
    ];
  }

  final List<FramePose> frame;
  final bool ulang;

  final _aliran = StreamController<FramePose>.broadcast();
  Timer? _timer;
  final _jam = Stopwatch();
  int _i = 0;
  double _geser = 0;

  @override
  String get nama => 'demo';

  @override
  Stream<FramePose> get aliran => _aliran.stream;

  @override
  Future<void> mulai() async {
    _jam
      ..reset()
      ..start();
    _i = 0;
    _geser = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) => _detak());
  }

  void _detak() {
    if (frame.isEmpty) return;
    final sekarang = _jam.elapsedMicroseconds / 1000.0;
    final awal = frame.first.t;
    while (_i < frame.length && frame[_i].t - awal + _geser <= sekarang) {
      final f = frame[_i];
      // Waktu dibuat terus naik saat rekaman diulang.
      _aliran.add(
        FramePose(
          t: f.t - awal + _geser,
          x: f.x,
          y: f.y,
          v: f.v,
          lebar: f.lebar,
          tinggi: f.tinggi,
        ),
      );
      _i++;
    }
    if (_i >= frame.length) {
      if (!ulang) {
        _timer?.cancel();
        return;
      }
      _geser += frame.last.t - awal + 500;
      _i = 0;
    }
  }

  @override
  Future<void> berhenti() async {
    _timer?.cancel();
    _jam.stop();
  }

  @override
  Future<void> dispose() async {
    await berhenti();
    await _aliran.close();
  }
}
