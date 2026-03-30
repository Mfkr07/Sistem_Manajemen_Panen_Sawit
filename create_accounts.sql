-- ============================================================
-- BUAT AKUN USER — Jalankan di Supabase SQL Editor
-- ============================================================
-- 
-- PENTING: Supabase Auth TIDAK mengizinkan membuat user via SQL biasa.
-- Anda HARUS membuat user melalui salah satu cara berikut:
--
--   Cara 1 (Paling Mudah): Supabase Dashboard
--     → Authentication → Users → "Add User" → masukkan email & password
--
--   Cara 2 (Via SQL): Gunakan function admin di bawah ini
-- ============================================================

-- ============================================================
-- CARA 2: Buat User via SQL (menggunakan Supabase Admin API)
-- Jalankan query-query di bawah ini SATU PER SATU di SQL Editor
-- ============================================================

-- ┌──────────────────────────────────────────────────────────┐
-- │  AKUN 1: ADMIN                                          │
-- │  Email: admin@sawit.com                                 │
-- │  Password: Admin123!                                    │
-- └──────────────────────────────────────────────────────────┘

-- Langkah 1: Buat auth user
SELECT supabase_admin.create_user(
  '{"email": "admin@sawit.com", "password": "Admin123!", "email_confirm": true}'::jsonb
);

-- Langkah 2: Masukkan ke tabel users dengan role admin
-- (Jika Anda sudah menjalankan trigger handle_new_user di schema.sql, 
--  row ini SUDAH otomatis dibuat. Anda hanya perlu UPDATE role-nya)
UPDATE users 
SET role = 'admin', name = 'Administrator'
WHERE email = 'admin@sawit.com';

-- ┌──────────────────────────────────────────────────────────┐
-- │  AKUN 2: STAKEHOLDER                                    │
-- │  Email: stakeholder@sawit.com                           │
-- │  Password: Stake123!                                    │
-- └──────────────────────────────────────────────────────────┘

SELECT supabase_admin.create_user(
  '{"email": "stakeholder@sawit.com", "password": "Stake123!", "email_confirm": true}'::jsonb
);

UPDATE users 
SET role = 'stakeholder', name = 'Pemilik Lahan 1'
WHERE email = 'stakeholder@sawit.com';


-- ============================================================
-- ALTERNATIF: Jika supabase_admin.create_user() TIDAK tersedia
-- di versi Supabase Anda, gunakan cara DASHBOARD:
-- ============================================================
-- 
-- 1. Buka Supabase Dashboard → Authentication → Users
-- 2. Klik "Add User" → "Create New User"
-- 3. Buat AKUN 1:
--      Email:    admin@sawit.com
--      Password: Admin123!
--      ✅ Auto Confirm User
-- 4. Buat AKUN 2:
--      Email:    stakeholder@sawit.com
--      Password: Stake123!
--      ✅ Auto Confirm User
--
-- 5. Setelah kedua user dibuat, jalankan SQL berikut untuk set role:
-- ============================================================

-- Jika trigger handle_new_user sudah aktif, data sudah masuk otomatis.
-- Tinggal update role dan nama:

UPDATE users SET role = 'admin', name = 'Administrator' 
WHERE email = 'admin@sawit.com';

UPDATE users SET role = 'stakeholder', name = 'Pemilik Lahan 1' 
WHERE email = 'stakeholder@sawit.com';


-- ============================================================
-- VERIFIKASI: Cek apakah data sudah benar
-- ============================================================

SELECT id, email, name, role, created_at FROM users;
