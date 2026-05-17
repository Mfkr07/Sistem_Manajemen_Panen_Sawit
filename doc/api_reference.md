# 🔌 API & Repository Reference

## Daftar Isi
1. [LandRepository](#landrepository)
2. [LocalDatabase](#localdatabase)
3. [ExportService](#exportservice)
4. [Riverpod Providers](#riverpod-providers)
5. [GoRouter Routes](#gorouter-routes)

---

## LandRepository

**File:** `lib/core/repositories/land_repository.dart`  
**Provider:** `landRepositoryProvider`

Repository utama yang menjadi bridge antara UI dan Supabase. Semua operasi CRUD melewati class ini.

### Operasi Lahan

| Method | Parameter | Return | Deskripsi |
|--------|-----------|--------|-----------|
| `getAllLands()` | — | `Future<List<LandModel>>` | Ambil semua lahan (admin). Fallback ke cache jika offline |
| `getLandsByStakeholder(id)` | `String stakeholderId` | `Future<List<LandModel>>` | Ambil lahan berdasarkan stakeholder |
| `addLand(land)` | `LandModel land` | `Future<void>` | Tambah lahan baru |
| `updateLand(id, ...)` | `String id`, `{name, sizeHectares, treeCount, stakeholderId, imageUrl}` | `Future<void>` | Update lahan (partial) |
| `deleteLand(id)` | `String id` | `Future<void>` | Hapus lahan |
| `uploadLandImage(...)` | `String landId, String filePath, List<int> bytes, String ext` | `Future<String?>` | Upload foto ke Supabase Storage, return public URL |

### Operasi Keuangan Lahan

| Method | Parameter | Return | Deskripsi |
|--------|-----------|--------|-----------|
| `getLandFinances(landId)` | `String landId` | `Future<List<LandFinanceModel>>` | Ambil semua data keuangan lahan dari server |
| `getLandFinanceByMonth(...)` | `String landId, int month, int year` | `Future<LandFinanceModel?>` | Ambil data keuangan spesifik bulan. Cek server dulu, fallback ke lokal |
| `upsertFinance(finance)` | `LandFinanceModel finance` | `Future<void>` | Simpan lokal (pending) + trigger sync |
| `syncPendingFinances()` | — | `Future<int>` | Sinkronkan semua data pending ke server. Return jumlah yang berhasil |
| `getAllFinancesLocally()` | — | `Future<List<LandFinanceModel>>` | Ambil semua data keuangan dari lokal |
| `getAllFinancesFromServer()` | — | `Future<List<LandFinanceModel>>` | Ambil dari server + cache lokal |

### Operasi User

| Method | Parameter | Return | Deskripsi |
|--------|-----------|--------|-----------|
| `getAllStakeholders()` | — | `Future<List<UserModel>>` | Ambil semua user dengan role 'stakeholder' |
| `getAllUsers()` | — | `Future<List<UserModel>>` | Ambil semua user (admin + stakeholder) |
| `updateUser(userId, ...)` | `String userId, {name, role}` | `Future<void>` | Update profil user |
| `deleteUser(userId)` | `String userId` | `Future<void>` | Hapus user dari tabel `users` |

---

## LocalDatabase

**File:** `lib/core/database/local_db.dart`  
**Akses:** `LocalDatabase.instance` (Singleton)

Penyimpanan lokal menggunakan `SharedPreferences` untuk mendukung mode offline.

### Operasi Harvest

| Method | Parameter | Return | Deskripsi |
|--------|-----------|--------|-----------|
| `insertHarvest(harvest)` | `HarvestModel` | `Future<void>` | Upsert harvest ke lokal |
| `updateHarvest(harvest)` | `HarvestModel` | `Future<void>` | Alias untuk `insertHarvest` |
| `deleteHarvest(id)` | `String id` | `Future<void>` | Hapus harvest dari lokal |
| `getHarvestById(id)` | `String id` | `Future<HarvestModel?>` | Ambil harvest spesifik |
| `getAllHarvests()` | — | `Future<List<HarvestModel>>` | Ambil semua, sorted by date desc |
| `getPendingHarvests()` | — | `Future<List<HarvestModel>>` | Ambil yang `syncStatus == 'pending'` |
| `markAsSynced(id)` | `String id` | `Future<void>` | Ubah status menjadi 'synced' |
| `clearDatabase()` | — | `Future<void>` | Hapus semua data lokal |

### Operasi Lands Cache

| Method | Parameter | Return | Deskripsi |
|--------|-----------|--------|-----------|
| `cacheLands(lands)` | `List<LandModel>` | `Future<void>` | Cache daftar lahan untuk offline |
| `getCachedLands()` | — | `Future<List<LandModel>>` | Ambil cache lahan |

### Operasi Land Finances

| Method | Parameter | Return | Deskripsi |
|--------|-----------|--------|-----------|
| `insertFinance(finance)` | `LandFinanceModel` | `Future<void>` | Upsert finance ke lokal |
| `getAllFinances()` | — | `Future<List<LandFinanceModel>>` | Ambil semua data keuangan |
| `getPendingFinances()` | — | `Future<List<LandFinanceModel>>` | Ambil yang pending sync |
| `markFinanceAsSynced(id)` | `String id` | `Future<void>` | Tandai sebagai synced |

---

## ExportService

**File:** `lib/core/services/export_service.dart`  
**Tipe:** Static methods (tidak memerlukan instansiasi)

### Export Rekapitulasi Panen

| Method | Parameter | Deskripsi |
|--------|-----------|-----------|
| `exportToPDF(context, harvests, timeRange, landNameMap)` | `BuildContext`, `List<HarvestModel>`, `String`, `Map<String,String>` | Generate PDF tabel rekapitulasi panen dan buka preview |
| `exportToExcel(harvests, timeRange, landNameMap)` | `List<HarvestModel>`, `String`, `Map<String,String>` | Generate file Excel dan download |

**Kolom PDF/Excel Panen:**
- No, Tanggal Panen, Nama Lahan, Berat (Kg), Jumlah Tandan, Rata-rata/Tandan, Waktu Upload, Terakhir Diedit

### Export Laporan Keuangan

| Method | Parameter | Deskripsi |
|--------|-----------|-----------|
| `exportFinanceToPDF(context, land, finance, harvests)` | `BuildContext`, `LandModel`, `LandFinanceModel`, `List<HarvestModel>` | Generate PDF laporan margin laba lahan |
| `exportFinanceToExcel(land, finance, harvests)` | `LandModel`, `LandFinanceModel`, `List<HarvestModel>` | Generate Excel keuangan lahan |

**Perhitungan Margin:**
```
Pendapatan Kotor = Total Tonase × Harga/KG
Pengeluaran = Pupuk + Pekerja + (Pestisida/12) + (Pruning/12)
Margin Laba = Pendapatan Kotor - Total Pengeluaran
```

### Platform-Specific Download
Download file Excel menggunakan *conditional import*:
- **Web:** `export_helper_web.dart` — menggunakan `dart:html` untuk trigger download browser
- **Mobile/Desktop:** `export_helper_stub.dart` — stub/fallback

---

## Riverpod Providers

| Provider | Tipe | Deskripsi |
|----------|------|-----------|
| `landRepositoryProvider` | `Provider<LandRepository>` | Singleton repository instance |
| `routerProvider` | `Provider<GoRouter>` | Router configuration |
| `themeModeProvider` | `StateNotifierProvider<ThemeModeNotifier, ThemeMode>` | Dark/Light mode state. Persisted di SharedPreferences |

### ThemeModeNotifier
```dart
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) { _load(); }
  
  Future<void> toggle() async { ... }  // Toggle dark ↔ light, save ke SharedPreferences
}
```
- Default: `ThemeMode.dark`
- Persistence key: `'isDarkMode'` di SharedPreferences

---

## GoRouter Routes

| Path | Page | Deskripsi |
|------|------|-----------|
| `/login` | `LoginPage` | Halaman login (initial route) |
| `/admin` | `AdminDashboardPage` | Dashboard admin (4 tab) |
| `/admin/accounts` | `ManageAccountsPage` | Halaman CRUD akun user |
| `/stakeholder` | `StakeholderDashboardPage` | Dashboard stakeholder (4 tab) |

### Alur Navigasi
```
/login
  ├─ (role == 'admin')    → /admin
  │   └─ Tab Pengaturan   → /admin/accounts
  └─ (role == 'stakeholder') → /stakeholder
```

### Navigasi Internal (Push)
Selain GoRouter, ada navigasi push standar untuk form dan halaman manajemen:
- `Navigator.push(context, ...)` → `InputHarvestForm`
- `Navigator.push(context, ...)` → `EditHarvestForm`
- Manajemen lahan menggunakan Dialog (bukan halaman terpisah)
