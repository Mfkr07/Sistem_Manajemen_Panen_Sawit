-- ============================================================
-- SISTEM MANAJEMEN PEMANENAN SAWIT — DATABASE SCHEMA
-- Jalankan di: Supabase Dashboard → SQL Editor → New Query
-- ============================================================

-- ============================================================
-- LANGKAH 1: PERBAIKAN SKEMA (Jalankan jika tabel sudah ada)
-- Jika tabel BELUM ada, langsung ke Langkah 2.
-- ============================================================

-- Hapus policies lama (akan dibuat ulang yang lebih aman)
DROP POLICY IF EXISTS "Allow all authenticated users to read and write to users" ON users;
DROP POLICY IF EXISTS "Allow all authenticated users to read and write to lands" ON lands;
DROP POLICY IF EXISTS "Allow all authenticated users to read and write to harvests" ON harvests;

-- ============================================================
-- LANGKAH 2: BUAT TABEL (Skip jika tabel sudah ada)
-- ============================================================

-- 1. Tabel Users (profil pengguna, terhubung ke auth.users)
CREATE TABLE IF NOT EXISTS users (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT NOT NULL,
  name TEXT NOT NULL DEFAULT '',
  role TEXT CHECK (role IN ('admin', 'stakeholder')) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Tabel Lands (Lahan)
CREATE TABLE IF NOT EXISTS lands (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  size_hectares NUMERIC NOT NULL DEFAULT 0,
  tree_count INTEGER NOT NULL DEFAULT 0,
  stakeholder_id UUID REFERENCES users(id) ON DELETE SET NULL,
  image_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
-- Juga tambahkan alter table agar memastikan kolom terbuat untuk tabel yang terlanjur ada
ALTER TABLE lands ADD COLUMN IF NOT EXISTS image_url TEXT;

-- 3. Tabel Harvests (Data Panen)
CREATE TABLE IF NOT EXISTS harvests (
  id UUID PRIMARY KEY,
  land_id UUID REFERENCES lands(id) ON DELETE CASCADE,
  weight_kg NUMERIC NOT NULL DEFAULT 0,
  bunch_count INTEGER NOT NULL DEFAULT 0,
  harvest_date TIMESTAMP WITH TIME ZONE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
-- Tambahkan kolom bunch_count jika tabel sudah ada
ALTER TABLE harvests ADD COLUMN IF NOT EXISTS bunch_count INTEGER NOT NULL DEFAULT 0;

-- 4. Tabel Land Finances (Buku Rekap Pengeluaran & Harga Bulanan)
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

-- ============================================================
-- LANGKAH 3: AKTIFKAN ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE lands ENABLE ROW LEVEL SECURITY;
ALTER TABLE harvests ENABLE ROW LEVEL SECURITY;
ALTER TABLE land_finances ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- LANGKAH 4: POLICIES (Aturan Akses)
-- ============================================================

-- === USERS TABLE ===
-- Semua user yang login bisa baca semua data users (untuk daftar stakeholder di dropdown)
CREATE POLICY "users_select" ON users
  FOR SELECT TO authenticated USING (true);

-- User hanya bisa update data dirinya sendiri
CREATE POLICY "users_update_own" ON users
  FOR UPDATE TO authenticated USING (auth.uid() = id);

-- Insert (dipakai saat registrasi, biasanya via trigger)
CREATE POLICY "users_insert" ON users
  FOR INSERT TO authenticated WITH CHECK (true);

-- === LANDS TABLE ===
-- Admin bisa CRUD semua lahan
CREATE POLICY "lands_admin_all" ON lands
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  );

-- Stakeholder bisa SELECT lahan miliknya
CREATE POLICY "lands_stakeholder_select" ON lands
  FOR SELECT TO authenticated
  USING (stakeholder_id = auth.uid());

-- === HARVESTS TABLE ===
-- Admin bisa CRUD semua data panen
CREATE POLICY "harvests_admin_all" ON harvests
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  );

-- Stakeholder bisa SELECT data panen lahan miliknya
CREATE POLICY "harvests_stakeholder_select" ON harvests
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM lands 
      WHERE lands.id = harvests.land_id 
        AND lands.stakeholder_id = auth.uid()
    )
  );

-- === LAND FINANCES TABLE ===
-- Admin bisa CRUD semua data keuangan lahan
CREATE POLICY "land_finances_admin_all" ON land_finances
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  );

-- Stakeholder bisa SELECT data keuangan lahan miliknya
CREATE POLICY "land_finances_stakeholder_select" ON land_finances
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM lands 
      WHERE lands.id = land_finances.land_id 
        AND lands.stakeholder_id = auth.uid()
    )
  );

-- ============================================================
-- LANGKAH 5: TRIGGER — auto update 'updated_at'
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop jika sudah ada lalu buat ulang
DROP TRIGGER IF EXISTS set_updated_at ON harvests;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON harvests
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS set_finances_updated_at ON land_finances;
CREATE TRIGGER set_finances_updated_at
  BEFORE UPDATE ON land_finances
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- LANGKAH 6: TRIGGER — auto-insert ke tabel users saat signup
-- Ini akan otomatis membuat row di tabel 'users' saat 
-- user baru dibuat di Supabase Auth.
-- ============================================================

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

-- Drop jika sudah ada lalu buat ulang
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- LANGKAH 7: Supabase Storage untuk Foto Lahan
-- ============================================================
INSERT INTO storage.buckets (id, name, public) 
VALUES ('land_images', 'land_images', true) 
ON CONFLICT (id) DO NOTHING;

-- RLS untuk Storage object agar admin bisa upload/delete
DROP POLICY IF EXISTS "Public View Land Images" ON storage.objects;
CREATE POLICY "Public View Land Images" ON storage.objects
  FOR SELECT USING (bucket_id = 'land_images');

DROP POLICY IF EXISTS "Admin Insert Land Images" ON storage.objects;
CREATE POLICY "Admin Insert Land Images" ON storage.objects
  FOR INSERT TO authenticated 
  WITH CHECK (bucket_id = 'land_images' AND EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role = 'admin'));

DROP POLICY IF EXISTS "Admin Update Land Images" ON storage.objects;
CREATE POLICY "Admin Update Land Images" ON storage.objects
  FOR UPDATE TO authenticated 
  USING (bucket_id = 'land_images' AND EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role = 'admin'));

DROP POLICY IF EXISTS "Admin Delete Land Images" ON storage.objects;
CREATE POLICY "Admin Delete Land Images" ON storage.objects
  FOR DELETE TO authenticated 
  USING (bucket_id = 'land_images' AND EXISTS (SELECT 1 FROM public.users WHERE users.id = auth.uid() AND users.role = 'admin'));

