"""Pendekatan berbasis aturan (baseline): ambang pada fitur ringkasan.

Aturan diperiksa berurutan sesuai Gerakan.aturan; yang pertama terpenuhi
menentukan label, dan bila tidak ada yang terpenuhi labelnya kelas benar.
Ambang tidak ditebak: dicari dari data latih dengan pencarian koordinat yang
memaksimalkan macro-F1. Kembarannya: lib/inti/klasifikasi/aturan.dart.
"""
import numpy as np
from sklearn.metrics import f1_score

from .fitur import NAMA_RINGKASAN
from .gerakan import Gerakan


class KlasifikasiAturan:
    def __init__(self, gerakan: Gerakan):
        self.g = gerakan
        self.kolom = [NAMA_RINGKASAN.index(a.fitur) for a in gerakan.aturan]
        self.label = [gerakan.indeks(a.label) for a in gerakan.aturan]
        self.op = [a.op for a in gerakan.aturan]
        self.ambang = np.zeros(len(gerakan.aturan))

    def _prediksi(self, R: np.ndarray, ambang: np.ndarray) -> np.ndarray:
        y = np.zeros(len(R), dtype=int)
        sisa = np.ones(len(R), dtype=bool)
        for kol, lab, op, a in zip(self.kolom, self.label, self.op, ambang):
            kena = (R[:, kol] > a) if op == ">" else (R[:, kol] < a)
            kena &= sisa
            y[kena] = lab
            sisa &= ~kena
        return y

    def _skor(self, R, y, ambang) -> float:
        return f1_score(y, self._prediksi(R, ambang), average="macro",
                        labels=list(range(len(self.g.kelas))), zero_division=0)

    def fit(self, R: np.ndarray, y: np.ndarray, putaran: int = 3, kandidat: int = 60):
        # Awal: titik tengah median kelas benar dan median kelas aturan itu.
        for i, (kol, lab) in enumerate(zip(self.kolom, self.label)):
            benar = R[y == 0, kol]
            salah = R[y == lab, kol]
            if len(benar) and len(salah):
                self.ambang[i] = (np.median(benar) + np.median(salah)) / 2
            else:
                self.ambang[i] = np.median(R[:, kol])
        terbaik = self._skor(R, y, self.ambang)
        for _ in range(putaran):
            berubah = False
            for i, kol in enumerate(self.kolom):
                calon = np.unique(np.quantile(R[:, kol], np.linspace(0.01, 0.99, kandidat)))
                for c in calon:
                    coba = self.ambang.copy()
                    coba[i] = c
                    s = self._skor(R, y, coba)
                    if s > terbaik + 1e-12:
                        terbaik, self.ambang, berubah = s, coba, True
            if not berubah:
                break
        return self

    def predict(self, R: np.ndarray) -> np.ndarray:
        return self._prediksi(R, self.ambang)

    def ke_json(self) -> dict:
        return {
            "jenis": "aturan",
            "gerakan": self.g.id,
            "aturan": [
                {"label": a.label, "fitur": a.fitur, "indeks_fitur": kol, "op": a.op,
                 "ambang": float(amb)}
                for a, kol, amb in zip(self.g.aturan, self.kolom, self.ambang)
            ],
            "bawaan": self.g.kode[0],
        }
