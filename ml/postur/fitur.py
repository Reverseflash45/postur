"""Fitur per frame dan ringkasan per repetisi.

Kembarannya di aplikasi: lib/inti/fitur.dart.
"""
import numpy as np

from . import landmark as L
from .gerakan import Gerakan
from .sinyal import PANJANG, haluskan, isi_hilang, normalisasi, sampel_ulang

NAMA_KANAL = [
    "lutut_ki", "lutut_ka", "pinggul_ki", "pinggul_ka", "siku_ki", "siku_ka",
    "bahu_ki", "bahu_ka", "condong", "lengkung", "rasio_lutut", "tinggi_pinggul",
    "lutut", "siku",
]
STAT = ["min", "max", "rerata", "sb", "rentang"]
NAMA_RINGKASAN = [f"{k}_{s}" for k in NAMA_KANAL for s in STAT] + ["durasi", "posisi_terendah"]
NAMA_KOORDINAT = [f"{n}_{s}" for n in L.TERPILIH for s in ("x", "y")]
NAMA_FITUR = NAMA_KANAL + NAMA_KOORDINAT
JUMLAH_FITUR = len(NAMA_FITUR)  # 38

_DERAJAT = 180.0 / np.pi
# Batas bawah jarak antar-pergelangan kaki (dalam satuan panjang torso) agar
# rasio lutut tidak meledak saat kaki rapat.
_JARAK_KAKI_MIN = 0.05


def sudut(a: np.ndarray, b: np.ndarray, c: np.ndarray) -> np.ndarray:
    """Sudut di titik b (derajat) untuk larik titik (..., 2)."""
    v1x, v1y = a[..., 0] - b[..., 0], a[..., 1] - b[..., 1]
    v2x, v2y = c[..., 0] - b[..., 0], c[..., 1] - b[..., 1]
    dot = v1x * v2x + v1y * v2y
    n = np.sqrt(v1x * v1x + v1y * v1y) * np.sqrt(v2x * v2x + v2y * v2y)
    cos = np.clip(dot / np.maximum(n, 1e-9), -1.0, 1.0)
    return np.arccos(cos) * _DERAJAT


def _jarak(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    dx, dy = a[..., 0] - b[..., 0], a[..., 1] - b[..., 1]
    return np.sqrt(dx * dx + dy * dy)


def kanal(xy: np.ndarray) -> np.ndarray:
    """14 kanal sudut/jarak per frame dari koordinat ternormalisasi (T, 33, 2)."""
    p = lambda i: xy[:, i]  # noqa: E731
    lutut_ki = sudut(p(L.PINGGUL_KI), p(L.LUTUT_KI), p(L.KAKI_KI))
    lutut_ka = sudut(p(L.PINGGUL_KA), p(L.LUTUT_KA), p(L.KAKI_KA))
    pinggul_ki = sudut(p(L.BAHU_KI), p(L.PINGGUL_KI), p(L.LUTUT_KI))
    pinggul_ka = sudut(p(L.BAHU_KA), p(L.PINGGUL_KA), p(L.LUTUT_KA))
    siku_ki = sudut(p(L.BAHU_KI), p(L.SIKU_KI), p(L.TANGAN_KI))
    siku_ka = sudut(p(L.BAHU_KA), p(L.SIKU_KA), p(L.TANGAN_KA))
    bahu_ki = sudut(p(L.SIKU_KI), p(L.BAHU_KI), p(L.PINGGUL_KI))
    bahu_ka = sudut(p(L.SIKU_KA), p(L.BAHU_KA), p(L.PINGGUL_KA))

    bahu = (p(L.BAHU_KI) + p(L.BAHU_KA)) / 2.0
    pinggul = (p(L.PINGGUL_KI) + p(L.PINGGUL_KA)) / 2.0
    kaki = (p(L.KAKI_KI) + p(L.KAKI_KA)) / 2.0

    # Kemiringan torso terhadap garis vertikal (0° = tegak). Sumbu y gambar
    # mengarah ke bawah, jadi "atas" adalah (0, -1).
    dx, dy = bahu[:, 0] - pinggul[:, 0], bahu[:, 1] - pinggul[:, 1]
    nd = np.maximum(np.sqrt(dx * dx + dy * dy), 1e-9)
    condong = np.arccos(np.clip(-dy / nd, -1.0, 1.0)) * _DERAJAT

    # Jarak tegak lurus pinggul dari garis bahu–pergelangan kaki. Normalnya
    # dipilih menghadap ke bawah gambar, sehingga positif = pinggul melorot.
    gx, gy = kaki[:, 0] - bahu[:, 0], kaki[:, 1] - bahu[:, 1]
    ng = np.maximum(np.sqrt(gx * gx + gy * gy), 1e-9)
    nx, ny = -gy / ng, gx / ng
    tanda = np.where(ny < 0.0, -1.0, 1.0)
    nx, ny = nx * tanda, ny * tanda
    lengkung = (pinggul[:, 0] - bahu[:, 0]) * nx + (pinggul[:, 1] - bahu[:, 1]) * ny

    rasio_lutut = _jarak(p(L.LUTUT_KI), p(L.LUTUT_KA)) / np.maximum(
        _jarak(p(L.KAKI_KI), p(L.KAKI_KA)), _JARAK_KAKI_MIN)
    tinggi_pinggul = kaki[:, 1] - pinggul[:, 1]

    return np.stack([
        lutut_ki, lutut_ka, pinggul_ki, pinggul_ka, siku_ki, siku_ka, bahu_ki, bahu_ka,
        condong, lengkung, rasio_lutut, tinggi_pinggul,
        (lutut_ki + lutut_ka) / 2.0, (siku_ki + siku_ka) / 2.0,
    ], axis=1)


def fitur_frame(xy_norm: np.ndarray) -> np.ndarray:
    """(T, 38): 14 kanal + koordinat x, y dari 12 landmark terpilih."""
    koordinat = xy_norm[:, L.TERPILIH, :].reshape(xy_norm.shape[0], -1)
    return np.concatenate([kanal(xy_norm), koordinat], axis=1)


def ringkasan(seq: np.ndarray, durasi_detik: float, gerakan: Gerakan) -> np.ndarray:
    """72 fitur ringkasan dari deret (64, 38) untuk Random Forest dan aturan."""
    hasil = []
    for k in range(len(NAMA_KANAL)):
        kol = seq[:, k]
        mn, mx = float(np.min(kol)), float(np.max(kol))
        rerata = float(np.sum(kol) / kol.shape[0])
        sb = float(np.sqrt(np.sum((kol - rerata) ** 2) / kol.shape[0]))
        hasil += [mn, mx, rerata, sb, mx - mn]
    utama = seq[:, NAMA_KANAL.index(gerakan.kanal_utama)]
    hasil += [durasi_detik, float(np.argmin(utama)) / (seq.shape[0] - 1)]
    return np.array(hasil, dtype=np.float64)


def proses_repetisi(t: np.ndarray, xy: np.ndarray, vis: np.ndarray, gerakan: Gerakan,
                    panjang: int = PANJANG) -> tuple[np.ndarray, np.ndarray]:
    """Dari potongan mentah satu repetisi ke (deret 64×38, ringkasan 72)."""
    xy = haluskan(isi_hilang(xy, vis))
    xy_norm, _ = normalisasi(xy)
    seq = sampel_ulang(fitur_frame(xy_norm), t, panjang)
    durasi = (float(t[-1]) - float(t[0])) / 1000.0
    return seq, ringkasan(seq, durasi, gerakan)
