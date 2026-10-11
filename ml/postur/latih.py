"""Eksperimen utama: validasi silang per subjek, laporan, dan ekspor model akhir.

    python -m postur latih --data data/rekaman --gerakan squat

Hasil di <keluar>/<gerakan>/: laporan.md, metrik.json, confusion matrix (PNG),
dan folder model/ yang tinggal disalin ke app/assets/model/<gerakan>/.
"""
import json
import time
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from scipy.stats import binomtest
from sklearn.metrics import accuracy_score, confusion_matrix, f1_score, precision_recall_fscore_support
from sklearn.model_selection import GroupKFold

from . import analisis, saraf
from . import subjek as profil_subjek
from .augmentasi import perbanyak
from .aturan import KlasifikasiAturan
from .data import Repetisi, larik, muat_dataset
from .fitur import NAMA_FITUR, NAMA_RINGKASAN
from .gerakan import Gerakan
from .hutan import hutan_ke_json, latih_hutan, prediksi_json, proba_lengkap
from .repetisi import segmentasi
from .sinyal import PANJANG

MODEL = ("aturan", "rf", "cnn", "lstm")
NAMA_MODEL = {
    "aturan": "Aturan (baseline)", "rf": "Random Forest", "cnn": "1D-CNN", "lstm": "LSTM",
    "cnn_tfl": "1D-CNN TFLite float32", "cnn_int8": "1D-CNN TFLite int8",
    "lstm_tfl": "LSTM TFLite float32", "lstm_int8": "LSTM TFLite int8",
}


def _bagi_validasi(reps: list[Repetisi], rng) -> tuple[list, list]:
    """Sisihkan ±20% subjek data latih sebagai validasi early stopping."""
    subjek = sorted({r.subjek for r in reps})
    rng.shuffle(subjek)
    n_val = max(1, round(0.2 * len(subjek))) if len(subjek) >= 3 else 0
    val = set(subjek[:n_val])
    return [r for r in reps if r.subjek not in val], [r for r in reps if r.subjek in val]


def _latih_saraf(jenis, reps_latih, g, aug, epoch, benih):
    rng = np.random.default_rng(benih)
    fit, val = _bagi_validasi(reps_latih, rng)
    X, _, y, _ = perbanyak(fit, g, aug, benih)
    Xv, yv = (None, None)
    if val:
        Xv, _, yv, _ = larik(val, g)
    return saraf.latih(jenis, X, y, Xv, yv, len(g.kelas), epoch=epoch, benih=benih), X


def _mcnemar(benar_a: np.ndarray, benar_b: np.ndarray) -> dict:
    b = int(np.sum(benar_a & ~benar_b))
    c = int(np.sum(~benar_a & benar_b))
    p = 1.0 if b + c == 0 else float(binomtest(min(b, c), b + c, 0.5).pvalue)
    return {"a_benar_b_salah": b, "a_salah_b_benar": c, "p": p}


def _gambar_cm(cm: np.ndarray, kode: list[str], judul: str, path: Path):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(4.2, 3.8), dpi=150)
    norm = cm / np.maximum(cm.sum(axis=1, keepdims=True), 1)
    ax.imshow(norm, cmap="Greens", vmin=0, vmax=1)
    for i in range(len(kode)):
        for j in range(len(kode)):
            ax.text(j, i, str(cm[i, j]), ha="center", va="center",
                    color="white" if norm[i, j] > 0.6 else "black", fontsize=9)
    ax.set_xticks(range(len(kode)), kode, fontsize=8)
    ax.set_yticks(range(len(kode)), kode, fontsize=8)
    ax.set_xlabel("Prediksi")
    ax.set_ylabel("Sebenarnya")
    ax.set_title(judul, fontsize=10)
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def evaluasi_hitung(sesi, g: Gerakan) -> dict:
    baris = []
    for s in sesi:
        if s.repetisi_manual is None:
            continue
        otomatis = len(segmentasi(s.t, s.xy, s.vis, g))
        baris.append({"sesi": s.id, "label": s.label, "otomatis": otomatis, "manual": s.repetisi_manual})
    if not baris:
        return {"n_set": 0}
    galat = np.array([abs(b["otomatis"] - b["manual"]) for b in baris])
    return {"n_set": len(baris), "mae": float(galat.mean()),
            "persen_tepat": float(np.mean(galat == 0) * 100), "rincian": baris}


def eksperimen(folder: Path, id_gerakan: str, keluar: Path, k: int = 5, aug: int = 2,
               epoch: int = 80, benih: int = 0, anotasi: Path | None = None,
               model=MODEL, ekspor: bool = True, kurva: bool = True) -> dict:
    t_mulai = time.time()
    g, sesi, reps = muat_dataset(folder, id_gerakan, anotasi)
    out = Path(keluar) / g.id
    out.mkdir(parents=True, exist_ok=True)
    SEQ, RING, y, grup = larik(reps, g)
    subjek = np.unique(grup)
    n_kelas = len(g.kelas)
    k = min(k, len(subjek))
    if k < 2:
        raise SystemExit("butuh minimal 2 subjek untuk validasi silang per subjek")
    sumber = sorted({s.meta.get("sumber_pose", "?") for s in sesi})
    print(f"[{g.id}] {len(sesi)} sesi, {len(reps)} repetisi, {len(subjek)} subjek, sumber {sumber}")
    print("  per kelas:", {c: int(np.sum(y == i)) for i, c in enumerate(g.kode)})

    hitung = evaluasi_hitung(sesi, g)
    print(f"  hitung repetisi: MAE {hitung.get('mae', float('nan')):.3f}, "
          f"tepat {hitung.get('persen_tepat', float('nan')):.1f}% dari {hitung['n_set']} set")

    kunci = list(model)
    if "cnn" in model:
        kunci += ["cnn_tfl", "cnn_int8"]
    if "lstm" in model:
        kunci += ["lstm_tfl", "lstm_int8"]
    oof = {m: np.full(len(y), -1) for m in kunci}
    per_fold = {m: [] for m in kunci}
    latensi = {m: [] for m in kunci if m.endswith(("_tfl", "_int8"))}
    ambang_fold = []

    for f, (tr, te) in enumerate(GroupKFold(n_splits=k).split(SEQ, y, grup)):
        print(f"  fold {f + 1}/{k}: uji subjek {sorted(set(grup[te]))}")
        reps_tr = [reps[i] for i in tr]
        X_aug, R_aug, y_aug, g_aug = perbanyak(reps_tr, g, aug, benih + f)
        if "aturan" in model:
            at = KlasifikasiAturan(g).fit(R_aug, y_aug)
            oof["aturan"][te] = at.predict(RING[te])
            ambang_fold.append(at.ambang.tolist())
        if "rf" in model:
            rf = latih_hutan(R_aug, y_aug, g_aug, benih=benih)
            oof["rf"][te] = proba_lengkap(rf, RING[te], n_kelas).argmax(1)
        for jenis in ("cnn", "lstm"):
            if jenis not in model:
                continue
            m, X_fit = _latih_saraf(jenis, reps_tr, g, aug, epoch, benih + f)
            oof[jenis][te] = m.proba(SEQ[te]).argmax(1)
            X_uji = m.standar(SEQ[te])
            for akhiran, int8 in (("_tfl", False), ("_int8", True)):
                isi = saraf.ke_tflite(m, int8=int8, X_wakil=X_fit)
                pen = saraf.PenerjemahTflite(isi)
                oof[jenis + akhiran][te] = pen.proba(X_uji).argmax(1)
                latensi[jenis + akhiran].append(pen.latensi_ms(X_uji))
        for m in kunci:
            per_fold[m].append(float(f1_score(y[te], oof[m][te], average="macro",
                                              labels=list(range(n_kelas)), zero_division=0)))
        print("    macro-F1:", {m: round(per_fold[m][-1], 3) for m in kunci})

    hasil_model = {}
    for m in kunci:
        p, r, f1, dukungan = precision_recall_fscore_support(
            y, oof[m], labels=list(range(n_kelas)), zero_division=0)
        cm = confusion_matrix(y, oof[m], labels=list(range(n_kelas)))
        hasil_model[m] = {
            "macro_f1_rerata": float(np.mean(per_fold[m])),
            "macro_f1_sb": float(np.std(per_fold[m])),
            "macro_f1_per_fold": per_fold[m],
            "macro_f1_gabungan": float(f1_score(y, oof[m], average="macro", zero_division=0)),
            "akurasi": float(accuracy_score(y, oof[m])),
            "per_kelas": {g.kode[i]: {"presisi": float(p[i]), "recall": float(r[i]),
                                      "f1": float(f1[i]), "n": int(dukungan[i])}
                          for i in range(n_kelas)},
            "confusion_matrix": cm.tolist(),
        }
        if m in latensi:
            hasil_model[m]["latensi_desktop_ms"] = float(np.mean(latensi[m]))
        if m in MODEL:
            _gambar_cm(cm, g.kode, f"{g.nama} – {NAMA_MODEL[m]}", out / f"cm_{m}.png")

    utama = [m for m in MODEL if m in model]
    mcnemar = {}
    for i, a in enumerate(utama):
        for b in utama[i + 1:]:
            mcnemar[f"{a}_vs_{b}"] = _mcnemar(oof[a] == y, oof[b] == y)

    print("  analisis tambahan: F1 per subjek, fitur penting" + (", kurva belajar" if kurva else ""))
    per_subjek = analisis.f1_per_subjek(y, {m: oof[m] for m in MODEL if m in model}, grup, n_kelas)
    analisis.gambar_per_subjek(per_subjek, NAMA_MODEL, f"{g.nama} – macro-F1 per subjek", out / "per_subjek.png")
    penting = analisis.fitur_penting(reps, g, aug, benih)
    analisis.gambar_fitur(penting, f"{g.nama} – 15 fitur terpenting (RF)", out / "fitur_penting.png")
    kb = None
    if kurva:
        kb = analisis.kurva_belajar(reps, g, k, aug, benih)
        analisis.gambar_kurva(kb, f"{g.nama} – kurva belajar", out / "kurva_belajar.png")

    profil = profil_subjek.muat_profil(folder)
    karakteristik = profil_subjek.ringkas(profil, {str(x) for x in subjek}) if profil else None

    metrik = {
        "gerakan": g.id, "dibuat": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "sumber_pose": sumber, "n_sesi": len(sesi), "n_repetisi": len(reps),
        "n_subjek": len(subjek), "k_fold": k, "augmentasi": aug, "epoch_maks": epoch,
        "per_kelas_n": {c: int(np.sum(y == i)) for i, c in enumerate(g.kode)},
        "hitung_repetisi": hitung, "model": hasil_model, "mcnemar": mcnemar,
        "ambang_aturan_per_fold": ambang_fold, "f1_per_subjek": per_subjek,
        "fitur_penting": penting, "kurva_belajar": kb,
        "karakteristik_subjek": karakteristik,
        "durasi_detik": round(time.time() - t_mulai, 1),
    }
    (out / "metrik.json").write_text(json.dumps(metrik, indent=2), encoding="utf-8")
    (out / "laporan.md").write_text(tulis_laporan(metrik, g), encoding="utf-8")
    tex = analisis.tulis_latex(metrik, g, NAMA_MODEL)
    if karakteristik:
        tex += "\n" + profil_subjek.tabel_latex(karakteristik)
    (out / "tabel.tex").write_text(tex, encoding="utf-8")
    print(f"  laporan: {out / 'laporan.md'}")

    if ekspor:
        ekspor_model(reps, g, out / "model", aug=aug, epoch=epoch, benih=benih,
                     sumber=sumber, ringkas={m: hasil_model[m]["macro_f1_rerata"] for m in kunci})
    return metrik


def tulis_laporan(m: dict, g: Gerakan) -> str:
    sintetis = m["sumber_pose"] == ["sintetis"]
    b = [f"# Hasil evaluasi – {g.nama}", ""]
    if sintetis:
        b += ["> **Data sintetis.** Angka di bawah hanya membuktikan pipeline berjalan. "
              "Jangan dilaporkan sebagai hasil penelitian.", ""]
    b += [f"- Dibuat: {m['dibuat']}",
          f"- Data: {m['n_sesi']} sesi, {m['n_repetisi']} repetisi, {m['n_subjek']} subjek "
          f"(sumber pose: {', '.join(m['sumber_pose'])})",
          f"- Validasi: {m['k_fold']}-fold GroupKFold per subjek, augmentasi {m['augmentasi']}× per repetisi latih",
          ""]
    if m.get("karakteristik_subjek"):
        b += ["## Karakteristik subjek", "", *profil_subjek.tabel_markdown(m["karakteristik_subjek"]), ""]
    b += ["## Jumlah repetisi per kelas", "", "| Kelas | Nama | n |", "|---|---|---|"]
    for k in g.kelas:
        b.append(f"| {k.kode} | {k.nama} | {m['per_kelas_n'][k.kode]} |")

    b += ["", "## Kinerja klasifikasi", "",
          "Macro-F1 rerata ± simpangan baku antar-fold; akurasi dari prediksi out-of-fold gabungan.", "",
          "| Model | Macro-F1 | Akurasi |", "|---|---|---|"]
    for k, v in m["model"].items():
        b.append(f"| {NAMA_MODEL[k]} | {v['macro_f1_rerata']:.3f} ± {v['macro_f1_sb']:.3f} | {v['akurasi']:.3f} |")

    for k in [x for x in MODEL if x in m["model"]]:
        v = m["model"][k]
        b += ["", f"### {NAMA_MODEL[k]} per kelas", "", "| Kelas | Presisi | Recall | F1 | n |",
              "|---|---|---|---|---|"]
        for kode, s in v["per_kelas"].items():
            b.append(f"| {kode} | {s['presisi']:.3f} | {s['recall']:.3f} | {s['f1']:.3f} | {s['n']} |")
        b += ["", f"![Confusion matrix {NAMA_MODEL[k]}](cm_{k}.png)"]

    if m["mcnemar"]:
        b += ["", "## Uji McNemar (pasangan model)", "",
              "| Pasangan | A benar, B salah | A salah, B benar | p |", "|---|---|---|---|"]
        for k, v in m["mcnemar"].items():
            a, c = k.split("_vs_")
            b.append(f"| {NAMA_MODEL[a]} vs {NAMA_MODEL[c]} | {v['a_benar_b_salah']} | "
                     f"{v['a_salah_b_benar']} | {v['p']:.4f} |")

    kuant = [(j, m["model"].get(f"{j}_tfl"), m["model"].get(f"{j}_int8")) for j in ("cnn", "lstm")]
    kuant = [x for x in kuant if x[1] and x[2]]
    if kuant:
        b += ["", "## Kuantisasi", "",
              "| Model | Macro-F1 float32 | Macro-F1 int8 | Selisih | Latensi desktop f32 / int8 (ms) |",
              "|---|---|---|---|---|"]
        for j, f32, i8 in kuant:
            b.append(f"| {NAMA_MODEL[j]} | {f32['macro_f1_rerata']:.3f} | {i8['macro_f1_rerata']:.3f} | "
                     f"{i8['macro_f1_rerata'] - f32['macro_f1_rerata']:+.3f} | "
                     f"{f32['latensi_desktop_ms']:.2f} / {i8['latensi_desktop_ms']:.2f} |")
        b += ["", "Latensi di ponsel diukur lewat layar *Uji kinerja* di aplikasi."]

    per = m.get("f1_per_subjek")
    if per:
        utama = [x for x in MODEL if x in per]
        b += ["", "## Macro-F1 per subjek", "",
              "Variasi antar-subjek menunjukkan seberapa stabil model pada orang yang tidak pernah dilihat.", "",
              "| Subjek | " + " | ".join(NAMA_MODEL[x] for x in utama) + " |",
              "|---|" + "---|" * len(utama)]
        for s in per[utama[0]]:
            b.append(f"| {s} | " + " | ".join(f"{per[x][s]:.3f}" for x in utama) + " |")
        b.append("| **Terendah** | " + " | ".join(f"{min(per[x].values()):.3f}" for x in utama) + " |")
        b += ["", "![F1 per subjek](per_subjek.png)"]

    if m.get("fitur_penting"):
        b += ["", "## Fitur terpenting (Random Forest)", "",
              "Penurunan impurity rerata; fitur ringkasan dari deret sudut per repetisi.", "",
              "| # | Fitur | Kepentingan |", "|---|---|---|"]
        b += [f"| {i + 1} | `{f['fitur']}` | {f['nilai']:.4f} |" for i, f in enumerate(m["fitur_penting"])]
        b += ["", "![Fitur penting](fitur_penting.png)"]

    kb = m.get("kurva_belajar")
    if kb:
        b += ["", "## Kurva belajar", "",
              "Macro-F1 pada subjek uji bila model dilatih dengan sebagian subjek latih saja.", "",
              "| Subjek latih | Aturan | Random Forest |", "|---|---|---|"]
        for n, a, r in zip(kb["ukuran"], kb["aturan"], kb["rf"]):
            b.append(f"| {n} | {a['rerata']:.3f} ± {a['sb']:.3f} | {r['rerata']:.3f} ± {r['sb']:.3f} |")
        b += ["", "![Kurva belajar](kurva_belajar.png)"]

    b += ["", "Tabel siap pakai untuk LaTeX ada di `tabel.tex` (butuh paket `booktabs`)."]

    h = m["hitung_repetisi"]
    if h.get("n_set"):
        b += ["", "## Penghitungan repetisi", "",
              f"- MAE: {h['mae']:.3f} repetisi per set",
              f"- Set dengan hitungan tepat: {h['persen_tepat']:.1f}% dari {h['n_set']} set"]
        meleset = [r for r in h["rincian"] if r["otomatis"] != r["manual"]]
        if meleset:
            b += ["", "| Sesi | Otomatis | Manual |", "|---|---|---|"]
            b += [f"| {r['sesi']} | {r['otomatis']} | {r['manual']} |" for r in meleset[:30]]
    return "\n".join(b) + "\n"


def ekspor_model(reps: list[Repetisi], g: Gerakan, folder: Path, aug: int, epoch: int, benih: int,
                 sumber: list[str], ringkas: dict):
    """Latih ulang semua model pada seluruh data lalu tulis berkas untuk aplikasi."""
    folder.mkdir(parents=True, exist_ok=True)
    n_kelas = len(g.kelas)
    print(f"  ekspor model akhir ke {folder}")
    X, R, yy, gg = perbanyak(reps, g, aug, benih)
    at = KlasifikasiAturan(g).fit(R, yy)
    (folder / "aturan.json").write_text(json.dumps(at.ke_json(), indent=1), encoding="utf-8")
    rf = latih_hutan(R, yy, gg, benih=benih)
    js = hutan_ke_json(rf, n_kelas, g.id)
    (folder / "hutan.json").write_text(json.dumps(js, separators=(",", ":")), encoding="utf-8")
    SEQ, RING, y, _ = larik(reps, g)
    selisih = np.abs(prediksi_json(js, RING[:50]) - proba_lengkap(rf, RING[:50], n_kelas)).max()
    assert selisih < 1e-4, f"ekspor hutan tidak setia ({selisih})"
    berkas = {"aturan": "aturan.json", "rf": "hutan.json"}
    standar, model_saraf = {}, {}
    for jenis in ("cnn", "lstm"):
        m, X_fit = _latih_saraf(jenis, reps, g, aug, epoch, benih)
        model_saraf[jenis] = m
        standar[jenis] = {"rerata": m.rerata.tolist(), "sb": m.sb.tolist()}
        for akhiran, int8 in (("", False), ("_int8", True)):
            nama = f"{jenis}{akhiran}.tflite"
            (folder / nama).write_bytes(saraf.ke_tflite(m, int8=int8, X_wakil=X_fit))
            berkas[jenis + akhiran] = nama

    # Contoh repetisi untuk uji kinerja dan uji kesetiaan di aplikasi.
    rng = np.random.default_rng(benih)
    pilih = []
    for i in range(n_kelas):
        idx = np.flatnonzero(y == i)
        pilih += rng.choice(idx, size=min(2, len(idx)), replace=False).tolist()
    contoh = []
    for i in pilih:
        seq = np.round(SEQ[i].astype(np.float64), 5)
        ring = np.round(RING[i], 6)
        isi = {"label": g.kode[y[i]], "seq": seq.tolist(), "ring": ring.tolist(),
               "aturan": g.kode[int(at.predict(ring[None])[0])],
               "rf": prediksi_json(js, ring[None])[0].round(6).tolist()}
        for jenis in ("cnn", "lstm"):
            pen = saraf.PenerjemahTflite((folder / f"{jenis}.tflite").read_bytes())
            isi[jenis] = pen.proba(model_saraf[jenis].standar(seq[None]))[0].round(6).tolist()
        contoh.append(isi)
    (folder / "contoh.json").write_text(json.dumps(contoh, separators=(",", ":")), encoding="utf-8")

    meta = {
        "format": "postur-model", "versi": 1, "gerakan": g.id, "nama": g.nama,
        "dibuat": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "sumber_data": "sintetis" if sumber == ["sintetis"] else "asli",
        "sumber_pose": sumber, "n_repetisi": len(reps), "n_subjek": len(set(r.subjek for r in reps)),
        "panjang": PANJANG, "fitur": NAMA_FITUR, "ringkasan": NAMA_RINGKASAN,
        "kelas": [{"kode": k.kode, "nama": k.nama, "ucapan": k.ucapan} for k in g.kelas],
        "berkas": berkas, "standarisasi": standar, "macro_f1_validasi": ringkas,
    }
    (folder / "meta.json").write_text(json.dumps(meta, indent=1), encoding="utf-8")
