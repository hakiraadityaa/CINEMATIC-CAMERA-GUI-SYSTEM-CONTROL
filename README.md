# Cinematic Camera GUI & System Control (V7 - Advanced Revision)
**Cinematic Camera GUI & System Control** adalah skrip utilitas kamera sinematik kelas profesional yang dirancang khusus untuk pembuat konten, videografer Roblox, dan pemain yang ingin mengambil cuplikan visual (*cinematic showcase*) berkualitas tinggi. Skrip ini dioptimalkan penuh untuk kenyamanan pengguna perangkat mobile (seperti **Delta Executor**) maupun PC, dengan antarmuka dinamis, responsif, dan bebas dari kebocoran memori (*memory leaks*).

---

## 🌟 Fitur Utama

### 1. Inisialisasi & Keamanan Terintegrasi
*   **Epic Loading Screen (5 Detik)**: Layar pemuatan berdurasi 5 detik dengan animasi bar progresif yang estetik. Menampilkan foto profil avatar Roblox pengguna secara langsung (*headshot*), Display Name, Username, User ID, serta atribusi kreator.
*   **Failsafe & Auto-Copy Error**: Sistem penanganan kesalahan (*fail-safe*) tingkat lanjut. Jika terjadi kendala sistem saat eksekusi atau runtime, detail error beserta runtutan baris kodenya (*traceback*) akan **otomatis tersalin ke clipboard** untuk mempermudah proses evaluasi pengembang.

### 2. Pilihan Preset Kamera Sinematik Profesional
Skrip ini dilengkapi dengan **8 preset pergerakan kamera** yang dirancang menggunakan kalkulasi matematika presisi:
1.  **Orbit**: Kamera berputar secara melingkar mengelilingi target secara dramatis.
2.  **Epic Pan**: Kamera bergeser secara halus dari sisi ke sisi sambil mengunci fokus pada target.
3.  **Dynamic Follow**: Kamera melacak pergerakan target dengan jeda (*latency*) yang elastis dan natural.
4.  **Handheld Shaky**: Mensimulasikan guncangan kamera alami (*organic camera sway*) menggunakan algoritma kebisingan Perlin (*Perlin Noise*).
5.  **Static Scenic**: Mengunci posisi kamera di satu koordinat estetis statis sambil terus melacak rotasi target.
6.  **Dolly Zoom (Vertigo Effect)**: Efek optik legendaris bioskop yang mengubah perspektif latar belakang secara dramatis selagi menjaga ukuran subjek tetap proporsional.
7.  **Crane Shot**: Menyapu sudut pandang secara vertikal dari bawah ke atas layaknya menggunakan katrol derek kamera studio.
8.  **Side Profile**: Mengunci kamera secara sejajar di samping kanan subjek untuk mengambil cuplikan berjalan atau berlari dari sudut profil.

### 3. Kontrol Kustomisasi & Slider Presisi
*   **Speed Slider**: Mengontrol kecepatan transisi dan putaran gerakan kamera sinematik (0.1x hingga 5.0x).
*   **Field of View (FOV) Slider**: Menyesuaikan lebar sudut lensa kamera (10° hingga 120°) secara fleksibel.
*   **Shake Intensity**: Mengatur kekuatan getaran pada mode *Handheld Shaky* (0.1 hingga 10.0).
*   **Camera Tilt (Dutch Angle)**: Slider khusus untuk memiringkan kamera secara diagonal pada sumbu *roll* (-30° hingga +30°) untuk komposisi visual yang lebih artistik.

### 4. Fitur Tambahan Tingkat Lanjut
*   **Velocity FOV Zoom**: Jika aktif, lebar lensa (FOV) akan menyesuaikan secara dinamis dan otomatis berdasarkan kecepatan linear subjek (sangat responsif, bahkan saat karakter sedang mengendarai kendaraan di dalam game).
*   **Focus Target Lock (Tap-to-Lock)**: Fitur raycast 3D interaktif yang memungkinkan kamera berfokus memutari pemain lain atau NPC di sekitar Anda hanya dengan mengetuk tubuh mereka di layar. Ketuk layar kosong untuk mereset fokus kembali ke diri sendiri.
*   **Cinematic Lighting (Post-Processing)**: Mengintegrasikan efek pencahayaan profesional langsung ke `game.Lighting` berupa *Depth of Field* (DoF) untuk memburamkan latar belakang secara estetis (*bokeh*), *Bloom* untuk pendaran cahaya, serta *Color Correction* untuk saturasi warna hangat (*warm cinematic tone*).

### 5. Mode Rekam Bersih (*Invisible Record Mode*)
*   **Clean Screen**: Tombol "Hide Panel" akan menyembunyikan seluruh UI tanpa menyisakan logo atau ikon apa pun yang dapat mengganggu estetika perekaman video.
*   **Double-Tap Restore**: Untuk memunculkan kembali panel kontrol, pengguna hanya perlu melakukan ketukan ganda (*double-tap/double-click*) pada area sentuh tak terlihat berukuran 120x120 piksel di pojok kanan atas layar.

---

## ⚙️ Kompatibilitas & Optimasi Teknis
*   **Mobile Responsive Design**: Menggunakan kombinasi ukuran relatif (*Scale*) dan *Size Constraint* sehingga antarmuka secara otomatis menyesuaikan ukuran pada layar ponsel terkecil (minimal 280x350px) tanpa memotong tulisan, dan tetap proporsional pada layar PC yang besar.
*   **Zero Resource Abuse**: Ikon-ikon UI dimuat menggunakan ID Aset digital resmi Roblox (bebas kotak kosong atau kegagalan karakter unicode).
*   **Clean Cleanup**: Seluruh koneksi `RenderStepped`, penunjuk target, dan instansi efek pencahayaan dijamin hancur (*destroyed*) sepenuhnya saat UI ditutup, mencegah terjadinya penumpukan beban RAM (*memory leak*).

---

##  Cara Penggunaan
1.  Salin seluruh kode script Cinematic Camera (V7) ke dalam executor pilihan Anda (misalnya Delta Executor).
2.  Jalankan skrip. Tunggu loading screen selama 5 detik hingga bar progres mencapai 100%.
3.  Panel kontrol utama akan terbuka. Sesuaikan gerakan kamera, kecepatan, FOV, pencahayaan, atau target sesuai kebutuhan Anda.
4.  Tekan **"Hide Panel to Record"** untuk menyembunyikan UI dan memulai proses perekaman layar secara bersih.
5.  Ketuk **dua kali** secara cepat di pojok kanan paling atas layar untuk mengembalikan panel kontrol.
6.  Tekan tombol silang **(✕)** pada header untuk menutup skrip dan merestorasi kamera ke keadaan semula.

---
*(script by hakiraadityaa)*
