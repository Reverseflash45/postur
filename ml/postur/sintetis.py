"""Generator sesi sintetis untuk menguji pipeline sebelum data asli tersedia.

Kerangka 3D sederhana digerakkan dengan kinematika maju, diproyeksikan ke
kamera (squat dari depan-serong, push-up dari samping), lalu diberi derau,
landmark yang meleset, dan frame yang hilang. Setiap subjek punya proporsi
tubuh, kecepatan, dan "gaya" sendiri supaya validasi per subjek bermakna.

PENTING: data ini hanya untuk memastikan kode berjalan benar. Angka evaluasi
dari data sintetis TIDAK boleh dilaporkan sebagai hasil penelitian.
"""
import math
from dataclasses import dataclass

import numpy as np

from . import landmark as L
from .data import Sesi
from .gerakan import PUSHUP, SQUAT, Gerakan


@dataclass
class Tubuh:
    betis: float
    paha: float
    torso: float
    lengan_atas: float
    lengan_bawah: float
    kaki: float  # setengah lebar kuda-kuda
    pinggul: float  # setengah lebar pinggul
    bahu: float  # setengah lebar bahu


@dataclass
class Subjek:
    kode: str
    tubuh: Tubuh
    kecepatan: float
    derau_px: float
    gaya: dict


def subjek_acak(kode: str, rng: np.random.Generator) -> Subjek:
    u = rng.uniform
    skala = u(0.9, 1.1)
    j = lambda x: x * skala * u(0.93, 1.07)  # noqa: E731
    tubuh = Tubuh(betis=j(0.43), paha=j(0.45), torso=j(0.52), lengan_atas=j(0.30),
                  lengan_bawah=j(0.27), kaki=j(0.15), pinggul=j(0.09), bahu=j(0.19))
    gaya = {
        "dalam": u(-8, 8), "condong": u(-8, 8), "valgus": u(0.0, 0.035),
        "dalam_pu": u(-0.03, 0.03), "lengkung": u(-0.03, 0.03), "lengan": u(10, 30),
    }
    return Subjek(kode, tubuh, kecepatan=u(0.75, 1.3), derau_px=u(2.0, 6.0), gaya=gaya)


# ---------------------------------------------------------------------------
# Parameter gerakan per kelas
# ---------------------------------------------------------------------------

def _param_squat(label: str, s: Subjek, rng) -> dict:
    u, g = rng.uniform, s.gaya
    p = {"a": u(22, 35), "b": u(70, 95), "c0": u(0, 8), "c": u(18, 38), "v": g["valgus"]}
    if label == "SQ-1":
        p.update(a=u(10, 22), b=u(40, 62), c=u(10, 25))
    elif label == "SQ-2":
        p.update(b=u(72, 92), v=g["valgus"] + u(0.04, 0.10))
    elif label == "SQ-3":
        p.update(a=u(18, 28), b=u(72, 92), c=u(40, 62))
    p["b"] += g["dalam"]
    p["c"] += g["condong"]
    p["lengan0"] = g["lengan"]
    p["lengan1"] = u(80, 95)
    return p


def _param_pushup(label: str, s: Subjek, rng) -> dict:
    u, g = rng.uniform, s.gaya
    p = {"h_bawah": u(0.16, 0.27), "melorot": g["lengkung"], "geser": u(0.14, 0.22)}
    if label == "PU-1":
        p.update(h_bawah=u(0.16, 0.27), melorot=g["lengkung"] + u(0.05, 0.14))
    elif label == "PU-2":
        p.update(h_bawah=u(0.18, 0.28), melorot=g["lengkung"] - u(0.07, 0.18))
    elif label == "PU-3":
        p.update(h_bawah=u(0.30, 0.40))
    p["h_bawah"] += g["dalam_pu"]
    return p


def _getar(p: dict, rng, persen: float = 0.06) -> dict:
    """Variasi kecil antar-repetisi dalam satu set."""
    return {k: v * (1 + rng.normal(0, persen)) if isinstance(v, float) else v for k, v in p.items()}


# ---------------------------------------------------------------------------
# Kinematika maju
# ---------------------------------------------------------------------------

def _wajah_tangan_kaki(P: np.ndarray, hidung, arah_tangan_ki, arah_tangan_ka):
    """Isi landmark kecil (mata, telinga, mulut, jari, tumit) di sekitar titik utama."""
    P[L.HIDUNG] = hidung
    for i, dx, dy, dz in [(1, .02, .03, -.01), (2, .035, .03, -.015), (3, .05, .03, -.02),
                          (4, -.02, .03, -.01), (5, -.035, .03, -.015), (6, -.05, .03, -.02),
                          (7, .075, .01, -.08), (8, -.075, .01, -.08),
                          (9, .025, -.04, 0), (10, -.025, -.04, 0)]:
        P[i] = hidung + np.array([dx, dy, dz])
    for (tangan, jari), arah in (((L.TANGAN_KI, (17, 19, 21)), arah_tangan_ki),
                                  ((L.TANGAN_KA, (18, 20, 22)), arah_tangan_ka)):
        for k, j in enumerate(jari):
            P[j] = P[tangan] + 0.07 * arah + np.array([0.012 * (k - 1), 0, 0])


def pose_squat(d: float, p: dict, tb: Tubuh) -> np.ndarray:
    """33×3 titik squat pada kedalaman d ∈ [0, 1]. Y ke atas, Z ke depan subjek."""
    P = np.zeros((L.JUMLAH, 3))
    a, b = math.radians(d * p["a"]), math.radians(d * p["b"])
    c = math.radians(p["c0"] + d * p["c"])
    v = d * p["v"]
    y_lutut = 0.08 + tb.betis * math.cos(a)
    z_lutut = tb.betis * math.sin(a)
    y_pinggul = y_lutut + tb.paha * math.cos(b)
    z_pinggul = z_lutut - tb.paha * math.sin(b)
    torso = np.array([0, math.cos(c), math.sin(c)])
    tengah_bahu = np.array([0, y_pinggul, z_pinggul]) + tb.torso * torso
    phi = math.radians(p["lengan0"] + d * (p["lengan1"] - p["lengan0"]))
    lengan = np.array([0, -math.cos(phi), math.sin(phi)])
    for s, (kaki, lutut, pinggul, bahu, siku, tangan, tumit, jari) in (
            (1, (L.KAKI_KI, L.LUTUT_KI, L.PINGGUL_KI, L.BAHU_KI, L.SIKU_KI, L.TANGAN_KI,
                 L.TUMIT_KI, L.JARI_KAKI_KI)),
            (-1, (L.KAKI_KA, L.LUTUT_KA, L.PINGGUL_KA, L.BAHU_KA, L.SIKU_KA, L.TANGAN_KA,
                  L.TUMIT_KA, L.JARI_KAKI_KA))):
        P[kaki] = [s * tb.kaki, 0.08, 0]
        P[lutut] = [s * (tb.kaki - v), y_lutut, z_lutut]
        P[pinggul] = [s * tb.pinggul, y_pinggul, z_pinggul]
        P[bahu] = tengah_bahu + [s * tb.bahu, 0, 0]
        P[siku] = P[bahu] + tb.lengan_atas * lengan
        P[tangan] = P[siku] + tb.lengan_bawah * lengan
        P[tumit] = P[kaki] + [0, -0.06, -0.06]
        P[jari] = P[kaki] + [s * 0.03, -0.07, 0.17]
    hidung = tengah_bahu + 0.2 * torso + np.array([0, 0, 0.1])
    _wajah_tangan_kaki(P, hidung, lengan, lengan)
    return P


def _siku_2d(W, S, l_bawah, l_atas):
    """Titik siku pada bidang (z, y) di antara pergelangan W dan bahu S, menekuk ke arah kaki."""
    dz, dy = S[0] - W[0], S[1] - W[1]
    D = math.hypot(dz, dy)
    if D >= l_bawah + l_atas - 1e-9:
        return (W[0] + dz * l_bawah / D, W[1] + dy * l_bawah / D)
    a = (l_bawah ** 2 - l_atas ** 2 + D ** 2) / (2 * D)
    h = math.sqrt(max(l_bawah ** 2 - a ** 2, 0.0))
    pz, py = W[0] + a * dz / D, W[1] + a * dy / D
    c1 = (pz - h * dy / D, py + h * dz / D)
    c2 = (pz + h * dy / D, py - h * dz / D)
    return c1 if c1[0] < c2[0] else c2


def pose_pushup(d: float, p: dict, tb: Tubuh) -> np.ndarray:
    """33×3 titik push-up pada kedalaman d ∈ [0, 1]. Z menuju arah kepala."""
    P = np.zeros((L.JUMLAH, 3))
    lengan = tb.lengan_atas + tb.lengan_bawah
    h_atas = lengan * 0.99 + 0.02
    h = h_atas - d * (h_atas - p["h_bawah"])
    tungkai = tb.betis + tb.paha
    badan = tungkai + tb.torso
    z_tangan = math.sqrt(max(badan ** 2 - (h_atas - 0.08) ** 2, 0.1))
    z_bahu = z_tangan + p["geser"] * d
    kaki = np.array([0.08, 0.0])  # (y, z)
    bahu = np.array([h, z_bahu])
    g = bahu - kaki
    g = g / np.linalg.norm(g)
    normal = np.array([g[1], -g[0]])  # (y, z) tegak lurus garis badan, mengarah ke atas
    if normal[0] < 0:
        normal = -normal
    melorot = p["melorot"] * (0.6 + 0.4 * d)
    f = tungkai / badan
    pinggul = kaki + f * (bahu - kaki) - melorot * normal
    lutut = (pinggul + kaki) / 2
    sz, sy = _siku_2d((z_tangan, 0.02), (z_bahu, h), tb.lengan_bawah, tb.lengan_atas)
    for s, (ka, lu, pi, ba, si, ta, tu, ja) in (
            (1, (L.KAKI_KI, L.LUTUT_KI, L.PINGGUL_KI, L.BAHU_KI, L.SIKU_KI, L.TANGAN_KI,
                 L.TUMIT_KI, L.JARI_KAKI_KI)),
            (-1, (L.KAKI_KA, L.LUTUT_KA, L.PINGGUL_KA, L.BAHU_KA, L.SIKU_KA, L.TANGAN_KA,
                  L.TUMIT_KA, L.JARI_KAKI_KA))):
        P[ka] = [s * 0.1, kaki[0], kaki[1]]
        P[lu] = [s * 0.1, lutut[0], lutut[1]]
        P[pi] = [s * tb.pinggul, pinggul[0], pinggul[1]]
        P[ba] = [s * tb.bahu, bahu[0], bahu[1]]
        P[si] = [s * (tb.bahu + 0.03), sy, sz]
        P[ta] = [s * (tb.bahu + 0.04), 0.02, z_tangan]
        P[tu] = P[ka] + [0, 0.02, -0.06]
        P[ja] = P[ka] + [0, -0.07, -0.05]
    arah = np.array([0, g[0], g[1]])
    hidung = np.array([0, bahu[0], bahu[1]]) + 0.22 * arah + np.array([0, -0.05, 0])
    ke_depan = np.array([0, 0, 1.0])
    _wajah_tangan_kaki(P, hidung, ke_depan, ke_depan)
    return P


# ---------------------------------------------------------------------------
# Kamera dan waktu
# ---------------------------------------------------------------------------

def proyeksi(P: np.ndarray, yaw: float, roll: float, skala: float) -> np.ndarray:
    x = P[:, 0] * math.cos(yaw) + P[:, 2] * math.sin(yaw)
    y = -P[:, 1]
    cr, sr = math.cos(roll), math.sin(roll)
    return np.stack([x * cr - y * sr, x * sr + y * cr], axis=1) * skala


def _mulus(u: float) -> float:
    return 0.5 - 0.5 * math.cos(math.pi * min(max(u, 0.0), 1.0))


def jadwal_kedalaman(n_rep: int, s: Subjek, rng) -> tuple[list, float]:
    """Daftar segmen (t_mulai, t_selesai, d_awal, d_akhir) dalam detik."""
    seg, t = [], 0.0
    diam = rng.uniform(1.0, 2.0)
    seg.append((t, t + diam, 0.0, 0.0))
    t += diam
    for _ in range(n_rep):
        turun = rng.uniform(0.8, 1.6) / s.kecepatan
        tahan = rng.uniform(0.0, 0.25)
        naik = rng.uniform(0.7, 1.3) / s.kecepatan
        jeda = rng.uniform(0.3, 0.9)
        for dur, d0, d1 in ((turun, 0, 1), (tahan, 1, 1), (naik, 1, 0), (jeda, 0, 0)):
            seg.append((t, t + dur, d0, d1))
            t += dur
    seg.append((t, t + rng.uniform(1.0, 2.0), 0.0, 0.0))
    return seg, seg[-1][1]


def kedalaman_pada(seg, t: float) -> tuple[float, int]:
    """Kedalaman pada waktu t beserta indeks repetisi yang sedang berjalan."""
    for k, (a, b, d0, d1) in enumerate(seg):
        if a <= t < b:
            return d0 + (d1 - d0) * _mulus((t - a) / max(b - a, 1e-9)), max((k - 1) // 4, 0)
    return 0.0, n_rep_dari(seg) - 1


def n_rep_dari(seg) -> int:
    return (len(seg) - 2) // 4


def buat_sesi(g: Gerakan, label: str, s: Subjek, rng: np.random.Generator, n_rep: int = 10,
              nomor: int = 0, label_rep: list[str] | None = None) -> Sesi:
    """Satu set latihan. label_rep (opsional) memberi label berbeda per repetisi, untuk demo."""
    if label_rep is not None:
        n_rep = len(label_rep)
    lebar, tinggi = (720, 1280) if g is SQUAT else (1280, 720)
    if g is SQUAT:
        yaw = math.radians(rng.choice([-1, 1]) * rng.uniform(37, 53))
    else:
        yaw = math.radians(rng.choice([-1, 1]) * rng.uniform(80, 100))
    roll = math.radians(rng.uniform(-4, 4))
    skala = rng.uniform(400, 600) if g is SQUAT else rng.uniform(480, 600)
    fps = rng.uniform(15, 30)

    param = _param_squat if g is SQUAT else _param_pushup
    if label_rep is None:
        p_set = param(label, s, rng)
        p_rep = [_getar(p_set, rng) for _ in range(n_rep)]
    else:
        p_rep = [_getar(param(lab, s, rng), rng) for lab in label_rep]
    seg, durasi = jadwal_kedalaman(n_rep, s, rng)

    n = int(durasi * fps)
    t = np.arange(n) * 1000.0 / fps + rng.normal(0, 2.0, n)
    t = np.maximum.accumulate(t)
    t = t + np.arange(n) * 1e-3  # pastikan naik ketat
    xy = np.zeros((n, L.JUMLAH, 2))
    vis = np.zeros((n, L.JUMLAH))
    geser = None
    for i in range(n):
        d, k = kedalaman_pada(seg, t[i] / 1000.0)
        p = p_rep[min(k, n_rep - 1)]
        P = (pose_squat if g is SQUAT else pose_pushup)(d, p, s.tubuh)
        P[:, 0] += 0.01 * math.sin(2 * math.pi * 0.3 * t[i] / 1000.0)  # goyang badan
        q = proyeksi(P, yaw, roll, skala)
        if geser is None:
            # Letakkan subjek di tengah bawah bingkai, berdasarkan pose awal.
            gx = lebar / 2 - (q[:, 0].min() + q[:, 0].max()) / 2 + rng.uniform(-40, 40)
            gy = tinggi * rng.uniform(0.82, 0.9) - q[:, 1].max()
            geser = np.array([gx, gy])
        q = q + geser + rng.normal(0, s.derau_px, q.shape)
        v = rng.uniform(0.85, 0.99, L.JUMLAH)
        meleset = rng.random(L.JUMLAH) < 0.01
        q[meleset] += rng.normal(0, 25, (meleset.sum(), 2))
        v[meleset] = rng.uniform(0.05, 0.45, meleset.sum())
        if rng.random() < 0.01:
            continue  # frame tanpa orang terdeteksi
        xy[i], vis[i] = q, v

    sid = f"{s.kode}-{g.id}-{label}-{nomor}"
    return Sesi(id=sid, subjek=s.kode, gerakan=g.id, label=label, t=t, xy=xy, vis=vis,
                repetisi_manual=n_rep,
                meta={"sumber_pose": "sintetis", "lebar": lebar, "tinggi": tinggi,
                      "kamera": "sintetis", "perangkat": "generator",
                      **({"label_rep": label_rep} if label_rep else {})})


def bangkitkan(n_subjek: int = 20, benih: int = 7, gerakan=(SQUAT, PUSHUP),
               set_per_kelas: int = 1) -> list[Sesi]:
    rng = np.random.default_rng(benih)
    hasil = []
    for k in range(n_subjek):
        s = subjek_acak(f"X{k + 1:02d}", rng)
        for g in gerakan:
            for label in g.kode:
                for nomor in range(set_per_kelas):
                    hasil.append(buat_sesi(g, label, s, rng, int(rng.integers(8, 13)), nomor))
    return hasil
