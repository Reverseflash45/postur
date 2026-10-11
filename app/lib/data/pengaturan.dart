import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferensi pengguna, disimpan di SharedPreferences.
class Pengaturan extends ChangeNotifier {
  Pengaturan._(this._p);

  static late Pengaturan instance;

  static Future<void> muat() async {
    instance = Pengaturan._(await SharedPreferences.getInstance());
  }

  final SharedPreferences _p;

  /// Model pilihan per gerakan; null = pakai yang terbaik menurut validasi.
  String? model(String gerakan) => _p.getString('model_$gerakan');

  Future<void> setModel(String gerakan, String? id) async {
    if (id == null) {
      await _p.remove('model_$gerakan');
    } else {
      await _p.setString('model_$gerakan', id);
    }
    notifyListeners();
  }

  bool get suara => _p.getBool('suara') ?? true;
  set suara(bool v) => _setBool('suara', v);

  bool get kameraDepan => _p.getBool('kamera_depan') ?? false;
  set kameraDepan(bool v) => _setBool('kamera_depan', v);

  bool get infoTeknis => _p.getBool('info_teknis') ?? false;
  set infoTeknis(bool v) => _setBool('info_teknis', v);

  /// Panduan pertama kali sudah dilihat.
  bool get sudahPanduan => _p.getBool('sudah_panduan') ?? false;
  set sudahPanduan(bool v) => _setBool('sudah_panduan', v);

  /// Semua model ikut menilai setiap repetisi (untuk perbandingan).
  bool get bandingkan => _p.getBool('bandingkan') ?? false;
  set bandingkan(bool v) => _setBool('bandingkan', v);

  int get target => _p.getInt('target') ?? 10;
  set target(int v) {
    _p.setInt('target', v);
    notifyListeners();
  }

  int get jumlahSet => _p.getInt('jumlah_set') ?? 3;
  set jumlahSet(int v) {
    _p.setInt('jumlah_set', v);
    notifyListeners();
  }

  /// Lama istirahat antar-set (detik).
  int get istirahat => _p.getInt('istirahat') ?? 60;
  set istirahat(int v) {
    _p.setInt('istirahat', v);
    notifyListeners();
  }

  /// Kode subjek terakhir di mode rekam data.
  String get subjekTerakhir => _p.getString('subjek_terakhir') ?? 'S01';
  set subjekTerakhir(String v) => _p.setString('subjek_terakhir', v);

  /// Latensi pose estimation dari sesi kamera terakhir, untuk layar uji kinerja.
  ({double ms, double fps, String waktu})? get statistikPose {
    final ms = _p.getDouble('pose_ms');
    final fps = _p.getDouble('pose_fps');
    if (ms == null || fps == null) return null;
    return (ms: ms, fps: fps, waktu: _p.getString('pose_waktu') ?? '');
  }

  Future<void> simpanStatistikPose(double ms, double fps) async {
    await _p.setDouble('pose_ms', ms);
    await _p.setDouble('pose_fps', fps);
    await _p.setString('pose_waktu', DateTime.now().toIso8601String());
  }

  void _setBool(String k, bool v) {
    _p.setBool(k, v);
    notifyListeners();
  }
}
