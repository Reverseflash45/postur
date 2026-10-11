import 'package:flutter_test/flutter_test.dart';
import 'package:postur/inti/gerakan.dart';
import 'package:postur/inti/protokol.dart';

void main() {
  test('bujur sangkar Williams 4x4 seimbang posisi dan urutan berdampingan', () {
    const n = 4;
    final baris = [for (var r = 0; r < n; r++) barisWilliams(n, r)];
    expect(baris.first, [0, 1, 3, 2]);
    // Tiap kelas sekali di tiap posisi.
    for (var p = 0; p < n; p++) {
      expect({for (final b in baris) b[p]}.length, n);
    }
    // Tiap pasangan berurutan (a lalu b) muncul tepat sekali.
    final pasangan = <String, int>{};
    for (final b in baris) {
      for (var i = 0; i < n - 1; i++) {
        pasangan.update('${b[i]}>${b[i + 1]}', (v) => v + 1, ifAbsent: () => 1);
      }
    }
    expect(pasangan.length, n * (n - 1));
    expect(pasangan.values.every((v) => v == 1), isTrue);
  });

  test('n ganjil memakai 2n baris dengan baris cermin', () {
    final b0 = barisWilliams(3, 0);
    expect(barisWilliams(3, 3), b0.reversed.toList());
    for (var r = 0; r < 6; r++) {
      expect(barisWilliams(3, r).toSet(), {0, 1, 2});
    }
  });

  test('nomor subjek dari kode', () {
    expect(nomorSubjek('S03'), 3);
    expect(nomorSubjek('P12'), 12);
    expect(nomorSubjek('ANA'), nomorSubjek('ANA'));
  });

  test('rencana menggilir gerakan pertama dan menyimpan target', () {
    final a = RencanaSesi.buat(subjek: 'S01', gerakan: [squat, pushup], target: 10);
    final b = RencanaSesi.buat(subjek: 'S02', gerakan: [squat, pushup], target: 8);
    expect(a.langkah, hasLength(8));
    expect(a.langkah.first.gerakan, 'squat');
    expect(b.langkah.first.gerakan, 'pushup');
    expect(b.langkah.every((l) => l.target == 8), isTrue);
    // Subjek berbeda, urutan kelas squat berbeda.
    final urutA = [for (final l in a.langkah.where((l) => l.gerakan == 'squat')) l.kelas];
    final urutB = [for (final l in b.langkah.where((l) => l.gerakan == 'squat')) l.kelas];
    expect(urutA, ['SQ-0', 'SQ-1', 'SQ-3', 'SQ-2']);
    expect(urutB, isNot(urutA));
    expect(urutB.toSet(), urutA.toSet());
  });

  test('kemajuan dan JSON pulang-pergi', () {
    final r = RencanaSesi.buat(subjek: 'S05', gerakan: [squat], target: 10);
    expect(r.berikutnya, 0);
    r.langkah[0]
      ..path = 'rekaman/x.json'
      ..repetisi = 10;
    r.langkah[1].dilewati = true;
    expect(r.berikutnya, 2);
    expect(r.jumlahSelesai, 1);
    expect(r.jumlahTuntas, 2);
    final balik = RencanaSesi.dariJson(r.keJson());
    expect(balik.subjek, 'S05');
    expect(balik.langkah[0].repetisi, 10);
    expect(balik.langkah[1].dilewati, isTrue);
    expect(balik.barisUrutan, 4);
    expect(balik.tamat, isFalse);
  });

  test('setiap kelas punya cara peragaan', () {
    for (final g in semuaGerakan) {
      for (final k in g.kelas) {
        expect(caraPeragaan[k.kode], isNotNull, reason: k.kode);
      }
    }
  });
}
