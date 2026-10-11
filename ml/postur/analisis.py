"""Analisis tambahan untuk Bab IV: F1 per subjek, kurva belajar, fitur penting,
dan ekspor tabel LaTeX.

Dipanggil dari latih.eksperimen; hasilnya ikut ke laporan.md dan metrik.json.
"""
from pathlib import Path

import numpy as np
from sklearn.metrics import f1_score
from sklearn.model_selection import GroupKFold

from .augmentasi import perbanyak
from .aturan import KlasifikasiAturan
from .data import Repetisi
from .fitur import NAMA_RINGKASAN
from .gerakan import Gerakan
from .hutan import latih_hutan, proba_lengkap


def _plt():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    return plt


def f1_per_subjek(y: np.ndarray, oof: dict, grup: np.ndarray, n_kelas: int) -> dict:
    """Macro-F1 tiap subjek untuk tiap model (dari prediksi out-of-fold)."""
    hasil = {}
    for m, pred in oof.items():
        hasil[m] = {}
        for s in sorted(set(grup)):
            idx = grup == s
            hasil[m][str(s)] = float(f1_score(y[idx], pred[idx], average="macro",
                                              labels=list(range(n_kelas)), zero_division=0))
    return hasil


def kurva_belajar(reps: list[Repetisi], g: Gerakan, k: int, aug: int, benih: int,
                  ulang: int = 3) -> dict:
    """Macro-F1 aturan dan RF terhadap jumlah subjek latih.

    Untuk tiap fold luar, model dilatih dengan n subjek acak dari data latih
    (diulang beberapa kali) lalu diuji pada subjek fold itu. Menjawab
    pertanyaan "berapa subjek yang cukup?".
    """
    rng = np.random.default_rng(benih)
    grup = np.array([r.subjek for r in reps])
    y = np.array([g.indeks(r.label) for r in reps])
    R = np.stack([r.ring for r in reps])
    subjek = np.unique(grup)
    n_latih_maks = len(subjek) - len(subjek) // k
    ukuran = sorted({n for n in (2, 4, 6, 8, 12, 16, 24, 32) if n < n_latih_maks} | {n_latih_maks})
    hasil = {"ukuran": ukuran, "aturan": [], "rf": []}
    lipat = list(GroupKFold(n_splits=k).split(R, y, grup))
    for n in ukuran:
        skor = {"aturan": [], "rf": []}
        for tr, te in lipat:
            s_tr = np.unique(grup[tr])
            for _ in range(ulang if n < len(s_tr) else 1):
                pilih = set(rng.choice(s_tr, size=min(n, len(s_tr)), replace=False))
                reps_tr = [reps[i] for i in tr if grup[i] in pilih]
                _, Ra, ya, ga = perbanyak(reps_tr, g, aug, benih)
                at = KlasifikasiAturan(g).fit(Ra, ya)
                skor["aturan"].append(f1_score(y[te], at.predict(R[te]), average="macro",
                                               labels=list(range(len(g.kelas))), zero_division=0))
                rf = latih_hutan(Ra, ya, ga, benih=benih, cari=False)
                pr = proba_lengkap(rf, R[te], len(g.kelas)).argmax(1)
                skor["rf"].append(f1_score(y[te], pr, average="macro",
                                           labels=list(range(len(g.kelas))), zero_division=0))
        for m in ("aturan", "rf"):
            hasil[m].append({"rerata": float(np.mean(skor[m])), "sb": float(np.std(skor[m]))})
        print(f"    kurva belajar n={n}: aturan {hasil['aturan'][-1]['rerata']:.3f}, "
              f"rf {hasil['rf'][-1]['rerata']:.3f}")
    return hasil


def gambar_kurva(kurva: dict, judul: str, path: Path):
    plt = _plt()
    fig, ax = plt.subplots(figsize=(5, 3.2), dpi=150)
    x = kurva["ukuran"]
    for m, nama, warna in (("aturan", "Aturan", "#888888"), ("rf", "Random Forest", "#1f6f5c")):
        r = np.array([v["rerata"] for v in kurva[m]])
        s = np.array([v["sb"] for v in kurva[m]])
        ax.plot(x, r, marker="o", color=warna, label=nama)
        ax.fill_between(x, r - s, r + s, color=warna, alpha=0.15)
    ax.set_xlabel("Jumlah subjek latih")
    ax.set_ylabel("Macro-F1")
    ax.set_ylim(0, 1)
    ax.grid(alpha=0.3)
    ax.legend(fontsize=8)
    ax.set_title(judul, fontsize=10)
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def fitur_penting(reps: list[Repetisi], g: Gerakan, aug: int, benih: int, n: int = 15) -> list[dict]:
    """Kepentingan fitur Random Forest (penurunan impurity rerata), dilatih pada semua data."""
    _, R, y, grup = perbanyak(reps, g, aug, benih)
    rf = latih_hutan(R, y, grup, benih=benih, cari=False)
    urut = np.argsort(rf.feature_importances_)[::-1][:n]
    return [{"fitur": NAMA_RINGKASAN[i], "nilai": float(rf.feature_importances_[i])} for i in urut]


def gambar_fitur(penting: list[dict], judul: str, path: Path):
    plt = _plt()
    fig, ax = plt.subplots(figsize=(5, 3.8), dpi=150)
    nama = [p["fitur"] for p in penting][::-1]
    nilai = [p["nilai"] for p in penting][::-1]
    ax.barh(nama, nilai, color="#1f6f5c")
    ax.set_xlabel("Kepentingan (penurunan impurity)")
    ax.tick_params(axis="y", labelsize=7)
    ax.set_title(judul, fontsize=10)
    ax.grid(axis="x", alpha=0.3)
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def gambar_per_subjek(per: dict, nama_model: dict, judul: str, path: Path):
    plt = _plt()
    model = [m for m in ("aturan", "rf", "cnn", "lstm") if m in per]
    subjek = list(per[model[0]].keys())
    fig, ax = plt.subplots(figsize=(max(5, 0.35 * len(subjek) + 2), 3.2), dpi=150)
    lebar = 0.8 / len(model)
    warna = ["#999999", "#1f6f5c", "#d98c1f", "#7a5fc4"]
    for i, m in enumerate(model):
        x = np.arange(len(subjek)) + i * lebar
        ax.bar(x, [per[m][s] for s in subjek], lebar, label=nama_model[m], color=warna[i])
    ax.set_xticks(np.arange(len(subjek)) + 0.4 - lebar / 2, subjek, fontsize=7, rotation=90)
    ax.set_ylim(0, 1)
    ax.set_ylabel("Macro-F1")
    ax.legend(fontsize=7, ncol=len(model))
    ax.set_title(judul, fontsize=10)
    ax.grid(axis="y", alpha=0.3)
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


# ---------------------------------------------------------------------------
# LaTeX
# ---------------------------------------------------------------------------

def _esc(s: str) -> str:
    return s.replace("_", r"\_").replace("%", r"\%").replace("&", r"\&")


def tulis_latex(m: dict, g: Gerakan, nama_model: dict) -> str:
    """Tabel booktabs siap tempel ke Bab IV (butuh \\usepackage{booktabs})."""
    b = [f"% Tabel hasil {g.nama} — dibuat otomatis oleh postur.latih", ""]
    b += [r"\begin{table}[htbp]", r"\centering",
          rf"\caption{{Kinerja klasifikasi {g.nama.lower()} (validasi silang {m['k_fold']}-fold per subjek)}}",
          rf"\label{{tab:kinerja-{g.id}}}", r"\begin{tabular}{lcc}", r"\toprule",
          r"Model & Macro-F1 & Akurasi \\", r"\midrule"]
    for k, v in m["model"].items():
        b.append(rf"{_esc(nama_model[k])} & {v['macro_f1_rerata']:.3f} $\pm$ {v['macro_f1_sb']:.3f} & "
                 rf"{v['akurasi']:.3f} \\")
    b += [r"\bottomrule", r"\end{tabular}", r"\end{table}", ""]

    utama = [k for k in ("aturan", "rf", "cnn", "lstm") if k in m["model"]]
    if utama:
        b += [r"\begin{table}[htbp]", r"\centering",
              rf"\caption{{F1 per kelas {g.nama.lower()}}}", rf"\label{{tab:perkelas-{g.id}}}",
              r"\begin{tabular}{l" + "c" * len(utama) + "}", r"\toprule",
              "Kelas & " + " & ".join(_esc(nama_model[k]) for k in utama) + r" \\", r"\midrule"]
        for kelas in g.kelas:
            nilai = " & ".join(f"{m['model'][k]['per_kelas'][kelas.kode]['f1']:.3f}" for k in utama)
            b.append(rf"{kelas.kode} {_esc(kelas.nama)} & {nilai} \\")
        b += [r"\bottomrule", r"\end{tabular}", r"\end{table}", ""]

    if m.get("mcnemar"):
        b += [r"\begin{table}[htbp]", r"\centering", rf"\caption{{Uji McNemar {g.nama.lower()}}}",
              rf"\label{{tab:mcnemar-{g.id}}}", r"\begin{tabular}{lccc}", r"\toprule",
              r"Pasangan & $b$ & $c$ & $p$ \\", r"\midrule"]
        for k, v in m["mcnemar"].items():
            a, c = k.split("_vs_")
            b.append(rf"{_esc(nama_model[a])} vs {_esc(nama_model[c])} & {v['a_benar_b_salah']} & "
                     rf"{v['a_salah_b_benar']} & {v['p']:.4f} \\")
        b += [r"\bottomrule", r"\end{tabular}", r"\end{table}", ""]

    h = m.get("hitung_repetisi", {})
    if h.get("n_set"):
        b += [rf"% Penghitungan repetisi: MAE {h['mae']:.3f}, tepat {h['persen_tepat']:.1f}\% dari {h['n_set']} set", ""]
    return "\n".join(b) + "\n"
