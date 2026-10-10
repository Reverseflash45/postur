"""Berkas uji kesetiaan Python ↔ Dart dan sesi demo untuk aplikasi.

    python -m postur paritas --keluar ../app/test/fixture
    python -m postur demo --keluar ../app/assets/demo

Aplikasi menghitung ulang semua fitur di Dart. Uji di app/test memuat
paritas.json dan memastikan sinyal, potongan repetisi, fitur, dan prediksi
aturan/hutan sama dengan hasil Python.
"""
import json
from pathlib import Path

import numpy as np

from . import sintetis
from .aturan import KlasifikasiAturan
from .data import potong_repetisi, sesi_dari_json, sesi_ke_json
from .fitur import proses_repetisi
from .gerakan import PUSHUP, SQUAT
from .hutan import hutan_ke_json, latih_hutan, prediksi_json
from .repetisi import segmentasi, sinyal_utama


def _bulat(s):
    """Sesi melewati JSON supaya angkanya persis sama dengan yang dibaca Dart."""
    return sesi_dari_json(json.loads(json.dumps(sesi_ke_json(s))))


def tulis_paritas(folder: Path) -> Path:
    rng = np.random.default_rng(11)
    subjek = sintetis.subjek_acak("P1", rng)
    hasil = {}
    for g in (SQUAT, PUSHUP):
        latih = [_bulat(sintetis.buat_sesi(g, lab, subjek, rng, 4)) for lab in g.kode]
        reps = [r for s in latih for r in potong_repetisi(s, g)]
        R = np.stack([r.ring for r in reps])
        y = np.array([g.indeks(r.label) for r in reps])
        at = KlasifikasiAturan(g).fit(R, y)
        rf = latih_hutan(R, y, np.array(["P1"] * len(y)), n_pohon=5, cari=False)
        js = hutan_ke_json(rf, len(g.kelas), g.id)

        sesi = _bulat(sintetis.buat_sesi(g, g.kode[1], subjek, rng, 3))
        sinyal = [sinyal_utama(sesi.xy[i], sesi.vis[i], g) for i in range(len(sesi.t))]
        potong = segmentasi(sesi.t, sesi.xy, sesi.vis, g)
        contoh = []
        for a, b in potong:
            seq, ring = proses_repetisi(sesi.t[a:b + 1], sesi.xy[a:b + 1], sesi.vis[a:b + 1], g)
            contoh.append({
                "mulai": a, "selesai": b, "seq": seq.tolist(), "ring": ring.tolist(),
                "aturan": int(at.predict(ring[None])[0]),
                "hutan": prediksi_json(js, ring[None])[0].tolist(),
            })
        hasil[g.id] = {"sesi": sesi_ke_json(sesi), "sinyal": sinyal,
                       "repetisi": [list(p) for p in potong], "contoh": contoh,
                       "model_aturan": at.ke_json(), "model_hutan": js}
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / "paritas.json"
    path.write_text(json.dumps(hasil, separators=(",", ":")), encoding="utf-8")
    return path


def tulis_demo(folder: Path) -> list[Path]:
    """Satu sesi per gerakan dengan label campuran, untuk mode demo tanpa kamera."""
    rng = np.random.default_rng(21)
    subjek = sintetis.subjek_acak("DEMO", rng)
    subjek.derau_px = 2.0
    folder.mkdir(parents=True, exist_ok=True)
    hasil = []
    for g, urutan in ((SQUAT, [0, 0, 1, 0, 2, 0, 3, 0]), (PUSHUP, [0, 0, 1, 0, 3, 0, 2, 0])):
        label_rep = [g.kode[i] for i in urutan]
        s = sintetis.buat_sesi(g, g.kode[0], subjek, rng, label_rep=label_rep)
        s.id = f"demo-{g.id}"
        path = folder / f"{g.id}.json"
        path.write_text(json.dumps(sesi_ke_json(s), separators=(",", ":")), encoding="utf-8")
        hasil.append(path)
    return hasil
