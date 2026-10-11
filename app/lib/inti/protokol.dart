import 'gerakan.dart';

/// Urutan perekaman seimbang untuk sesi pengambilan data.
///
/// Kelas kesalahan yang diperagakan berurutan bisa saling memengaruhi
/// (kelelahan, terbawa gaya gerakan sebelumnya). Supaya pengaruh itu tersebar
/// rata, urutan kelas tiap subjek diambil dari satu baris bujur sangkar latin
/// seimbang Williams: tiap kelas muncul sekali di tiap posisi, dan tiap
/// pasangan "kelas A tepat sebelum kelas B" muncul sama sering.

/// Baris ke-[baris] dari bujur sangkar Williams berukuran [n].
///
/// Untuk n genap cukup n baris. Untuk n ganjil butuh 2n baris; baris n..2n-1
/// adalah kebalikan dari baris 0..n-1.
List<int> barisWilliams(int n, int baris) {
  assert(n > 0);
  final pertama = <int>[0];
  var kiri = 1, kanan = n - 1;
  for (var i = 1; i < n; i++) {
    pertama.add(i.isOdd ? kiri++ : kanan--);
  }
  final siklus = n.isEven ? n : 2 * n;
  final b = baris % siklus;
  final geser = b % n;
  final hasil = [for (final v in pertama) (v + geser) % n];
  return b >= n ? hasil.reversed.toList() : hasil;
}

/// Nomor urut subjek dari kodenya: "S03" -> 3. Kode tanpa angka diberi
/// nomor stabil dari hurufnya supaya urutannya tetap sama tiap kali dibuka.
int nomorSubjek(String kode) {
  final m = RegExp(r'\d+').firstMatch(kode);
  if (m != null) return int.parse(m.group(0)!);
  return kode.codeUnits.fold(0, (a, c) => (a * 31 + c) % 9973) + 1;
}

/// Satu langkah sesi: satu set satu kelas.
class LangkahRekam {
  LangkahRekam({
    required this.gerakan,
    required this.kelas,
    required this.target,
    this.path,
    this.repetisi,
    this.dilewati = false,
  });

  final String gerakan;
  final String kelas;
  final int target;

  /// Berkas rekaman yang tersimpan untuk langkah ini.
  String? path;

  /// Hitungan manual saat disimpan.
  int? repetisi;
  bool dilewati;

  bool get selesai => path != null;
  bool get tuntas => selesai || dilewati;

  Map<String, dynamic> keJson() => {
    'gerakan': gerakan,
    'kelas': kelas,
    'target': target,
    'path': path,
    'repetisi': repetisi,
    'dilewati': dilewati,
  };

  factory LangkahRekam.dariJson(Map<String, dynamic> j) => LangkahRekam(
    gerakan: j['gerakan'] as String,
    kelas: j['kelas'] as String,
    target: j['target'] as int,
    path: j['path'] as String?,
    repetisi: j['repetisi'] as int?,
    dilewati: j['dilewati'] as bool? ?? false,
  );
}

/// Rencana sesi terpandu untuk satu subjek.
class RencanaSesi {
  RencanaSesi({
    required this.subjek,
    required this.langkah,
    required this.dibuat,
    this.barisUrutan = 0,
  });

  final String subjek;
  final List<LangkahRekam> langkah;
  final DateTime dibuat;

  /// Baris bujur sangkar Williams yang dipakai (untuk dicatat di laporan).
  final int barisUrutan;

  static const format = 'postur-terpandu';

  int get jumlahSelesai => langkah.where((l) => l.selesai).length;
  int get jumlahTuntas => langkah.where((l) => l.tuntas).length;
  bool get tamat => langkah.every((l) => l.tuntas);

  /// Langkah pertama yang belum selesai dan belum dilewati.
  int? get berikutnya {
    final i = langkah.indexWhere((l) => !l.tuntas);
    return i < 0 ? null : i;
  }

  /// Susun rencana: tiap gerakan, urutan kelas menurut baris Williams subjek.
  /// Bila dua gerakan direkam, gerakan pertama bergantian antar subjek.
  factory RencanaSesi.buat({
    required String subjek,
    required List<Gerakan> gerakan,
    required int target,
    DateTime? waktu,
  }) {
    final no = nomorSubjek(subjek);
    final urutGerakan = no.isEven ? gerakan.reversed.toList() : gerakan;
    final baris = no - 1;
    return RencanaSesi(
      subjek: subjek,
      dibuat: waktu ?? DateTime.now(),
      barisUrutan: baris,
      langkah: [
        for (final g in urutGerakan)
          for (final i in barisWilliams(g.kelas.length, baris))
            LangkahRekam(gerakan: g.id, kelas: g.kelas[i].kode, target: target),
      ],
    );
  }

  Map<String, dynamic> keJson() => {
    'format': format,
    'versi': 1,
    'subjek': subjek,
    'dibuat': dibuat.toIso8601String(),
    'baris_urutan': barisUrutan,
    'langkah': [for (final l in langkah) l.keJson()],
  };

  factory RencanaSesi.dariJson(Map<String, dynamic> j) => RencanaSesi(
    subjek: j['subjek'] as String,
    dibuat: DateTime.tryParse(j['dibuat'] as String? ?? '') ?? DateTime(2000),
    barisUrutan: j['baris_urutan'] as int? ?? 0,
    langkah: [
      for (final l in j['langkah'] as List)
        LangkahRekam.dariJson(l as Map<String, dynamic>),
    ],
  );
}

/// Cara memperagakan tiap kelas dengan aman, dibacakan ke subjek.
const caraPeragaan = <String, String>{
  'SQ-0': 'Lakukan squat dengan bentuk terbaikmu, tempo sedang.',
  'SQ-1': 'Turun hanya setengah jalan, lalu naik lagi. Jangan sampai paha sejajar lantai.',
  'SQ-2': 'Saat turun, biarkan lutut sedikit bergerak ke dalam. Cukup ringan, jangan dipaksa.',
  'SQ-3': 'Saat turun, condongkan dada ke depan lebih dari biasanya. Punggung tetap lurus.',
  'PU-0': 'Badan lurus dari bahu sampai tumit, turun sampai siku sekitar sembilan puluh derajat.',
  'PU-1': 'Biarkan pinggul sedikit melengkung turun. Berhenti bila punggung bawah terasa tidak nyaman.',
  'PU-2': 'Angkat pinggul sedikit lebih tinggi dari garis badan, seperti huruf V landai.',
  'PU-3': 'Turun hanya sedikit, siku jauh dari sembilan puluh derajat.',
};
