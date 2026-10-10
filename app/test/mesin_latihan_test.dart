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
}
