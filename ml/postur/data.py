"""Format berkas sesi dan pembentukan dataset per repetisi.

Satu berkas sesi = satu set latihan dengan satu label, direkam oleh aplikasi
(mode Rekam data), diolah dari video (postur.video), atau dibangkitkan
(postur.sintetis). Formatnya JSON:

    {
      "format": "postur-sesi", "versi": 1,
      "id": "...", "subjek": "S01", "gerakan": "squat", "label": "SQ-2",
      "repetisi_manual": 10, "sumber_pose": "mlkit", "lebar": 720, "tinggi": 1280,
      "t": [ms, ...],
      "pose": [[x0, y0, v0, x1, y1, v1, ... 99 angka] atau null, ...]
    }

Koordinat dalam piksel gambar yang sudah tegak. null = tidak ada orang.
"""
import csv
import json
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

from . import landmark as L
from .fitur import proses_repetisi
from .gerakan import Gerakan, ambil
from .repetisi import segmentasi

FORMAT = "postur-sesi"
BUANG = "BUANG"


@dataclass
class Sesi:
    id: str
    subjek: str
    gerakan: str
    label: str
    t: np.ndarray  # (T,) ms
    xy: np.ndarray  # (T, 33, 2)
    vis: np.ndarray  # (T, 33)
    repetisi_manual: int | None = None
    meta: dict = field(default_factory=dict)


@dataclass
class Repetisi:
    sesi: str
    subjek: str
    gerakan: str
    indeks: int
    label: str
    t: np.ndarray
    xy: np.ndarray
    vis: np.ndarray
    seq: np.ndarray | None = None
    ring: np.ndarray | None = None


def sesi_dari_json(d: dict) -> Sesi:
    if d.get("format") != FORMAT:
        raise ValueError(f"bukan berkas sesi Postur (format={d.get('format')!r})")
    n = len(d["t"])
    xy = np.zeros((n, L.JUMLAH, 2))
    vis = np.zeros((n, L.JUMLAH))
    for i, p in enumerate(d["pose"]):
        if p is None:
            continue
        a = np.asarray(p, dtype=np.float64).reshape(L.JUMLAH, 3)
        xy[i] = a[:, :2]
        vis[i] = a[:, 2]
    meta = {k: v for k, v in d.items() if k not in ("t", "pose")}
    return Sesi(id=d["id"], subjek=str(d["subjek"]), gerakan=d["gerakan"], label=d["label"],
                t=np.asarray(d["t"], dtype=np.float64), xy=xy, vis=vis,
                repetisi_manual=d.get("repetisi_manual"), meta=meta)


def sesi_ke_json(s: Sesi) -> dict:
    pose = []
    for i in range(len(s.t)):
        if not s.vis[i].any():
            pose.append(None)
            continue
        a = np.concatenate([s.xy[i], s.vis[i][:, None]], axis=1)
        pose.append([round(float(v), 2) for v in a.reshape(-1)])
    d = dict(s.meta)
    d.update({
        "format": FORMAT, "versi": 1, "id": s.id, "subjek": s.subjek, "gerakan": s.gerakan,
        "label": s.label, "repetisi_manual": s.repetisi_manual,
        "t": [round(float(v), 1) for v in s.t], "pose": pose,
    })
    return d


def muat_sesi(path: Path) -> Sesi:
    return sesi_dari_json(json.loads(Path(path).read_text(encoding="utf-8")))


def simpan_sesi(s: Sesi, folder: Path) -> Path:
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / f"{s.id}.json"
    path.write_text(json.dumps(sesi_ke_json(s), separators=(",", ":")), encoding="utf-8")
    return path


def muat_folder(folder: Path, gerakan: str | None = None) -> list[Sesi]:
    hasil = []
    for p in sorted(Path(folder).rglob("*.json")):
        try:
            s = muat_sesi(p)
        except (ValueError, KeyError, json.JSONDecodeError):
            continue
        if gerakan is None or s.gerakan == gerakan:
            hasil.append(s)
    return hasil


def muat_anotasi(path: Path | None) -> dict[tuple[str, int], str]:
    """anotasi.csv berkolom sesi,rep,label. Label BUANG = repetisi dibuang."""
    if path is None or not Path(path).exists():
        return {}
    with open(path, encoding="utf-8", newline="") as f:
        return {(r["sesi"], int(r["rep"])): r["label"].strip() for r in csv.DictReader(f)}


def potong_repetisi(s: Sesi, gerakan: Gerakan, anotasi: dict | None = None,
                    hitung_fitur: bool = True) -> list[Repetisi]:
    anotasi = anotasi or {}
    hasil = []
    for k, (a, b) in enumerate(segmentasi(s.t, s.xy, s.vis, gerakan)):
        label = anotasi.get((s.id, k), s.label)
        if label == BUANG:
            continue
        if label not in gerakan.kode:
            raise ValueError(f"label {label!r} di sesi {s.id} rep {k} bukan kelas {gerakan.id}")
        r = Repetisi(sesi=s.id, subjek=s.subjek, gerakan=gerakan.id, indeks=k, label=label,
                     t=s.t[a:b + 1], xy=s.xy[a:b + 1], vis=s.vis[a:b + 1])
        if hitung_fitur:
            r.seq, r.ring = proses_repetisi(r.t, r.xy, r.vis, gerakan)
        hasil.append(r)
    return hasil


def larik(reps: list[Repetisi], gerakan: Gerakan):
    """Ubah daftar repetisi menjadi (SEQ, RING, y, grup)."""
    seq = np.stack([r.seq for r in reps]).astype(np.float32)
    ring = np.stack([r.ring for r in reps])
    y = np.array([gerakan.indeks(r.label) for r in reps])
    grup = np.array([r.subjek for r in reps])
    return seq, ring, y, grup


def muat_dataset(folder: Path, id_gerakan: str, anotasi: Path | None = None):
    g = ambil(id_gerakan)
    sesi = muat_folder(folder, g.id)
    if not sesi:
        raise SystemExit(f"tidak ada berkas sesi {g.id} di {folder}")
    an = muat_anotasi(anotasi)
    reps = [r for s in sesi for r in potong_repetisi(s, g, an)]
    return g, sesi, reps
