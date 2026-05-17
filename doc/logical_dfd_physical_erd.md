# Logical DFD & Physical ERD — Sistem Manajemen Panen Sawit

---

## 1. Data Flow Diagram (DFD) — Logical

### 1.1 Diagram Konteks (Level 0)

Diagram konteks menunjukkan sistem sebagai satu proses utama yang berinteraksi dengan entitas luar (external entities).

```mermaid
flowchart TB
    Admin["🧑‍💼 Admin"]
    Stakeholder["🧑‍🌾 Stakeholder"]
    SupabaseAuth["🔐 Supabase Auth"]
    Storage["📁 Supabase Storage"]

    Admin -- "Email + Password" --> SMPS
    Admin -- "Data Lahan, Data Panen,\nData Keuangan, Data Akun" --> SMPS
    SMPS -- "Dashboard Analitik,\nLaporan PDF/Excel,\nDaftar Lahan & Panen" --> Admin

    Stakeholder -- "Email + Password" --> SMPS
    SMPS -- "Dashboard Lahan,\nRiwayat Panen,\nLaporan Keuangan" --> Stakeholder

    SMPS -- "Validasi Kredensial,\nRegistrasi User" --> SupabaseAuth
    SupabaseAuth -- "Token Autentikasi,\nUser ID" --> SMPS

    SMPS -- "Upload Foto Lahan" --> Storage
    Storage -- "URL Foto Publik" --> SMPS

    SMPS["⚙️ Sistem Manajemen\nPemanenan Sawit\n(SMPS)"]

    style SMPS fill:#059669,stroke:#047857,color:#fff,stroke-width:3px
    style Admin fill:#1e40af,stroke:#1e3a8a,color:#fff
    style Stakeholder fill:#7c3aed,stroke:#6d28d9,color:#fff
    style SupabaseAuth fill:#f59e0b,stroke:#d97706,color:#fff
    style Storage fill:#06b6d4,stroke:#0891b2,color:#fff
```

#### Penjelasan External Entity

| No | External Entity | Deskripsi |
|----|----------------|-----------|
| 1 | **Admin** | Pengelola sistem yang memiliki akses penuh: CRUD lahan, panen, keuangan, akun user |
| 2 | **Stakeholder** | Pemilik lahan yang hanya bisa melihat data lahan, panen, dan keuangan miliknya |
| 3 | **Supabase Auth** | Layanan autentikasi pihak ketiga (Supabase) untuk login/registrasi |
| 4 | **Supabase Storage** | Penyimpanan file cloud untuk foto/gambar lahan |

---

### 1.2 DFD Level 1

Dekomposisi sistem utama menjadi proses-proses inti.

```mermaid
flowchart TB
    Admin["🧑‍💼 Admin"]
    Stakeholder["🧑‍🌾 Stakeholder"]
    SupabaseAuth["🔐 Supabase Auth"]
    Storage["📁 Supabase Storage"]

    subgraph SMPS ["⚙️ Sistem Manajemen Pemanenan Sawit"]
        P1["1.0\nManajemen\nAutentikasi"]
        P2["2.0\nManajemen\nLahan"]
        P3["3.0\nManajemen\nPanen"]
        P4["4.0\nManajemen\nKeuangan"]
        P5["5.0\nManajemen\nAkun"]
        P6["6.0\nPelaporan &\nEkspor"]
        P7["7.0\nSinkronisasi\nData"]

        D1[("D1\nusers")]
        D2[("D2\nlands")]
        D3[("D3\nharvests")]
        D4[("D4\nland_finances")]
        D5[("D5\nLocal Storage\n(SharedPrefs)")]
    end

    %% Autentikasi
    Admin -- "Email, Password" --> P1
    Stakeholder -- "Email, Password" --> P1
    P1 -- "Validasi Kredensial" --> SupabaseAuth
    SupabaseAuth -- "Token, User ID" --> P1
    P1 -- "Query Role" --> D1
    P1 -- "Redirect berdasarkan Role" --> Admin
    P1 -- "Redirect berdasarkan Role" --> Stakeholder

    %% Manajemen Lahan
    Admin -- "CRUD Data Lahan" --> P2
    P2 -- "Simpan/Ubah/Hapus" --> D2
    P2 -- "Upload Foto" --> Storage
    Storage -- "Public URL" --> P2
    P2 -- "Daftar Lahan" --> Admin
    P2 -- "Lahan Milik" --> Stakeholder
    D2 -- "Data Lahan" --> P2

    %% Manajemen Panen
    Admin -- "Input/Edit Data Panen" --> P3
    P3 -- "Simpan Lokal (Offline)" --> D5
    P3 -- "Simpan/Ubah/Hapus" --> D3
    D3 -- "Data Panen" --> P3
    D2 -- "Referensi Lahan" --> P3
    P3 -- "Riwayat Panen" --> Admin
    P3 -- "Riwayat Panen Milik" --> Stakeholder

    %% Manajemen Keuangan
    Admin -- "Input Data Keuangan\n(Pupuk, Pekerja, dll)" --> P4
    P4 -- "Simpan Lokal" --> D5
    P4 -- "Simpan/Ubah" --> D4
    D4 -- "Data Keuangan" --> P4
    D2 -- "Referensi Lahan" --> P4
    P4 -- "Laporan Margin" --> Admin
    P4 -- "Laporan Margin Milik" --> Stakeholder

    %% Manajemen Akun
    Admin -- "CRUD Akun User" --> P5
    P5 -- "Simpan/Ubah/Hapus" --> D1
    D1 -- "Daftar User" --> P5
    P5 -- "Daftar Akun" --> Admin

    %% Pelaporan
    Admin -- "Permintaan Ekspor" --> P6
    Stakeholder -- "Permintaan Ekspor" --> P6
    D3 -- "Data Panen" --> P6
    D4 -- "Data Keuangan" --> P6
    D2 -- "Data Lahan" --> P6
    P6 -- "File PDF / Excel" --> Admin
    P6 -- "File PDF / Excel" --> Stakeholder

    %% Sinkronisasi
    P7 -- "Baca Data Pending" --> D5
    P7 -- "Kirim ke Server" --> D3
    P7 -- "Kirim ke Server" --> D4
    D5 -- "Data Offline" --> P7

    style P1 fill:#f59e0b,stroke:#d97706,color:#fff
    style P2 fill:#059669,stroke:#047857,color:#fff
    style P3 fill:#2563eb,stroke:#1d4ed8,color:#fff
    style P4 fill:#7c3aed,stroke:#6d28d9,color:#fff
    style P5 fill:#dc2626,stroke:#b91c1c,color:#fff
    style P6 fill:#06b6d4,stroke:#0891b2,color:#fff
    style P7 fill:#ea580c,stroke:#c2410c,color:#fff

    style D1 fill:#fef3c7,stroke:#f59e0b,color:#92400e
    style D2 fill:#d1fae5,stroke:#059669,color:#065f46
    style D3 fill:#dbeafe,stroke:#2563eb,color:#1e3a5f
    style D4 fill:#ede9fe,stroke:#7c3aed,color:#4c1d95
    style D5 fill:#fed7aa,stroke:#ea580c,color:#7c2d12
```

#### Penjelasan Proses DFD Level 1

| No | ID Proses | Nama Proses | Deskripsi |
|----|-----------|-------------|-----------|
| 1 | **1.0** | Manajemen Autentikasi | Login menggunakan Supabase Auth, validasi kredensial, cek role (`admin`/`stakeholder`), dan redirect ke dashboard yang sesuai |
| 2 | **2.0** | Manajemen Lahan | CRUD data lahan oleh Admin. Stakeholder hanya bisa melihat lahan miliknya. Termasuk upload foto lahan ke Supabase Storage |
| 3 | **3.0** | Manajemen Panen | Input/edit data panen (berat kg, jumlah tandan, tanggal panen) oleh Admin. Data disimpan ke local storage (offline-first) dan disinkronkan ke server |
| 4 | **4.0** | Manajemen Keuangan | Input data keuangan per lahan per bulan (biaya pupuk, pekerja, pestisida, pruning, harga/kg). Menghitung margin laba bersih |
| 5 | **5.0** | Manajemen Akun | Admin mengelola (CRUD) akun user seluruh sistem |
| 6 | **6.0** | Pelaporan & Ekspor | Generate laporan rekapitulasi panen dan laporan keuangan/margin dalam format PDF dan Excel |
| 7 | **7.0** | Sinkronisasi Data | Proses background yang membaca data pending dari local storage dan mengirimnya ke Supabase server |

#### Penjelasan Data Store

| No | ID | Nama Data Store | Tipe | Deskripsi |
|----|----|-----------------|------|-----------|
| 1 | **D1** | `users` | Supabase (Cloud) | Profil pengguna: id, email, nama, role |
| 2 | **D2** | `lands` | Supabase (Cloud) | Data lahan: nama, luas, jumlah pohon, foto, stakeholder |
| 3 | **D3** | `harvests` | Supabase (Cloud) | Data panen: berat, tandan, tanggal panen |
| 4 | **D4** | `land_finances` | Supabase (Cloud) | Data keuangan lahan: biaya bulanan, harga, margin |
| 5 | **D5** | Local Storage | SharedPreferences (Lokal) | Cache offline: harvests pending, finances pending, lands cache |

---

### 1.3 DFD Level 2 — Proses 3.0 (Manajemen Panen)

Dekomposisi lebih detail pada proses input & sinkronisasi panen.

```mermaid
flowchart TB
    Admin["🧑‍💼 Admin"]

    subgraph P3 ["3.0 Manajemen Panen"]
        P3_1["3.1\nInput Data\nPanen Baru"]
        P3_2["3.2\nEdit Data\nPanen"]
        P3_3["3.3\nAmbil Riwayat\nPanen"]
        P3_4["3.4\nFilter Panen\nper Lahan"]
        P3_5["3.5\nStream\nRealtime"]
    end

    D2[("D2\nlands")]
    D3[("D3\nharvests")]
    D5[("D5\nLocal Storage")]

    Admin -- "Lahan, Berat, Tandan, Tanggal" --> P3_1
    P3_1 -- "Generate UUID" --> P3_1
    P3_1 -- "Simpan (status: pending)" --> D5
    P3_1 -- "Upsert ke server" --> D3

    Admin -- "ID Panen, Data Baru" --> P3_2
    P3_2 -- "Update" --> D3
    P3_2 -- "Update lokal" --> D5

    D3 -- "Semua data panen + JOIN lands.name" --> P3_3
    P3_3 -- "Riwayat panen lengkap" --> Admin

    Admin -- "Pilih Lahan / Rentang Tanggal" --> P3_4
    D3 -- "Data terfilter" --> P3_4
    D2 -- "Daftar lahan" --> P3_4
    P3_4 -- "Hasil filter" --> Admin

    D3 -- "Realtime stream" --> P3_5
    P3_5 -- "Update otomatis" --> Admin

    style P3_1 fill:#2563eb,stroke:#1d4ed8,color:#fff
    style P3_2 fill:#2563eb,stroke:#1d4ed8,color:#fff
    style P3_3 fill:#2563eb,stroke:#1d4ed8,color:#fff
    style P3_4 fill:#2563eb,stroke:#1d4ed8,color:#fff
    style P3_5 fill:#2563eb,stroke:#1d4ed8,color:#fff
```

---

### 1.4 DFD Level 2 — Proses 6.0 (Pelaporan & Ekspor)

```mermaid
flowchart TB
    Admin["🧑‍💼 Admin"]
    Stakeholder["🧑‍🌾 Stakeholder"]

    subgraph P6 ["6.0 Pelaporan & Ekspor"]
        P6_1["6.1\nGenerate Laporan\nRekapitulasi Panen"]
        P6_2["6.2\nGenerate Laporan\nKeuangan & Margin"]
        P6_3["6.3\nRender\nPDF"]
        P6_4["6.4\nRender\nExcel"]
    end

    D2[("D2\nlands")]
    D3[("D3\nharvests")]
    D4[("D4\nland_finances")]

    Admin -- "Pilih periode" --> P6_1
    Stakeholder -- "Pilih periode" --> P6_1
    D3 -- "Data panen by date range" --> P6_1
    D2 -- "Mapping nama lahan" --> P6_1

    Admin -- "Pilih lahan + bulan" --> P6_2
    Stakeholder -- "Pilih lahan + bulan" --> P6_2
    D4 -- "Data biaya & harga" --> P6_2
    D3 -- "Data panen bulan ini" --> P6_2
    D2 -- "Info lahan" --> P6_2

    P6_1 -- "Data rekapitulasi" --> P6_3
    P6_1 -- "Data rekapitulasi" --> P6_4
    P6_2 -- "Data margin" --> P6_3
    P6_2 -- "Data margin" --> P6_4

    P6_3 -- "File PDF" --> Admin
    P6_3 -- "File PDF" --> Stakeholder
    P6_4 -- "File Excel (.xlsx)" --> Admin
    P6_4 -- "File Excel (.xlsx)" --> Stakeholder

    style P6_1 fill:#06b6d4,stroke:#0891b2,color:#fff
    style P6_2 fill:#06b6d4,stroke:#0891b2,color:#fff
    style P6_3 fill:#06b6d4,stroke:#0891b2,color:#fff
    style P6_4 fill:#06b6d4,stroke:#0891b2,color:#fff
```

---

## 2. Physical ERD — Notasi James Martin (Crow's Foot)

Physical ERD menunjukkan implementasi **fisik** database, termasuk: tipe data spesifik platform (PostgreSQL), constraint, trigger, index, dan unique constraint.

### 2.1 Diagram Physical ERD

```mermaid
erDiagram
    AUTH_USERS {
        UUID id PK "Supabase internal auth table"
        TEXT email "User login email"
        JSONB raw_user_meta_data "Metadata (name, role)"
    }

    USERS {
        UUID id PK "REFERENCES auth.users(id) ON DELETE CASCADE"
        TEXT email "NOT NULL"
        TEXT name "NOT NULL DEFAULT ''"
        TEXT role "NOT NULL CHECK(admin|stakeholder)"
        TIMESTAMPTZ created_at "DEFAULT NOW()"
    }

    LANDS {
        UUID id PK "DEFAULT gen_random_uuid()"
        TEXT name "NOT NULL"
        NUMERIC size_hectares "NOT NULL DEFAULT 0"
        INTEGER tree_count "NOT NULL DEFAULT 0"
        UUID stakeholder_id FK "REFERENCES users(id) ON DELETE SET NULL"
        TEXT image_url "NULLABLE - Supabase Storage URL"
        TIMESTAMPTZ created_at "DEFAULT NOW()"
    }

    HARVESTS {
        UUID id PK "Client-generated UUID"
        UUID land_id FK "REFERENCES lands(id) ON DELETE CASCADE"
        NUMERIC weight_kg "NOT NULL DEFAULT 0"
        INTEGER bunch_count "NOT NULL DEFAULT 0"
        TIMESTAMPTZ harvest_date "NOT NULL"
        TIMESTAMPTZ created_at "DEFAULT NOW()"
        TIMESTAMPTZ updated_at "DEFAULT NOW() - auto via trigger"
    }

    LAND_FINANCES {
        UUID id PK "DEFAULT gen_random_uuid()"
        UUID land_id FK "REFERENCES lands(id) ON DELETE CASCADE"
        INTEGER period_month "NOT NULL (1-12)"
        INTEGER period_year "NOT NULL (e.g. 2026)"
        NUMERIC price_per_kg "NOT NULL DEFAULT 0"
        NUMERIC fertilizer_cost "NOT NULL DEFAULT 0"
        NUMERIC worker_cost "NOT NULL DEFAULT 0"
        NUMERIC pesticide_yearly_cost "NOT NULL DEFAULT 0"
        NUMERIC pruning_yearly_cost "NOT NULL DEFAULT 0"
        TIMESTAMPTZ created_at "DEFAULT NOW()"
        TIMESTAMPTZ updated_at "DEFAULT NOW() - auto via trigger"
    }

    SUPABASE_STORAGE {
        TEXT bucket_id "land_images"
        TEXT object_path "covers/filename.ext"
        TEXT public_url "Publicly accessible URL"
    }

    AUTH_USERS ||--|| USERS : "trigger: on_auth_user_created"
    USERS ||--o{ LANDS : "1 stakeholder → 0..N lahan"
    LANDS ||--o{ HARVESTS : "1 lahan → 0..N panen"
    LANDS ||--o{ LAND_FINANCES : "1 lahan → 0..N rekap keuangan"
    LANDS ||--o| SUPABASE_STORAGE : "0..1 foto lahan"
```

---

### 2.2 Spesifikasi Fisik Detail per Tabel

#### Tabel: `users`

| Kolom | Tipe Data PostgreSQL | Constraint | Keterangan Fisik |
|-------|---------------------|------------|------------------|
| `id` | `UUID` | `PK`, `FK → auth.users(id) ON DELETE CASCADE` | Tidak auto-generated, diisi dari Supabase Auth trigger |
| `email` | `TEXT` | `NOT NULL` | Variable-length, unlimited |
| `name` | `TEXT` | `NOT NULL DEFAULT ''` | String kosong jika tidak diisi saat registrasi |
| `role` | `TEXT` | `NOT NULL`, `CHECK (role IN ('admin', 'stakeholder'))` | Enum logical via CHECK constraint |
| `created_at` | `TIMESTAMP WITH TIME ZONE` | `DEFAULT NOW()` | Timezone-aware, auto-fill |

**RLS:** Enabled  
**Trigger:** `on_auth_user_created` → auto-insert saat registrasi via `handle_new_user()`

---

#### Tabel: `lands`

| Kolom | Tipe Data PostgreSQL | Constraint | Keterangan Fisik |
|-------|---------------------|------------|------------------|
| `id` | `UUID` | `PK`, `DEFAULT gen_random_uuid()` | Auto-generated UUID v4 oleh PostgreSQL |
| `name` | `TEXT` | `NOT NULL` | Nama/label lahan |
| `size_hectares` | `NUMERIC` | `NOT NULL DEFAULT 0` | Presisi arbitrer, cocok untuk desimal luas |
| `tree_count` | `INTEGER` | `NOT NULL DEFAULT 0` | Jumlah pohon sawit di lahan |
| `stakeholder_id` | `UUID` | `FK → users(id) ON DELETE SET NULL`, `NULLABLE` | NULL = belum ditugaskan |
| `image_url` | `TEXT` | `NULLABLE` | URL publik foto dari Supabase Storage bucket `land_images` |
| `created_at` | `TIMESTAMP WITH TIME ZONE` | `DEFAULT NOW()` | Auto-fill saat insert |

**RLS:** Enabled  
**Index:** Implicit on `id` (PK)

---

#### Tabel: `harvests`

| Kolom | Tipe Data PostgreSQL | Constraint | Keterangan Fisik |
|-------|---------------------|------------|------------------|
| `id` | `UUID` | `PK` | Di-generate oleh client (Flutter app) menggunakan `uuid` package |
| `land_id` | `UUID` | `FK → lands(id) ON DELETE CASCADE` | Cascade delete: hapus lahan → hapus semua panen |
| `weight_kg` | `NUMERIC` | `NOT NULL DEFAULT 0` | Berat total panen (kilogram) |
| `bunch_count` | `INTEGER` | `NOT NULL DEFAULT 0` | Jumlah tandan buah segar (TBS) |
| `harvest_date` | `TIMESTAMP WITH TIME ZONE` | `NOT NULL` | Tanggal pelaksanaan panen |
| `created_at` | `TIMESTAMP WITH TIME ZONE` | `DEFAULT NOW()` | Waktu record pertama kali dibuat |
| `updated_at` | `TIMESTAMP WITH TIME ZONE` | `DEFAULT NOW()` | Auto-update via trigger `set_updated_at` |

**RLS:** Enabled  
**Trigger:** `set_updated_at` → `BEFORE UPDATE` → `update_updated_at_column()`  
**Computed (App-level):** `avg_weight_per_bunch = weight_kg / bunch_count`

---

#### Tabel: `land_finances`

| Kolom | Tipe Data PostgreSQL | Constraint | Keterangan Fisik |
|-------|---------------------|------------|------------------|
| `id` | `UUID` | `PK`, `DEFAULT gen_random_uuid()` | Auto-generated |
| `land_id` | `UUID` | `FK → lands(id) ON DELETE CASCADE` | Cascade delete |
| `period_month` | `INTEGER` | `NOT NULL` | Bulan periode (1–12) |
| `period_year` | `INTEGER` | `NOT NULL` | Tahun periode (e.g., 2026) |
| `price_per_kg` | `NUMERIC` | `NOT NULL DEFAULT 0` | Harga jual sawit per kilogram (Rp) |
| `fertilizer_cost` | `NUMERIC` | `NOT NULL DEFAULT 0` | Biaya pupuk bulanan (Rp) |
| `worker_cost` | `NUMERIC` | `NOT NULL DEFAULT 0` | Biaya pekerja bulanan (Rp) |
| `pesticide_yearly_cost` | `NUMERIC` | `NOT NULL DEFAULT 0` | Biaya pestisida tahunan (Rp), dibagi 12 di app |
| `pruning_yearly_cost` | `NUMERIC` | `NOT NULL DEFAULT 0` | Biaya pruning/pangkas tahunan (Rp), dibagi 12 di app |
| `created_at` | `TIMESTAMP WITH TIME ZONE` | `DEFAULT NOW()` | Auto-fill |
| `updated_at` | `TIMESTAMP WITH TIME ZONE` | `DEFAULT NOW()` | Auto-update via trigger |

**RLS:** Enabled  
**Trigger:** `set_finances_updated_at` → `BEFORE UPDATE` → `update_updated_at_column()`  
**Unique Constraint:** `UNIQUE(land_id, period_month, period_year)` — satu record keuangan per lahan per bulan

---

#### Storage: `land_images` (Supabase Storage Bucket)

| Properti | Nilai |
|----------|-------|
| **Bucket ID** | `land_images` |
| **Akses** | Public (gambar bisa diakses tanpa auth) |
| **Path Pattern** | `covers/{landId}_{timestamp}.{ext}` |
| **RLS Policies** | SELECT: Public, INSERT/UPDATE/DELETE: Admin only |

---

### 2.3 Peta Referential Integrity Lengkap

```mermaid
flowchart LR
    subgraph "PostgreSQL - Supabase"
        AU["auth.users"]
        U["users"]
        L["lands"]
        H["harvests"]
        LF["land_finances"]
        S["storage.objects\n(land_images)"]
    end

    AU -- "PK: id\nON DELETE CASCADE" --> U
    U -- "PK: id\nON DELETE SET NULL" --> L
    L -- "PK: id\nON DELETE CASCADE" --> H
    L -- "PK: id\nON DELETE CASCADE" --> LF
    L -. "image_url\n(logical ref)" .-> S

    style AU fill:#fbbf24,stroke:#f59e0b,color:#78350f
    style U fill:#34d399,stroke:#059669,color:#064e3b
    style L fill:#60a5fa,stroke:#2563eb,color:#1e3a5f
    style H fill:#a78bfa,stroke:#7c3aed,color:#4c1d95
    style LF fill:#f472b6,stroke:#ec4899,color:#831843
    style S fill:#94a3b8,stroke:#64748b,color:#1e293b
```

### 2.4 Tabel Ringkasan Relasi Fisik

| No | Parent Table | Child Table | FK Column | Cardinality | ON DELETE | UNIQUE Constraint |
|----|-------------|-------------|-----------|-------------|-----------|-------------------|
| 1 | `auth.users` | `users` | `users.id` | 1:1 | `CASCADE` | PK |
| 2 | `users` | `lands` | `lands.stakeholder_id` | 1:N (0..*) | `SET NULL` | — |
| 3 | `lands` | `harvests` | `harvests.land_id` | 1:N (0..*) | `CASCADE` | — |
| 4 | `lands` | `land_finances` | `land_finances.land_id` | 1:N (0..*) | `CASCADE` | `UNIQUE(land_id, period_month, period_year)` |

---

### 2.5 Daftar Trigger & Function

| No | Trigger Name | Table | Event | Timing | Function | Deskripsi |
|----|-------------|-------|-------|--------|----------|-----------|
| 1 | `on_auth_user_created` | `auth.users` | `INSERT` | `AFTER` | `handle_new_user()` | Auto-insert profil di `users` saat signup |
| 2 | `set_updated_at` | `harvests` | `UPDATE` | `BEFORE` | `update_updated_at_column()` | Auto-update `updated_at` timestamp |
| 3 | `set_finances_updated_at` | `land_finances` | `UPDATE` | `BEFORE` | `update_updated_at_column()` | Auto-update `updated_at` timestamp |

---

### 2.6 Ringkasan RLS Policies per Tabel

| Tabel | Total Policies | Admin Access | Stakeholder Access |
|-------|---------------|-------------|-------------------|
| `users` | 3 | SELECT all, INSERT, UPDATE own | SELECT all, UPDATE own |
| `lands` | 2 | ALL (CRUD) | SELECT own only |
| `harvests` | 2 | ALL (CRUD) | SELECT own lands only |
| `land_finances` | 2 | ALL (CRUD) | SELECT own lands only |
| `storage.objects` | 4 | SELECT, INSERT, UPDATE, DELETE | SELECT only (public) |
| **Total** | **13** | | |

---

## 3. Mapping Logical → Physical

| DFD Data Store | Physical Table | DBMS | Storage Engine |
|----------------|---------------|------|----------------|
| D1: users | `public.users` | PostgreSQL (Supabase) | Cloud |
| D2: lands | `public.lands` | PostgreSQL (Supabase) | Cloud |
| D3: harvests | `public.harvests` | PostgreSQL (Supabase) | Cloud |
| D4: land_finances | `public.land_finances` | PostgreSQL (Supabase) | Cloud |
| D5: Local Storage | `SharedPreferences` | Key-Value (JSON) | Device Local |
| — | `auth.users` | PostgreSQL (Supabase) | Cloud (Managed) |
| — | `storage.objects` | Supabase Storage | Cloud (S3-compatible) |
