"""Ekstraksi landmark dari berkas video dengan MediaPipe Pose Landmarker.

    python -m postur video rekaman.mp4 --subjek S01 --gerakan squat --label SQ-0

Dipakai untuk video yang direkam di luar aplikasi atau dataset publik.
Catatan: aplikasi memakai ML Kit, bukan MediaPipe. Keduanya memakai
topologi BlazePose yang sama, tetapi keluarannya tidak identik; bila
mencampur sumber, laporkan sumber_pose di Bab IV dan pertimbangkan untuk
mengevaluasinya terpisah.
"""
import urllib.request
from datetime import datetime
from pathlib import Path

import numpy as np

from . import landmark as L
from .data import Sesi

URL_MODEL = ("https://storage.googleapis.com/mediapipe-models/pose_landmarker/"
             "pose_landmarker_full/float16/latest/pose_landmarker_full.task")
MODEL = Path(__file__).resolve().parent.parent / "model" / "pose_landmarker_full.task"


def _pastikan_model() -> Path:
    if not MODEL.exists():
        MODEL.parent.mkdir(parents=True, exist_ok=True)
        print(f"mengunduh model MediaPipe ke {MODEL} ...")
        urllib.request.urlretrieve(URL_MODEL, MODEL)
    return MODEL


def sesi_dari_video(path: Path, subjek: str, gerakan: str, label: str,
                    repetisi: int | None = None) -> Sesi:
    import cv2
    import mediapipe as mp
    from mediapipe.tasks import python as mpp
    from mediapipe.tasks.python import vision

    opsi = vision.PoseLandmarkerOptions(
        base_options=mpp.BaseOptions(model_asset_path=str(_pastikan_model())),
        running_mode=vision.RunningMode.VIDEO,
        num_poses=1,
    )
    cap = cv2.VideoCapture(str(path))
    if not cap.isOpened():
        raise SystemExit(f"video tidak bisa dibuka: {path}")
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    lebar = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    tinggi = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    t, xy, vis = [], [], []
    with vision.PoseLandmarker.create_from_options(opsi) as det:
        i = 0
        while True:
            ok, bgr = cap.read()
            if not ok:
                break
            ms = int(round(i * 1000.0 / fps))
            gambar = mp.Image(image_format=mp.ImageFormat.SRGB,
                              data=cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB))
            hasil = det.detect_for_video(gambar, ms)
            p = np.zeros((L.JUMLAH, 2))
            v = np.zeros(L.JUMLAH)
            if hasil.pose_landmarks:
                for j, lm in enumerate(hasil.pose_landmarks[0][:L.JUMLAH]):
                    # Koordinat MediaPipe ternormalisasi 0–1; aplikasi menyimpan
                    # piksel, jadi dikalikan ukuran bingkai supaya sebanding.
                    p[j] = (lm.x * lebar, lm.y * tinggi)
                    v[j] = lm.visibility if lm.visibility is not None else 1.0
            t.append(float(ms))
            xy.append(p)
            vis.append(v)
            i += 1
    cap.release()
    if not t:
        raise SystemExit(f"tidak ada frame terbaca dari {path}")
    cap_waktu = datetime.now().strftime("%Y%m%dT%H%M%S")
    return Sesi(
        id=f"{subjek}-{gerakan}-{label}-{Path(path).stem}-{cap_waktu}",
        subjek=subjek, gerakan=gerakan, label=label,
        t=np.array(t), xy=np.stack(xy), vis=np.stack(vis), repetisi_manual=repetisi,
        meta={"sumber_pose": "mediapipe-full", "lebar": lebar, "tinggi": tinggi,
              "kamera": "video", "video": Path(path).name},
    )
