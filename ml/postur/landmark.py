"""Indeks 33 landmark tubuh versi BlazePose.

ML Kit Pose Detection (dipakai di aplikasi) dan MediaPipe Pose Landmarker
(dipakai untuk mengolah video) memakai topologi yang sama, jadi indeks di sini
berlaku untuk keduanya. "Kiri" dan "kanan" adalah sisi tubuh subjek, bukan sisi
gambar.
"""

JUMLAH = 33

HIDUNG = 0
BAHU_KI, BAHU_KA = 11, 12
SIKU_KI, SIKU_KA = 13, 14
TANGAN_KI, TANGAN_KA = 15, 16  # pergelangan tangan
PINGGUL_KI, PINGGUL_KA = 23, 24
LUTUT_KI, LUTUT_KA = 25, 26
KAKI_KI, KAKI_KA = 27, 28  # pergelangan kaki
TUMIT_KI, TUMIT_KA = 29, 30
JARI_KAKI_KI, JARI_KAKI_KA = 31, 32

# Pasangan kiri–kanan, dipakai untuk augmentasi cermin.
PASANGAN = [(1, 4), (2, 5), (3, 6), (7, 8), (9, 10), (11, 12), (13, 14), (15, 16),
            (17, 18), (19, 20), (21, 22), (23, 24), (25, 26), (27, 28), (29, 30), (31, 32)]

# Landmark yang koordinatnya ikut menjadi fitur model deret waktu.
TERPILIH = [BAHU_KI, BAHU_KA, SIKU_KI, SIKU_KA, TANGAN_KI, TANGAN_KA,
            PINGGUL_KI, PINGGUL_KA, LUTUT_KI, LUTUT_KA, KAKI_KI, KAKI_KA]

# Garis kerangka untuk digambar.
TULANG = [(11, 12), (11, 13), (13, 15), (12, 14), (14, 16), (11, 23), (12, 24), (23, 24),
          (23, 25), (25, 27), (24, 26), (26, 28), (27, 29), (29, 31), (27, 31), (28, 30),
          (30, 32), (28, 32)]


def indeks_cermin() -> list[int]:
    """Urutan indeks setelah kiri dan kanan ditukar."""
    idx = list(range(JUMLAH))
    for a, b in PASANGAN:
        idx[a], idx[b] = b, a
    return idx
