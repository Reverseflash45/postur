"""Profil subjek penelitian (dari aplikasi, mode sesi terpandu).

Aplikasi mengekspor satu berkas per subjek bersama rekaman:

    {"format": "postur-subjek", "versi": 1, "kode": "S01", "usia": "18-24",
     "jenis_kelamin": "L", "pengalaman": "rutin", "tinggi_cm": 170,
     "persetujuan": true, "dibuat": "..."}

Isinya anonim (tanpa nama) dan dipakai untuk tabel karakteristik subjek di
Bab III/IV.
"""
import json
from pathlib import Path

import numpy as np

FORMAT = "postur-subjek"
RENTANG_USIA = ["18-24", "25-34", "35-44", "45+"]
PENGALAMAN = {"pemula": "Pemula", "kadang": "Kadang-kadang", "rutin": "Rutin"}
JENIS_KELAMIN = {"L": "Laki-laki", "P": "Perempuan"}


def muat_profil(folder: Path) -> dict[str, dict]:
    """Semua profil subjek di bawah folder (rekursif), dikunci kode subjek."""
    hasil = {}
    for p in sorted(Path(folder).rglob("*.json")):
        try:
            d = json.loads(p.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue
        if isinstance(d, dict) and d.get("format") == FORMAT:
            hasil[str(d["kode"])] = d
    return hasil


def ringkas(profil: dict[str, dict], dipakai: set[str] | None = None) -> dict:
    """Ringkasan demografi untuk subjek yang datanya dipakai.

    Subjek di `dipakai` yang tidak punya profil dicatat di `tanpa_profil`.
    """
    kode = sorted(dipakai if dipakai is not None else profil)
    ada = [profil[k] for k in kode if k in profil]
    tinggi = [p["tinggi_cm"] for p in ada if p.get("tinggi_cm")]
    hitung = lambda kunci, nilai: {n: sum(1 for p in ada if p.get(kunci) == n) for n in nilai}
    return {
        "n": len(ada),
        "tanpa_profil": [k for k in kode if k not in profil],
        "tanpa_persetujuan": [p["kode"] for p in ada if not p.get("persetujuan")],
        "jenis_kelamin": hitung("jenis_kelamin", JENIS_KELAMIN),
        "usia": hitung("usia", RENTANG_USIA),
        "pengalaman": hitung("pengalaman", PENGALAMAN),
        "tinggi_cm": None if not tinggi else {
            "n": len(tinggi), "min": int(min(tinggi)), "maks": int(max(tinggi)),
            "rerata": round(float(np.mean(tinggi)), 1), "sb": round(float(np.std(tinggi, ddof=1)), 1) if len(tinggi) > 1 else 0.0,
        },
    }


def _persen(n: int, total: int) -> str:
    return f"{n} ({100 * n / total:.0f}%)" if total else "0"


def _baris(r: dict) -> list[tuple[str, str, str]]:
    """(kelompok, kategori, nilai) untuk tabel karakteristik."""
    n = r["n"]
    b = []
    for kunci, judul, nama in (("jenis_kelamin", "Jenis kelamin", JENIS_KELAMIN),
                               ("usia", "Usia (tahun)", {u: u for u in RENTANG_USIA}),
                               ("pengalaman", "Pengalaman latihan", PENGALAMAN)):
        pertama = True
        for k, v in r[kunci].items():
            if v == 0:
                continue
            b.append((judul if pertama else "", nama[k], _persen(v, n)))
            pertama = False
    t = r["tinggi_cm"]
    if t:
        b.append(("Tinggi badan (cm)", f"rerata ± SB (n={t['n']})", f"{t['rerata']} ± {t['sb']}"))
        b.append(("", "rentang", f"{t['min']}–{t['maks']}"))
    return b


def tabel_markdown(r: dict) -> list[str]:
    b = [f"Jumlah subjek: {r['n']}", "", "| Karakteristik | Kategori | n (%) |", "|---|---|---|"]
    b += [f"| {a} | {k} | {v} |" for a, k, v in _baris(r)]
    if r["tanpa_profil"]:
        b += ["", f"Tanpa profil: {', '.join(r['tanpa_profil'])} (direkam lewat set manual)."]
    if r["tanpa_persetujuan"]:
        b += ["", f"**Persetujuan belum tercatat:** {', '.join(r['tanpa_persetujuan'])}."]
    return b


def tabel_latex(r: dict) -> str:
    """Tabel booktabs karakteristik subjek."""
    b = ["% Karakteristik subjek — dibuat otomatis oleh postur", "",
         r"\begin{table}[htbp]", r"\centering",
         rf"\caption{{Karakteristik subjek penelitian ($n={r['n']}$)}}",
         r"\label{tab:subjek}", r"\begin{tabular}{llr}", r"\toprule",
         r"Karakteristik & Kategori & $n$ (\%) \\", r"\midrule"]
    for a, k, v in _baris(r):
        a, k, v = (x.replace("%", r"\%").replace("±", r"$\pm$").replace("–", "--") for x in (a, k, v))
        b.append(rf"{a} & {k} & {v} \\")
    b += [r"\bottomrule", r"\end{tabular}", r"\end{table}", ""]
    return "\n".join(b)
