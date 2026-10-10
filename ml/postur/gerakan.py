"""Definisi gerakan dan kelas kesalahannya.

Satu sumber kebenaran untuk label: urutan kelas di sini menentukan indeks
keluaran model, dan berkas ini diekspor ke aplikasi lewat meta.json.
"""
from dataclasses import dataclass

from . import landmark as L


@dataclass(frozen=True)
class Kelas:
    kode: str
    nama: str
    # Arahan untuk subjek saat perekaman data.
    arahan: str
    # Kalimat pendek yang diucapkan aplikasi setelah repetisi.
    ucapan: str


@dataclass(frozen=True)
class Aturan:
    """Satu baris pendekatan berbasis aturan: label jika fitur <op> ambang."""
    label: str
    fitur: str
    op: str  # ">" atau "<"


@dataclass(frozen=True)
class Gerakan:
    id: str
    nama: str
    kelas: tuple[Kelas, ...]
    # Tiga landmark sendi utama (kiri, kanan) untuk menghitung repetisi.
    sendi_utama: tuple[tuple[int, int, int], tuple[int, int, int]]
    # Kanal ringkasan yang dipakai untuk "posisi terendah".
    kanal_utama: str
    # Rentang gerak minimum (derajat) agar satu siklus dihitung repetisi.
    rom_min: float
    aturan: tuple[Aturan, ...]
    # Landmark yang wajib terlihat sebelum latihan dimulai.
    wajib_terlihat: tuple[int, ...]

    @property
    def kode(self) -> list[str]:
        return [k.kode for k in self.kelas]

    def indeks(self, kode: str) -> int:
        return self.kode.index(kode)


SQUAT = Gerakan(
    id="squat",
    nama="Squat",
    kelas=(
        Kelas("SQ-0", "Benar",
              "Turun sampai paha sejajar lantai, lutut searah ujung kaki, punggung netral.",
              "Bagus"),
        Kelas("SQ-1", "Kurang dalam",
              "Turun hanya setengah jalan, paha tidak sampai sejajar lantai.",
              "Turun lebih dalam"),
        Kelas("SQ-2", "Lutut masuk ke dalam",
              "Saat turun, biarkan kedua lutut bergerak saling mendekat.",
              "Dorong lutut ke luar"),
        Kelas("SQ-3", "Badan terlalu condong",
              "Saat turun, condongkan badan jauh ke depan.",
              "Dada lebih tegak"),
    ),
    sendi_utama=((L.PINGGUL_KI, L.LUTUT_KI, L.KAKI_KI), (L.PINGGUL_KA, L.LUTUT_KA, L.KAKI_KA)),
    kanal_utama="lutut",
    rom_min=30.0,
    aturan=(
        Aturan("SQ-1", "lutut_min", ">"),
        Aturan("SQ-2", "rasio_lutut_min", "<"),
        Aturan("SQ-3", "condong_max", ">"),
    ),
    wajib_terlihat=(L.BAHU_KI, L.BAHU_KA, L.PINGGUL_KI, L.PINGGUL_KA,
                    L.LUTUT_KI, L.LUTUT_KA, L.KAKI_KI, L.KAKI_KA),
)

PUSHUP = Gerakan(
    id="pushup",
    nama="Push-up",
    kelas=(
        Kelas("PU-0", "Benar",
              "Bahu, pinggul, dan pergelangan kaki segaris; dada turun sampai siku sekitar 90°.",
              "Bagus"),
        Kelas("PU-1", "Pinggul turun",
              "Biarkan pinggul melengkung turun di bawah garis badan.",
              "Kencangkan perut, pinggul naik sedikit"),
        Kelas("PU-2", "Pinggul terangkat",
              "Angkat pinggul tinggi sehingga badan membentuk huruf V terbalik.",
              "Turunkan pinggul, badan lurus"),
        Kelas("PU-3", "Kurang dalam",
              "Turunkan dada hanya setengah jalan.",
              "Turun lebih dalam"),
    ),
    sendi_utama=((L.BAHU_KI, L.SIKU_KI, L.TANGAN_KI), (L.BAHU_KA, L.SIKU_KA, L.TANGAN_KA)),
    kanal_utama="siku",
    rom_min=30.0,
    aturan=(
        Aturan("PU-3", "siku_min", ">"),
        Aturan("PU-1", "lengkung_max", ">"),
        Aturan("PU-2", "lengkung_min", "<"),
    ),
    wajib_terlihat=(L.BAHU_KI, L.SIKU_KI, L.TANGAN_KI, L.PINGGUL_KI, L.KAKI_KI),
)

SEMUA = {g.id: g for g in (SQUAT, PUSHUP)}


def ambil(id_gerakan: str) -> Gerakan:
    try:
        return SEMUA[id_gerakan]
    except KeyError:
        raise ValueError(f"gerakan tidak dikenal: {id_gerakan!r} (pilihan: {', '.join(SEMUA)})")
