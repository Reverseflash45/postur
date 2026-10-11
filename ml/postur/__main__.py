"""Antarmuka baris perintah.

    python -m postur sintetis --subjek 20 --keluar data/sintetis
    python -m postur latih --data data/sintetis --gerakan squat --keluar hasil
    python -m postur video rekaman.mp4 --subjek S01 --gerakan squat --label SQ-0 --keluar data/video
    python -m postur periksa --data data/rekaman
"""
import argparse
from collections import Counter
from pathlib import Path


def main(argv=None):
    ap = argparse.ArgumentParser(prog="postur")
    sub = ap.add_subparsers(dest="perintah", required=True)

    s = sub.add_parser("sintetis", help="bangkitkan sesi sintetis untuk uji pipeline")
    s.add_argument("--subjek", type=int, default=20)
    s.add_argument("--benih", type=int, default=7)
    s.add_argument("--keluar", type=Path, default=Path("data/sintetis"))

    s = sub.add_parser("latih", help="validasi silang per subjek + ekspor model")
    s.add_argument("--data", type=Path, required=True)
    s.add_argument("--gerakan", choices=["squat", "pushup", "semua"], default="semua")
    s.add_argument("--keluar", type=Path, default=Path("hasil"))
    s.add_argument("--anotasi", type=Path, default=None, help="anotasi.csv (sesi,rep,label)")
    s.add_argument("--fold", type=int, default=5)
    s.add_argument("--augmentasi", type=int, default=2)
    s.add_argument("--epoch", type=int, default=80)
    s.add_argument("--benih", type=int, default=0)
    s.add_argument("--model", default="aturan,rf,cnn,lstm")
    s.add_argument("--tanpa-ekspor", action="store_true")
    s.add_argument("--tanpa-kurva", action="store_true", help="lewati kurva belajar")

    s = sub.add_parser("periksa", help="ringkasan isi folder sesi dan repetisi yang terdeteksi")
    s.add_argument("--data", type=Path, required=True)
    s.add_argument("--anotasi", type=Path, default=None)
    s.add_argument("--csv", type=Path, default=None, help="tulis templat anotasi.csv")

    s = sub.add_parser("video", help="ekstrak landmark dari video dengan MediaPipe")
    s.add_argument("video", type=Path, nargs="+")
    s.add_argument("--subjek", required=True)
    s.add_argument("--gerakan", choices=["squat", "pushup"], required=True)
    s.add_argument("--label", required=True)
    s.add_argument("--repetisi", type=int, default=None, help="hitungan manual")
    s.add_argument("--keluar", type=Path, default=Path("data/video"))

    s = sub.add_parser("paritas", help="tulis berkas uji kesetiaan Python–Dart")
    s.add_argument("--keluar", type=Path, default=Path("../app/test/fixture"))

    s = sub.add_parser("demo", help="tulis sesi demo untuk aplikasi")
    s.add_argument("--keluar", type=Path, default=Path("../app/assets/demo"))

    a = ap.parse_args(argv)

    if a.perintah == "paritas":
        from .paritas import tulis_paritas
        print("ditulis:", tulis_paritas(a.keluar))
    elif a.perintah == "demo":
        from .paritas import tulis_demo
        for p in tulis_demo(a.keluar):
            print("ditulis:", p)

    if a.perintah == "sintetis":
        from .data import simpan_sesi
        from .sintetis import bangkitkan
        sesi = bangkitkan(a.subjek, a.benih)
        for x in sesi:
            simpan_sesi(x, a.keluar / x.gerakan)
        import json
        from .sintetis import profil_acak
        (a.keluar / "subjek").mkdir(parents=True, exist_ok=True)
        for p in profil_acak(a.subjek, a.benih):
            (a.keluar / "subjek" / f"subjek-{p['kode']}.json").write_text(json.dumps(p), encoding="utf-8")
        print(f"{len(sesi)} sesi sintetis + {a.subjek} profil subjek ditulis ke {a.keluar}")

    elif a.perintah == "latih":
        from .latih import eksperimen
        daftar = ["squat", "pushup"] if a.gerakan == "semua" else [a.gerakan]
        for gid in daftar:
            eksperimen(a.data, gid, a.keluar, k=a.fold, aug=a.augmentasi, epoch=a.epoch,
                       benih=a.benih, anotasi=a.anotasi, model=tuple(a.model.split(",")),
                       ekspor=not a.tanpa_ekspor, kurva=not a.tanpa_kurva)

    elif a.perintah == "periksa":
        import csv
        from .data import muat_anotasi, muat_folder, potong_repetisi
        from .gerakan import ambil
        sesi = muat_folder(a.data)
        an = muat_anotasi(a.anotasi)
        baris = []
        for s in sesi:
            g = ambil(s.gerakan)
            reps = potong_repetisi(s, g, an, hitung_fitur=False)
            print(f"{s.id:40s} {s.label:5s} subjek {s.subjek:5s} frame {len(s.t):5d} "
                  f"rep {len(reps):3d} manual {s.repetisi_manual}")
            baris += [(s.id, r.indeks, r.label) for r in reps]
        print("Repetisi per label:", dict(sorted(Counter(b[2] for b in baris).items())))
        from .subjek import muat_profil, ringkas
        profil = muat_profil(a.data)
        if profil:
            r = ringkas(profil, {s.subjek for s in sesi})
            print(f"Profil subjek: {r['n']}; JK {r['jenis_kelamin']}; usia {r['usia']}; "
                  f"pengalaman {r['pengalaman']}")
            if r["tanpa_profil"]:
                print("  tanpa profil:", ", ".join(r["tanpa_profil"]))
            if r["tanpa_persetujuan"]:
                print("  PERINGATAN persetujuan belum tercatat:", ", ".join(r["tanpa_persetujuan"]))
        if a.csv:
            with open(a.csv, "w", encoding="utf-8", newline="") as f:
                w = csv.writer(f)
                w.writerow(["sesi", "rep", "label"])
                w.writerows(baris)
            print(f"templat anotasi ditulis ke {a.csv}; ubah labelnya atau isi BUANG")

    elif a.perintah == "video":
        from .data import simpan_sesi
        from .video import sesi_dari_video
        for v in a.video:
            s = sesi_dari_video(v, a.subjek, a.gerakan, a.label, a.repetisi)
            print("ditulis:", simpan_sesi(s, a.keluar / a.gerakan))


if __name__ == "__main__":
    main()
