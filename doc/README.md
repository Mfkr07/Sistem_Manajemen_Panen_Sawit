# 🌴 Palm Harvest — Sistem Manajemen Pemanenan Sawit

**Versi:** 1.0.0  
**Platform:** Android, iOS, Web  
**Framework:** Flutter 3.x + Supabase  

---

## Daftar Isi

1. [Gambaran Umum](#gambaran-umum)
2. [Arsitektur Sistem](#arsitektur-sistem)
3. [Teknologi & Dependensi](#teknologi--dependensi)
4. [Struktur Proyek](#struktur-proyek)
5. [Model Data](#model-data)
6. [Fitur Aplikasi](#fitur-aplikasi)
7. [Panduan Setup & Deployment](./setup_guide.md)
8. [Database Schema](./database_schema.md)
9. [API & Repository](./api_reference.md)
10. [Design System](./design_system.md)

---

## Gambaran Umum

**Palm Harvest** adalah aplikasi manajemen pemanenan kelapa sawit yang dirancang untuk dua jenis pengguna:

| Role | Deskripsi |
|------|-----------|
| **Admin** | Mengelola data panen, lahan, akun pengguna, keuangan lahan, dan mengekspor laporan |
| **Stakeholder** | Memantau portofolio lahan miliknya, melihat histori panen, tren, dan mengekspor rekapitulasi |

### Keunggulan Utama

- **Offline-First** — Data panen disimpan lokal terlebih dahulu, lalu disinkronkan ke server saat online
- **Multi-Platform** — Satu codebase untuk Android, iOS, dan Web
- **Responsive UI** — Layout otomatis menyesuaikan: Mobile (BottomNav), Tablet (NavigationRail), Desktop (Permanent Sidebar)
- **Dark/Light Mode** — Tema dinamis yang tersimpan di preferensi lokal
- **Export Laporan** — Rekapitulasi panen dan keuangan dalam format PDF dan Excel

---

## Arsitektur Sistem

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER APPLICATION                       │
│                                                             │
│  ┌──────────┐  ┌──────────────┐  ┌────────────────────┐    │
│  │   UI /   │  │  Repository  │  │   Local Database   │    │
│  │  Pages   │──│   (Bridge)   │──│  (SharedPreferences)│   │
│  └──────────┘  └──────┬───────┘  └────────────────────┘    │
│                       │                                     │
└───────────────────────┼─────────────────────────────────────┘
                        │ HTTPS
                        ▼
              ┌─────────────────┐
              │    SUPABASE     │
              │  ┌───────────┐  │
              │  │  Auth     │  │  ← Login, Signup, JWT
              │  ├───────────┤  │
              │  │ PostgreSQL│  │  ← users, lands, harvests, land_finances
              │  ├───────────┤  │
              │  │  Storage  │  │  ← Foto lahan (land_images bucket)
              │  ├───────────┤  │
              │  │   RLS     │  │  ← Row Level Security policies
              │  └───────────┘  │
              └─────────────────┘
```

### Alur Data (Offline-First)

```
Input Panen → SharedPreferences (status: pending) → Sync ke Supabase (status: synced)
```

1. Admin menginput data panen → data masuk ke `SharedPreferences` dengan `syncStatus = 'pending'`
2. Saat sinkronisasi dipicu → data dikirim ke Supabase via `upsert`
3. Jika berhasil → `syncStatus` diubah menjadi `'synced'`
4. Jika gagal (offline) → data tetap tersimpan lokal, bisa dicoba lagi nanti

---

## Teknologi & Dependensi

| Kategori | Package | Versi | Fungsi |
|----------|---------|-------|--------|
| **State Management** | `flutter_riverpod` | ^2.5.1 | Reactive state management |
| **Routing** | `go_router` | ^14.0.0 | Deklaratif URL-based routing |
| **Backend** | `supabase_flutter` | ^2.5.0 | Auth, Database, Storage |
| **Offline DB** | `shared_preferences` | ^2.2.2 | Key-value local storage |
| **Chart** | `fl_chart` | ^0.68.0 | Line chart & Pie chart |
| **Export PDF** | `pdf` + `printing` | ^3.10.8 / ^5.11.1 | Generate & preview PDF |
| **Export Excel** | `excel` | any | Generate .xlsx files |
| **Typography** | `google_fonts` | ^6.2.1 | Inter font family |
| **Utility** | `uuid` | ^4.3.3 | UUID v4 generator |
| **Utility** | `intl` | ^0.20.2 | Date & number formatting |
| **Media** | `image_picker` | ^1.2.1 | Pilih foto dari galeri/kamera |
| **Media** | `image_cropper` | ^12.2.0 | Crop foto sebelum upload |

---

## Struktur Proyek

```
lib/
├── main.dart                          # Entry point, Supabase init, MaterialApp
├── core/
│   ├── database/
│   │   └── local_db.dart              # SharedPreferences wrapper (offline storage)
│   ├── models/
│   │   └── models.dart                # UserModel, LandModel, HarvestModel, LandFinanceModel
│   ├── repositories/
│   │   └── land_repository.dart       # Supabase CRUD bridge + offline fallback
│   ├── router/
│   │   └── app_router.dart            # GoRouter config (login, admin, stakeholder)
│   ├── services/
│   │   ├── export_service.dart        # PDF & Excel generator
│   │   ├── export_helper_web.dart     # Web-specific download logic
│   │   └── export_helper_stub.dart    # Stub for non-web platforms
│   └── theme/
│       ├── app_colors.dart            # AppColors (accent), DColors (surface/text)
│       ├── app_theme.dart             # ThemeData builder (light/dark)
│       └── theme_provider.dart        # Riverpod ThemeMode notifier
└── features/
    ├── auth/
    │   └── presentation/
    │       └── login_page.dart         # Login dengan split-screen desktop
    ├── admin/
    │   └── presentation/
    │       ├── admin_dashboard.dart    # Dashboard admin (4 tab + sidebar)
    │       ├── input_harvest_form.dart # Form input panen baru
    │       ├── edit_harvest_form.dart  # Form edit data panen
    │       └── manage_accounts_page.dart # CRUD akun user
    ├── stakeholder/
    │   └── presentation/
    │       └── stakeholder_dashboard.dart # Dashboard stakeholder (4 tab + sidebar)
    └── shared/
        └── presentation/             # Komponen shared (jika ada)
```

---

## Model Data

### UserModel
| Field | Tipe | Deskripsi |
|-------|------|-----------|
| `id` | UUID | Primary key, ref ke `auth.users` |
| `email` | String | Email login |
| `name` | String | Nama lengkap |
| `role` | String | `'admin'` atau `'stakeholder'` |

### LandModel
| Field | Tipe | Deskripsi |
|-------|------|-----------|
| `id` | UUID | Auto-generated |
| `name` | String | Nama lahan |
| `sizeHectares` | double | Luas dalam hektar |
| `treeCount` | int | Jumlah pohon sawit |
| `stakeholderId` | UUID | FK ke `users.id` (pemilik) |
| `imageUrl` | String? | URL foto lahan di Supabase Storage |
| `createdAt` | DateTime? | Timestamp pembuatan |

### HarvestModel
| Field | Tipe | Deskripsi |
|-------|------|-----------|
| `id` | UUID | Auto-generated (client-side) |
| `landId` | UUID | FK ke `lands.id` |
| `landName` | String? | Nama lahan (display-only, dari cache/join) |
| `weightKg` | double | Berat panen (KG) |
| `bunchCount` | int | Jumlah tandan |
| `harvestDate` | DateTime | Tanggal dan waktu panen |
| `createdAt` | DateTime | Timestamp pembuatan |
| `updatedAt` | DateTime | Timestamp update terakhir |
| `syncStatus` | String | `'pending'` atau `'synced'` (lokal saja) |

**Computed Property:**
- `avgWeightPerBunch` → `weightKg / bunchCount` (berat rata-rata per tandan)

### LandFinanceModel
| Field | Tipe | Deskripsi |
|-------|------|-----------|
| `id` | UUID | Auto-generated |
| `landId` | UUID | FK ke `lands.id` |
| `periodMonth` | int | Bulan periode (1-12) |
| `periodYear` | int | Tahun periode |
| `pricePerKg` | double | Harga jual per KG (Rp) |
| `fertilizerCost` | double | Biaya pupuk bulanan |
| `workerCost` | double | Biaya pekerja bulanan |
| `pesticideYearlyCost` | double | Biaya pestisida tahunan |
| `pruningYearlyCost` | double | Biaya pruning tahunan |
| `syncStatus` | String | `'pending'` atau `'synced'` |

---

## Fitur Aplikasi

### 🔐 Autentikasi
- Login via email + password (Supabase Auth)
- Role-based routing: Admin → `/admin`, Stakeholder → `/stakeholder`
- Split-screen UI pada layar desktop (≥900px) dengan branding panel

### 👨‍💼 Admin Dashboard
| Tab | Fitur |
|-----|-------|
| **Beranda** | Stat cards (panen bulan ini, total data, jumlah lahan, pending sync), line chart tren panen, pie chart distribusi lahan, histori terkini, export |
| **Histori** | Filter waktu (7 hari - 1 tahun - kustom), grid 2-kolom di desktop, ringkasan total |
| **Lahan** | Daftar lahan + total panen per lahan, grid 3-kolom di desktop, link ke Manajemen Lahan |
| **Pengaturan** | Toggle dark/light mode, manajemen akun, export, hapus data offline, logout |

**Fitur CRUD Admin:**
- ✅ Input data panen baru (offline-first)
- ✅ Edit data panen
- ✅ Hapus data panen
- ✅ Sinkronisasi data pending ke Supabase
- ✅ Tambah/edit/hapus lahan (termasuk upload foto, assign stakeholder)
- ✅ Edit profil user (nama, role)
- ✅ Hapus user dari sistem
- ✅ Input data keuangan lahan per bulan
- ✅ Export rekapitulasi panen (PDF/Excel)
- ✅ Export laporan keuangan & margin laba (PDF/Excel)

### 👤 Stakeholder Dashboard
| Tab | Fitur |
|-----|-------|
| **Beranda** | Lahan saya (horizontal scroll), stat cards (4 kolom desktop termasuk rata-rata/bulan), tren panen, histori terkini, export |
| **Histori** | Sama dengan admin, tapi terbatas pada lahan miliknya |
| **Lahan** | Grid lahan miliknya + total panen masing-masing |
| **Profil** | Info akun, toggle tema, export, logout |

### 📊 Visualisasi Data
- **Line Chart** — Tren panen per waktu (7 hari / 1 bulan / 3 bulan / 6 bulan / 1 tahun)
- **Pie Chart** — Distribusi berat panen per lahan (admin only)

### 📤 Export
- **PDF** — Tabel rekapitulasi panen + laporan keuangan margin laba per lahan
- **Excel (.xlsx)** — Spreadsheet panen + keuangan
- Cross-platform: mobile (share), web (download langsung)

### 🎨 Responsive UI
| Breakpoint | Layout | Navigasi |
|------------|--------|----------|
| < 600px (Mobile) | Single column | BottomNavigationBar + Drawer |
| 600–899px (Tablet) | Adaptive | NavigationRail |
| ≥ 900px (Desktop) | Multi column, Grid | Permanent Sidebar |

---

> 📖 Untuk panduan setup lengkap, lihat [Setup Guide](./setup_guide.md)  
> 🗄️ Untuk skema database, lihat [Database Schema](./database_schema.md)  
> 🔌 Untuk referensi API/Repository, lihat [API Reference](./api_reference.md)  
> 🎨 Untuk design system, lihat [Design System](./design_system.md)  
