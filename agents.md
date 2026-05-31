# Ashidqi - AI Agent Knowledge Base

File ini ditujukan bagi AI Agent untuk mendapatkan konteks penuh mengenai repositori aplikasi **Ashidqi (Sahabat Ibadah Harian)** secara instan.

## 1. Konteks Proyek & Teknologi
- **Nama Aplikasi**: Ashidqi
- **Platform**: Flutter (Android/iOS)
- **Bahasa**: Dart
- **State Management**: `provider` (MultiProvider di-inisiasi di `main.dart`)
- **Penyimpanan Lokal**: 
  - `sqflite` (untuk basis data besar seperti Al-Quran dan Hadis - via `DatabaseService`)
  - `shared_preferences` (untuk state UI, caching API ringan, dan Jurnal Ibadah)
- **API Eksternal**: Aladhan (Jadwal Sholat & Hijri), Al-Quran Cloud, AhmadRamadhan API.

## 2. Struktur Direktori Utama
- `lib/core/`: Berisi tema (`app_theme.dart`), warna (`app_colors.dart`), dan _utilities_ (seperti `tajweed_parser.dart`).
- `lib/models/`: Struktur data (PrayerTimes, Surah, Ayah, Qari, DhikrOption).
- `lib/providers/`: State management global (`prayer_settings_provider.dart`, `theme_provider.dart`).
- `lib/screens/`: Dipisahkan berdasarkan fitur (home, quran, hadith, fasting, doa, zakat, journal, dsb).
- `lib/services/`: Logika _backend_ lokal dan API (DatabaseService, NotificationService, PrayerTimesService, WidgetService, JournalService).
- `lib/widgets/`: Komponen UI yang dapat digunakan kembali (_reusable components_) seperti `app_bottom_nav_bar.dart`.

## 3. Fitur yang Sudah Ada & Berjalan
1. **Jadwal Sholat & Countdown Real-time**: Menggunakan GPS untuk mendapatkan _prayer times_ dari Aladhan. Memiliki fallback banner UI jika GPS mati (menggunakan default Jakarta).
2. **Al-Quran Digital**: Terjemahan bahasa Indonesia, tajweed parser, bookmark, & pemutar audio Murottal per ayat (mendukung fitur unduh untuk pemutaran *offline*).
3. **Kumpulan Doa & Hadis**: Data ditarik dari API dan sebagian bisa dicari (_search_).
4. **Kalender Puasa Sunnah**: Menandai hari sunnah/haram puasa (berdasarkan perhitungan Hijriah API Aladhan) dan dilengkapi tombol notifikasi (_reminder_) H-1 pukul 20:00.
5. **Kalkulator Zakat**: Zakat Maal, Penghasilan, Emas, dan Fitrah lengkap dengan hitungan nisab dan UI interaktif.
6. **Jurnal Ibadah (Mutaba'ah Yaumiyah)**: Checklist 12 ibadah harian dengan statistik mingguan interaktif, data disimpan _offline_ melalui SharedPreferences.
7. **Peta Masjid & Arah Kiblat**: Menggunakan _flutter_map_ (OpenStreetMap) dan sensor kompas lokal.
8. **Tasbih Digital**: Dzikir counter dengan getaran (haptic) dan opsi suara.
9. **Tema (Light/Dark Mode)**: Persisten disimpan melalui `ThemeProvider`.
10. **Notifikasi Lanjut**: Pengingat sholat yang kaya pengaturan (koreksi waktu, pilihan muadzin) serta alarm pengingat Tahajud khusus 120 menit sebelum waktu Subuh.

## 4. Catatan Teknis & Optimasi yang Telah Dilakukan
- **Notifikasi di Background**: Telah diatasi menggunakan modul `workmanager`. Aplikasi kini memiliki _background service_ (`BackgroundService`) yang berjalan ~24 jam sekali untuk menjadwalkan notifikasi sholat hingga **7 hari ke depan** ke dalam `flutter_local_notifications`. Hal ini mencegah OS (seperti MIUI/ColorOS) mematikan alarm karena fitur _Aggressive Battery Optimization_.
- **Ukuran Icon**: File `assets/icon/icon.png` yang sebelumnya berukuran ~10.5 MB telah dikompres secara efisien menjadi ~251 KB menggunakan _downscaling_ ke 512x512, memangkas 98% ukuran file tanpa merusak kualitas visual.
- **Lazy Loading Al-Quran**: Metode `getAyahsBySurah` di `DatabaseService` kini menggunakan `limit` dan `offset` untuk memfasilitasi _infinite scrolling_ di `QuranReaderScreen`. Pemuatan ayat (terutama untuk surah panjang) jauh lebih efisien di RAM.
- **Sistem Penyimpanan Audio Lokal**: Diatur melalui `AudioDownloadService` menggunakan `path_provider` dan `http`. Membantu pemutar audio memilih _device file source_ jika sudah terunduh ketimbang memanggil _URL source_ yang menguras data pengguna.
- **Siklus Hidup `StreamController`**: Menggunakan pola pemanggilan `.close()` pada fungsi `dispose()` di `DatabaseService` untuk menghindari _memory leaks_. Pastikan AI selanjutnya menerapkan pola yang sama jika membuat _stream_ baru.
- **Manajemen State Kalender Hijriah**: API Aladhan sering kali membutuhkan waktu beberapa detik untuk _fetch_. Caching sudah diterapkan, namun _error handling_ offline (_timeout_) sesekali mengandalkan _fallback_ ke paket lokal `hijri_calendar`. Pertahankan struktur _fallback_ ini.

## 5. Arahan untuk Fitur Masa Depan
Jika User meminta untuk menambahkan fitur baru:
1. Pastikan fitur tersebut ditambahkan rujukannya ke `main.dart` (_routes_).
2. Letakkan di folder `lib/screens/<nama_fitur>` agar modul tetap rapi.
3. Tetap gunakan _Glassmorphism_ UI (kombinasi `BackdropFilter` dan container semi-transparan) jika memungkinkan untuk menyelaraskan dengan bahasa desain aplikasi saat ini.
4. Jangan ragu memodifikasi `AppBottomNavBar` di `lib/widgets` atau _Quick Actions_ di `home_screen.dart` jika _user_ meminta akses yang lebih cepat terhadap fitur tersebut.
