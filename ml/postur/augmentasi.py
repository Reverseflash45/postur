"""Augmentasi repetisi pada tingkat landmark mentah.

Augmentasi dilakukan sebelum ekstraksi fitur, supaya fitur hasil augmentasi
dihitung dengan jalur yang sama persis dengan data asli.
"""
import math

import numpy as np

from . import landmark as L
from .data import Repetisi
from .fitur import proses_repetisi
from .gerakan import Gerakan

_CERMIN = L.indeks_cermin()


def augmentasi_satu(r: Repetisi, rng: np.random.Generator) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    t, xy, vis = r.t.copy(), r.xy.copy(), r.vis.copy()
    if rng.random() < 0.5:
        # Cermin kiri-kanan: balik sumbu x lalu tukar label sisi tubuh.
        xy[..., 0] = -xy[..., 0]
        xy, vis = xy[:, _CERMIN], vis[:, _CERMIN]
    pusat = (xy[0, L.PINGGUL_KI] + xy[0, L.PINGGUL_KA]) / 2
    a = math.radians(rng.uniform(-8, 8))
    ca, sa = math.cos(a), math.sin(a)
    d = xy - pusat
    xy = np.stack([d[..., 0] * ca - d[..., 1] * sa, d[..., 0] * sa + d[..., 1] * ca], axis=-1) + pusat
    torso = np.linalg.norm((xy[:, L.BAHU_KI] + xy[:, L.BAHU_KA]) / 2
                           - (xy[:, L.PINGGUL_KI] + xy[:, L.PINGGUL_KA]) / 2, axis=1)
    xy = xy + rng.normal(0, 0.01 * float(np.median(torso)), xy.shape)
    t = t[0] + (t - t[0]) * rng.uniform(0.85, 1.15)
    return t, xy, vis


def perbanyak(reps: list[Repetisi], gerakan: Gerakan, kali: int, benih: int = 0):
    """Kembalikan (SEQ, RING, y, grup) berisi data asli + `kali` salinan augmentasi."""
    rng = np.random.default_rng(benih)
    seq, ring, y, grup = [], [], [], []
    for r in reps:
        seq.append(r.seq)
        ring.append(r.ring)
        y.append(gerakan.indeks(r.label))
        grup.append(r.subjek)
        for _ in range(kali):
            t, xy, vis = augmentasi_satu(r, rng)
            s, g = proses_repetisi(t, xy, vis, gerakan)
            seq.append(s)
            ring.append(g)
            y.append(gerakan.indeks(r.label))
            grup.append(r.subjek)
    return (np.stack(seq).astype(np.float32), np.stack(ring), np.array(y), np.array(grup))
