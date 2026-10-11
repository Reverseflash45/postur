import 'package:web/web.dart' as web;

/// Penyimpanan versi web: localStorage peramban, jadi riwayat latihan tetap
/// ada setelah halaman dimuat ulang. Bila localStorage tidak bisa dipakai
/// (mode privat, kuota penuh), isi disimpan di memori saja.
class Penyimpanan {
  Penyimpanan._();

  static final instance = Penyimpanan._();

  static const bisaEkspor = false;

  static const _awalan = 'postur:';

  final Map<String, String> _memori = {};

  web.Storage? get _ls {
    try {
      return web.window.localStorage;
    } catch (_) {
      return null;
    }
  }

  Future<void> tulis(String nama, String isi) async {
    _memori[nama] = isi;
    try {
      _ls?.setItem('$_awalan$nama', isi);
    } catch (_) {
      // Kuota penuh: tetap ada di memori sampai halaman ditutup.
    }
  }

  Future<String?> baca(String nama) async {
    final ada = _memori[nama];
    if (ada != null) return ada;
    try {
      return _ls?.getItem('$_awalan$nama');
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> daftar(String folder) async {
    final semua = <String>{
      ..._memori.keys.where((k) => k.startsWith('$folder/')),
    };
    final ls = _ls;
    if (ls != null) {
      try {
        for (var i = 0; i < ls.length; i++) {
          final k = ls.key(i);
          if (k != null && k.startsWith('$_awalan$folder/')) {
            semua.add(k.substring(_awalan.length));
          }
        }
      } catch (_) {}
    }
    return semua.toList()..sort();
  }

  Future<int> ukuran(String nama) async => (await baca(nama))?.length ?? 0;

  Future<void> hapus(String nama) async {
    _memori.remove(nama);
    try {
      _ls?.removeItem('$_awalan$nama');
    } catch (_) {}
  }

  Future<String?> zip(List<String> nama, String namaZip) async => null;
}
