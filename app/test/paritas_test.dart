import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:postur/inti/fitur.dart';
import 'package:postur/inti/gerakan.dart';
import 'package:postur/inti/klasifikasi/aturan.dart';
import 'package:postur/inti/klasifikasi/hutan.dart';
import 'package:postur/inti/pose.dart';
import 'package:postur/inti/repetisi.dart';

/// Memastikan jalur Dart menghasilkan angka yang sama dengan Python.
///
/// test/fixture/paritas.json dibuat oleh `python -m postur paritas`.
void main() {
  final fixture =
      jsonDecode(File('test/fixture/paritas.json').readAsStringSync()) as Map<String, dynamic>;

  for (final g in semuaGerakan) {
    group(g.nama, () {
      final d = fixture[g.id] as Map<String, dynamic>;
      final sesi = d['sesi'] as Map<String, dynamic>;
      final t = [for (final v in sesi['t'] as List) (v as num).toDouble()];
      final pose = sesi['pose'] as List;
      final lebar = (sesi['lebar'] as num).toDouble();
      final tinggi = (sesi['tinggi'] as num).toDouble();
      final frame = [
        for (var i = 0; i < t.length; i++) FramePose.dariJson(t[i], pose[i] as List?, lebar, tinggi),
      ];

      test('sinyal utama per frame', () {
        final harap = d['sinyal'] as List;
        for (var i = 0; i < frame.length; i++) {
          final s = sinyalUtama(frame[i], g);
          if (harap[i] == null) {
            expect(s, isNull, reason: 'frame $i');
          } else {
            expect(s, closeTo((harap[i] as num).toDouble(), 1e-9), reason: 'frame $i');
          }
        }
      });

      test('potongan repetisi', () {
        final hitung = PenghitungRepetisi(g);
        final hasil = <List<int>>[];
        for (var i = 0; i < frame.length; i++) {
          final p = hitung.proses(i, frame[i].t, sinyalUtama(frame[i], g));
          if (p != null) hasil.add([p.mulai, p.selesai]);
        }
        expect(hasil, [for (final r in d['repetisi'] as List) (r as List).cast<int>()]);
      });

      final contoh = d['contoh'] as List;
      final aturan = KlasifikasiAturan.dariJson(d['model_aturan'] as Map<String, dynamic>, g.kode);
      final hutan = KlasifikasiHutan.dariJson(d['model_hutan'] as Map<String, dynamic>);

      for (var c = 0; c < contoh.length; c++) {
        test('fitur dan prediksi repetisi $c', () {
          final r = contoh[c] as Map<String, dynamic>;
          final f = prosesRepetisi(frame.sublist(r['mulai'] as int, (r['selesai'] as int) + 1), g);
          final seq = r['seq'] as List;
          expect(f.seq.length, seq.length);
          for (var i = 0; i < seq.length; i++) {
            final baris = seq[i] as List;
            for (var k = 0; k < jumlahFitur; k++) {
              expect(f.seq[i][k], closeTo((baris[k] as num).toDouble(), 1e-8),
                  reason: 'seq[$i][$k]');
            }
          }
          final ring = r['ring'] as List;
          for (var k = 0; k < ring.length; k++) {
            expect(f.ring[k], closeTo((ring[k] as num).toDouble(), 1e-8),
                reason: namaRingkasan[k]);
          }
          expect(aturan.prediksi(f).indeks, r['aturan']);
          final p = hutan.proba(f.ring);
          final harap = r['hutan'] as List;
          for (var k = 0; k < p.length; k++) {
            expect(p[k], closeTo((harap[k] as num).toDouble(), 1e-9));
          }
        });
      }
    });
  }
}
