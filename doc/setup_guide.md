# 🚀 Panduan Setup & Deployment

## Daftar Isi
1. [Prasyarat](#prasyarat)
2. [Setup Supabase](#1-setup-supabase)
3. [Setup Proyek Flutter](#2-setup-proyek-flutter)
4. [Menjalankan Aplikasi](#3-menjalankan-aplikasi)
5. [Build & Deployment](#4-build--deployment)
6. [Troubleshooting](#troubleshooting)

---

## Prasyarat

| Tool | Versi Minimum | Cek Instalasi |
|------|--------------|---------------|
| Flutter SDK | ≥ 3.0.0 | `flutter --version` |
| Dart SDK | ≥ 3.0.0 | `dart --version` |
| Chrome | Latest | Untuk `flutter run -d chrome` |
| Android Studio / VS Code | Latest | IDE pilihan |
| Git | Latest | `git --version` |
| Akun Supabase | Free tier | [supabase.com](https://supabase.com) |

---

## 1. Setup Supabase

### 1.1 Buat Project Baru
1. Buka [supabase.com/dashboard](https://supabase.com/dashboard)
2. Klik **"New Project"**
3. Isi nama project, password database, dan pilih region terdekat
4. Tunggu provisioning selesai (~2 menit)

### 1.2 Jalankan Database Schema
1. Buka **SQL Editor** → **New Query**
2. Copy-paste seluruh isi file [`supabase_schema.sql`](../supabase_schema.sql)
3. Klik **Run** — ini akan membuat:
   - Tabel: `users`, `lands`, `harvests`, `land_finances`
   - Row Level Security (RLS) policies
   - Trigger `set_updated_at` (auto-update timestamp)
   - Trigger `handle_new_user` (auto-insert user saat signup)
   - Storage bucket `land_images`

### 1.3 Buat Akun User
**Cara 1: Via Supabase Dashboard (Direkomendasikan)**
1. Buka **Authentication** → **Users** → **Add User**
2. Buat akun admin:
   - Email: `admin@sawit.com`
   - Password: `Admin123!`
   - ✅ Auto Confirm User
3. Buat akun stakeholder:
   - Email: `stakeholder@sawit.com`
   - Password: `Stake123!`
   - ✅ Auto Confirm User
4. Jalankan SQL berikut untuk set role:
```sql
UPDATE users SET role = 'admin', name = 'Administrator' 
WHERE email = 'admin@sawit.com';

UPDATE users SET role = 'stakeholder', name = 'Pemilik Lahan 1' 
WHERE email = 'stakeholder@sawit.com';
```

**Cara 2: Via SQL** — Lihat file [`create_accounts.sql`](../create_accounts.sql)

### 1.4 Catat Kredensial
Buka **Settings** → **API** dan catat:
- **Project URL** — `https://xxxx.supabase.co`
- **Anon Key** — `eyJhbGc...`

---

## 2. Setup Proyek Flutter

### 2.1 Clone Repository
```bash
git clone https://github.com/Mfkr07/Sistem_Manajemen_Panen_Sawit.git
cd Sistem_Manajemen_Panen_Sawit
```

### 2.2 Install Dependencies
```bash
flutter pub get
```

### 2.3 Konfigurasi Supabase
Buka file `lib/main.dart` dan sesuaikan URL + Anon Key:
```dart
await Supabase.initialize(
  url: 'https://YOUR_PROJECT.supabase.co',      // ← Ganti
  anonKey: 'YOUR_ANON_KEY_HERE',                 // ← Ganti
);
```

> ⚠️ **PENTING:** Jangan commit kredensial ke public repository. Pertimbangkan menggunakan environment variables atau file `.env` untuk production.

---

## 3. Menjalankan Aplikasi

### Web (Development)
```bash
flutter run -d chrome
```

### Android (Emulator atau Device)
```bash
flutter run -d android
```
Pastikan USB Debugging aktif dan device terhubung.

### iOS (macOS only)
```bash
flutter run -d ios
```

### Desktop (Windows)
```bash
flutter run -d windows
```

---

## 4. Build & Deployment

### 4.1 Build APK (Android)
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

### 4.2 Build Web
```bash
flutter build web --release
```
Output: `build/web/`

### 4.3 Deploy ke Vercel (Web)

**Konfigurasi sudah tersedia** di [`vercel.json`](../vercel.json):
```json
{
  "version": 2,
  "buildCommand": "echo 'Skip'",
  "installCommand": "echo 'Skip'",
  "public": true,
  "outputDirectory": "build/web",
  "rewrites": [
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

**Langkah deploy:**
1. Build web terlebih dahulu: `flutter build web --release`
2. Commit & push `build/web/` ke repository
3. Hubungkan repository ke Vercel
4. Vercel akan otomatis deploy dari folder `build/web/`

**Atau manual via Vercel CLI:**
```bash
npm i -g vercel
flutter build web --release
vercel --prod
```

---

## Troubleshooting

### ❌ "Failed to connect to Supabase"
- Pastikan URL dan Anon Key di `main.dart` benar
- Pastikan project Supabase dalam status **Active** (bukan paused)
- Cek koneksi internet

### ❌ "RLS policy violation" / "Permission denied"
- Pastikan semua policies di `supabase_schema.sql` sudah dijalankan
- Verifikasi: `SELECT * FROM pg_policies;`
- Pastikan user sudah ada di tabel `users` dengan role yang benar

### ❌ Login berhasil tapi redirect tidak terjadi
- Cek tabel `users` — pastikan ada row dengan `id` yang cocok dengan `auth.users.id`
- Jika trigger `handle_new_user` belum aktif saat user dibuat, row mungkin tidak ada
- Solusi: Insert manual ke tabel `users`

### ❌ "supabase_admin.create_user() not found"
- Fungsi ini hanya tersedia di beberapa versi Supabase
- Gunakan **Dashboard** → **Authentication** → **Add User** sebagai alternatif

### ❌ Build web error `dart:html`
- Gunakan conditional import yang sudah tersedia di `export_helper_web.dart` / `export_helper_stub.dart`
- Pastikan package `web` ada di dependencies

### ❌ Gambar lahan tidak muncul
- Pastikan bucket `land_images` sudah dibuat (lihat schema.sql Langkah 7)
- Pastikan policies storage sudah aktif
- Cek apakah bucket di-set sebagai `public = true`
