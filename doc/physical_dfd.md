# Physical DFD — Sistem Manajemen Panen Sawit

## Ringkasan Sistem

Aplikasi Flutter multi-platform (Web, Android, Desktop) untuk mengelola data panen kelapa sawit. Menggunakan arsitektur **offline-first** dengan local storage (SharedPreferences) dan sinkronisasi ke **Supabase** (PostgreSQL + Auth + Storage).

---

## Diagram Konteks (Level 0)

```mermaid
flowchart TB
    subgraph External["Entitas Luar"]
        ADMIN["👤 Admin"]
        STAKEHOLDER["👤 Stakeholder\n(Pemilik Lahan)"]
    end

    SISTEM[" Sistem Manajemen\nPemanenan Sawit\n(Flutter App)"]

    ADMIN -->|"Email + Password"| SISTEM
    SISTEM -->|"Dashboard, Laporan PDF/Excel"| ADMIN
    ADMIN -->|"Data Panen, Lahan, Keuangan, Akun"| SISTEM

    STAKEHOLDER -->|"Email + Password"| SISTEM
    SISTEM -->|"Dashboard Read-Only, Laporan"| STAKEHOLDER
```

> **Penjelasan:** Sistem memiliki 2 aktor utama. **Admin** memiliki hak CRUD penuh atas seluruh data. **Stakeholder** hanya bisa melihat data lahan miliknya sendiri.

---

## DFD Level 1 — Proses Utama

```mermaid
flowchart TB
    ADMIN["👤 Admin"]
    STAKEHOLDER["👤 Stakeholder"]

    subgraph SUPABASE_AUTH["D1 — Supabase Auth"]
        AUTH_DB[("auth.users")]
    end

    subgraph SUPABASE_DB["D2 — Supabase PostgreSQL"]
        USERS_TBL[("users")]
        LANDS_TBL[("lands")]
        HARVESTS_TBL[("harvests")]
        FINANCES_TBL[("land_finances")]
    end

    subgraph SUPABASE_STORAGE["D3 — Supabase Storage"]
        LAND_IMAGES[("land_images\nbucket")]
    end

    subgraph LOCAL["D4 — Local Storage\n(SharedPreferences)"]
        LOCAL_HARVESTS[("offline_harvests")]
        LOCAL_LANDS[("cached_lands")]
        LOCAL_FINANCES[("offline_finances")]
    end

    P1["P1\nAutentikasi\n& Otorisasi"]
    P2["P2\nManajemen\nData Panen"]
    P3["P3\nManajemen\nLahan"]
    P4["P4\nManajemen\nKeuangan"]
    P5["P5\nSinkronisasi\nData"]
    P6["P6\nEkspor\nLaporan"]
    P7["P7\nManajemen\nAkun"]

    %% Auth
    ADMIN -->|"email, password"| P1
    STAKEHOLDER -->|"email, password"| P1
    P1 -->|"signInWithPassword()"| AUTH_DB
    AUTH_DB -->|"session token, uid"| P1
    P1 -->|"SELECT role"| USERS_TBL
    USERS_TBL -->|"role: admin/stakeholder"| P1
    P1 -->|"redirect /admin atau /stakeholder"| ADMIN
    P1 -->|"redirect /stakeholder"| STAKEHOLDER

    %% Panen
    ADMIN -->|"land_id, weight_kg,\nharvest_date"| P2
    P2 -->|"INSERT harvest"| LOCAL_HARVESTS
    P2 -->|"SELECT *, lands(name)"| HARVESTS_TBL
    HARVESTS_TBL -->|"List HarvestModel"| P2
    P2 -->|"daftar panen, chart, histori"| ADMIN
    P2 -->|"daftar panen (filtered by land)"| STAKEHOLDER

    %% Lahan
    ADMIN -->|"nama, luas, jumlah pohon,\nstakeholder, foto"| P3
    P3 -->|"INSERT/UPDATE/DELETE"| LANDS_TBL
    P3 -->|"uploadBinary()"| LAND_IMAGES
    LAND_IMAGES -->|"public URL"| P3
    P3 -->|"cache lands"| LOCAL_LANDS
    LANDS_TBL -->|"List LandModel"| P3
    P3 -->|"daftar lahan + detail"| ADMIN
    STAKEHOLDER -->|"stakeholder_id"| P3
    P3 -->|"lahan milik stakeholder"| STAKEHOLDER

    %% Keuangan
    ADMIN -->|"harga/kg, biaya pupuk,\npekerja, pestisida, pruning"| P4
    P4 -->|"INSERT finance"| LOCAL_FINANCES
    P4 -->|"SELECT finances"| FINANCES_TBL
    FINANCES_TBL -->|"List LandFinanceModel"| P4
    P4 -->|"rekap keuangan + margin"| ADMIN
    P4 -->|"rekap keuangan (read-only)"| STAKEHOLDER

    %% Sync
    ADMIN -->|"tombol Sync"| P5
    P5 -->|"getPending()"| LOCAL_HARVESTS
    P5 -->|"getPending()"| LOCAL_FINANCES
    LOCAL_HARVESTS -->|"pending harvests"| P5
    LOCAL_FINANCES -->|"pending finances"| P5
    P5 -->|"UPSERT harvests"| HARVESTS_TBL
    P5 -->|"UPSERT finances"| FINANCES_TBL
    P5 -->|"markAsSynced()"| LOCAL_HARVESTS
    P5 -->|"markAsSynced()"| LOCAL_FINANCES
    P5 -->|"notifikasi hasil sync"| ADMIN

    %% Export
    ADMIN -->|"pilih periode, format"| P6
    STAKEHOLDER -->|"pilih periode, format"| P6
    P6 -->|"query by date range"| HARVESTS_TBL
    P6 -->|"file PDF / Excel"| ADMIN
    P6 -->|"file PDF / Excel"| STAKEHOLDER

    %% Akun
    ADMIN -->|"edit nama, role, hapus user"| P7
    P7 -->|"UPDATE/DELETE users"| USERS_TBL
    P7 -->|"daftar semua akun"| ADMIN
```

---

## DFD Level 2 — Detail Per Proses

### P1 — Autentikasi & Otorisasi

```mermaid
flowchart LR
    USER["👤 User\n(Admin/Stakeholder)"]

    P1_1["P1.1\nValidasi Form\n(LoginPage)"]
    P1_2["P1.2\nLogin ke\nSupabase Auth"]
    P1_3["P1.3\nCek Role\nUser"]
    P1_4["P1.4\nRouting\nBerdasarkan Role"]

    AUTH_DB[("D1: auth.users")]
    USERS_TBL[("D2: users")]

    USER -->|"email, password"| P1_1
    P1_1 -->|"validated credentials"| P1_2
    P1_2 -->|"signInWithPassword()"| AUTH_DB
    AUTH_DB -->|"uid, session"| P1_2
    P1_2 -->|"uid"| P1_3
    P1_3 -->|"SELECT role WHERE id=uid"| USERS_TBL
    USERS_TBL -->|"role"| P1_3
    P1_3 -->|"role info"| P1_4
    P1_4 -->|"GoRouter → /admin"| USER
    P1_4 -->|"GoRouter → /stakeholder"| USER
```

| Komponen Fisik | Teknologi | File |
|---|---|---|
| Form Login | Flutter `TextFormField` | `login_page.dart` |
| Auth Provider | Supabase Auth SDK | `supabase_flutter` |
| Router | GoRouter | `app_router.dart` |
| Policy | Row Level Security (RLS) | `supabase_schema.sql` |

---

### P2 — Manajemen Data Panen

```mermaid
flowchart TB
    ADMIN["👤 Admin"]

    P2_1["P2.1\nInput Panen\n(InputHarvestForm)"]
    P2_2["P2.2\nSimpan ke\nLocal DB"]
    P2_3["P2.3\nLoad & Merge\nData"]
    P2_4["P2.4\nEdit Panen\n(EditHarvestForm)"]
    P2_5["P2.5\nHapus Panen"]
    P2_6["P2.6\nTampilkan\nChart & Histori"]

    LOCAL_H[("D4: offline_harvests\nSharedPreferences")]
    SERVER_H[("D2: harvests\nSupabase")]

    ADMIN -->|"land_id, weight_kg, date"| P2_1
    P2_1 -->|"HarvestModel (pending)"| P2_2
    P2_2 -->|"insertHarvest()"| LOCAL_H
    P2_3 -->|"getAllHarvests()"| LOCAL_H
    P2_3 -->|"getAllHarvestsFromServer()"| SERVER_H
    LOCAL_H -->|"local list"| P2_3
    SERVER_H -->|"server list + lands(name)"| P2_3
    P2_3 -->|"merged & sorted list"| P2_6
    P2_6 -->|"line chart, pie chart, cards"| ADMIN

    ADMIN -->|"edit data"| P2_4
    P2_4 -->|"updateHarvest()"| LOCAL_H
    P2_4 -->|"UPSERT"| SERVER_H

    ADMIN -->|"hapus"| P2_5
    P2_5 -->|"deleteHarvest()"| LOCAL_H
    P2_5 -->|"DELETE"| SERVER_H
```

| Komponen Fisik | Teknologi | File |
|---|---|---|
| Form Input | Flutter Form | `input_harvest_form.dart` |
| Form Edit | Flutter Form | `edit_harvest_form.dart` |
| Repository | Supabase Client | `harvest_repository.dart` |
| Local DB | SharedPreferences | `local_db.dart` |
| Chart | fl_chart (LineChart, PieChart) | `admin_dashboard.dart` |

---

### P3 — Manajemen Lahan

```mermaid
flowchart TB
    ADMIN["👤 Admin"]
    STAKEHOLDER["👤 Stakeholder"]

    P3_1["P3.1\nCRUD Lahan\n(AdminDashboard)"]
    P3_2["P3.2\nUpload Foto\nLahan"]
    P3_3["P3.3\nCache Lahan\nLokal"]
    P3_4["P3.4\nTampilkan\nDetail Lahan"]

    LANDS_TBL[("D2: lands\nSupabase")]
    LAND_IMG[("D3: land_images\nSupabase Storage")]
    LOCAL_L[("D4: cached_lands\nSharedPreferences")]

    ADMIN -->|"nama, luas, pohon,\nstakeholder_id"| P3_1
    P3_1 -->|"INSERT/UPDATE/DELETE"| LANDS_TBL
    LANDS_TBL -->|"List LandModel"| P3_1
    P3_1 -->|"cacheLands()"| P3_3
    P3_3 -->|"setString()"| LOCAL_L

    ADMIN -->|"pilih foto (ImagePicker)"| P3_2
    P3_2 -->|"crop (ImageCropper)"| P3_2
    P3_2 -->|"uploadBinary()"| LAND_IMG
    LAND_IMG -->|"getPublicUrl()"| P3_2
    P3_2 -->|"UPDATE image_url"| LANDS_TBL

    P3_1 -->|"grid lahan + modal detail"| ADMIN
    STAKEHOLDER -->|"stakeholder_id"| P3_4
    P3_4 -->|"SELECT WHERE stakeholder_id"| LANDS_TBL
    P3_4 -->|"card lahan (read-only)"| STAKEHOLDER
```

| Komponen Fisik | Teknologi | File |
|---|---|---|
| CRUD Lahan | Supabase Client | `land_repository.dart` |
| Image Picker | `image_picker` plugin | `admin_dashboard.dart` |
| Image Cropper | `image_cropper` plugin | `admin_dashboard.dart` |
| Storage | Supabase Storage (bucket: `land_images`) | `land_repository.dart` |

---

### P4 — Manajemen Keuangan (Rekapitulasi)

```mermaid
flowchart TB
    ADMIN["👤 Admin"]

    P4_1["P4.1\nInput Data\nKeuangan Bulanan"]
    P4_2["P4.2\nSimpan Lokal\n(pending)"]
    P4_3["P4.3\nHitung Margin\nLaba"]
    P4_4["P4.4\nTampilkan\nRekap"]

    LOCAL_F[("D4: offline_finances\nSharedPreferences")]
    SERVER_F[("D2: land_finances\nSupabase")]
    SERVER_H[("D2: harvests\nSupabase")]

    ADMIN -->|"harga/kg, pupuk, pekerja,\npestisida, pruning,\nbulan, tahun"| P4_1
    P4_1 -->|"LandFinanceModel (pending)"| P4_2
    P4_2 -->|"insertFinance()"| LOCAL_F
    P4_2 -->|"auto-sync UPSERT"| SERVER_F

    P4_3 -->|"query tonase bulan ini"| SERVER_H
    P4_3 -->|"query biaya"| SERVER_F
    SERVER_H -->|"total weight_kg"| P4_3
    SERVER_F -->|"LandFinanceModel"| P4_3

    P4_3 -->|"gross revenue, costs, margin"| P4_4
    P4_4 -->|"tabel rekap + margin card"| ADMIN
```

**Rumus Perhitungan Margin:**
```
Pendapatan Kotor = Total Tonase × Harga/Kg
Pengeluaran = Pupuk + Pekerja + (Pestisida/12) + (Pruning/12)
Margin Laba = Pendapatan Kotor − Pengeluaran
```

---

### P5 — Sinkronisasi Data (Offline-First)

```mermaid
flowchart LR
    ADMIN["👤 Admin"]

    P5_1["P5.1\nCek Data\nPending"]
    P5_2["P5.2\nSync Harvests\nke Server"]
    P5_3["P5.3\nSync Finances\nke Server"]
    P5_4["P5.4\nMark as\nSynced"]

    LOCAL_H[("D4: offline_harvests")]
    LOCAL_F[("D4: offline_finances")]
    SERVER_H[("D2: harvests")]
    SERVER_F[("D2: land_finances")]

    ADMIN -->|"tekan tombol Sync"| P5_1
    P5_1 -->|"getPendingHarvests()"| LOCAL_H
    P5_1 -->|"getPendingFinances()"| LOCAL_F
    LOCAL_H -->|"pending list"| P5_2
    LOCAL_F -->|"pending list"| P5_3
    P5_2 -->|"UPSERT per record"| SERVER_H
    P5_3 -->|"UPSERT (onConflict)"| SERVER_F
    P5_2 -->|"success"| P5_4
    P5_3 -->|"success"| P5_4
    P5_4 -->|"markAsSynced(id)"| LOCAL_H
    P5_4 -->|"markFinanceAsSynced(id)"| LOCAL_F
    P5_4 -->|"notif: N data disinkronkan"| ADMIN
```

---

### P6 — Ekspor Laporan

```mermaid
flowchart TB
    USER["👤 Admin / Stakeholder"]

    P6_1["P6.1\nPilih Periode\n& Format"]
    P6_2["P6.2\nQuery Data\nPanen"]
    P6_3["P6.3\nGenerate\nPDF"]
    P6_4["P6.4\nGenerate\nExcel"]

    SERVER_H[("D2: harvests")]

    USER -->|"start_date, end_date,\nformat (PDF/Excel)"| P6_1
    P6_1 -->|"date range + land filter"| P6_2
    P6_2 -->|"getHarvestsByDateRange()"| SERVER_H
    SERVER_H -->|"filtered harvests"| P6_2
    P6_2 -->|"data"| P6_3
    P6_2 -->|"data"| P6_4
    P6_3 -->|"PDF (pw.Document → Printing.layoutPdf)"| USER
    P6_4 -->|"Excel (excel.save → download)"| USER
```

| Jenis Laporan | Library | Output |
|---|---|---|
| Rekap Panen (PDF) | `pdf` + `printing` | Tabel panen + total berat |
| Rekap Panen (Excel) | `excel` | Spreadsheet .xlsx |
| Laporan Keuangan (PDF) | `pdf` + `printing` | Ringkasan margin + rincian panen |
| Laporan Keuangan (Excel) | `excel` | Spreadsheet .xlsx |

---

### P7 — Manajemen Akun (Admin Only)

```mermaid
flowchart TB
    ADMIN["👤 Admin"]

    P7_1["P7.1\nLihat Semua\nUser"]
    P7_2["P7.2\nEdit Profil\nUser"]
    P7_3["P7.3\nHapus User"]

    USERS_TBL[("D2: users\nSupabase")]

    ADMIN -->|"buka halaman akun"| P7_1
    P7_1 -->|"SELECT * ORDER BY role, name"| USERS_TBL
    USERS_TBL -->|"List UserModel"| P7_1
    P7_1 -->|"grid user cards"| ADMIN

    ADMIN -->|"ubah nama / role"| P7_2
    P7_2 -->|"UPDATE users SET name, role"| USERS_TBL

    ADMIN -->|"hapus user (bukan diri sendiri)"| P7_3
    P7_3 -->|"DELETE FROM users"| USERS_TBL
```

---

## Ringkasan Data Store

| ID | Nama Store | Tipe Fisik | Lokasi | Isi |
|---|---|---|---|---|
| D1 | `auth.users` | PostgreSQL (Supabase Auth) | Cloud | Credential autentikasi |
| D2a | `users` | PostgreSQL | Cloud | Profil user (id, email, name, role) |
| D2b | `lands` | PostgreSQL | Cloud | Data lahan (nama, luas, pohon, stakeholder, image_url) |
| D2c | `harvests` | PostgreSQL | Cloud | Data panen (land_id, weight_kg, harvest_date) |
| D2d | `land_finances` | PostgreSQL | Cloud | Rekap keuangan bulanan per lahan |
| D3 | `land_images` | Supabase Storage | Cloud | File foto lahan (.jpg/.png) |
| D4a | `offline_harvests` | SharedPreferences (JSON) | Device | Cache + pending panen |
| D4b | `cached_lands` | SharedPreferences (JSON) | Device | Cache data lahan (fallback offline) |
| D4c | `offline_finances` | SharedPreferences (JSON) | Device | Cache + pending keuangan |

---

## Ringkasan Entitas Eksternal

| Entitas | Deskripsi | Akses |
|---|---|---|
| **Admin** | Pengelola sistem. Full CRUD semua data. | Login → `/admin` |
| **Stakeholder** | Pemilik lahan. Read-only data miliknya. | Login → `/stakeholder` |

---

## Alur Data Trigger Otomatis (Server-Side)

```mermaid
flowchart LR
    SIGNUP["User Signup\n(Supabase Auth)"] -->|"AFTER INSERT on auth.users"| TRIGGER1["Trigger:\nhandle_new_user()"]
    TRIGGER1 -->|"INSERT INTO users\n(id, email, name, role)"| USERS_TBL[("users")]

    UPDATE_H["UPDATE harvests"] -->|"BEFORE UPDATE"| TRIGGER2["Trigger:\nset_updated_at"]
    TRIGGER2 -->|"SET updated_at = NOW()"| HARVESTS_TBL[("harvests")]

    UPDATE_F["UPDATE land_finances"] -->|"BEFORE UPDATE"| TRIGGER3["Trigger:\nset_finances_updated_at"]
    TRIGGER3 -->|"SET updated_at = NOW()"| FINANCES_TBL[("land_finances")]
```

---

## Matriks CRUD — Proses vs Data Store

| Proses | users | lands | harvests | land_finances | land_images | Local DB |
|---|---|---|---|---|---|---|
| P1 Autentikasi | **R** | — | — | — | — | — |
| P2 Data Panen | — | R | **CRUD** | — | — | **CRUD** |
| P3 Lahan | R | **CRUD** | — | — | **CRU** | **CU** |
| P4 Keuangan | — | — | R | **CRU** | — | **CRU** |
| P5 Sinkronisasi | — | — | **U** | **U** | — | **RU** |
| P6 Ekspor | — | R | **R** | R | — | — |
| P7 Akun | **RUD** | — | — | — | — | — |
