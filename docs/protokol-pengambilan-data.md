# Protokol Pengambilan Data

Dokumen ini menjabarkan prosedur pengambilan data untuk penelitian *Sistem Deteksi Kesalahan Postur Latihan Squat dan Push-Up Berbasis Pose Estimation dan Klasifikasi Deret Waktu pada Perangkat Android*. Isinya dapat dipakai sebagai bahan Bab III (Metodologi) dan lampiran skripsi. Seluruh langkah sudah didukung oleh aplikasi Postur melalui menu **Lab → Rekam data → Subjek baru** (mode sesi terpandu).

## 1. Tujuan

Pengambilan data bertujuan mengumpulkan rekaman koordinat titik tubuh dari gerakan squat dan push-up, baik yang dilakukan dengan benar maupun dengan kesalahan yang umum terjadi, untuk melatih dan mengevaluasi model klasifikasi per repetisi.

## 2. Subjek

### 2.1 Kriteria inklusi

1. Berusia 18–45 tahun.
2. Dalam kondisi sehat dan mampu melakukan squat serta push-up tanpa beban.
3. Bersedia mengikuti seluruh prosedur dan menandatangani formulir persetujuan.

### 2.2 Kriteria eksklusi

1. Mengalami cedera muskuloskeletal pada lutut, pinggul, punggung, bahu, atau pergelangan tangan dalam enam bulan terakhir.
2. Memiliki keluhan nyeri sendi saat bergerak.
3. Memiliki kondisi kardiovaskular atau kondisi lain yang membatasi aktivitas fisik ringan.
4. Sedang hamil.

### 2.3 Jumlah subjek

Evaluasi menggunakan validasi silang 5-fold yang dikelompokkan per subjek (*GroupKFold*), sehingga data satu subjek tidak pernah muncul sekaligus di data latih dan data uji. Jumlah minimal yang disarankan adalah 15 subjek, idealnya 20 subjek, agar setiap fold memiliki 3–4 subjek uji. Kurva belajar pada laporan pelatihan membantu menilai apakah jumlah subjek sudah memadai.

## 3. Kelas gerakan

Setiap subjek memperagakan delapan kelas, masing-masing satu set berisi 10 repetisi (dapat diatur 5–20 di aplikasi).

| Kode | Gerakan | Kelas | Cara memperagakan |
|---|---|---|---|
| SQ-0 | Squat | Benar | Paha turun hingga sejajar lantai, lutut searah ujung kaki, punggung netral, tempo sedang. |
| SQ-1 | Squat | Kurang dalam | Turun hanya setengah jalan; paha tidak mencapai sejajar lantai. |
| SQ-2 | Squat | Lutut masuk ke dalam | Saat turun, kedua lutut sedikit bergerak saling mendekat. Diperagakan ringan, tidak dipaksakan. |
| SQ-3 | Squat | Badan terlalu condong | Saat turun, dada dicondongkan ke depan lebih dari biasanya dengan punggung tetap lurus. |
| PU-0 | Push-up | Benar | Bahu, pinggul, dan pergelangan kaki segaris; dada turun hingga siku sekitar 90°. |
| PU-1 | Push-up | Pinggul turun | Pinggul sedikit melengkung turun di bawah garis badan. Dihentikan bila punggung bawah terasa tidak nyaman. |
| PU-2 | Push-up | Pinggul terangkat | Pinggul diangkat sedikit lebih tinggi dari garis badan. |
| PU-3 | Push-up | Kurang dalam | Turun hanya sedikit; siku jauh dari 90°. |

Subjek yang tidak mampu melakukan push-up penuh boleh melewatkan set push-up. Set yang dilewati tercatat di aplikasi dan dilaporkan.

## 4. Urutan perekaman

Urutan kelas yang selalu sama dapat menimbulkan bias: kelelahan akan selalu jatuh pada kelas terakhir, dan gaya gerakan satu kelas dapat terbawa ke kelas berikutnya. Untuk mengendalikan efek ini, urutan kelas setiap subjek diambil dari bujur sangkar latin seimbang Williams berukuran 4×4:

| Baris | Urutan kelas (indeks 0–3) |
|---|---|
| 1 | 0, 1, 3, 2 |
| 2 | 1, 2, 0, 3 |
| 3 | 2, 3, 1, 0 |
| 4 | 3, 0, 2, 1 |

Subjek ke-*n* memakai baris ((*n* − 1) mod 4) + 1. Dalam setiap empat subjek berurutan, tiap kelas muncul tepat satu kali di setiap posisi, dan tiap pasangan "kelas A tepat sebelum kelas B" muncul tepat satu kali. Bila kedua gerakan direkam, subjek bernomor ganjil memulai dengan squat dan subjek bernomor genap memulai dengan push-up. Aplikasi menyusun urutan ini secara otomatis dan mencatat baris yang dipakai.

## 5. Peralatan dan lingkungan

1. Ponsel Android 7.0 atau lebih baru dengan aplikasi Postur.
2. Tripod atau penyangga ponsel; untuk push-up dapat diletakkan mendatar di lantai.
3. Matras latihan.
4. Meteran untuk mengukur jarak kamera.
5. Ruang bebas sekitar 3 × 4 meter dengan pencahayaan merata dari depan atau samping, tanpa cahaya terang di belakang subjek.
6. Formulir persetujuan dan lembar observasi tercetak.

## 6. Penempatan kamera

| Gerakan | Orientasi ponsel | Sudut pandang | Jarak | Ketinggian |
|---|---|---|---|---|
| Squat | Tegak (potret) | Depan-serong ±45° | 2–3 m | Setinggi pinggang subjek |
| Push-up | Mendatar (lanskap) | Samping | 2–3 m | Dekat lantai, 10–30 cm |

Seluruh tubuh subjek, dari kepala hingga kaki, harus berada di dalam bingkai sepanjang gerakan. Aplikasi memeriksa kelengkapan titik tubuh dan jarak sebelum perekaman dimulai.

## 7. Prosedur

1. **Penjelasan dan persetujuan.** Peneliti menjelaskan tujuan, prosedur, risiko, dan hak subjek menggunakan lembar informasi di aplikasi, lalu subjek menandatangani formulir persetujuan.
2. **Penapisan.** Peneliti memastikan subjek memenuhi kriteria inklusi dan tidak memenuhi kriteria eksklusi.
3. **Pendaftaran.** Peneliti mengisi kode subjek (S01, S02, dan seterusnya), rentang usia, jenis kelamin, pengalaman latihan, dan tinggi badan (opsional) di aplikasi. Nama subjek tidak dicatat di aplikasi.
4. **Pemanasan.** Subjek melakukan pemanasan ringan selama sekitar lima menit.
5. **Demonstrasi.** Sebelum setiap set, aplikasi membacakan cara memperagakan kelas tersebut, dan peneliti mencontohkannya bila perlu.
6. **Perekaman.** Peneliti menekan tombol rekam. Setelah subjek diam di posisi awal, aplikasi menghitung mundur 3-2-1 lalu mulai merekam. Perekaman berhenti otomatis setelah jumlah repetisi target tercapai.
7. **Hitungan manual.** Selama perekaman, peneliti menghitung repetisi secara manual dan mengisinya saat menyimpan. Hitungan ini dipakai untuk mengevaluasi penghitung repetisi otomatis.
8. **Istirahat.** Subjek beristirahat 60 detik antar-set. Aplikasi menampilkan penghitung waktu istirahat.
9. **Pergantian gerakan.** Saat berpindah dari squat ke push-up atau sebaliknya, aplikasi mengingatkan peneliti untuk mengatur ulang posisi ponsel.
10. **Pendinginan.** Setelah seluruh set selesai, subjek melakukan peregangan ringan.
11. **Peninjauan.** Peneliti meninjau setiap set di aplikasi (menu Tinjau), memutar ulang tiap repetisi, lalu mengganti label atau membuang repetisi yang tidak sesuai dengan kelas yang dimaksud.

## 8. Keselamatan

1. Semua gerakan dilakukan tanpa beban tambahan.
2. Peragaan kesalahan dibuat ringan dan tidak dipaksakan.
3. Subjek boleh berhenti kapan saja, dan perekaman dihentikan segera bila subjek merasa nyeri, pusing, atau tidak nyaman.
4. Air minum disediakan, dan istirahat antar-set dapat diperpanjang sesuai kebutuhan subjek.

## 9. Kerahasiaan dan pengelolaan data

1. Aplikasi hanya menyimpan koordinat 33 titik tubuh per frame hasil pose estimation di perangkat. Video dan foto tidak disimpan.
2. Subjek diidentifikasi dengan kode anonim. Daftar yang menghubungkan kode dengan nama hanya terdapat pada formulir persetujuan kertas yang disimpan terpisah oleh peneliti.
3. Data demografi dicatat dalam bentuk rentang (usia) dan kategori, bukan nilai yang dapat mengidentifikasi individu.
4. Bila subjek mengundurkan diri, peneliti menghapus seluruh data subjek melalui menu *Subjek mengundurkan diri* di aplikasi dan memusnahkan data turunannya di komputer.
5. Data hanya dipakai untuk keperluan penelitian ini dan tidak dibagikan dalam bentuk yang dapat mengidentifikasi subjek.

## 10. Kontrol kualitas

1. Subjek mengenakan pakaian yang tidak terlalu longgar dan kontras dengan latar belakang.
2. Hasil pemeriksaan kesiapan (seluruh titik tubuh terlihat dan jarak sesuai) wajib terpenuhi sebelum perekaman dimulai.
3. Satu set yang gagal (subjek keluar bingkai, salah peragaan berulang, atau gangguan) direkam ulang melalui daftar urutan set. Rekaman lama otomatis dihapus.
4. Panel *Kesehatan dataset* di aplikasi memantau keseimbangan jumlah repetisi antar-kelas dan menandai subjek tanpa profil atau persetujuan.

## 11. Pengolahan data

1. Ekspor seluruh rekaman dari aplikasi ke berkas `.zip`. Profil subjek dan rencana sesi ikut terekspor.
2. Ekstrak berkas ke folder `ml/data/rekaman/` di komputer.
3. Periksa isi dataset, repetisi yang terdeteksi, dan ringkasan demografi:

   ```bash
   python -m postur periksa --data data/rekaman
   ```

4. Latih dan evaluasi seluruh model:

   ```bash
   python -m postur latih --data data/rekaman --keluar hasil
   ```

   Laporan di `hasil/<gerakan>/` memuat karakteristik subjek, kinerja tiap model, uji McNemar, F1 per subjek, kurva belajar, serta `tabel.tex` yang siap ditempel ke Bab IV.

## Lampiran

- Formulir persetujuan: [formulir-persetujuan.docx](formulir-persetujuan.docx)
- Lembar observasi per subjek: [lembar-observasi.docx](lembar-observasi.docx)
