import 'package:flutter_tts/flutter_tts.dart';

/// Umpan balik suara berbahasa Indonesia.
///
/// Saat berlatih, mata tertuju ke lantai, bukan ke layar dua meter jauhnya.
class Suara {
  Suara._();

  static final instance = Suara._();

  final _tts = FlutterTts();
  bool _siap = false;

  Future<void> _siapkan() async {
    if (_siap) return;
    _siap = true;
    try {
      await _tts.setLanguage('id-ID');
      await _tts.setSpeechRate(0.55);
      await _tts.awaitSpeakCompletion(false);
    } catch (_) {
      // Mesin suara tidak tersedia; ucapkan() akan diam saja.
    }
  }

  Future<void> ucapkan(String teks) async {
    await _siapkan();
    try {
      await _tts.stop();
      await _tts.speak(teks);
    } catch (_) {}
  }

  Future<void> diam() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

const _satuan = [
  '',
  'satu',
  'dua',
  'tiga',
  'empat',
  'lima',
  'enam',
  'tujuh',
  'delapan',
  'sembilan',
  'sepuluh',
  'sebelas',
];

/// Angka ke kata, cukup untuk hitungan repetisi (0–999).
String angkaKeKata(int n) {
  if (n <= 0) return 'nol';
  if (n < 12) return _satuan[n];
  if (n < 20) return '${_satuan[n - 10]} belas';
  if (n < 100) {
    final s = n % 10;
    return '${_satuan[n ~/ 10]} puluh${s == 0 ? '' : ' ${_satuan[s]}'}';
  }
  if (n < 1000) {
    final r = n ~/ 100, sisa = n % 100;
    final depan = r == 1 ? 'seratus' : '${_satuan[r]} ratus';
    return sisa == 0 ? depan : '$depan ${angkaKeKata(sisa)}';
  }
  return n.toString();
}
