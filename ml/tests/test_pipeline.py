import json

import numpy as np
import pytest

from postur import landmark as L
from postur import sintetis
from postur.aturan import KlasifikasiAturan
from postur.data import potong_repetisi, sesi_dari_json, sesi_ke_json
from postur.fitur import JUMLAH_FITUR, NAMA_RINGKASAN, kanal, proses_repetisi, sudut
from postur.gerakan import PUSHUP, SQUAT
from postur.hutan import hutan_ke_json, latih_hutan, prediksi_json, proba_lengkap
from postur.repetisi import segmentasi
from postur.sinyal import haluskan, isi_hilang, normalisasi, sampel_ulang


def test_sudut_dasar():
    a, b = np.array([[1.0, 0.0]]), np.array([[0.0, 0.0]])
    assert sudut(a, b, np.array([[0.0, 1.0]]))[0] == pytest.approx(90)
    assert sudut(a, b, np.array([[-1.0, 0.0]]))[0] == pytest.approx(180)
    assert sudut(a, b, np.array([[1.0, 1.0]]))[0] == pytest.approx(45)


def test_cermin_adalah_involusi():
    c = L.indeks_cermin()
    assert [c[i] for i in c] == list(range(L.JUMLAH))
    assert c[L.LUTUT_KI] == L.LUTUT_KA


def test_isi_hilang_interpolasi_dan_tepi():
    xy = np.zeros((5, L.JUMLAH, 2))
    xy[:, 0, 0] = [0, 99, 2, 3, 99]
    vis = np.ones((5, L.JUMLAH))
    vis[[1, 4], 0] = 0.1
    hasil = isi_hilang(xy, vis)
    assert hasil[:, 0, 0].tolist() == [0, 1, 2, 3, 3]


def test_haluskan_mempertahankan_kuadrat_di_tengah():
    t = np.arange(20, dtype=float)
    x = 0.5 * t ** 2 - 3 * t + 1
    h = haluskan(x)
    assert np.allclose(h[3:-3], x[3:-3])


def test_normalisasi_titik_asal_dan_skala():
    xy = np.random.default_rng(0).normal(size=(4, L.JUMLAH, 2)) * 50 + 300
    xn, skala = normalisasi(xy)
    pinggul = (xn[:, L.PINGGUL_KI] + xn[:, L.PINGGUL_KA]) / 2
    assert np.allclose(pinggul, 0)
    assert skala > 0


def test_sampel_ulang_linear():
    t = np.array([0.0, 10.0, 30.0])
    x = np.array([[0.0], [1.0], [3.0]])
    r = sampel_ulang(x, t, 4)
    assert r[:, 0] == pytest.approx([0, 1, 2, 3])


@pytest.fixture(scope="module")
def sesi_contoh():
    rng = np.random.default_rng(3)
    s = sintetis.subjek_acak("T1", rng)
    return {lab: sintetis.buat_sesi(SQUAT, lab, s, rng, 10) for lab in SQUAT.kode} | {
        lab: sintetis.buat_sesi(PUSHUP, lab, s, rng, 10) for lab in PUSHUP.kode}


def test_segmentasi_menghitung_sesi_sintetis(sesi_contoh):
    for lab, s in sesi_contoh.items():
        g = SQUAT if lab.startswith("SQ") else PUSHUP
        n = len(segmentasi(s.t, s.xy, s.vis, g))
        assert abs(n - s.repetisi_manual) <= 1, lab


def test_bentuk_fitur(sesi_contoh):
    reps = potong_repetisi(sesi_contoh["SQ-0"], SQUAT)
    assert reps[0].seq.shape == (64, JUMLAH_FITUR)
    assert reps[0].ring.shape == (len(NAMA_RINGKASAN),)
    assert np.isfinite(reps[0].seq).all()


def test_fitur_membedakan_kelas(sesi_contoh):
    def rerata(lab, nama):
        g = SQUAT if lab.startswith("SQ") else PUSHUP
        reps = potong_repetisi(sesi_contoh[lab], g)
        return np.mean([r.ring[NAMA_RINGKASAN.index(nama)] for r in reps])
    assert rerata("SQ-1", "lutut_min") > rerata("SQ-0", "lutut_min") + 20
    assert rerata("SQ-2", "rasio_lutut_min") < rerata("SQ-0", "rasio_lutut_min")
    assert rerata("SQ-3", "condong_max") > rerata("SQ-0", "condong_max") + 10
    assert rerata("PU-1", "lengkung_max") > rerata("PU-0", "lengkung_max")
    assert rerata("PU-2", "lengkung_min") < rerata("PU-0", "lengkung_min")
    assert rerata("PU-3", "siku_min") > rerata("PU-0", "siku_min") + 10


def test_lengkung_tidak_bergantung_arah_hadap():
    xy = np.zeros((1, L.JUMLAH, 2))
    for i, (x, y) in {L.BAHU_KI: (100, 0), L.BAHU_KA: (100, 0), L.PINGGUL_KI: (50, 10),
                      L.PINGGUL_KA: (50, 10), L.KAKI_KI: (0, 0), L.KAKI_KA: (0, 0)}.items():
        xy[0, i] = (x, y)
    kiri = kanal(xy)[0, 9]
    xy[..., 0] *= -1
    kanan = kanal(xy)[0, 9]
    assert kiri == pytest.approx(10) and kanan == pytest.approx(10)


def test_sesi_json_bolak_balik(sesi_contoh):
    s = sesi_contoh["PU-2"]
    s2 = sesi_dari_json(json.loads(json.dumps(sesi_ke_json(s))))
    assert s2.label == "PU-2" and len(s2.t) == len(s.t)
    assert np.allclose(s2.xy[s.vis.any(axis=1)], s.xy[s.vis.any(axis=1)], atol=0.01)


def test_hutan_json_setia_dan_aturan_belajar(sesi_contoh):
    reps = [r for lab in SQUAT.kode for r in potong_repetisi(sesi_contoh[lab], SQUAT)]
    R = np.stack([r.ring for r in reps])
    y = np.array([SQUAT.indeks(r.label) for r in reps])
    rf = latih_hutan(R, y, np.array(["a"] * len(y)), n_pohon=10, cari=False)
    js = hutan_ke_json(rf, 4, "squat")
    assert np.abs(prediksi_json(js, R) - proba_lengkap(rf, R, 4)).max() < 1e-5
    at = KlasifikasiAturan(SQUAT).fit(R, y)
    assert (at.predict(R) == y).mean() > 0.7


def test_augmentasi_tetap_berhingga(sesi_contoh):
    from postur.augmentasi import augmentasi_satu
    r = potong_repetisi(sesi_contoh["SQ-2"], SQUAT)[0]
    t, xy, vis = augmentasi_satu(r, np.random.default_rng(0))
    seq, ring = proses_repetisi(t, xy, vis, SQUAT)
    assert np.isfinite(seq).all() and np.isfinite(ring).all()
