# 🎨 Design System

## Daftar Isi
1. [Filosofi Desain](#filosofi-desain)
2. [Palet Warna](#palet-warna)
3. [Tipografi](#tipografi)
4. [Breakpoint & Layout Responsif](#breakpoint--layout-responsif)
5. [Komponen UI](#komponen-ui)
6. [Dark/Light Mode](#darklight-mode)

---

## Filosofi Desain

Palm Harvest mengadopsi pendekatan desain **premium fintech-inspired** dengan prinsip utama:

- **Glassmorphism & Gradients** — Kartu dan elemen penting menggunakan gradient serta efek transparan
- **Minimal & Bersih** — Penggunaan whitespace yang konsisten dan tipografi Inter yang modern
- **Theme-Aware** — Semua komponen otomatis menyesuaikan diri dengan mode terang/gelap
- **Mobile-First, Desktop-Enhanced** — UI dasar dirancang untuk mobile, lalu diperkaya untuk desktop

---

## Palet Warna

### Warna Aksen (Sama di Light & Dark)

| Nama | Hex | Penggunaan |
|------|-----|------------|
| **Primary** | `#34D399` | Tombol utama, indikator aktif, chart |
| **Primary Dark** | `#10B981` | Hover/pressed state |
| **Primary Light** | `#6EE7B7` | Background ringan |
| **Cyan** | `#06B6D4` | Stat card, icon admin, accent sekunder |
| **Violet** | `#8B5CF6` | Stakeholder accent, sidebar aktif |
| **Violet Light** | `#A78BFA` | Gradient kedua violet |
| **Amber** | `#F59E0B` | Warning, stat card ketiga |
| **Rose** | `#F43F5E` | Delete, logout, error |
| **Blue** | `#3B82F6` | Info, link |

### Gradient Presets

| Nama | Warna | Penggunaan |
|------|-------|------------|
| `gradientPrimary` | `#34D399` → `#06B6D4` | Tombol utama, sidebar aktif (admin), stat cards |
| `gradientViolet` | `#8B5CF6` → `#A78BFA` | Sidebar aktif (stakeholder), profil icon |
| `gradientAmber` | `#F59E0B` → `#FBBF24` | Stat card rata-rata |
| `gradientRose` | `#F43F5E` → `#FB7185` | Tombol hapus |

### Warna Surface (Tergantung Tema)

#### Dark Mode (`DColors.dark`)
| Property | Hex | Penggunaan |
|----------|-----|------------|
| `bg` | `#0B0F19` | Background utama scaffold |
| `surface` | `#141925` | Card, AppBar, dialog |
| `surfaceLight` | `#1C2333` | Input field, chip |
| `surfaceBright` | `#232B3E` | Elevated surface |
| `textPrimary` | `#F1F5F9` | Judul, teks utama |
| `textSecondary` | `#94A3B8` | Subtitle, deskripsi |
| `textMuted` | `#64748B` | Hint, label ringan |
| `border` | `#FFFFFF14` | Border kartu & input |

#### Light Mode (`DColors.light`)
| Property | Hex | Penggunaan |
|----------|-----|------------|
| `bg` | `#F8FAFC` | Background utama scaffold |
| `surface` | `#FFFFFF` | Card, AppBar, dialog |
| `surfaceLight` | `#F1F5F9` | Input field, chip |
| `surfaceBright` | `#E2E8F0` | Elevated surface |
| `textPrimary` | `#0F172A` | Judul, teks utama |
| `textSecondary` | `#475569` | Subtitle, deskripsi |
| `textMuted` | `#94A3B8` | Hint, label ringan |
| `border` | `#E2E8F0` | Border kartu & input |

### Cara Akses di Kode
```dart
// Aksen (statis, sama di semua tema)
AppColors.primary     // #34D399
AppColors.rose        // #F43F5E
AppColors.gradientPrimary

// Surface (dinamis, berubah sesuai tema)
final c = context.dc;  // Extension method
c.surface       // Warna card
c.textPrimary   // Warna teks utama
c.border        // Warna border
```

---

## Tipografi

**Font Family:** [Inter](https://fonts.google.com/specimen/Inter) (Google Fonts)

| Elemen | Size | Weight | Contoh Penggunaan |
|--------|------|--------|-------------------|
| Display Large | - | Bold | - |
| Title Large | 20px | W600 | AppBar title |
| Title Medium | 16px | W600 | Section header |
| Body Large | 14px | W400 | Konten utama |
| Body Medium | 14px | W400 | Deskripsi |
| Body Small | 12px | W400 | Timestamp, label |
| Label Large | 14px | W600 | Tombol |

### Penggunaan di Kode
```dart
GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)
```

---

## Breakpoint & Layout Responsif

### Tabel Breakpoint

| Breakpoint | Range | Layout | Navigasi |
|------------|-------|--------|----------|
| **Mobile** | < 600px | Single column, full-width | BottomNavigationBar + Drawer (burger menu) |
| **Tablet** | 600px – 899px | Adaptive | NavigationRail (icon-only sidebar) |
| **Desktop** | ≥ 900px | Multi-column, sidebar | Permanent Sidebar (280px wide) |

### Implementasi di Kode
```dart
return LayoutBuilder(builder: (context, constraints) {
  final isDesktop = constraints.maxWidth >= 900;
  final isTablet  = constraints.maxWidth >= 600 && constraints.maxWidth < 900;
  final isMobile  = constraints.maxWidth < 600;
  
  // ... conditional layout
});
```

### Pola Layout Per Halaman

#### Login Page
| Mobile | Desktop (≥ 900px) |
|--------|-------------------|
| Centered card dengan gradient background | Split-screen: branding panel (kiri) + form card (kanan) |

#### Dashboard (Admin & Stakeholder)
| Elemen | Mobile | Tablet | Desktop |
|--------|--------|--------|---------|
| Navigasi | BottomNav + Drawer | NavigationRail | Permanent Sidebar |
| Stat Cards | 3 kolom | 3 kolom | 4 kolom |
| Chart + Histori | Stacked vertikal | Stacked vertikal | Row (5:3 flex) |
| Data Grid | ListView 1 kolom | ListView 1 kolom | GridView 2-3 kolom |

#### Form Pages
| Mobile | Desktop |
|--------|---------|
| Full-width form | Centered card (maxWidth: 560px) |

#### Manajemen (Lahan & Akun)
| Mobile | Desktop |
|--------|---------|
| ListView 1 kolom | GridView 2-3 kolom (maxWidth: 1200px) |

### Content Max Width
- **Dashboard content:** `maxWidth: 1400px`
- **Forms:** `maxWidth: 560px`
- **Management grids:** `maxWidth: 1200px`
- **Profile/Settings:** `maxWidth: 600px`

---

## Komponen UI

### Stat Card
```
┌─────────────────────┐
│ [Gradient Icon]      │
│ 1,250.0 KG          │  ← Value + Unit
│ Bulan Ini        ▸  │  ← Label + optional chevron
└─────────────────────┘
```
- Background: gradient (via `LinearGradient`)
- Icon: rounded with white color
- Interactive: optional `onTap` + chevron indicator

### Sidebar (Desktop)
```
┌──────────────────────┐
│ [Avatar] Nama User   │  ← Gradient header + initials
│          email@...   │
├──────────────────────┤
│ ▌ 🏠 Beranda         │  ← Active: bar + highlight
│   📋 Histori         │  ← Inactive: normal
│   🌿 Lahan           │
│   ⚙️ Pengaturan      │
│                      │
│ ┌──────────────────┐ │
│ │ 🚪 Keluar        │ │  ← Rose accent
│ └──────────────────┘ │
│ Palm Harvest v1.0    │  ← Version footer
└──────────────────────┘
```

### Land Card
```
┌────────────────────────────────────┐
│ [🌿 Gradient]  Nama Lahan    [⋮]  │  ← PopupMenu (Edit/Hapus)
│                2.5 Ha              │
│                Pemilik: John       │
└────────────────────────────────────┘
```

### Harvest Card (History)
```
┌───────────────────────────────────────┐
│ [Gradient Strip]  Lahan Utara        │
│                   20 Apr 2026        │
│                              150 KG  │
└───────────────────────────────────────┘
```

---

## Dark/Light Mode

### Switching
- Disimpan di `SharedPreferences` dengan key `'isDarkMode'`
- Default: **Dark Mode**
- Toggle via `ref.read(themeModeProvider.notifier).toggle()`
- Tersedia di halaman Pengaturan (Admin) dan Profil (Stakeholder)

### Implementasi
```dart
// Di MaterialApp
MaterialApp.router(
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: ref.watch(themeModeProvider),  // Reactive
  ...
);

// Di widget mana saja
final c = context.dc;  // Mendapatkan DColors yang sesuai tema aktif
Container(
  color: c.surface,       // Otomatis putih (light) atau gelap (dark)
  child: Text('Hello', 
    style: TextStyle(color: c.textPrimary)),  // Otomatis menyesuaikan
);
```

### Elemen yang Berubah
| Elemen | Light | Dark |
|--------|-------|------|
| Scaffold | `#F8FAFC` (abu sangat terang) | `#0B0F19` (biru tua gelap) |
| Card | `#FFFFFF` | `#141925` |
| Text | `#0F172A` (gelap) | `#F1F5F9` (terang) |
| Border | `#E2E8F0` | `rgba(255,255,255,0.08)` |
| Input Fill | `#F1F5F9` | `#1C2333` |

### Elemen yang TIDAK Berubah
- Semua warna aksen (`AppColors.*`) tetap sama
- Gradient tombol
- Ikon dalam gradient card
- Warna chart line/bar
