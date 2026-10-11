import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:postur/data/suara.dart';
import 'package:postur/inti/fitur.dart';
import 'package:postur/inti/gerakan.dart';
import 'package:postur/inti/klasifikasi/klasifikasi.dart';
import 'package:postur/inti/mesin_latihan.dart';
import 'package:postur/inti/pose.dart';
import 'package:postur/sumber/sumber_rekaman.dart';

/// Klasifikasi palsu yang selalu memilih kelas tertentu.
class _Tetap extends Pengklasifikasi {
  _Tetap(this.kelas);

  final int kelas;

  @override
  String get id => 'tetap';

  @override
  Prediksi prediksi(FiturRepetisi f) => Prediksi(kelas, [for (var i = 0; i < 4; i++) i == kelas ? 1 : 0]);
}

List<FramePose> _demo(String id) => SumberRekaman.bacaFrame(
      jsonDecode(File('assets/demo/$id.json').readAsStringSync()) as Map<String, dynamic>,
    );

void main() {
  test('rekaman demo squat menghasilkan 8 repetisi', () {
    final m = MesinLatihan(gerakan: squat, klasifikasi: _Tetap(2));
    final dinilai = <HasilRepetisi>[];
    m.diRepetisi = dinilai.add;
    _demo('squat').forEach(m.masukkan);
    expect(m.jumlah, 8);
    expect(dinilai.length, 8);
    expect(m.sebaran, [0, 0, 8, 0]);
    expect(m.hasil.every((h) => h.rom > squat.romMin), isTrue);
  });

  test('rekaman demo push-up menghasilkan 8 repetisi', () {
    final m = MesinLatihan(gerakan: pushup, klasifikasi: _Tetap(0));
    _demo('pushup').forEach(m.masukkan);
    expect(m.jumlah, 8);
    expect(m.jumlahBenar, 8);
  });

  test('mode rekam menyimpan semua frame tanpa klasifikasi', () {
    final frame = _demo('squat');
    final m = MesinLatihan(gerakan: squat, rekamSemua: true);
    frame.forEach(m.masukkan);
    expect(m.semuaFrame.length, frame.length);
    expect(m.hasil.every((h) => h.kelas == -1), isTrue);
  });

  test('frame kosong sesaat tidak mengubah status siap maupun kerangka', () {
    final frame = _demo('squat');
    final m = MesinLatihan(gerakan: squat);
    for (final f in frame.take(30)) {
      m.masukkan(f);
    }
    expect(m.kesiapan, Kesiapan.siap);
    final penuh = m.terakhir;
    final t = frame[29].t;
    m.masukkan(FramePose.kosong(t + 30, 720, 1280));
    expect(m.kesiapan, Kesiapan.siap);
    expect(m.terakhir, same(penuh));
    // Kosong terus lebih dari 0,6 detik: barulah pesan muncul.
    for (var k = 2; k < 30; k++) {
      m.masukkan(FramePose.kosong(t + 30.0 * k, 720, 1280));
    }
    expect(m.kesiapan, Kesiapan.tidakAdaOrang);
  });

  test('angka diucapkan dalam bahasa Indonesia', () {
    expect(angkaKeKata(1), 'satu');
    expect(angkaKeKata(11), 'sebelas');
    expect(angkaKeKata(15), 'lima belas');
    expect(angkaKeKata(20), 'dua puluh');
    expect(angkaKeKata(37), 'tiga puluh tujuh');
    expect(angkaKeKata(100), 'seratus');
    expect(angkaKeKata(112), 'seratus dua belas');
  });

  test('jeda tidak mencatat repetisi; mulaiHitung memulai set baru', () {
    final frame = _demo('squat');
    final m = MesinLatihan(gerakan: squat, klasifikasi: _Tetap(0), aktif: false);
    final separuh = frame.length ~/ 2;
    for (final f in frame.take(separuh)) {
      m.masukkan(f);
    }
    expect(m.jumlah, 0);
    m.mulaiHitung(set: 2);
    for (final f in frame.skip(separuh)) {
      m.masukkan(f);
    }
    expect(m.jumlah, greaterThan(0));
    expect(m.hasil.every((h) => h.set == 2), isTrue);
    expect(m.jumlahSetIni, m.jumlah);
  });

  test('tempo, pose putar ulang, dan pendapat model pembanding tersimpan', () {
    final m = MesinLatihan(gerakan: squat, klasifikasi: _Tetap(0), pembanding: [_TetapLain(2)]);
    _demo('squat').forEach(m.masukkan);
    final h = m.hasil.first;
    expect(h.pose.length, langkahPutar * 24);
    expect(h.kurva.length, langkahPutar);
    final t = h.tempo!;
    expect(t.turun + t.naik, closeTo(h.durasi, 1e-9));
    expect(t.turun, greaterThan(0));
    expect(h.pendapat, {'lain': 2});
    expect(h.skor, 100);
    final balik = HasilRepetisi.dariJson(jsonDecode(jsonEncode(h.keJson())) as Map<String, dynamic>);
    expect(balik.pendapat, {'lain': 2});
    expect(balik.kurva.length, langkahPutar);
    expect(balik.set, h.set);
  });

  test('catatan lama tanpa pose, kurva, dan pendapat tetap terbaca', () {
    final h = HasilRepetisi.dariJson({
      'nomor': 1, 'kelas': 1, 'peluang': [0.2, 0.8, 0, 0], 'durasi': 1.5, 'rom': 70,
    });
    expect(h.pose, isEmpty);
    expect(h.tempo, isNull);
    expect(h.pendapat, isEmpty);
    expect(h.skor, 20);
  });
}

class _TetapLain extends _Tetap {
  _TetapLain(super.kelas);

  @override
  String get id => 'lain';
}
