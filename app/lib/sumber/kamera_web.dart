import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../inti/pose.dart';
import 'sumber_pose.dart';

const bool kameraTersedia = true;

/// Perekaman data penelitian tetap hanya di Android: data latih harus berasal
/// dari pose estimator yang sama dengan aplikasi (ML Kit), bukan MediaPipe web.
const bool bisaRekamData = false;

@JS('posturPose')
external _PosturPose get _pose;

extension type _PosturPose._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> siapkan();
  external JSString delegasi();
  external JSFloat64Array? deteksi(web.HTMLVideoElement video, double ms);
}

/// Webcam + MediaPipe Pose Landmarker (model full) untuk versi web.
///
/// Padanan [SumberKamera] di Android: landmark BlazePose 33 titik dalam
/// piksel gambar, jadi fitur, segmentasi, dan model yang sama bisa dipakai.
/// Frame diproses sekali per frame video baru lewat requestAnimationFrame.
class SumberKamera extends SumberPose {
  SumberKamera({required this.depan}) : _jenis = 'postur-kamera-${_n++}' {
    _video = web.document.createElement('video') as web.HTMLVideoElement
      ..autoplay = true
      ..muted = true
      ..playsInline = true;
    _video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'cover'
      ..transform = depan ? 'scaleX(-1)' : '';
    final video = _video;
    ui_web.platformViewRegistry.registerViewFactory(_jenis, (int _) => video);
  }

  static int _n = 0;

  final bool depan;
  final String _jenis;
  late final web.HTMLVideoElement _video;
  web.MediaStream? _aliranMedia;
  final _aliran = StreamController<FramePose>.broadcast();
  final _jam = Stopwatch();
  bool _jalan = false;
  bool _siap = false;
  double _waktuVideo = -1;
  double _msTerakhir = 0;

  double _totalMs = 0;
  int _nPose = 0;
  int _nDetik = 0;
  int _awalDetik = 0;
  double? _fps;
  int _gagalBeruntun = 0;
  String? _galat;
  String _delegasi = '';

  @override
  String get nama =>
      'mediapipe-web-full${_delegasi.isEmpty ? '' : '-$_delegasi'}';

  @override
  Stream<FramePose> get aliran => _aliran.stream;

  @override
  bool get cermin => depan;

  @override
  double? get msPose => _nPose == 0 ? null : _totalMs / _nPose;

  @override
  double? get fps => _fps;

  @override
  String? get galat => _gagalBeruntun >= 10 ? _galat : null;

  @override
  Widget? pratinjau() => _siap ? HtmlElementView(viewType: _jenis) : null;

  @override
  Future<void> mulai() async {
    final md = web.window.navigator.mediaDevices;
    final batasan = web.MediaStreamConstraints(
      audio: false.toJS,
      video: {
        'facingMode': depan ? 'user' : 'environment',
        'width': {'ideal': 640},
        'height': {'ideal': 480},
      }.jsify()!,
    );
    // Izin kamera dan model pose dimuat bersamaan supaya tidak menunggu dua kali.
    final media = md.getUserMedia(batasan).toDart;
    final model = _pose.siapkan().toDart;
    final aliranMedia = await media;
    _aliranMedia = aliranMedia;
    try {
      await model;
    } catch (e) {
      _matikanMedia();
      throw StateError(
        'Model pose tidak bisa dimuat. Periksa koneksi internet. ($e)',
      );
    }
    _delegasi = _pose.delegasi().toDart;
    _video.srcObject = aliranMedia;
    await _video.play().toDart;
    _siap = true;
    _jalan = true;
    _jam.start();
    _putar();
  }

  void _putar() {
    if (!_jalan) return;
    web.window.requestAnimationFrame(
      ((JSNumber _) {
        _olah();
        _putar();
      }).toJS,
    );
  }

  void _olah() {
    final wv = _video.currentTime;
    // Tanpa frame video baru, hasilnya pasti sama; lewati.
    if (wv == _waktuVideo || _video.videoWidth == 0) return;
    _waktuVideo = wv;
    final t = _jam.elapsedMicroseconds / 1000.0;
    // MediaPipe menolak stempel waktu yang tidak naik.
    final ms = t <= _msTerakhir ? _msTerakhir + 0.01 : t;
    _msTerakhir = ms;
    try {
      final sw = Stopwatch()..start();
      final hasil = _pose.deteksi(_video, ms);
      _catat(sw.elapsedMicroseconds / 1000.0, t);
      final f = FramePose.kosong(
        t,
        _video.videoWidth.toDouble(),
        _video.videoHeight.toDouble(),
      );
      if (hasil != null) {
        final a = hasil.toDart;
        for (var j = 0; j < 33; j++) {
          f.x[j] = a[3 * j];
          f.y[j] = a[3 * j + 1];
          f.v[j] = a[3 * j + 2];
        }
      }
      if (!_aliran.isClosed) _aliran.add(f);
      _gagalBeruntun = 0;
    } catch (e) {
      _gagalBeruntun++;
      _galat = '$e';
    }
  }

  void _catat(double ms, double t) {
    _totalMs += ms;
    _nPose++;
    _nDetik++;
    final detik = (t / 1000).floor();
    if (detik != _awalDetik) {
      _fps = _nDetik / (detik - _awalDetik);
      _nDetik = 0;
      _awalDetik = detik;
    }
  }

  void _matikanMedia() {
    final s = _aliranMedia;
    if (s == null) return;
    for (final trek in s.getTracks().toDart) {
      trek.stop();
    }
    _aliranMedia = null;
  }

  @override
  Future<void> berhenti() async {
    _jalan = false;
  }

  @override
  Future<void> dispose() async {
    _jalan = false;
    _matikanMedia();
    _video
      ..pause()
      ..srcObject = null;
    await _aliran.close();
  }
}
