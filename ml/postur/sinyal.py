"""Praproses deret landmark: isi titik hilang, haluskan, normalisasi, sampel ulang.

Setiap fungsi di sini punya kembaran di aplikasi (lib/inti/sinyal.dart) dan
harus menghasilkan angka yang sama. Karena itu filter ditulis manual alih-alih
memakai scipy: urutan operasinya harus bisa ditiru persis di Dart.
"""
import numpy as np

from . import landmark as L

AMBANG_VIS = 0.5
PANJANG = 64  # langkah waktu per repetisi setelah sampel ulang

# Savitzky–Golay jendela 7, orde 2.
_SG7 = np.array([-2.0, 3.0, 6.0, 7.0, 6.0, 3.0, -2.0]) / 21.0


def isi_hilang(xy: np.ndarray, vis: np.ndarray, ambang: float = AMBANG_VIS) -> np.ndarray:
    """Ganti koordinat yang visibilitasnya rendah dengan interpolasi linear antar-frame.

    xy: (T, 33, 2), vis: (T, 33). Titik di tepi diisi nilai valid terdekat.
    Landmark yang tidak pernah terlihat dibiarkan apa adanya.
    """
    xy = np.array(xy, dtype=np.float64, copy=True)
    idx = np.arange(xy.shape[0], dtype=np.float64)
    for j in range(xy.shape[1]):
        ok = vis[:, j] >= ambang
        if ok.all() or not ok.any():
            continue
        for d in range(2):
            xy[~ok, j, d] = np.interp(idx[~ok], idx[ok], xy[ok, j, d])
    return xy


def haluskan(x: np.ndarray) -> np.ndarray:
    """Savitzky–Golay (7, 2) di sepanjang sumbu waktu; tepi diisi nilai ujung."""
    x = np.asarray(x, dtype=np.float64)
    n = x.shape[0]
    pad = np.concatenate([np.repeat(x[:1], 3, axis=0), x, np.repeat(x[-1:], 3, axis=0)], axis=0)
    hasil = np.zeros_like(x)
    for k in range(7):
        hasil = hasil + _SG7[k] * pad[k:k + n]
    return hasil


def normalisasi(xy: np.ndarray) -> tuple[np.ndarray, float]:
    """Pindahkan titik asal ke tengah pinggul dan skalakan dengan panjang torso.

    Skala memakai median panjang torso sepanjang repetisi, bukan per frame,
    supaya badan yang membungkuk tidak ikut "membesar".
    """
    pinggul = (xy[:, L.PINGGUL_KI] + xy[:, L.PINGGUL_KA]) / 2.0
    bahu = (xy[:, L.BAHU_KI] + xy[:, L.BAHU_KA]) / 2.0
    d = bahu - pinggul
    torso = np.sqrt(d[:, 0] * d[:, 0] + d[:, 1] * d[:, 1])
    skala = max(float(np.median(torso)), 1e-6)
    return (xy - pinggul[:, None, :]) / skala, skala


def sampel_ulang(x: np.ndarray, t: np.ndarray, n: int = PANJANG) -> np.ndarray:
    """Interpolasi linear (T, F) menjadi (n, F) dengan jarak waktu seragam."""
    t = np.asarray(t, dtype=np.float64)
    if t[-1] <= t[0]:
        return np.repeat(x[:1], n, axis=0).astype(np.float64)
    langkah = (t[-1] - t[0]) / (n - 1)
    tb = np.arange(n, dtype=np.float64) * langkah + t[0]
    tb[-1] = t[-1]
    return np.stack([np.interp(tb, t, x[:, k]) for k in range(x.shape[1])], axis=1)
