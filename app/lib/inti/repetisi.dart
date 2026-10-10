import 'dart:math' as math;

import 'fitur.dart';
import 'gerakan.dart';
import 'pose.dart';
import 'sinyal.dart';

/// Penghitung repetisi — salinan ml/postur/repetisi.py.

/// Rerata sudut sendi utama kiri dan kanan yang terlihat; null bila tidak ada.
double? sinyalUtama(FramePose f, Gerakan g) {
  var total = 0.0;
  var n = 0;
  for (final s in g.sendiUtama) {
    final a = s[0], b = s[1], c = s[2];
    if (math.min(f.v[a], math.min(f.v[b], f.v[c])) >= ambangVis) {
      total += sudut(f.x[a], f.y[a], f.x[b], f.y[b], f.x[c], f.y[c]);
      n += 1;
    }
  }
  return n > 0 ? total / n : null;
}

class KonfigRepetisi {
  const KonfigRepetisi({
    this.ambangMulai = 25,
    this.ambangSelesai = 15,
    required this.romMin,
    this.alfa = 0.5,
    this.batasMs = 8000,
  });

  final double ambangMulai;
  final double ambangSelesai;
  final double romMin;
  final double alfa;
  final double batasMs;
}

/// Potongan satu repetisi (indeks frame, inklusif).
class Potongan {
  const Potongan(this.mulai, this.selesai, this.rom);

  final int mulai;
  final int selesai;

  /// Rentang gerak sinyal utama yang sudah dihaluskan (derajat).
  final double rom;
}

class PenghitungRepetisi {
  PenghitungRepetisi(Gerakan g, {KonfigRepetisi? konfig})
    : k = konfig ?? KonfigRepetisi(romMin: g.romMin);

  final KonfigRepetisi k;

  double? halus;
  bool turun = false;
  double? puncak;
  double minimum = 0;
  int _iTepi = 0;
  double _tTepi = 0;
  int _iMulai = 0;
  double _tMulai = 0;

  void reset() {
    halus = null;
    turun = false;
    puncak = null;
    minimum = 0;
    _iTepi = 0;
    _tTepi = 0;
  }

  Potongan? proses(int i, double t, double? nilai) {
    if (nilai == null) return null;
    final h = halus;
    final s = h == null ? nilai : k.alfa * nilai + (1.0 - k.alfa) * h;
    halus = s;

    if (!turun) {
      if (puncak == null || s > puncak!) puncak = s;
      if (s >= puncak! - k.ambangSelesai) {
        _iTepi = i;
        _tTepi = t;
      }
      if (s < puncak! - k.ambangMulai) {
        turun = true;
        minimum = s;
        _iMulai = _iTepi;
        _tMulai = _tTepi;
      }
      return null;
    }

    if (s < minimum) minimum = s;
    if (t - _tMulai > k.batasMs) {
      _kembaliKeAtas(i, t, s);
      return null;
    }
    if (s >= puncak! - k.ambangSelesai) {
      final rom = puncak! - minimum;
      final hasil = rom >= k.romMin ? Potongan(_iMulai, i, rom) : null;
      _kembaliKeAtas(i, t, s);
      return hasil;
    }
    return null;
  }

  void _kembaliKeAtas(int i, double t, double s) {
    turun = false;
    puncak = s;
    _iTepi = i;
    _tTepi = t;
  }
}
