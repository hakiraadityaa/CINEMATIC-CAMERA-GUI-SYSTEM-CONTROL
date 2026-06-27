# Cinematic Camera GUI & System Control `V7.0 - Advanced`

<p align="center">
  <img src="https://c.tenor.com/wrqESzPzXvMAAAAC/tenor.gif" alt="MegaKot GIF" width="410">
</p>

[![Version](https://img.shields.io/badge/Version-7.0--Advanced_Revision-blueviolet?style=for-the-badge&logo=roblox)](https://roblox.com)
[![Executor Compatibility](https://img.shields.io/badge/Executor-Delta_/_Mobile_/_PC-green?style=for-the-badge&logo=lua)](https://lua.org)
[![UI Responsive](https://img.shields.io/badge/UI_Scale-Dynamic_Responsive-orange?style=for-the-badge)](https://roblox.com)
[![Memory Leaks](https://img.shields.io/badge/Memory_Leaks-0%25_Safe-red?style=for-the-badge)](https://roblox.com)

**Cinematic Camera GUI & System Control** adalah skrip utilitas kamera sinematik kelas profesional yang dirancang khusus untuk para kreator konten, videografer Roblox, dan pengembang *showcase* game. Skrip ini menghadirkan pergerakan kamera mekanis kelas atas dengan antarmuka modern yang sangat ringan, responsif pada layar mobile terkecil, dan bebas dari kebocoran memori (*memory leaks*).

---

## 🛠️ Spesifikasi Teknis & Arsitektur

> [!IMPORTANT]
> Skrip ini menggunakan model penanganan error **Thread Failsafe** dengan pembungkus `xpcall` pada setiap interaksi. Jika terjadi kesalahan (*crash*/*runtime error*), detail pesan kesalahan beserta tumpukan baris kodenya (*traceback*) akan **otomatis tersalin ke clipboard** untuk kenyamanan *debugging* Anda.

### 📌 Repositori Informasi Teknis
*   **Bahasa Utama**: Luau (Roblox Lua 5.1 Dialect)
*   **Sistem Animasi UI**: `TweenService` dengan kurva *Easing* Dinamis
*   **Sistem Update Kamera**: `RunService.RenderStepped` (Sinkronisasi FPS Tinggi)
*   **Metode Seleksi Target**: *Raycasting 3D* berbasis `UserInputService`
*   **Integrasi Efek Visual**: Modifikasi dinamis pada instansi objek di `game.Lighting`

---

## 🎬 Panduan Pilihan Preset Gerakan Kamera Sinematik

Tabel di bawah ini memetakan karakteristik teknis dari masing-masing **8 preset kamera** beserta rekomendasi skenario penggunaannya untuk hasil rekaman terbaik:

| Preset Kamera | Karakteristik Teknis | Skenario Penggunaan yang Direkomendasikan |
| :--- | :--- | :--- |
| **Orbit** | Berputar melingkar 360° secara kontinu | *Showcase* detail armor, senjata, aksesoris, atau kostum karakter. |
| **Epic Pan** | Geser horizontal perlahan membentuk parabola | Menyorot pemandangan luas, kota, lanskap alam (*establishing shot*). |
| **Dynamic Follow** | Pelacakan dinamis dengan latensi elastis | Aksi kejar-kejaran (*action chase*), parkour lari, atau balap mobil. |
| **Handheld Shaky** | Getaran berbasis *Perlin Noise* (Kebisingan 3D) | Sudut pandang jurnalis, adegan aksi darurat, atau pertempuran intens. |
| **Static Scenic** | Kamera diam di koordinat tetap sambil melacak target | Adegan menyambut kedatangan subjek dari kejauhan (*reception shot*). |
| **Dolly Zoom** | Efek Vertigo (Distorsi perspektif latar belakang) | Momen dramatis, ketegangan tinggi, kejutan cerita, atau realisasi plot. |
| **Crane Shot** | Sapuan vertikal naik/turun secara perlahan | Pengenalan area baru dari sudut pandang tinggi (*high-angle opening*). |
| **Side Profile** | Meluncur sejajar mengikuti sisi samping subjek | Cuplikan transisi berjalan estetis (*aesthetic slow walking edits*). |

---

## ⚙️ Fitur Pengaturan Tambahan (Post-Processing & Sliders)

```
[MAIN CONTROL PANEL]
 ├── Status Mode (Active / Inactive)
 ├── Movement Style Preset Buttons (8 Styles)
 ├── Sliders Configuration
 │    ├── Movement Speed (0.1x - 5.0x)
 │    ├── Field of View (10° - 120°)
 │    ├── Shake Intensity (0.1 - 10.0)
 │    └── Camera Tilt (Dutch Angle: -30° to +30°)
 ├── Velocity FOV Zoom (Adaptif sesuai Kecepatan Gerak)
 ├── Cinematic Lighting (Depth of Field, Bloom, & Color Grading)
 └── Target Selector (Raycast Player/NPC Lock)
```

*   **Camera Tilt (Dutch Angle)**: Memiringkan horizon kamera secara diagonal untuk menciptakan komposisi visual yang lebih artistik dan tidak kaku.
*   **Velocity FOV Zoom**: FOV akan membesar secara otomatis seiring bertambahnya kecepatan subjek (bekerja sempurna saat subjek menaiki kendaraan cepat).
*   **Cinematic Lighting**: Menginjeksikan efek visual profesional secara dinamis (DoF blur latar belakang, saturasi hangat, dan pendaran cahaya) dan membersihkannya secara aman saat dinonaktifkan.

---

## 🎮 Panduan Pintas Cepat (Quick Gestures & Controls)

Gunakan kombinasi gestur interaktif di bawah ini untuk mengontrol UI sinematik Anda secara profesional saat melakukan perekaman layar:

*   **Menyembunyikan UI**: Tekan tombol <kbd>Hide Panel to Record</kbd> untuk menyembunyikan seluruh antarmuka (layar akan menjadi 100% bersih tanpa logo apa pun).
*   **Menampilkan Kembali UI**: Lakukan <kbd>Double Tap</kbd> (ketukan ganda pada mobile) atau <kbd>Double Click</kbd> (pada PC) di **Pojok Kanan Paling Atas Layar** (Area sentuh tak terlihat berukuran 120x120px).
*   **Mengunci Target Baru**: Tekan <kbd>Target: Self</kbd> hingga berubah warna menjadi hijau, lalu ketuk subjek pemain lain atau NPC di sekitar Anda.
*   **Mereset Target**: Tekan tombol target tersebut, lalu ketuk area tanah atau langit yang kosong di layar Anda.
*   **Menutup Skrip Sepenuhnya**: Klik tombol silang <kbd>✕</kbd> pada bagian kanan atas Header panel.

---

## 🚀 Script Loader

Gunakan *loadstring* di bawah ini untuk mengeksekusi skrip secara instan pada executor Anda:

```lua
-- Cinematic Camera GUI & System Control (V7)
-- Fully compatible with Delta Executor (Mobile & PC)
-- Failsafe error tracking enabled

loadstring(game:HttpGet("https://raw.githubusercontent.com/hakiraadityaa/CINEMATIC-CAMERA-GUI-SYSTEM-CONTROL/refs/heads/main/main.lua"))()

-- (script by hakiraadityaa)
```

---
<p align="center">
 script by hakiraadityaa
</p>
<p align="center">
  <img src="https://media.tenor.com/L-IjAK9S05kAAAAi/madoka.gif" alt="Madoka GIF" width="220">
</p>
