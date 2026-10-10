import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

/// Penyimpanan berkas sederhana di bawah `<dokumen aplikasi>/postur/`.
class Penyimpanan {
  Penyimpanan._();

  static final instance = Penyimpanan._();

  static const bisaEkspor = true;

  Directory? _akar;

  Future<Directory> _dir() async {
    final ada = _akar;
    if (ada != null) return ada;
    final d = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/postur',
    );
    await d.create(recursive: true);
    return _akar = d;
  }

  Future<File> _berkas(String nama) async =>
      File('${(await _dir()).path}/$nama');

  Future<void> tulis(String nama, String isi) async {
    final f = await _berkas(nama);
    await f.parent.create(recursive: true);
    // Tulis ke berkas sementara lalu ganti nama, supaya rekaman panjang tidak
    // tertinggal setengah jadi bila aplikasi ditutup di tengah penulisan.
    final sementara = File('${f.path}.tmp');
    await sementara.writeAsString(isi, flush: true);
    await sementara.rename(f.path);
  }

  Future<String?> baca(String nama) async {
    final f = await _berkas(nama);
    return await f.exists() ? f.readAsString() : null;
  }

  Future<List<String>> daftar(String folder) async {
    final d = Directory('${(await _dir()).path}/$folder');
    if (!await d.exists()) return [];
    final hasil = <String>[];
    await for (final e in d.list()) {
      if (e is File && e.path.endsWith('.json')) {
        hasil.add('$folder/${e.uri.pathSegments.last}');
      }
    }
    hasil.sort();
    return hasil;
  }

  Future<int> ukuran(String nama) async {
    final f = await _berkas(nama);
    return await f.exists() ? f.length() : 0;
  }

  Future<void> hapus(String nama) async {
    final f = await _berkas(nama);
    if (await f.exists()) await f.delete();
  }

  /// Satukan berkas ke dalam zip di folder sementara; kembalikan path-nya.
  Future<String?> zip(List<String> nama, String namaZip) async {
    final arsip = Archive();
    for (final n in nama) {
      final f = await _berkas(n);
      if (await f.exists()) {
        arsip.addFile(
          ArchiveFile.bytes(n.split('/').last, await f.readAsBytes()),
        );
      }
    }
    final keluar = File('${(await getTemporaryDirectory()).path}/$namaZip');
    await keluar.writeAsBytes(ZipEncoder().encodeBytes(arsip), flush: true);
    return keluar.path;
  }
}
