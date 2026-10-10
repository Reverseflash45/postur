"""Random Forest: pelatihan dengan pencarian hiperparameter dan ekspor ke JSON.

Aplikasi menjalankan hutan ini langsung di Dart (lib/inti/klasifikasi/hutan.dart)
dari berkas JSON, tanpa TFLite.
"""
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import GridSearchCV, GroupKFold

GRID = {"max_depth": [8, 12, 16], "min_samples_leaf": [1, 3]}


def latih_hutan(R: np.ndarray, y: np.ndarray, grup: np.ndarray, benih: int = 0,
                n_pohon: int = 100, cari: bool = True) -> RandomForestClassifier:
    dasar = RandomForestClassifier(n_estimators=n_pohon, class_weight="balanced",
                                   random_state=benih, n_jobs=-1)
    n_grup = len(np.unique(grup))
    if not cari or n_grup < 3:
        return dasar.set_params(max_depth=12, min_samples_leaf=1).fit(R, y)
    cv = GroupKFold(n_splits=min(3, n_grup))
    gs = GridSearchCV(dasar, GRID, scoring="f1_macro", cv=cv, n_jobs=1)
    gs.fit(R, y, groups=grup)
    return gs.best_estimator_


def proba_lengkap(rf: RandomForestClassifier, R: np.ndarray, n_kelas: int) -> np.ndarray:
    """predict_proba dengan kolom untuk semua kelas, termasuk yang tak ada di data latih."""
    p = np.zeros((len(R), n_kelas))
    p[:, rf.classes_.astype(int)] = rf.predict_proba(R)
    return p


def hutan_ke_json(rf: RandomForestClassifier, n_kelas: int, gerakan: str) -> dict:
    pohon = []
    for est in rf.estimators_:
        tr = est.tree_
        nilai = tr.value[:, 0, :]
        nilai = nilai / np.maximum(nilai.sum(axis=1, keepdims=True), 1e-12)
        daun = tr.children_left == -1
        pohon.append({
            "f": tr.feature.tolist(),
            "t": [float(v) for v in tr.threshold],
            "l": tr.children_left.tolist(),
            "r": tr.children_right.tolist(),
            # Peluang kelas hanya untuk daun; simpul dalam diisi null.
            "p": [[round(float(v), 6) for v in nilai[i]] if daun[i] else None
                  for i in range(tr.node_count)],
        })
    return {"jenis": "hutan", "gerakan": gerakan, "n_kelas": n_kelas,
            "kelas": [int(c) for c in rf.classes_], "pohon": pohon}


def prediksi_json(model: dict, R: np.ndarray) -> np.ndarray:
    """Penerjemah hutan JSON dalam Python, untuk memastikan ekspornya setia."""
    R32 = R.astype(np.float32)
    hasil = np.zeros((len(R), model["n_kelas"]))
    kelas = model["kelas"]
    for pohon in model["pohon"]:
        f, t, l, r, p = pohon["f"], pohon["t"], pohon["l"], pohon["r"], pohon["p"]
        for n in range(len(R)):
            i = 0
            while l[i] != -1:
                i = l[i] if R32[n, f[i]] <= t[i] else r[i]
            for k, c in enumerate(kelas):
                hasil[n, c] += p[i][k]
    return hasil / len(model["pohon"])
