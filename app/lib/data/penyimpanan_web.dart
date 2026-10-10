/// Penyimpanan di memori untuk versi web (pratinjau). Hilang saat dimuat ulang.
class Penyimpanan {
  Penyimpanan._();

  static final instance = Penyimpanan._();

  static const bisaEkspor = false;

  final Map<String, String> _isi = {};

  Future<void> tulis(String nama, String isi) async => _isi[nama] = isi;

  Future<String?> baca(String nama) async => _isi[nama];

  Future<List<String>> daftar(String folder) async =>
      _isi.keys.where((k) => k.startsWith('$folder/')).toList()..sort();

  Future<int> ukuran(String nama) async => _isi[nama]?.length ?? 0;

  Future<void> hapus(String nama) async => _isi.remove(nama);

  Future<String?> zip(List<String> nama, String namaZip) async => null;
}
