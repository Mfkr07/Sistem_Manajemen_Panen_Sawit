# 🗄️ Database Schema

## Daftar Isi
1. [Entity Relationship Diagram](#entity-relationship-diagram)
2. [Tabel Users](#1-tabel-users)
3. [Tabel Lands](#2-tabel-lands)
4. [Tabel Harvests](#3-tabel-harvests)
5. [Tabel Land Finances](#4-tabel-land_finances)
6. [Row Level Security (RLS)](#row-level-security-rls)
7. [Triggers](#triggers)
8. [Storage](#storage)

---

## Entity Relationship Diagram

```
┌──────────────────┐       ┌──────────────────┐
│    auth.users     │       │      users       │
│  (Supabase Auth)  │       │   (app profile)  │
│──────────────────│  1:1  │──────────────────│
│ id (UUID) PK     │◄─────►│ id (UUID) PK/FK  │
│ email            │       │ email            │
│ encrypted_pass   │       │ name             │
│ ...              │       │ role             │
└──────────────────┘       │ created_at       │
                           └───────┬──────────┘
                                   │ 1:N
                                   ▼
                           ┌──────────────────┐
                           │      lands       │
                           │──────────────────│
                           │ id (UUID) PK     │
                           │ name             │
                           │ size_hectares    │
                           │ tree_count       │
                           │ stakeholder_id FK│──► users.id
                           │ image_url        │
                           │ created_at       │
                           └───────┬──────────┘
                                   │ 1:N             1:N
                          ┌────────┴────────┐
                          ▼                 ▼
                  ┌──────────────┐  ┌────────────────┐
                  │   harvests   │  │ land_finances  │
                  │──────────────│  │────────────────│
                  │ id (UUID) PK │  │ id (UUID) PK   │
                  │ land_id   FK │  │ land_id     FK │
                  │ weight_kg    │  │ period_month   │
                  │ bunch_count  │  │ period_year    │
                  │ harvest_date │  │ price_per_kg   │
                  │ created_at   │  │ fertilizer_cost│
                  │ updated_at   │  │ worker_cost    │
                  └──────────────┘  │ pesticide_y... │
                                    │ pruning_y...   │
                                    │ created_at     │
                                    │ updated_at     │
                                    └────────────────┘
                                    UNIQUE(land_id, period_month, period_year)
```

---

## 1. Tabel `users`

Profil pengguna yang terhubung langsung ke `auth.users` Supabase.

```sql
CREATE TABLE IF NOT EXISTS users (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT '',
  role TEXT CHECK (role IN ('admin', 'stakeholder')) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

| Kolom | Tipe | Constraint | Deskripsi |
|-------|------|-----------|-----------|
| `id` | UUID | PK, FK → auth.users | ID dari Supabase Auth |
| `email` | TEXT | NOT NULL | Email user |
| `name` | TEXT | NOT NULL, DEFAULT '' | Nama lengkap |
| `role` | TEXT | CHECK ('admin','stakeholder') | Role akses |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | Waktu pembuatan |

---

## 2. Tabel `lands`

Data lahan kelapa sawit.

```sql
CREATE TABLE IF NOT EXISTS lands (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  size_hectares NUMERIC NOT NULL DEFAULT 0,
  tree_count INTEGER NOT NULL DEFAULT 0,
  stakeholder_id UUID REFERENCES users(id) ON DELETE SET NULL,
  image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

| Kolom | Tipe | Constraint | Deskripsi |
|-------|------|-----------|-----------|
| `id` | UUID | PK, auto-gen | ID unik lahan |
| `name` | TEXT | NOT NULL | Nama lahan |
| `size_hectares` | NUMERIC | NOT NULL, DEFAULT 0 | Luas dalam hektar |
| `tree_count` | INTEGER | NOT NULL, DEFAULT 0 | Jumlah pohon |
| `stakeholder_id` | UUID | FK → users.id, ON DELETE SET NULL | Pemilik lahan |
| `image_url` | TEXT | nullable | URL foto lahan |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | Waktu pembuatan |

---

## 3. Tabel `harvests`

Data pemanenan kelapa sawit.

```sql
CREATE TABLE IF NOT EXISTS harvests (
  id UUID PRIMARY KEY,
  land_id UUID REFERENCES lands(id) ON DELETE CASCADE,
  weight_kg NUMERIC NOT NULL DEFAULT 0,
  bunch_count INTEGER NOT NULL DEFAULT 0,
  harvest_date TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

| Kolom | Tipe | Constraint | Deskripsi |
|-------|------|-----------|-----------|
| `id` | UUID | PK (dari client) | ID unik, di-generate oleh Flutter |
| `land_id` | UUID | FK → lands.id, ON DELETE CASCADE | Lahan terkait |
| `weight_kg` | NUMERIC | NOT NULL, DEFAULT 0 | Berat panen (KG) |
| `bunch_count` | INTEGER | NOT NULL, DEFAULT 0 | Jumlah tandan |
| `harvest_date` | TIMESTAMPTZ | NOT NULL | Tanggal panen |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | Waktu pembuatan |
| `updated_at` | TIMESTAMPTZ | DEFAULT NOW() | Auto-update via trigger |

> **Catatan:** `id` di-generate di sisi client (Flutter) menggunakan UUID v4 untuk mendukung offline-first. Server tidak menggunakan `gen_random_uuid()` karena data bisa dibuat saat offline.

---

## 4. Tabel `land_finances`

Buku rekap pengeluaran & harga bulanan per lahan.

```sql
CREATE TABLE IF NOT EXISTS land_finances (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  land_id UUID REFERENCES lands(id) ON DELETE CASCADE,
  period_month INTEGER NOT NULL,
  period_year INTEGER NOT NULL,
  price_per_kg NUMERIC NOT NULL DEFAULT 0,
  fertilizer_cost NUMERIC NOT NULL DEFAULT 0,
  worker_cost NUMERIC NOT NULL DEFAULT 0,
  pesticide_yearly_cost NUMERIC NOT NULL DEFAULT 0,
  pruning_yearly_cost NUMERIC NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(land_id, period_month, period_year)
);
```

| Kolom | Tipe | Constraint | Deskripsi |
|-------|------|-----------|-----------|
| `id` | UUID | PK, auto-gen | ID unik |
| `land_id` | UUID | FK → lands.id | Lahan terkait |
| `period_month` | INTEGER | NOT NULL | Bulan (1-12) |
| `period_year` | INTEGER | NOT NULL | Tahun |
| `price_per_kg` | NUMERIC | DEFAULT 0 | Harga jual per KG |
| `fertilizer_cost` | NUMERIC | DEFAULT 0 | Biaya pupuk/bulan |
| `worker_cost` | NUMERIC | DEFAULT 0 | Biaya pekerja/bulan |
| `pesticide_yearly_cost` | NUMERIC | DEFAULT 0 | Biaya pestisida/tahun |
| `pruning_yearly_cost` | NUMERIC | DEFAULT 0 | Biaya pruning/tahun |

**Unique Constraint:** `(land_id, period_month, period_year)` — hanya boleh 1 record per lahan per bulan.

---

## Row Level Security (RLS)

Semua tabel menggunakan RLS untuk keamanan data:

### Tabel `users`
| Policy | Aksi | Rule |
|--------|------|------|
| `users_select` | SELECT | Semua user authenticated bisa baca |
| `users_update_own` | UPDATE | Hanya bisa update data diri sendiri |
| `users_insert` | INSERT | Semua user authenticated bisa insert |

### Tabel `lands`
| Policy | Aksi | Rule |
|--------|------|------|
| `lands_admin_all` | ALL | Admin bisa CRUD semua lahan |
| `lands_stakeholder_select` | SELECT | Stakeholder hanya bisa lihat lahan miliknya |

### Tabel `harvests`
| Policy | Aksi | Rule |
|--------|------|------|
| `harvests_admin_all` | ALL | Admin bisa CRUD semua data panen |
| `harvests_stakeholder_select` | SELECT | Stakeholder hanya bisa lihat panen dari lahannya |

### Tabel `land_finances`
| Policy | Aksi | Rule |
|--------|------|------|
| `land_finances_admin_all` | ALL | Admin bisa CRUD semua data keuangan |
| `land_finances_stakeholder_select` | SELECT | Stakeholder hanya bisa lihat keuangan lahannya |

---

## Triggers

### Auto-update `updated_at`
```sql
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```
Diterapkan pada: `harvests`, `land_finances`

### Auto-insert User pada Signup
```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'stakeholder')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```
Trigger ini berjalan `AFTER INSERT ON auth.users` sehingga setiap kali user baru dibuat via Auth, otomatis ada profil di tabel `users`.

---

## Storage

### Bucket: `land_images`
- **Tujuan:** Menyimpan foto lahan yang diupload admin
- **Akses:** Public read, Admin-only write/delete
- **Path pattern:** `covers/{landId}_{timestamp}.{ext}`

**Policies:**
| Policy | Aksi | Rule |
|--------|------|------|
| Public View Land Images | SELECT | Semua orang bisa lihat |
| Admin Insert Land Images | INSERT | Admin only |
| Admin Update Land Images | UPDATE | Admin only |
| Admin Delete Land Images | DELETE | Admin only |
