import '../data/pengaturan.dart';
import '../inti/klasifikasi/klasifikasi.dart';
import '../inti/paket_model.dart';

/// Nama model beserta macro-F1 validasinya.
String labelModel(PaketModel p, String id) {
  final f1 = p.f1(id);
  return '${namaModel[id]}${f1 == null ? '' : ' · F1 ${f1.toStringAsFixed(2)}'}';
}

/// Model yang dipakai saat ini untuk sebuah gerakan.
String modelAktif(PaketModel p) {
  final id = Pengaturan.instance.model(p.gerakan.id);
  return id != null && p.tersedia.contains(id) ? id : p.terbaik;
}

const _hari = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];
const _bulan = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MEI',
  'JUN',
  'JUL',
  'AGU',
  'SEP',
  'OKT',
  'NOV',
  'DES',
];

String hariSingkat(DateTime d) => _hari[d.weekday - 1];

/// "SAB 11 OKT"
String tanggalSingkat(DateTime d) =>
    '${hariSingkat(d)} ${d.day} ${_bulan[d.month - 1]}';

/// "11 OKT 14.05"
String tanggalJam(DateTime d) =>
    '${d.day} ${_bulan[d.month - 1]} ${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';
