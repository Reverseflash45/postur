import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../inti/pose.dart';
import 'sumber_pose.dart';

const bool kameraTersedia = true;

/// Data penelitian hanya direkam dengan pose estimator aplikasi (ML Kit).
const bool bisaRekamData = true;

/// Kamera ponsel + ML Kit Pose Detection (model accurate, mode stream).
///
/// Frame yang datang saat frame sebelumnya masih diproses dilewati, jadi
/// laju frame mengikuti kecepatan pose estimation di perangkat.
class SumberKamera extends SumberPose {
  SumberKamera({required this.depan});

  final bool depan;

  CameraController? _c;
  CameraDescription? _kamera;
  final _detektor = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.accurate,
    ),
  );
  final _aliran = StreamController<FramePose>.broadcast();
  final _jam = Stopwatch();
  bool _sibuk = false;
  bool _berhenti = false;

  double _totalMs = 0;
  int _nPose = 0;
  int _nDetik = 0;
  int _awalDetik = 0;
  double? _fps;
  int _gagalBeruntun = 0;
  String? _galat;

  static const _orientasi = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  String get nama => 'mlkit-accurate';

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
  Widget? pratinjau() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return null;
    return CameraPreview(c);
  }

  @override
  Future<void> mulai() async {
    final semua = await availableCameras();
    if (semua.isEmpty) throw StateError('Tidak ada kamera');
    final arah = depan ? CameraLensDirection.front : CameraLensDirection.back;
    final kamera = semua.firstWhere(
      (k) => k.lensDirection == arah,
      orElse: () => semua.first,
    );
    final c = CameraController(
      kamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );
    await c.initialize();
    _kamera = kamera;
    _c = c;
    _jam.start();
    await c.startImageStream(_olah);
  }

  Future<void> _olah(CameraImage img) async {
    if (_sibuk || _berhenti) return;
    _sibuk = true;
    final t = _jam.elapsedMicroseconds / 1000.0;
    try {
      final rotasi = _rotasi();
      if (rotasi == null) return;
      final masuk = _inputImage(img, rotasi);
      if (masuk == null) return;
      final sw = Stopwatch()..start();
      final hasil = await _detektor.processImage(masuk);
      _catat(sw.elapsedMicroseconds / 1000.0, t);

      final tegak = rotasi == 90 || rotasi == 270;
      final f = FramePose.kosong(
        t,
        (tegak ? img.height : img.width).toDouble(),
        (tegak ? img.width : img.height).toDouble(),
      );
      if (hasil.isNotEmpty) {
        for (final lm in hasil.first.landmarks.values) {
          final j = lm.type.index;
          f.x[j] = lm.x;
          f.y[j] = lm.y;
          f.v[j] = lm.likelihood;
        }
      }
      if (!_aliran.isClosed) _aliran.add(f);
      _gagalBeruntun = 0;
    } catch (e) {
      // Satu frame gagal tidak boleh menghentikan latihan, tapi kegagalan
      // beruntun ditampilkan supaya tidak terlihat seperti "tidak ada orang".
      _gagalBeruntun++;
      _galat = '$e';
    } finally {
      _sibuk = false;
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

  /// Rotasi yang membuat gambar sensor tegak, mengikuti contoh resmi ML Kit.
  int? _rotasi() {
    final c = _c, k = _kamera;
    if (c == null || k == null) return null;
    final komp = _orientasi[c.value.deviceOrientation];
    if (komp == null) return null;
    return k.lensDirection == CameraLensDirection.front
        ? (k.sensorOrientation + komp) % 360
        : (k.sensorOrientation - komp + 360) % 360;
  }

  InputImage? _inputImage(CameraImage img, int rotasi) {
    final rot = InputImageRotationValue.fromRawValue(rotasi);
    final format = InputImageFormatValue.fromRawValue(img.format.raw);
    if (rot == null || format == null || img.planes.length != 1) return null;
    final plane = img.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(img.width.toDouble(), img.height.toDouble()),
        rotation: rot,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  Future<void> berhenti() async {
    _berhenti = true;
    final c = _c;
    if (c != null && c.value.isStreamingImages) {
      await c.stopImageStream();
    }
  }

  @override
  Future<void> dispose() async {
    await berhenti();
    await _c?.dispose();
    _c = null;
    await _detektor.close();
    await _aliran.close();
  }
}
