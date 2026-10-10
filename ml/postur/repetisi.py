"""Penghitung repetisi berbasis mesin keadaan pada sudut sendi utama.

Bekerja frame demi frame (kausal) karena aplikasi harus menghitung saat
latihan berlangsung. Pelatihan model memakai kelas yang sama persis, supaya
potongan repetisi di data latih sama dengan yang dilihat aplikasi.
Kembarannya: lib/inti/repetisi.dart.
"""
import math
from dataclasses import dataclass

import numpy as np

from .gerakan import Gerakan
from .sinyal import AMBANG_VIS

_DERAJAT = 180.0 / math.pi


def _sudut1(a, b, c) -> float:
    v1x, v1y = a[0] - b[0], a[1] - b[1]
    v2x, v2y = c[0] - b[0], c[1] - b[1]
    dot = v1x * v2x + v1y * v2y
    n = math.sqrt(v1x * v1x + v1y * v1y) * math.sqrt(v2x * v2x + v2y * v2y)
    cos = min(1.0, max(-1.0, dot / max(n, 1e-9)))
    return math.acos(cos) * _DERAJAT


def sinyal_utama(xy: np.ndarray, vis: np.ndarray, gerakan: Gerakan) -> float | None:
    """Rerata sudut sendi utama kiri dan kanan yang terlihat; None bila keduanya tidak."""
    total, n = 0.0, 0
    for a, b, c in gerakan.sendi_utama:
        if min(vis[a], vis[b], vis[c]) >= AMBANG_VIS:
            total += _sudut1(xy[a], xy[b], xy[c])
            n += 1
    return total / n if n else None


@dataclass
class KonfigRepetisi:
    # Turun sejauh ini (derajat) dari puncak = repetisi dimulai.
    ambang_mulai: float = 25.0
    # Kembali ke dalam jarak ini dari puncak = repetisi selesai.
    ambang_selesai: float = 15.0
    # Rentang gerak minimum supaya dihitung. Diisi dari Gerakan.
    rom_min: float = 35.0
    # Bobot EMA untuk meredam getaran keypoint.
    alfa: float = 0.5
    # Repetisi yang tidak selesai dalam waktu ini dibatalkan (ms).
    batas_ms: float = 8000.0


class PenghitungRepetisi:
    """Masukkan sinyal per frame; keluarkan (indeks_mulai, indeks_selesai) tiap repetisi."""

    def __init__(self, gerakan: Gerakan, konfig: KonfigRepetisi | None = None):
        self.k = konfig or KonfigRepetisi(rom_min=gerakan.rom_min)
        self.reset()

    def reset(self):
        self.halus: float | None = None
        self.turun = False
        self.puncak: float | None = None
        self.minimum = 0.0
        self.i_tepi = 0
        self.t_tepi = 0.0
        self.i_mulai = 0
        self.t_mulai = 0.0

    def proses(self, i: int, t: float, nilai: float | None) -> tuple[int, int] | None:
        if nilai is None:
            return None
        s = nilai if self.halus is None else self.k.alfa * nilai + (1.0 - self.k.alfa) * self.halus
        self.halus = s

        if not self.turun:
            if self.puncak is None or s > self.puncak:
                self.puncak = s
            if s >= self.puncak - self.k.ambang_selesai:
                self.i_tepi, self.t_tepi = i, t
            if s < self.puncak - self.k.ambang_mulai:
                self.turun = True
                self.minimum = s
                self.i_mulai, self.t_mulai = self.i_tepi, self.t_tepi
            return None

        self.minimum = min(self.minimum, s)
        if t - self.t_mulai > self.k.batas_ms:
            self._kembali_ke_atas(i, t, s)
            return None
        if s >= self.puncak - self.k.ambang_selesai:
            hasil = (self.i_mulai, i) if self.puncak - self.minimum >= self.k.rom_min else None
            self._kembali_ke_atas(i, t, s)
            return hasil
        return None

    def _kembali_ke_atas(self, i: int, t: float, s: float):
        self.turun = False
        self.puncak = s
        self.i_tepi, self.t_tepi = i, t


def segmentasi(t: np.ndarray, xy: np.ndarray, vis: np.ndarray, gerakan: Gerakan,
               konfig: KonfigRepetisi | None = None) -> list[tuple[int, int]]:
    """Jalankan penghitung pada seluruh sesi; hasilnya daftar (mulai, selesai) inklusif."""
    hitung = PenghitungRepetisi(gerakan, konfig)
    hasil = []
    for i in range(len(t)):
        rep = hitung.proses(i, float(t[i]), sinyal_utama(xy[i], vis[i], gerakan))
        if rep is not None:
            hasil.append(rep)
    return hasil
