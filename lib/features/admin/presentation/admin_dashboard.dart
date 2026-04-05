import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'input_harvest_form.dart';
import 'edit_harvest_form.dart';
import 'manage_lands_page.dart';
import 'manage_accounts_page.dart';
import '../../../core/database/local_db.dart';
import '../../../core/models/models.dart';
import '../../../core/repositories/harvest_repository.dart';
import '../../../core/repositories/land_repository.dart';
import '../../../core/services/export_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  // ── State ──
  List<HarvestModel> _harvests = [];
  List<LandModel> _lands = [];
  Map<String, String> _landNameMap = {};
  bool _isLoading = true;
  bool _isSyncing = false;
  int _pendingCount = 0;

  String _currentUserName = '';
  int _tabIndex = 0;

  // Chart
  String _chartTimeframe = '2 Minggu';
  final List<String> _chartTimeframes = ['Harian', '2 Minggu', '1 Bulan', '3 Bulan'];

  // Monthly total
  late int _selectedMonth;
  late int _selectedYear;

  // History tab filter
  String _histFilter = 'Semua';
  DateTime? _histStart;
  DateTime? _histEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _loadData();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        final d = await Supabase.instance.client.from('users').select('name').eq('id', uid).single();
        if (mounted) setState(() => _currentUserName = d['name'] ?? '');
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _lands = await LandRepository().getAllLands();
      _landNameMap = {for (var l in _lands) l.id: l.name};
      final local = await LocalDatabase.instance.getAllHarvests();
      _pendingCount = local.where((h) => h.syncStatus == 'pending').length;
      List<HarvestModel> server = [];
      try { server = await HarvestRepository().getAllHarvestsFromServer(); } catch (_) {}
      final ids = local.map((h) => h.id).toSet();
      final merged = <HarvestModel>[...local, ...server.where((h) => !ids.contains(h.id))];
      merged.sort((a, b) => b.harvestDate.compareTo(a.harvestDate));
      setState(() { _harvests = merged; _isLoading = false; });
    } catch (e) { setState(() => _isLoading = false); }
  }

  Future<void> _syncData() async {
    setState(() => _isSyncing = true);
    try {
      final n = await HarvestRepository().syncPendingHarvests();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$n data disinkronkan!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal sync: $e')));
    }
    setState(() => _isSyncing = false);
    await _loadData();
  }

  void _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  // ── Helpers ──
  double get _monthTotal => _harvests
      .where((h) => h.harvestDate.month == _selectedMonth && h.harvestDate.year == _selectedYear)
      .fold(0.0, (s, h) => s + h.weightKg);

  String get _monthLabel {
    const m = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agt','Sep','Okt','Nov','Des'];
    return '${m[_selectedMonth - 1]} $_selectedYear';
  }

  List<HarvestModel> get _filteredHistory {
    if (_histStart != null && _histEnd != null) {
      return _harvests.where((h) =>
          h.harvestDate.isAfter(_histStart!.subtract(const Duration(days: 1))) &&
          h.harvestDate.isBefore(_histEnd!.add(const Duration(days: 1)))).toList();
    }
    return List.of(_harvests);
  }

  final _drawerItems = const [
    {'icon': Icons.home_rounded, 'label': 'Beranda'},
    {'icon': Icons.receipt_long_rounded, 'label': 'Histori'},
    {'icon': Icons.terrain_rounded, 'label': 'Lahan'},
    {'icon': Icons.settings_rounded, 'label': 'Pengaturan'},
  ];

  String get _userInitials {
    if (_currentUserName.isEmpty) return 'A';
    final parts = _currentUserName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return parts[0][0].toUpperCase();
  }

  Widget _buildSidebarContent(DColors c) {
    return SafeArea(
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF0891B2)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Row(children: [
            // Avatar with initials
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
              ),
              child: Center(child: Text(_userInitials,
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_currentUserName.isEmpty ? 'Admin' : _currentUserName,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('Administrator', style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
            ])),
          ]),
        ),
        const SizedBox(height: 12),
        // Add harvest button for web
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: AppColors.gradientPrimary,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: ListTile(
              leading: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              title: Text('Input Panen', style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, color: Colors.white, fontSize: 14)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () async {
                final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => const InputHarvestForm()));
                if (r == true) _loadData();
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Nav items with active bar indicator
        ...List.generate(_drawerItems.length, (i) {
          final item = _drawerItems[i];
          final active = _tabIndex == i;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _tabIndex = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary.withOpacity(0.1) : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    // Active bar indicator
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 3, height: active ? 24 : 0,
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: active ? 10 : 13),
                    Icon(item['icon'] as IconData,
                        color: active ? AppColors.primary : c.textMuted, size: 21),
                    const SizedBox(width: 12),
                    Expanded(child: Text(item['label'] as String, style: GoogleFonts.inter(
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? AppColors.primary : c.textPrimary, fontSize: 14))),
                  ]),
                ),
              ),
            ),
          );
        }),
        const Spacer(),
        // Logout
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.rose.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: Icon(Icons.logout_rounded, color: AppColors.rose, size: 22),
              title: Text('Keluar', style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600, color: AppColors.rose, fontSize: 14)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: _logout,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('Palm Harvest v1.0', style: GoogleFonts.inter(fontSize: 11, color: c.textMuted)),
        ),
      ]),
    );
  }

  Widget _buildDrawer(DColors c) {
    return Drawer(
      backgroundColor: c.surface,
      child: _buildSidebarContent(c),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final titles = ['Dashboard Admin', 'Histori Panen', 'Manajemen Lahan', 'Pengaturan'];

    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= 900;
      final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;
      final isMobile = constraints.maxWidth < 600;

      final mainContent = Scaffold(
        key: isDesktop ? const ValueKey('desktop') : (isTablet ? const ValueKey('tablet') : const ValueKey('mobile')),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: isMobile
              ? Builder(builder: (ctx) => IconButton(
                  icon: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(
                      color: c.surfaceLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border)),
                    child: Icon(Icons.menu_rounded, size: 18, color: c.textSecondary)),
                  onPressed: () => Scaffold.of(ctx).openDrawer()))
              : null,
          title: _tabIndex == 0
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Halo, ${_currentUserName.isEmpty ? 'Admin' : _currentUserName} ',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
                  Text('Dashboard Admin', style: GoogleFonts.inter(fontSize: 12, color: c.textMuted)),
                ])
              : Text(titles[_tabIndex]),
          actions: [
            if (_tabIndex == 0) ...[
              if (_isSyncing)
                const Padding(padding: EdgeInsets.all(12),
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
              else
                _appBarAction(
                  icon: Icons.sync_rounded,
                  badge: _pendingCount,
                  highlight: _pendingCount > 0,
                  onTap: _syncData,
                ),
            ],
          ],
        ),
        drawer: isMobile ? _buildDrawer(c) : null,
        body: SafeArea(
          child: _isLoading
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(), const SizedBox(height: 16),
                  Text('Memuat data...', style: GoogleFonts.inter(color: c.textMuted)),
                ]))
              : IndexedStack(index: _tabIndex, children: [
                  _homeTab(isDesktop), _historyTab(), _landsTab(), _settingsTab(),
                ]),
        ),
        floatingActionButton: (isMobile || isTablet) ? Container(
          decoration: BoxDecoration(
            gradient: AppColors.gradientPrimary, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: FloatingActionButton(
            backgroundColor: Colors.transparent, elevation: 0,
            onPressed: () async {
              final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => const InputHarvestForm()));
              if (r == true) _loadData();
            },
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ) : null,
        floatingActionButtonLocation: isMobile ? FloatingActionButtonLocation.centerDocked : null,
        bottomNavigationBar: isMobile ? _buildBottomBar(c) : null,
      );

      if (isDesktop) {
        return Scaffold(
          backgroundColor: c.surfaceLight,
          body: Row(children: [
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(right: BorderSide(color: c.border)),
              ),
              child: _buildSidebarContent(c),
            ),
            Expanded(child: mainContent),
          ]),
        );
      } else if (isTablet) {
        return Scaffold(
          backgroundColor: c.surfaceLight,
          body: Row(children: [
            Container(
              decoration: BoxDecoration(color: c.surface, border: Border(right: BorderSide(color: c.border))),
              child: NavigationRail(
                backgroundColor: c.surface,
                selectedIndex: _tabIndex,
                onDestinationSelected: (i) => setState(() => _tabIndex = i),
                labelType: NavigationRailLabelType.all,
                selectedLabelTextStyle: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11),
                unselectedLabelTextStyle: GoogleFonts.inter(color: c.textMuted, fontWeight: FontWeight.w500, fontSize: 11),
                destinations: _drawerItems.map((item) => NavigationRailDestination(
                  icon: Icon(item['icon'] as IconData, color: c.textMuted),
                  selectedIcon: Icon(item['icon'] as IconData, color: AppColors.primary),
                  label: Text(item['label'] as String),
                )).toList(),
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: IconButton(
                        icon: const Icon(Icons.logout_rounded, color: AppColors.rose),
                        onPressed: _logout,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: mainContent),
          ]),
        );
      }

      return mainContent;
    });
  }

  Widget _appBarAction({required IconData icon, int badge = 0, bool highlight = false, required VoidCallback onTap}) {
    final c = context.dc;
    return Padding(padding: const EdgeInsets.only(right: 8), child: IconButton(
      icon: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(
        color: highlight ? AppColors.amber.withOpacity(0.15) : c.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: highlight ? AppColors.amber.withOpacity(0.3) : c.border),
      ), child: Badge(isLabelVisible: badge > 0, label: Text('$badge', style: const TextStyle(fontSize: 9)),
          backgroundColor: AppColors.amber, child: Icon(icon, size: 18,
          color: highlight ? AppColors.amber : c.textSecondary))),
      onPressed: onTap,
    ));
  }

  // ════════════════════════════════════════════════════════════════
  // BOTTOM BAR
  // ════════════════════════════════════════════════════════════════
  Widget _buildBottomBar(DColors c) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(height: 60, child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(0, Icons.home_rounded, 'Beranda', c),
          _navItem(1, Icons.receipt_long_rounded, 'Histori', c),
          const SizedBox(width: 48),
          _navItem(2, Icons.terrain_rounded, 'Lahan', c),
          _navItem(3, Icons.settings_rounded, 'Lainnya', c),
        ],
      )),
    );
  }

  Widget _navItem(int idx, IconData icon, String label, DColors c) {
    final active = _tabIndex == idx;
    return Expanded(child: InkWell(
      onTap: () => setState(() => _tabIndex = idx),
      borderRadius: BorderRadius.circular(12),
      child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 22, color: active ? AppColors.primary : c.textMuted),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppColors.primary : c.textMuted)),
      ]),
    ));
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 0 – HOME
  // ════════════════════════════════════════════════════════════════
  Widget _homeTab(bool isDesktop) {
    final c = context.dc;
    final recentHarvests = _harvests.take(6).toList();
    return RefreshIndicator(
      color: AppColors.primary, backgroundColor: c.surface,
      onRefresh: _loadData,
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 16, 8, isDesktop ? 24 : 16, 100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_pendingCount > 0) ...[_syncBanner(c), const SizedBox(height: 16)],
            // Stats — 4 columns on desktop, 3 on mobile
            if (isDesktop)
              Row(children: [
                Expanded(child: _statCard(Icons.scale_rounded, '${_monthTotal.toStringAsFixed(1)}', 'KG',
                    _selectedMonth == DateTime.now().month && _selectedYear == DateTime.now().year ? 'Bulan Ini' : _monthLabel,
                    AppColors.gradientPrimary, onTap: _showMonthPicker, chevron: true)),
                const SizedBox(width: 12),
                Expanded(child: _statCard(Icons.list_alt_rounded, '${_harvests.length}', null, 'Total Data', AppColors.gradientViolet)),
                const SizedBox(width: 12),
                Expanded(child: _statCard(Icons.terrain_rounded, '${_lands.length}', null, 'Jumlah Lahan',
                    const LinearGradient(colors: [AppColors.cyan, Color(0xFF38BDF8)]))),
                const SizedBox(width: 12),
                Expanded(child: _statCard(Icons.cloud_upload_rounded, '$_pendingCount', null, 'Pending',
                    _pendingCount > 0 ? AppColors.gradientAmber : LinearGradient(colors: [c.textMuted, c.textMuted]))),
              ])
            else
              Row(children: [
                Expanded(child: _statCard(Icons.scale_rounded, '${_monthTotal.toStringAsFixed(1)}', 'KG',
                    _selectedMonth == DateTime.now().month && _selectedYear == DateTime.now().year ? 'Bulan Ini' : _monthLabel,
                    AppColors.gradientPrimary, onTap: _showMonthPicker, chevron: true)),
                const SizedBox(width: 10),
                Expanded(child: _statCard(Icons.list_alt_rounded, '${_harvests.length}', null, 'Total Data', AppColors.gradientViolet)),
                const SizedBox(width: 10),
                Expanded(child: _statCard(Icons.cloud_upload_rounded, '$_pendingCount', null, 'Pending',
                    _pendingCount > 0 ? AppColors.gradientAmber : LinearGradient(colors: [c.textMuted, c.textMuted]))),
              ]),
            const SizedBox(height: 24),
            
            // Charts (Responsive row for desktop)
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _sectionTitle('Tren Panen'),
                              SizedBox(width: 280, child: _timeframePills(c)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _harvests.isEmpty ? _empty('Belum ada data', Icons.show_chart_rounded) : _lineChart(c),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: c.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle('Distribusi per Lahan'),
                          const SizedBox(height: 16),
                          _harvests.isEmpty ? _empty('Belum ada data', Icons.pie_chart_outline_rounded) : _pieChart(c),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              _sectionTitle('Tren Panen'),
              const SizedBox(height: 12),
              _timeframePills(c),
              const SizedBox(height: 12),
              _harvests.isEmpty ? _empty('Belum ada data', Icons.show_chart_rounded) : _lineChart(c),
              const SizedBox(height: 24),
              _sectionTitle('Distribusi per Lahan'),
              const SizedBox(height: 12),
              _harvests.isEmpty ? _empty('Belum ada data', Icons.pie_chart_outline_rounded) : _pieChart(c),
            ],

            const SizedBox(height: 24),
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 1, child: _exportBtn(c)),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          _sectionTitle('Histori Terkini'),
                          TextButton(onPressed: () => setState(() => _tabIndex = 1), child: const Text('Semua →')),
                        ]),
                        const SizedBox(height: 8),
                        if (recentHarvests.isEmpty) _empty('Belum ada data', Icons.inbox_rounded)
                        else _desktopHarvestGrid(recentHarvests, c),
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              _exportBtn(c),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _sectionTitle('Histori Terkini'),
                TextButton(onPressed: () => setState(() => _tabIndex = 1), child: const Text('Semua →')),
              ]),
              const SizedBox(height: 8),
              if (_harvests.isEmpty) _empty('Belum ada data', Icons.inbox_rounded)
              else ..._harvests.take(5).map((h) => _harvestCard(h, c)),
            ],
          ]),
        ),
      )),
    );
  }

  Widget _desktopHarvestGrid(List<HarvestModel> items, DColors c) {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: items.map((h) => SizedBox(
        width: 320,
        child: _harvestCard(h, c),
      )).toList(),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 1 – HISTORY
  // ════════════════════════════════════════════════════════════════
  Widget _historyTab() {
    final c = context.dc;
    final filters = ['Semua', '7 Hari', '1 Bulan', '3 Bulan', '6 Bulan', '1 Tahun', 'Kustom'];
    final filtered = _filteredHistory;
    final total = filtered.fold(0.0, (s, h) => s + h.weightKg);

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 700;
      return Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.border))),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              isWide
                  ? Wrap(spacing: 6, runSpacing: 6,
                      children: filters.map((f) {
                        final sel = _histFilter == f;
                        return GestureDetector(
                          onTap: () => _applyHistFilter(f),
                          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: sel ? AppColors.gradientPrimary : null,
                              color: sel ? null : c.surfaceLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sel ? Colors.transparent : c.border)),
                            child: Text(f, style: GoogleFonts.inter(fontSize: 12,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                color: sel ? Colors.white : c.textMuted))));
                      }).toList())
                  : SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
                      children: filters.map((f) {
                        final sel = _histFilter == f;
                        return Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
                          onTap: () => _applyHistFilter(f),
                          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              gradient: sel ? AppColors.gradientPrimary : null,
                              color: sel ? null : c.surfaceLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sel ? Colors.transparent : c.border)),
                            child: Text(f, style: GoogleFonts.inter(fontSize: 12,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                color: sel ? Colors.white : c.textMuted)))));
                      }).toList())),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Text(
                  _histStart != null && _histEnd != null
                      ? '${DateFormat('dd MMM yyyy').format(_histStart!)} — ${DateFormat('dd MMM yyyy').format(_histEnd!)}'
                      : 'Semua waktu',
                  style: GoogleFonts.inter(fontSize: 12, color: c.textMuted))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('${filtered.length} data • ${total.toStringAsFixed(1)} KG',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
              ]),
            ]),
          )),
        ),
        Expanded(child: filtered.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.inbox_rounded, size: 56, color: c.textMuted), const SizedBox(height: 12),
                Text('Tidak ada data pada periode ini', style: GoogleFonts.inter(color: c.textMuted)),
              ]))
            : Center(child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: isWide
                    ? GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: constraints.maxWidth >= 1000 ? 2 : 1,
                          mainAxisSpacing: 8, crossAxisSpacing: 12, mainAxisExtent: 80),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _harvestCard(filtered[i], c))
                    : ListView.builder(padding: const EdgeInsets.all(16), itemCount: filtered.length,
                        itemBuilder: (_, i) => _harvestCard(filtered[i], c)),
              ))),
      ]);
    });
  }

  void _applyHistFilter(String f) {
    setState(() {
      _histFilter = f;
      final now = DateTime.now();
      switch (f) {
        case 'Semua': _histStart = null; _histEnd = null; break;
        case '7 Hari': _histStart = now.subtract(const Duration(days: 7)); _histEnd = now; break;
        case '1 Bulan': _histStart = DateTime(now.year, now.month - 1, now.day); _histEnd = now; break;
        case '3 Bulan': _histStart = DateTime(now.year, now.month - 3, now.day); _histEnd = now; break;
        case '6 Bulan': _histStart = now.subtract(const Duration(days: 180)); _histEnd = now; break;
        case '1 Tahun': _histStart = now.subtract(const Duration(days: 365)); _histEnd = now; break;
        case 'Kustom': _pickHistDateRange(); return;
      }
    });
  }

  Future<void> _pickHistDateRange() async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(),
      initialDateRange: _histStart != null && _histEnd != null
          ? DateTimeRange(start: _histStart!, end: _histEnd!)
          : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()),
      builder: (ctx, child) => Theme(data: Theme.of(ctx), child: child!));
    if (picked != null) setState(() { _histStart = picked.start; _histEnd = picked.end; _histFilter = 'Kustom'; });
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 2 – LANDS
  // ════════════════════════════════════════════════════════════════
  Widget _landsTab() {
    final c = context.dc;
    Widget landCard(LandModel l) {
      final total = _harvests.where((h) => h.landId == l.id).fold(0.0, (s, h) => s + h.weightKg);
      return Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border)),
        child: Row(children: [
          Container(width: 4, height: 40, decoration: BoxDecoration(
              color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: c.textPrimary)),
            const SizedBox(height: 4),
            Text('${l.sizeHectares} Ha', style: GoogleFonts.inter(fontSize: 12, color: c.textMuted)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(total.toStringAsFixed(1), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: c.textPrimary)),
            Text('KG', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: c.textMuted)),
          ]),
        ]),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 700;
      return Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Row(children: [
            Expanded(child: Text('${_lands.length} lahan terdaftar', style: GoogleFonts.inter(color: c.textMuted, fontSize: 13))),
            TextButton.icon(icon: const Icon(Icons.open_in_new_rounded, size: 16), label: const Text('Kelola'),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageLandsPage())).then((_) => _loadData())),
          ]),
        ))),
        Expanded(child: _lands.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.terrain_rounded, size: 56, color: c.textMuted), const SizedBox(height: 12),
                Text('Belum ada lahan', style: GoogleFonts.inter(color: c.textMuted)),
              ]))
            : Center(child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: isWide
                    ? GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: constraints.maxWidth >= 1000 ? 3 : 2,
                          mainAxisSpacing: 10, crossAxisSpacing: 12, mainAxisExtent: 78),
                        itemCount: _lands.length,
                        itemBuilder: (_, i) => landCard(_lands[i]))
                    : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _lands.length,
                        itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 8), child: landCard(_lands[i]))),
              ))),
      ]);
    });
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 3 – SETTINGS
  // ════════════════════════════════════════════════════════════════
  Widget _settingsTab() {
    final c = context.dc;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(children: [
        // Theme toggle
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
            color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(
                gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(10)),
              child: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, size: 20, color: Colors.white)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Tema Aplikasi', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: c.textPrimary)),
              Text(isDark ? 'Mode Gelap' : 'Mode Terang', style: GoogleFonts.inter(fontSize: 12, color: c.textMuted)),
            ])),
            Switch(value: isDark, activeColor: AppColors.primary,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle()),
          ]),
        ),
        const SizedBox(height: 12),
        _settingTile(c, Icons.people_outline_rounded, 'Manajemen Akun', 'Kelola user & role', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageAccountsPage()));
        }),
        _settingTile(c, Icons.download_rounded, 'Export Rekapitulasi', 'PDF atau Excel', () => _showExportDialog()),
        _settingTile(c, Icons.delete_sweep_rounded, 'Hapus Data Offline', null, _showClearConfirm, color: AppColors.amber),
        const SizedBox(height: 24),
        _settingTile(c, Icons.logout_rounded, 'Keluar', null, _logout, color: AppColors.rose),
      ]),
    )));
  }

  Widget _settingTile(DColors c, IconData icon, String title, String? sub, VoidCallback onTap, {Color? color}) {
    return Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(
        color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(
            color: (color ?? AppColors.primary).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: color ?? c.textSecondary)),
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14,
            color: color ?? c.textPrimary)),
        subtitle: sub != null ? Text(sub) : null,
        trailing: Icon(Icons.chevron_right_rounded, color: c.textMuted),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
  }

  // ════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ════════════════════════════════════════════════════════════════
  Widget _sectionTitle(String t) => Text(t, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: context.dc.textPrimary));

  Widget _statCard(IconData icon, String val, String? unit, String label, LinearGradient grad,
      {VoidCallback? onTap, bool chevron = false}) {
    final c = context.dc;
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: grad, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: Colors.white)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Flexible(child: Text(val, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: c.textPrimary),
              overflow: TextOverflow.ellipsis)),
          if (unit != null) ...[const SizedBox(width: 2), Padding(padding: const EdgeInsets.only(bottom: 2),
            child: Text(unit, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: c.textMuted)))],
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: c.textMuted), overflow: TextOverflow.ellipsis)),
          if (chevron) Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: c.textMuted),
        ]),
      ])));
  }

  Widget _timeframePills(DColors c) => Container(padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
    child: Row(children: _chartTimeframes.map((tf) {
      final a = tf == _chartTimeframe;
      return Expanded(child: GestureDetector(onTap: () => setState(() => _chartTimeframe = tf),
        child: AnimatedContainer(duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(gradient: a ? AppColors.gradientPrimary : null, borderRadius: BorderRadius.circular(9)),
          child: Text(tf, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12,
              fontWeight: a ? FontWeight.w700 : FontWeight.w500, color: a ? Colors.white : c.textMuted)))));
    }).toList()));

  Widget _syncBanner(DColors c) => Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: AppColors.amber.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withOpacity(0.2))),
    child: Row(children: [
      Icon(Icons.cloud_off_rounded, color: AppColors.amber, size: 16), const SizedBox(width: 10),
      Expanded(child: Text('$_pendingCount data menunggu sync', style: GoogleFonts.inter(color: AppColors.amber, fontWeight: FontWeight.w500, fontSize: 13))),
      TextButton(onPressed: _isSyncing ? null : _syncData, child: Text('SYNC', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.amber))),
    ]));

  Widget _empty(String t, IconData i) => Container(width: double.infinity, padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(color: context.dc.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.dc.border)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(i, size: 40, color: context.dc.textMuted), const SizedBox(height: 12),
      Text(t, style: GoogleFonts.inter(color: context.dc.textMuted, fontSize: 14)),
    ]));

  Widget _exportBtn(DColors c) => Container(width: double.infinity,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: c.borderLight)),
    child: Material(color: c.surface, borderRadius: BorderRadius.circular(14),
      child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () => _showExportDialog(),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.download_rounded, color: AppColors.primary, size: 20), const SizedBox(width: 8),
            Text('Export Rekapitulasi', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14)),
          ])))));

  Widget _harvestCard(HarvestModel h, DColors c) {
    final name = _landNameMap[h.landId] ?? h.landName ?? h.landId;
    final pending = h.syncStatus == 'pending';
    final accent = pending ? AppColors.amber : AppColors.primary;
    return Container(margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(14),
        child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () => _showDetail(h),
          child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
            Container(width: 4, height: 44, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: c.textPrimary)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.calendar_today_rounded, size: 11, color: c.textMuted), const SizedBox(width: 4),
                Text(DateFormat('dd MMM yyyy').format(h.harvestDate), style: GoogleFonts.inter(fontSize: 11, color: c.textMuted)),
                if (pending) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text('PENDING', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.amber)))],
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${h.weightKg}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: c.textPrimary)),
              Text('KG', style: GoogleFonts.inter(fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(width: 8),
            GestureDetector(onTap: () async {
              final r = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditHarvestForm(harvest: h)));
              if (r == true) _loadData();
            }, child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(
                color: c.surfaceLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.border)),
              child: Icon(Icons.edit_rounded, size: 14, color: c.textSecondary))),
          ])))));
  }

  // ════════════════════════════════════════════════════════════════
  // CHART LOGIC
  // ════════════════════════════════════════════════════════════════
  String _groupKey(DateTime d) {
    switch (_chartTimeframe) {
      case 'Harian': return DateFormat('dd MMM yy').format(d);
      case '2 Minggu': return DateFormat('dd MMM yy').format(_bwStart(d));
      case '1 Bulan': return DateFormat('MMM yyyy').format(d);
      case '3 Bulan': return 'Q${((d.month - 1) ~/ 3) + 1} ${d.year}';
      default: return DateFormat('dd MMM yy').format(d);
    }
  }
  DateTime _sortKey(DateTime d) {
    switch (_chartTimeframe) {
      case 'Harian': return DateTime(d.year, d.month, d.day);
      case '2 Minggu': return _bwStart(d);
      case '1 Bulan': return DateTime(d.year, d.month);
      case '3 Bulan': return DateTime(d.year, ((d.month - 1) ~/ 3) * 3 + 1);
      default: return DateTime(d.year, d.month, d.day);
    }
  }
  DateTime _bwStart(DateTime d) {
    final e = DateTime(2020, 1, 6); final ds = d.difference(e).inDays;
    return e.add(Duration(days: ds - (ds % 14)));
  }

  Widget _lineChart(DColors c) {
    final Map<DateTime, _CB> bk = {};
    for (var h in _harvests) { final sk = _sortKey(h.harvestDate); final lb = _groupKey(h.harvestDate);
      bk.putIfAbsent(sk, () => _CB(lb, 0)); bk[sk]!.t += h.weightKg; }
    final sk = bk.keys.toList()..sort();
    final e = sk.map((k) => bk[k]!).toList();
    if (e.isEmpty) return _empty('Tidak ada data', Icons.show_chart_rounded);
    final maxY = e.map((x) => x.t).reduce((a, b) => a > b ? a : b);
    return Container(height: 280, padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      child: LineChart(LineChartData(minY: 0, maxY: maxY * 1.2,
        gridData: FlGridData(show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: c.border, strokeWidth: 1)),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, interval: 1,
            getTitlesWidget: (v, _) { final i = v.toInt(); if (i < 0 || i >= e.length) return const SizedBox();
              final s = e.length > 20 ? 5 : e.length > 10 ? 3 : e.length > 6 ? 2 : 1;
              if (i % s != 0 && i != e.length - 1) return const SizedBox();
              return Padding(padding: const EdgeInsets.only(top: 8), child: Text(e[i].l, style: GoogleFonts.inter(fontSize: 8, color: c.textMuted))); })),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 48,
            getTitlesWidget: (v, _) => Text('${v.toInt()}', style: GoogleFonts.inter(fontSize: 10, color: c.textMuted)))),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => c.surfaceBright, tooltipBorder: BorderSide(color: c.borderLight), tooltipRoundedRadius: 10,
          getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('${e[s.spotIndex].l}\n${s.y.toStringAsFixed(1)} KG',
              GoogleFonts.inter(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 12))).toList())),
        lineBarsData: [LineChartBarData(
          spots: List.generate(e.length, (i) => FlSpot(i.toDouble(), e[i].t)),
          isCurved: true, curveSmoothness: 0.3, gradient: AppColors.gradientPrimary,
          barWidth: 2.5, isStrokeCapRound: true,
          dotData: FlDotData(show: e.length <= 30, getDotPainter: (_, __, ___, ____) =>
              FlDotCirclePainter(radius: 3, color: AppColors.primary, strokeWidth: 2, strokeColor: c.surface)),
          belowBarData: BarAreaData(show: true, gradient: LinearGradient(
              colors: [AppColors.primary.withOpacity(0.15), AppColors.primary.withOpacity(0.0)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        )],
      )));
  }

  Widget _pieChart(DColors c) {
    final Map<String, double> ld = {};
    for (var h in _harvests) { final n = _landNameMap[h.landId] ?? h.landName ?? h.landId; ld[n] = (ld[n] ?? 0) + h.weightKg; }
    if (ld.isEmpty) return _empty('Tidak ada data', Icons.pie_chart_outline_rounded);
    final cls = [AppColors.primary, AppColors.violet, AppColors.amber, AppColors.cyan, AppColors.rose, AppColors.blue, const Color(0xFFF472B6), const Color(0xFF2DD4BF)];
    final en = ld.entries.toList(); final tot = en.fold(0.0, (s, e) => s + e.value);
    return Container(height: 240, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      child: Row(children: [
        Expanded(flex: 3, child: PieChart(PieChartData(sectionsSpace: 2, centerSpaceRadius: 28,
          sections: List.generate(en.length, (i) => PieChartSectionData(value: en[i].value,
            title: '${(en[i].value / tot * 100).toStringAsFixed(0)}%',
            titleStyle: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
            color: cls[i % cls.length], radius: 48))))),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(en.length, (i) => Padding(padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [Container(width: 10, height: 10, decoration: BoxDecoration(
                color: cls[i % cls.length], borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              Expanded(child: Text(en[i].key, style: GoogleFonts.inter(fontSize: 11, color: c.textSecondary), overflow: TextOverflow.ellipsis)),
            ]))))),
      ]));
  }

  // ════════════════════════════════════════════════════════════════
  // DIALOGS
  // ════════════════════════════════════════════════════════════════
  void _showMonthPicker() {
    int tm = _selectedMonth, ty = _selectedYear;
    const mn = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agt','Sep','Okt','Nov','Des'];
    showModalBottomSheet(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, ss) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: context.dc.surfaceBright, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Text('Pilih Bulan & Tahun', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: context.dc.textPrimary)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => ss(() => ty--)),
          Text('$ty', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: context.dc.textPrimary)),
          IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: ty < DateTime.now().year ? () => ss(() => ty++) : null),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: List.generate(12, (i) {
          final m = i + 1; final sel = m == tm; final fut = ty == DateTime.now().year && m > DateTime.now().month;
          return GestureDetector(onTap: fut ? null : () => ss(() => tm = m),
            child: AnimatedContainer(duration: const Duration(milliseconds: 150), width: 58, height: 38, alignment: Alignment.center,
              decoration: BoxDecoration(gradient: sel ? AppColors.gradientPrimary : null, color: sel ? null : context.dc.surfaceLight,
                  borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? Colors.transparent : context.dc.border)),
              child: Text(mn[i], style: GoogleFonts.inter(fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color: fut ? context.dc.textMuted : sel ? Colors.white : context.dc.textSecondary))));
        })),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: Container(
          decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(12)),
          child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
            onPressed: () { setState(() { _selectedMonth = tm; _selectedYear = ty; }); Navigator.pop(ctx); },
            child: const Text('Terapkan')))),
      ]))));
  }

  void _showDetail(HarvestModel h) {
    final c = context.dc; final name = _landNameMap[h.landId] ?? h.landName ?? h.landId;
    showModalBottomSheet(context: context, builder: (ctx) => Padding(padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.surfaceBright, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Text('Detail Panen', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const Divider(height: 24),
        _dr('Lahan', name), _dr('Berat', '${h.weightKg} KG'),
        _dr('Tanggal', DateFormat('dd MMMM yyyy, HH:mm').format(h.harvestDate)),
        _dr('Upload', DateFormat('dd MMMM yyyy, HH:mm').format(h.createdAt)),
        _dr('Status', h.syncStatus == 'pending' ? '⏳ Menunggu' : '✅ Tersinkron'),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: Container(
          decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(12)),
          child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
            icon: const Icon(Icons.edit_rounded), label: const Text('Edit'),
            onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => EditHarvestForm(harvest: h)))
                .then((r) { if (r == true) _loadData(); }); }))),
      ])));
  }
  Widget _dr(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 100, child: Text(l, style: GoogleFonts.inter(color: context.dc.textMuted, fontSize: 13))),
      Expanded(child: Text(v, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: context.dc.textPrimary))),
    ]));

  void _showExportDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Export Rekapitulasi', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _expTile(ctx, Icons.date_range_rounded, '6 Bulan Terakhir', AppColors.cyan, () { Navigator.pop(ctx); _expRange(180, '6 Bulan Terakhir'); }),
        const SizedBox(height: 8),
        _expTile(ctx, Icons.calendar_today_rounded, '1 Tahun Terakhir', AppColors.primary, () { Navigator.pop(ctx); _expRange(365, '1 Tahun Terakhir'); }),
      ])));
  }
  Widget _expTile(BuildContext ctx, IconData i, String t, Color cl, VoidCallback onTap) => Material(
    color: cl.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
    child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [Icon(i, color: cl, size: 20), const SizedBox(width: 12),
          Expanded(child: Text(t, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.dc.textPrimary))),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.dc.textMuted)]))));

  void _expRange(int d, String l) {
    final now = DateTime.now(); final s = now.subtract(Duration(days: d));
    final f = _harvests.where((h) => h.harvestDate.isAfter(s) && h.harvestDate.isBefore(now.add(const Duration(days: 1)))).toList();
    _showFmtDialog(f, l);
  }
  void _showFmtDialog(List<HarvestModel> data, String label) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Format — $label', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _expTile(ctx, Icons.picture_as_pdf_rounded, 'PDF', AppColors.rose, () async { Navigator.pop(ctx);
          try { await ExportService.exportToPDF(context, data, label, _landNameMap); }
          catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'))); } }),
        const SizedBox(height: 8),
        _expTile(ctx, Icons.table_chart_rounded, 'Excel', AppColors.primary, () async { Navigator.pop(ctx);
          try { await ExportService.exportToExcel(data, label, _landNameMap);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File Excel diunduh!')));
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'))); } }),
      ])));
  }
  void _showClearConfirm() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Hapus Data Offline?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      content: Text('Data lokal akan dihapus. Data di server tidak terpengaruh.', style: GoogleFonts.inter(color: context.dc.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        Container(decoration: BoxDecoration(gradient: AppColors.gradientRose, borderRadius: BorderRadius.circular(10)),
          child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
            onPressed: () async { Navigator.pop(ctx); await LocalDatabase.instance.clearDatabase();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data offline dihapus')));
              _loadData(); }, child: const Text('Hapus'))),
      ]));
  }
}

class _CB { final String l; double t; _CB(this.l, this.t); }
