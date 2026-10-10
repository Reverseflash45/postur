"""Model deret waktu (1D-CNN dan LSTM) beserta konversi ke TFLite.

Standarisasi fitur sengaja dilakukan di luar model: sudut (0–180) dan
koordinat (±3) yang masuk ke satu tensor int8 berbagi satu skala kuantisasi,
sehingga koordinat hancur menjadi satu-dua tingkat nilai. Aplikasi menerapkan
(x - rerata) / sb dari meta.json sebelum memanggil interpreter.
"""
import os
import tempfile
import time
import warnings
from dataclasses import dataclass

os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "2")
warnings.filterwarnings("ignore", message=".*tf.lite.Interpreter is deprecated.*")

import numpy as np  # noqa: E402
import tensorflow as tf  # noqa: E402
from tensorflow import keras  # noqa: E402
from tensorflow.keras import layers  # noqa: E402

from .fitur import JUMLAH_FITUR  # noqa: E402
from .sinyal import PANJANG  # noqa: E402

JENIS = ("cnn", "lstm")


@dataclass
class ModelSaraf:
    jenis: str
    keras: keras.Model
    rerata: np.ndarray  # (38,)
    sb: np.ndarray  # (38,)

    def standar(self, X: np.ndarray) -> np.ndarray:
        return ((X - self.rerata) / self.sb).astype(np.float32)

    def proba(self, X: np.ndarray) -> np.ndarray:
        return self.keras.predict(self.standar(X), verbose=0)


def statistik(X: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    datar = X.reshape(-1, X.shape[-1]).astype(np.float64)
    rerata = datar.mean(axis=0)
    sb = datar.std(axis=0)
    sb[sb < 1e-6] = 1.0
    return rerata, sb


def bangun(jenis: str, n_kelas: int) -> keras.Model:
    masuk = keras.Input((PANJANG, JUMLAH_FITUR), name="fitur")
    x = masuk
    if jenis == "cnn":
        x = layers.Conv1D(64, 5, padding="same", activation="relu")(x)
        x = layers.BatchNormalization()(x)
        x = layers.Conv1D(64, 5, padding="same", activation="relu")(x)
        x = layers.BatchNormalization()(x)
        x = layers.MaxPooling1D(2)(x)
        x = layers.Conv1D(128, 3, padding="same", activation="relu")(x)
        x = layers.GlobalAveragePooling1D()(x)
    elif jenis == "lstm":
        # unroll=True: graf TFLite hanya berisi operasi bawaan (tanpa WHILE),
        # jadi bisa dikuantisasi penuh dan jalan di interpreter mana pun.
        x = layers.LSTM(64, unroll=True)(x)
    else:
        raise ValueError(jenis)
    x = layers.Dropout(0.3)(x)
    keluar = layers.Dense(n_kelas, activation="softmax", name="peluang")(x)
    model = keras.Model(masuk, keluar, name=jenis)
    model.compile(optimizer=keras.optimizers.Adam(1e-3),
                  loss="sparse_categorical_crossentropy", metrics=["accuracy"])
    return model


def bobot_kelas(y: np.ndarray, n_kelas: int) -> dict:
    hitung = np.bincount(y, minlength=n_kelas).astype(float)
    ada = hitung > 0
    w = np.ones(n_kelas)
    w[ada] = len(y) / (ada.sum() * hitung[ada])
    return {i: float(w[i]) for i in range(n_kelas)}


def latih(jenis: str, X: np.ndarray, y: np.ndarray, X_val: np.ndarray | None, y_val: np.ndarray | None,
          n_kelas: int, epoch: int = 80, benih: int = 0, verbose: int = 0) -> ModelSaraf:
    keras.utils.set_random_seed(benih)
    rerata, sb = statistik(X)
    hasil = ModelSaraf(jenis, bangun(jenis, n_kelas), rerata, sb)
    model = hasil.keras
    cb = []
    val = None
    if X_val is not None and len(X_val):
        val = (hasil.standar(X_val), y_val)
        cb.append(keras.callbacks.EarlyStopping(monitor="val_loss", patience=12,
                                                restore_best_weights=True))
    model.fit(hasil.standar(X), y, validation_data=val, epochs=epoch, batch_size=32, callbacks=cb,
              class_weight=bobot_kelas(y, n_kelas), verbose=verbose)
    return hasil


def ke_tflite(ms: ModelSaraf, int8: bool = False, X_wakil: np.ndarray | None = None) -> bytes:
    """Konversi ke TFLite dengan masukan [1, 64, 38] float32 yang sudah distandarkan.

    int8=True memakai kuantisasi pasca-pelatihan dengan data wakil (mentah;
    distandarkan di sini). Masukan dan keluaran tetap float supaya kode
    aplikasi sama untuk kedua versi.
    """
    model = ms.keras
    if X_wakil is not None:
        X_wakil = ms.standar(X_wakil)
    # Lewat SavedModel: konversi langsung dari fungsi Keras 3 menyisakan operasi
    # READ_VARIABLE yang gagal saat kalibrasi int8.
    with tempfile.TemporaryDirectory() as tmp:
        model.export(tmp, format="tf_saved_model", verbose=False,
                     input_signature=[tf.TensorSpec([1, PANJANG, JUMLAH_FITUR], tf.float32)])
        conv = tf.lite.TFLiteConverter.from_saved_model(tmp)
        return _konversi(conv, int8, X_wakil)


def _konversi(conv, int8: bool, X_wakil) -> bytes:
    if int8:
        if X_wakil is None:
            raise ValueError("kuantisasi int8 butuh X_wakil")
        conv.optimizations = [tf.lite.Optimize.DEFAULT]
        wakil = X_wakil[np.random.default_rng(0).permutation(len(X_wakil))[:300]].astype(np.float32)

        def data_wakil():
            for i in range(len(wakil)):
                yield [wakil[i:i + 1]]

        conv.representative_dataset = data_wakil
    return conv.convert()


class PenerjemahTflite:
    def __init__(self, isi: bytes):
        self.it = tf.lite.Interpreter(model_content=isi)
        self.it.allocate_tensors()
        self.masuk = self.it.get_input_details()[0]["index"]
        self.keluar = self.it.get_output_details()[0]["index"]

    def proba(self, X: np.ndarray) -> np.ndarray:
        hasil = []
        for i in range(len(X)):
            self.it.set_tensor(self.masuk, X[i:i + 1].astype(np.float32))
            self.it.invoke()
            hasil.append(self.it.get_tensor(self.keluar)[0].copy())
        return np.array(hasil)

    def latensi_ms(self, X: np.ndarray, ulang: int = 200) -> float:
        x = X[:1].astype(np.float32)
        for _ in range(10):
            self.it.set_tensor(self.masuk, x)
            self.it.invoke()
        mulai = time.perf_counter()
        for _ in range(ulang):
            self.it.set_tensor(self.masuk, x)
            self.it.invoke()
        return (time.perf_counter() - mulai) * 1000 / ulang
