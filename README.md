# Postur

![Layar Postur: pilih gerakan, latihan dengan bagian tubuh yang salah menyala, dan ringkasan sesi](docs/tampilan.webp)

**[Coba di browser](https://postur.raffstw.my.id)** (webcam, tanpa instalasi) ·
**[Unduh APK terbaru](https://github.com/Reverseflash45/postur/releases/latest)** · Android 7.0+, arm64

Deteksi kesalahan postur **squat** dan **push-up** dari kamera ponsel. Pose
estimation (ML Kit / MediaPipe, 33 landmark BlazePose) mengubah video menjadi
deret koordinat sendi, penghitung repetisi memotongnya per repetisi, lalu satu
dari empat model menilai setiap repetisi: aturan ambang sudut, Random Forest,
1D-CNN, atau LSTM. Semuanya berjalan di perangkat.

Proyek skripsi: *Sistem Deteksi Kesalahan Postur Latihan Squat dan Push-Up
Berbasis Pose Estimation dan Klasifikasi Deret Waktu pada Perangkat Android*.

```
kamera ──► pose (33 titik) ──► segmentasi repetisi ──► fitur 64×38 / 72 ──► model ──► umpan balik suara
```

| Gerakan | Kelas |
|---|---|
| Squat (kamera depan-serong ±45°) | SQ-0 benar · SQ-1 kurang dalam · SQ-2 lutut masuk ke dalam · SQ-3 badan terlalu condong |
| Push-up (kamera dari samping) | PU-0 benar · PU-1 pinggul turun · PU-2 pinggul terangkat · PU-3 kurang dalam |

## Versi web

Aplikasi yang sama juga berjalan di browser dengan webcam:

- **Pose estimation**: MediaPipe Pose Landmarker (model *full*, GPU bila ada,
  CPU bila tidak). Keluarannya 33 titik BlazePose dengan urutan yang sama
  dengan ML Kit, jadi fitur, segmentasi, dan model tidak berubah.
- **Model**: aturan dan Random Forest berjalan di Dart seperti di Android.
  1D-CNN dan LSTM memakai **berkas `.tflite` yang sama** lewat TensorFlow.js
  TFLite (WebAssembly). Di *Uji kinerja* versi web, selisihnya terhadap
  keluaran Python sekitar 5×10⁻⁷ dan model int8 memilih kelas yang sama di
  8/8 repetisi contoh.
- **Privasi**: video tidak pernah meninggalkan browser. Riwayat latihan
  disimpan di localStorage.
- **Batasan**: perekaman data penelitian sengaja hanya ada di Android, karena
  data latih harus berasal dari pose estimator yang sama dengan yang dipakai
  aplikasi (ML Kit). Ekspor .zip juga hanya di Android.

Jembatan JavaScript-nya ada di `app/web/postur.js`, sumber kameranya di
`app/lib/sumber/kamera_web.dart`, dan TFLite web di
`app/lib/inti/klasifikasi/tflite_web.dart`.

## Isi repo

```
ml/    Python: data, fitur, segmentasi, 4 model, evaluasi GroupKFold, analisis Bab IV, ekspor TFLite
app/   Flutter (Android): latihan per set, mode demo, rekam & tinjau data, uji kinerja, info model
```

### Aplikasi

- **Latih**: cek posisi (badan terlihat, jarak, diam) → hitung mundur → set dengan
  target repetisi → istirahat berwaktu. Bagian tubuh yang salah disorot di
  kerangka, koreksi diucapkan, pengukur sudut berubah hijau saat kedalaman tercapai.
- **Ringkasan**: skor form (peluang kelas benar), rentang gerak tiap repetisi,
  tempo turun/naik, temuan utama, putar ulang kerangka tiap repetisi, kartu hasil
  PNG untuk dibagikan. Dengan *Bandingkan semua model* aktif, setiap repetisi
  juga dinilai model lain dan kesepakatannya ditampilkan.
- **Progres**: repetisi 14 hari, tren skor, rekor, riwayat.
- **Lab**: sesi pengambilan data terpandu, rekam set manual, tinjau dan label
  ulang tiap repetisi, uji kinerja, info model, panduan, pengaturan.
- **Sesi terpandu** (Lab → Rekam data → *Subjek baru*): lembar informasi dan
  persetujuan, profil subjek anonim, urutan kelas seimbang per subjek
  (bujur sangkar latin Williams), instruksi suara tiap set, rekaman yang
  berhenti sendiri saat target repetisi tercapai, istirahat berwaktu,
  pengingat posisi ponsel saat ganti gerakan, rekam ulang, dan hapus data
  bila subjek mengundurkan diri. Panel *Kesehatan dataset* menampilkan
  keseimbangan kelas, karakteristik subjek, dan peringatan sebelum ekspor.

Logika fitur dan segmentasi ditulis dua kali (Python untuk pelatihan, Dart
untuk aplikasi). `app/test/paritas_test.dart` memastikan keduanya menghasilkan
angka yang sama dengan berkas uji dari Python, sampai ±1e-8.

## Alur penelitian

1. **Rekam data** di aplikasi lewat sesi terpandu, mengikuti
   [protokol pengambilan data](docs/protokol-pengambilan-data.md). Cetak
   [formulir persetujuan](docs/formulir-persetujuan.docx) dan
   [lembar observasi](docs/lembar-observasi.docx) untuk tiap subjek (teksnya
   bisa diubah di `docs/buat_formulir.py`). Data latih berasal dari pose
   estimator yang sama dengan yang dipakai saat aplikasi berjalan.
2. **Ekspor** semua rekaman (.zip) dari aplikasi ke laptop, lalu ekstrak ke
   `ml/data/rekaman/`.
3. **Tinjau** tiap rekaman di aplikasi (ketuk sesi di *Rekam data*): putar
   ulang tiap repetisi, ganti labelnya, atau buang yang salah diperagakan.
   Hasilnya tersimpan sebagai `label_rep` di berkas sesi. Alternatifnya di
   laptop:
   ```
   cd ml
   .venv/Scripts/python -m postur periksa --data data/rekaman --csv data/anotasi.csv
   ```
   Prioritas label: `anotasi.csv` > `label_rep` dari aplikasi > label set.
4. **Latih dan evaluasi** (5-fold GroupKFold per subjek, augmentasi, McNemar,
   kuantisasi int8):
   ```
   .venv/Scripts/python -m postur latih --data data/rekaman --anotasi data/anotasi.csv --keluar hasil
   ```
   Hasilnya di `hasil/<gerakan>/`:
   - `laporan.md` dan `metrik.json`: karakteristik subjek, macro-F1, per kelas,
     McNemar, kuantisasi, penghitungan repetisi, F1 per subjek, fitur
     terpenting RF, kurva belajar
   - `tabel.tex`: tabel booktabs siap tempel ke Bab IV, termasuk tabel
     karakteristik subjek bila profil subjek ikut diekspor
   - PNG: confusion matrix tiap model, F1 per subjek, fitur penting, kurva belajar

   Kurva belajar bisa dilewati dengan `--tanpa-kurva`.
5. **Pasang model** ke aplikasi: salin `hasil/<gerakan>/model/*` ke
   `app/assets/model/<gerakan>/`, lalu build ulang APK.
6. **Ukur di ponsel** lewat menu *Uji kinerja*: latensi tiap model,
   ekstraksi fitur, dan pose estimation. Tombol salin menghasilkan tabel
   Markdown.

Video dari luar aplikasi (atau dataset publik) bisa diolah dengan MediaPipe:

```
.venv/Scripts/python -m postur video rekaman.mp4 --subjek S01 --gerakan squat --label SQ-0 --repetisi 10
```

## Data sintetis

Sebelum data asli ada, `python -m postur sintetis` membangkitkan sesi dari
kerangka 3D yang digerakkan secara kinematik, diproyeksikan ke kamera, dan
diberi derau. Model bawaan di `app/assets/model/` dilatih dari data ini,
sehingga aplikasinya bisa langsung dicoba (aplikasi menandainya sebagai
"Data sintetis").

> Angka evaluasi dari data sintetis hanya membuktikan pipeline berjalan.
> Jangan dilaporkan sebagai hasil penelitian.

## Menjalankan

**Python** (3.10):

```
cd ml
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements.txt
.venv/Scripts/python -m pytest
```

**Aplikasi** (Flutter 3.47):

```
cd app
flutter test
flutter build apk --release --split-per-abi
```

**Versi web**:

```
cd app
flutter run -d chrome            # pengembangan
flutter build web --release      # hasil di build/web, termasuk vercel.json
cd build/web && vercel link --yes --project postur && vercel deploy --prod
                                 # atau hosting statis apa pun (butuh HTTPS untuk kamera)
```

## Pembaruan berkas uji

Setelah mengubah fitur atau segmentasi di kedua sisi:

```
cd ml
.venv/Scripts/python -m postur paritas   # app/test/fixture/paritas.json
.venv/Scripts/python -m postur demo      # app/assets/demo/*.json
cd ../app && flutter test
```
