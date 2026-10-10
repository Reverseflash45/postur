/// Indeks 33 landmark tubuh versi BlazePose — sama dengan ml/postur/landmark.py.
///
/// ML Kit Pose Detection memakai urutan yang sama (PoseLandmarkType.values),
/// jadi indeks enum bisa dipakai langsung. "Kiri" = sisi tubuh subjek.
abstract final class Lm {
  static const jumlah = 33;

  static const hidung = 0;
  static const bahuKi = 11, bahuKa = 12;
  static const sikuKi = 13, sikuKa = 14;
  static const tanganKi = 15, tanganKa = 16;
  static const pinggulKi = 23, pinggulKa = 24;
  static const lututKi = 25, lututKa = 26;
  static const kakiKi = 27, kakiKa = 28;

  /// Landmark yang koordinatnya ikut jadi fitur model deret waktu.
  static const terpilih = [
    bahuKi, bahuKa, sikuKi, sikuKa, tanganKi, tanganKa, //
    pinggulKi, pinggulKa, lututKi, lututKa, kakiKi, kakiKa,
  ];

  /// Garis kerangka untuk digambar.
  static const tulang = [
    [11, 12],
    [11, 13],
    [13, 15],
    [12, 14],
    [14, 16],
    [11, 23],
    [12, 24],
    [23, 24], //
    [23, 25],
    [25, 27],
    [24, 26],
    [26, 28],
    [27, 29],
    [29, 31],
    [27, 31],
    [28, 30],
    [30, 32], [28, 32],
  ];

  /// Titik yang digambar sebagai sendi (wajah dan jari dilewati).
  static const sendi = [
    0,
    11,
    12,
    13,
    14,
    15,
    16,
    23,
    24,
    25,
    26,
    27,
    28,
    31,
    32,
  ];
}
