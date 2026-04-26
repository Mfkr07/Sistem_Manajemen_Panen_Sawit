import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'input_harvest_form.dart';
import 'edit_harvest_form.dart';
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
  List<UserModel> _stakeholders = [];
  List<LandFinanceModel> _finances = [];
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
  int _historyViewIndex = 0; // 0 for Panen, 1 for Rekapitulasi
  String _histFilter = 'Semua';
  DateTime? _histStart;
  DateTime? _histEnd;
  String? _histLandFilter;
  
  // Rekapitulasi filter
  int? _rekapFilterMonth;
  int? _rekapFilterYear;

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
      _stakeholders = await LandRepository().getAllStakeholders();
      _landNameMap = {for (var l in _lands) l.id: l.name};
      final local = await LocalDatabase.instance.getAllHarvests();
      _pendingCount = local.where((h) => h.syncStatus == 'pending').length;
      List<HarvestModel> server = [];
      try { server = await HarvestRepository().getAllHarvestsFromServer(); } catch (_) {}
      final ids = local.map((h) => h.id).toSet();
      final merged = <HarvestModel>[...local, ...server.where((h) => !ids.contains(h.id))];
      merged.sort((a, b) => b.harvestDate.compareTo(a.harvestDate));
      
      // Load finances
      final localFin = await LocalDatabase.instance.getAllFinances();
      _pendingCount += localFin.where((f) => f.syncStatus == 'pending').length;
      List<LandFinanceModel> serverFin = [];
      try { serverFin = await LandRepository().getAllFinancesFromServer(); } catch (_) {}
      final finIds = localFin.map((f) => f.id).toSet();
      final mergedFin = <LandFinanceModel>[...localFin, ...serverFin.where((f) => !finIds.contains(f.id))];

      setState(() { 
        _harvests = merged; 
        _finances = mergedFin;
        _isLoading = false; 
      });
    } catch (e) { setState(() => _isLoading = false); }
  }

  Future<void> _syncData() async {
    setState(() => _isSyncing = true);
    try {
      final n1 = await HarvestRepository().syncPendingHarvests();
      final n2 = await LandRepository().syncPendingFinances();
      final total = n1 + n2;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$total data disinkronkan!')));
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
    List<HarvestModel> result = _harvests;
    if (_histLandFilter != null) {
      result = result.where((h) => h.landId == _histLandFilter).toList();
    }
    if (_histStart != null && _histEnd != null) {
      return result.where((h) =>
          h.harvestDate.isAfter(_histStart!.subtract(const Duration(days: 1))) &&
          h.harvestDate.isBefore(_histEnd!.add(const Duration(days: 1)))).toList();
    }
    return result.toList();
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
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
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
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
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
                    color: active ? AppColors.primary.withValues(alpha: 0.1) : null,
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
              color: AppColors.rose.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.rose, size: 22),
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
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
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
        color: highlight ? AppColors.amber.withValues(alpha: 0.15) : c.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlight ? AppColors.amber.withValues(alpha: 0.3) : c.border),
      ), child: Badge(isLabelVisible: badge > 0, label: Text(badge.toString(), style: const TextStyle(fontSize: 9)),
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
                Expanded(child: _statCard(Icons.scale_rounded, _monthTotal.toStringAsFixed(1), 'KG',
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
                Expanded(child: _statCard(Icons.scale_rounded, _monthTotal.toStringAsFixed(1), 'KG',
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
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 700;
      return Column(children: [
        // --- Segemented Toggle ---
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.border))),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Container(
              decoration: BoxDecoration(color: c.surfaceLight, borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.all(4),
              child: Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _historyViewIndex = 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _historyViewIndex == 0 ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text('Histori Panen', style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: _historyViewIndex == 0 ? Colors.white : c.textMuted)),
                  ),
                )),
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _historyViewIndex = 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _historyViewIndex == 1 ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Text('Histori Rekapitulasi', style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: _historyViewIndex == 1 ? Colors.white : c.textMuted)),
                  ),
                )),
              ]),
            ),
          )),
        ),
        // --- Tab Content ---
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: _historyViewIndex == 0 
                ? KeyedSubtree(key: const ValueKey('panen'), child: _historyPanenView(isWide, c))
                : KeyedSubtree(key: const ValueKey('rekap'), child: _historyRekapView(isWide, c)),
          ),
        ),
      ]);
    });
  }

  Widget _historyPanenView(bool isWide, DColors c) {
    final filters = ['Semua', '7 Hari', '1 Bulan', '3 Bulan', '6 Bulan', '1 Tahun', 'Kustom'];
    final filtered = _filteredHistory;
    final total = filtered.fold(0.0, (s, h) => s + h.weightKg);

    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.border))),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Pilih Lahan', style: GoogleFonts.inter(fontSize: 12, color: c.textMuted))),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: c.surfaceLight,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _histLandFilter,
                    isExpanded: true,
                    icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: c.textMuted),
                    style: GoogleFonts.inter(fontSize: 12, color: c.textPrimary, fontWeight: FontWeight.w600),
                    dropdownColor: c.surface,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Semua Lahan', overflow: TextOverflow.ellipsis)),
                      ..._lands.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name, overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (val) => setState(() => _histLandFilter = val),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
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
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
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
                        crossAxisCount: isWide ? 2 : 1, // Actually if constraints > 1000 then 2, maybe let's fix it simply
                        mainAxisSpacing: 8, crossAxisSpacing: 12, mainAxisExtent: 96),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _harvestCard(filtered[i], c))
                  : ListView.builder(padding: const EdgeInsets.all(16), itemCount: filtered.length,
                      itemBuilder: (_, i) => _harvestCard(filtered[i], c)),
            ))),
    ]);
  }

  Widget _historyRekapView(bool isWide, DColors c) {
    // Generate available month-year combinations from stored finances
    final availablePeriods = <String>{};
    for (final f in _finances) {
      availablePeriods.add('${f.periodMonth}-${f.periodYear}');
    }
    
    // Sort available periods newest first
    final sortedPeriods = availablePeriods.toList()..sort((a, b) {
      final pA = a.split('-'); final pB = b.split('-');
      if (pA[1] != pB[1]) return int.parse(pB[1]).compareTo(int.parse(pA[1]));
      return int.parse(pB[0]).compareTo(int.parse(pA[0]));
    });

    // Apply Filter
    var filteredFinances = List<LandFinanceModel>.from(_finances);
    if (_rekapFilterMonth != null && _rekapFilterYear != null) {
      filteredFinances = filteredFinances.where((f) => 
          f.periodMonth == _rekapFilterMonth && f.periodYear == _rekapFilterYear).toList();
    }

    // Sort by most recent period
    filteredFinances.sort((a, b) {
      if (a.periodYear != b.periodYear) return b.periodYear.compareTo(a.periodYear);
      return b.periodMonth.compareTo(a.periodMonth);
    });

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];

    return Column(children: [
      // Filter row
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.border))),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Row(children: [
            Expanded(child: Text('Filter Periode Rekapitulasi', style: GoogleFonts.inter(fontSize: 12, color: c.textMuted))),
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: c.surfaceLight,
                border: Border.all(color: c.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _rekapFilterMonth != null && _rekapFilterYear != null 
                      ? '$_rekapFilterMonth-$_rekapFilterYear' 
                      : 'Semua',
                  icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: c.textMuted),
                  style: GoogleFonts.inter(fontSize: 12, color: c.textPrimary, fontWeight: FontWeight.w600),
                  dropdownColor: c.surface,
                  items: [
                    const DropdownMenuItem(value: 'Semua', child: Text('Semua Periode')),
                    ...sortedPeriods.map((p) {
                      final parts = p.split('-');
                      final m = int.parse(parts[0]);
                      final y = int.parse(parts[1]);
                      return DropdownMenuItem(value: p, child: Text('${months[m-1]} $y'));
                    }),
                  ],
                  onChanged: (val) {
                    setState(() {
                      if (val == null || val == 'Semua') {
                        _rekapFilterMonth = null;
                        _rekapFilterYear = null;
                      } else {
                        final parts = val.split('-');
                        _rekapFilterMonth = int.parse(parts[0]);
                        _rekapFilterYear = int.parse(parts[1]);
                      }
                    });
                  },
                ),
              ),
            ),
          ]),
        )),
      ),

      Expanded(child: filteredFinances.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.receipt_long_rounded, size: 56, color: c.textMuted), const SizedBox(height: 12),
              Text('Belum ada histori rekapitulasi pada periode ini', style: GoogleFonts.inter(color: c.textMuted)),
            ]))
          : Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: isWide
                  ? GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 180),
                      itemCount: filteredFinances.length,
                      itemBuilder: (_, i) => _financeHistoryCard(filteredFinances[i], c))
                  : ListView.builder(padding: const EdgeInsets.all(16), itemCount: filteredFinances.length,
                      itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _financeHistoryCard(filteredFinances[i], c))),
            ))),
    ]);
  }

  Widget _financeHistoryCard(LandFinanceModel fin, DColors c) {
    final land = _lands.firstWhere((l) => l.id == fin.landId, orElse: () => LandModel(id: '', name: 'Lahan Tidak Diketahui', stakeholderId: '', sizeHectares: 0, treeCount: 0));
    final mH = _harvests.where((h) => h.landId == fin.landId && h.harvestDate.month == fin.periodMonth && h.harvestDate.year == fin.periodYear).toList();
    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    double totalTonnage = mH.fold(0.0, (s, h) => s + h.weightKg);
    double grossRevenue = totalTonnage * fin.pricePerKg;
    double totalCost = fin.fertilizerCost + fin.workerCost + (fin.pesticideYearlyCost / 12) + (fin.pruningYearlyCost / 12);
    double margin = grossRevenue - totalCost;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.violet.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.request_quote_rounded, color: AppColors.violet, size: 16)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(land.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: c.textPrimary)),
            Text('Bulan ${fin.periodMonth} / Tahun ${fin.periodYear}', style: GoogleFonts.inter(fontSize: 11, color: c.textMuted)),
          ])),
          // Actions
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 18, color: c.textMuted),
            onSelected: (action) async {
              if (action == 'pdf') {
                await ExportService.exportFinanceToPDF(context, land, fin, mH);
              } else if (action == 'excel') {
                await ExportService.exportFinanceToExcel(land, fin, mH);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'pdf', child: Row(children: [const Icon(Icons.picture_as_pdf_rounded, color: AppColors.rose, size: 16), const SizedBox(width: 8), Text('Export PDF', style: GoogleFonts.inter(fontSize: 12))])),
              PopupMenuItem(value: 'excel', child: Row(children: [const Icon(Icons.table_chart_rounded, color: Colors.green, size: 16), const SizedBox(width: 8), Text('Export Excel', style: GoogleFonts.inter(fontSize: 12))])),
            ],
          ),
        ]),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _financeStatItem('Total Panen', '${totalTonnage.toStringAsFixed(1)} KG', c.textMuted, c),
          _financeStatItem('Bruto', fmt.format(grossRevenue), c.textPrimary, c),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _financeStatItem('Pengeluaran', fmt.format(totalCost), AppColors.rose, c),
          _financeStatItem('Margin Net', fmt.format(margin), margin >= 0 ? Colors.green : AppColors.rose, c, isBold: true),
        ]),
      ]),
    );
  }

  Widget _financeStatItem(String label, String value, Color valueColor, DColors c, {bool isBold = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.inter(fontSize: 10, color: c.textMuted)),
      const SizedBox(height: 2),
      Text(value, style: GoogleFonts.inter(fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, fontSize: 13, color: valueColor)),
    ]);
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

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 700;
      return Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 8), child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Row(children: [
            Expanded(child: Text('${_lands.length} lahan terdaftar', style: GoogleFonts.inter(color: c.textMuted, fontSize: 13))),
            Container(decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(10)),
              child: TextButton.icon(
                style: TextButton.styleFrom(iconColor: Colors.white, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                icon: const Icon(Icons.add_rounded, size: 16), label: Text('Tambah Lahan', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                onPressed: _showAddLandDialog,
              )),
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
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400, // Kembalikan ke 400
                          mainAxisSpacing: 16, crossAxisSpacing: 16, mainAxisExtent: 310), // Extent lebih besar agar ada ruang shadow bloom
                        itemCount: _lands.length,
                        itemBuilder: (_, i) => _buildLandCard(_lands[i], c))
                    : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), itemCount: _lands.length,
                        itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 16), child: SizedBox(height: 310, child: _buildLandCard(_lands[i], c)))),
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
            Switch(value: isDark, activeThumbColor: AppColors.primary,
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
            color: (color ?? AppColors.primary).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
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
    decoration: BoxDecoration(color: AppColors.amber.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.2))),
    child: Row(children: [
      const Icon(Icons.cloud_off_rounded, color: AppColors.amber, size: 16), const SizedBox(width: 10),
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
                  decoration: BoxDecoration(color: AppColors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                  child: Text('PENDING', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.amber)))],
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${h.weightKg}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: c.textPrimary)),
              Text('KG', style: GoogleFonts.inter(fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w600)),
              if (h.bunchCount > 0)
                Text('${h.bunchCount} tandan', style: GoogleFonts.inter(fontSize: 9, color: AppColors.cyan, fontWeight: FontWeight.w600)),
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
              colors: [AppColors.primary.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.0)],
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
        if (h.bunchCount > 0) ...[
          _dr('Jumlah Tandan', '${h.bunchCount} Tandan'),
          _dr('Rata-rata/Tandan', '${h.avgWeightPerBunch.toStringAsFixed(2)} KG'),
        ],
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
    color: cl.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12),
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

  // ════════════════════════════════════════════════════════════════
  // LAND MANAGEMENT
  // ════════════════════════════════════════════════════════════════
  Widget _buildLandCard(LandModel land, DColors c) {
    final owner = _stakeholders.where((s) => s.id == land.stakeholderId).firstOrNull;
    final total = _harvests.where((h) => h.landId == land.id).fold(0.0, (s, h) => s + h.weightKg);

    bool isHovered = false;

    return StatefulBuilder(
      builder: (ctx, ss) => MouseRegion(
        onEnter: (_) => ss(() => isHovered = true),
        onExit: (_) => ss(() => isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => _showLandDetailModal(land, owner?.name ?? owner?.email ?? 'Tidak diketahui', total, c),
          child: Padding(
            padding: const EdgeInsets.all(12), // Ruang lega untuk sebaran shadow box
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: c.surface, 
                borderRadius: BorderRadius.circular(16), 
                border: Border.all(color: isHovered ? AppColors.cyan : c.border, width: isHovered ? 1.5 : 1.0),
                boxShadow: isHovered ? [BoxShadow(color: AppColors.cyan.withValues(alpha: 0.2), blurRadius: 16, spreadRadius: 0, offset: const Offset(0, 0))] : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15), // Clip children so they don't cover the border
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Gambar Header
                  SizedBox(
                  height: 120, // Kembalikan tinggi image
                  child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                child: land.imageUrl != null && land.imageUrl!.isNotEmpty
                    ? Image.network(land.imageUrl!, fit: BoxFit.cover, errorBuilder: (ctx, e, s) => Container(color: c.surface))
                    : Image.network('https://images.unsplash.com/photo-1589308078052-9efaec11dbaf?q=80&w=800&auto=format&fit=crop', 
                fit: BoxFit.cover, errorBuilder: (ctx, e, s) => Container(color: c.surface),
              )),
              Positioned.fill(child: Container(color: Colors.black.withValues(alpha: 0.2))),
              Positioned(top: 12, right: 12, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  const Icon(Icons.aspect_ratio_rounded, color: AppColors.cyan, size: 10),
                  const SizedBox(width: 4),
                  Text('${land.sizeHectares} Hektar', style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
              )),
              // Floating Icon Box di pojok kiri bawah image
              Positioned(
                bottom: -20, left: 16,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: AppColors.cyan.withValues(alpha: 0.1), border: Border.all(color: AppColors.cyan, strokeAlign: BorderSide.strokeAlignOutside), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.terrain_rounded, color: AppColors.cyan),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 28), // Jarak untuk floating icon
          // Informasi teks
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(land.name, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
                const SizedBox(height: 4),
                Text('${land.treeCount} Batang  •  Pemilik ${owner?.name ?? 'Tidak diketahui'}', style: GoogleFonts.inter(fontSize: 10, color: c.textMuted), overflow: TextOverflow.ellipsis),
              ])),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 18, color: c.textMuted),
                splashRadius: 18,
                onSelected: (action) {
                  if (action == 'edit') _showEditLandDialog(land);
                  if (action == 'delete') _confirmDelete(land, c);
                  if (action == 'margin') _showLandFinanceForm(land);
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(value: 'margin', child: Row(children: [const Icon(Icons.request_quote_rounded, color: AppColors.violet, size: 16), const SizedBox(width: 8), Text('Pengeluaran', style: GoogleFonts.inter(fontWeight: FontWeight.w500))])),
                  PopupMenuItem(value: 'edit', child: Row(children: [const Icon(Icons.edit_rounded, color: AppColors.cyan, size: 16), const SizedBox(width: 8), Text('Edit', style: GoogleFonts.inter(fontWeight: FontWeight.w500))])),
                  PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_outline_rounded, color: AppColors.rose, size: 16), const SizedBox(width: 8), Text('Hapus', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: AppColors.rose))])),
                ],
              ),
            ]),
          ),
          const Spacer(),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1, color: c.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('TOTAL PANEN', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: c.textMuted)),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(total.toStringAsFixed(1), style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white)),
                const SizedBox(width: 4),
                Text('KG', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.cyan)),
              ]),
            ]),
          ),
        ]), // closes Column
        ), // closes ClipRRect
      ), // closes AnimatedContainer
    ), // closes Padding
      ), // closes MouseRegion
    ), // closes GestureDetector
    ); // closes StatefulBuilder
  }

  void _showLandDetailModal(LandModel land, String ownerName, double total, DColors c) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Tutup Detail',
      barrierColor: Colors.black.withValues(alpha: 0.6),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 800, // Diperbesar secara drastis!
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.border)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header Image Box
              SizedBox(
                height: 300, // Gambar top jadi lebih megah
                child: Stack(children: [
                  Positioned.fill(child: land.imageUrl != null && land.imageUrl!.isNotEmpty 
                      ? Image.network(land.imageUrl!, fit: BoxFit.cover, errorBuilder: (ctx, e, s) => Container(color: c.surface))
                      : Image.network('https://images.unsplash.com/photo-1589308078052-9efaec11dbaf?q=80&w=800&auto=format&fit=crop', fit: BoxFit.cover, errorBuilder: (ctx, e, s) => Container(color: c.surface))),
                  Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.9)])))),
                  
                  // Action Buttons Cepat di Kanan Atas
                  Positioned(top: 16, right: 16, child: Row(children: [
                     _actionPill(Icons.request_quote_rounded, AppColors.violet, () { Navigator.pop(ctx); _showLandFinanceForm(land); }),
                     const SizedBox(width: 8),
                     _actionPill(Icons.edit_rounded, AppColors.cyan, () { Navigator.pop(ctx); _showEditLandDialog(land); }),
                     const SizedBox(width: 8),
                     _actionPill(Icons.delete_outline_rounded, AppColors.rose, () { Navigator.pop(ctx); _confirmDelete(land, c); }),
                     const SizedBox(width: 16),
                     _actionPill(Icons.close_rounded, Colors.white, () { Navigator.pop(ctx); }),
                  ])),
                  
                  // Label Nama di Kiri Bawah
                  Positioned(bottom: 20, left: 24, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                     Text(land.name, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                     const SizedBox(height: 6),
                     Row(children: [
                       const Icon(Icons.location_on_outlined, color: AppColors.cyan, size: 14),
                       const SizedBox(width: 6),
                       Text('Lihat di Peta (Batas Wilayah)', style: GoogleFonts.inter(color: AppColors.cyan, fontSize: 12, fontWeight: FontWeight.w600)),
                     ])
                  ])),
                ]),
              ),
              
              // 4 Kartu Detail (Luas, Pohon, Pemilik, Panen)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: _detailCardInfo('LUAS LAHAN', Icons.map_outlined, '${land.sizeHectares}', 'Ha', c)),
                    const SizedBox(width: 16),
                    Expanded(child: _detailCardInfo('JUMLAH POHON', Icons.nature_outlined, '${land.treeCount}', 'Batang', c)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _detailCardInfo('PEMILIK', Icons.person_outline, ownerName, '', c)),
                    const SizedBox(width: 16),
                    Expanded(child: _detailCardInfo('TOTAL PANEN', Icons.scale_outlined, total.toStringAsFixed(1), 'KG', c, highlight: true)),
                  ]),
                ]),
              ),
              
              // Foto Lahan (Versi Penuh)
              if (land.imageUrl != null && land.imageUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('FOTO LAHAN', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: c.textMuted)),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: c.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              land.imageUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, e, s) => Container(
                                height: 200, color: c.surfaceLight,
                                child: const Center(child: Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // Bottom Footer Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                   TextButton(onPressed: () => Navigator.pop(ctx), style: TextButton.styleFrom(foregroundColor: Colors.white), child: Text('Tutup', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                   const SizedBox(width: 16),
                   ElevatedButton(
                     style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                     onPressed: () {
                       Navigator.pop(ctx);
                       Navigator.push(context, MaterialPageRoute(builder: (_) => const InputHarvestForm())).then((r) {
                         if (r == true) _loadData();
                       });
                     },
                     child: Text('Input Panen', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                   ),
                ]),
              ),
            ]),
          ),
        ),
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  Widget _actionPill(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
       onTap: onTap,
       child: Container(
         padding: const EdgeInsets.all(6),
         decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.4))),
         child: Icon(icon, color: color, size: 16),
       ),
    );
  }

  Widget _detailCardInfo(String title, IconData icon, String val, String unit, DColors c, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(color: c.surfaceLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (highlight) Positioned(right: -10, bottom: -20, child: Icon(Icons.scale_rounded, size: 80, color: Colors.white.withValues(alpha: 0.03))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 12, color: c.textMuted), const SizedBox(width: 6),
              Text(title, style: GoogleFonts.inter(color: c.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Flexible(child: Text(val, style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
              if (unit.isNotEmpty) ...[
                 const SizedBox(width: 4),
                 Text(unit, style: GoogleFonts.inter(color: highlight ? AppColors.cyan : c.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
              ]
            ]),
          ]),
        ],
      ),
    );
  }

  Future<Uint8List?> _pickAndCropImage() async {
    final picker = ImagePicker();
    XFile? pickedFile;
    
    try {
      pickedFile = await picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error ImagePicker: $e')));
      return null;
    }
    
    if (pickedFile == null) return null;

    final bool isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS);
    
    if (isDesktop) {
       return await pickedFile.readAsBytes();
    }

    if (!mounted) return null;

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 4, ratioY: 3),
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: 'Potong Foto Lahan',
              toolbarColor: AppColors.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.ratio4x3,
              lockAspectRatio: true),
          IOSUiSettings(title: 'Potong Foto Lahan', aspectRatioLockEnabled: true),
          WebUiSettings(context: context),
        ],
      );

      if (croppedFile != null) {
        return await croppedFile.readAsBytes();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error Cropper: $e')));
      return await pickedFile.readAsBytes();
    }
    
    return null;
  }

  void _showAddLandDialog() {
    final nameController = TextEditingController();
    final sizeController = TextEditingController();
    final treeCountController = TextEditingController();
    String? selectedStakeholderId;
    Uint8List? selectedImageBytes;
    bool isUploading = false;

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text('Tambah Lahan Baru', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Image Picker Area
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              try {
                final bytes = await _pickAndCropImage();
                if (bytes != null) setDialogState(() => selectedImageBytes = bytes);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OnTap Error: $e')));
              }
            },
            child: Container(
              height: 120, width: double.infinity,
              decoration: BoxDecoration(
                color: context.dc.surfaceLight, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.dc.border),
                image: selectedImageBytes != null ? DecorationImage(image: MemoryImage(selectedImageBytes!), fit: BoxFit.cover) : null,
              ),
              child: selectedImageBytes == null
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.add_a_photo_outlined, color: AppColors.cyan, size: 30),
                      const SizedBox(height: 8),
                      Text('Tambahkan Foto (4:3)', style: GoogleFonts.inter(color: context.dc.textMuted, fontSize: 12)),
                    ])
                  : Align(alignment: Alignment.topRight, child: Container(margin: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 16), onPressed: () => setDialogState(() => selectedImageBytes = null)))),
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nama Lahan', prefixIcon: Icon(Icons.terrain))),
          const SizedBox(height: 12),
          TextField(controller: sizeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Luas (Hektar)', prefixIcon: Icon(Icons.straighten))),
          const SizedBox(height: 12),
          TextField(controller: treeCountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jumlah Batang', prefixIcon: Icon(Icons.nature_people))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedStakeholderId, isExpanded: true, decoration: const InputDecoration(labelText: 'Pemilik (Stakeholder)', prefixIcon: Icon(Icons.person)),
            items: _stakeholders.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name.isEmpty ? s.email : s.name, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (val) => setDialogState(() => selectedStakeholderId = val),
          ),
        ])),
        actions: [
          TextButton(onPressed: isUploading ? null : () => Navigator.pop(ctx), child: const Text('Batal')),
          Container(decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(10)),
            child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
              onPressed: isUploading ? null : () async {
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                if (nameController.text.isEmpty || sizeController.text.isEmpty || selectedStakeholderId == null) {
                  messenger.showSnackBar(const SnackBar(content: Text('Semua field wajib diisi (Foto opsional)'))); return;
                }
                setDialogState(() => isUploading = true);
                try {
                  final newLand = LandModel(
                    name: nameController.text, sizeHectares: double.tryParse(sizeController.text) ?? 0,
                    treeCount: int.tryParse(treeCountController.text) ?? 0, stakeholderId: selectedStakeholderId!,
                  );
                  String? uploadedUrl;
                  if (selectedImageBytes != null) {
                    uploadedUrl = await LandRepository().uploadLandImage(newLand.id, 'image.jpg', selectedImageBytes!, '.jpg');
                  }
                  
                  // Update model with URL and save
                  final finalLand = LandModel(
                    id: newLand.id, name: newLand.name, sizeHectares: newLand.sizeHectares,
                    treeCount: newLand.treeCount, stakeholderId: newLand.stakeholderId,
                    imageUrl: uploadedUrl, createdAt: newLand.createdAt,
                  );
                  await LandRepository().addLand(finalLand);
                  
                  if (!mounted) return;
                  navigator.pop();
                  _loadData(); // Re-fetch
                  messenger.showSnackBar(const SnackBar(content: Text('Lahan ditambahkan')));
                } catch (e) {
                  setDialogState(() => isUploading = false);
                  if (mounted) messenger.showSnackBar(SnackBar(content: Text('Gagal menambahkan: $e')));
                }
              }, child: isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Simpan'))),
        ],
      )));
  }

  void _showEditLandDialog(LandModel land) {
    final nameController = TextEditingController(text: land.name);
    final sizeController = TextEditingController(text: land.sizeHectares.toString());
    final treeCountController = TextEditingController(text: land.treeCount.toString());
    String? selectedStakeholderId = land.stakeholderId;
    Uint8List? selectedImageBytes;
    bool isUploading = false;
    bool removeExistingPhoto = false;

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text('Edit Lahan', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Image Picker Area
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              try {
                final bytes = await _pickAndCropImage();
                if (bytes != null) setDialogState(() { selectedImageBytes = bytes; removeExistingPhoto = false; });
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OnTap Error: $e')));
              }
            },
            child: Container(
              height: 120, width: double.infinity,
              decoration: BoxDecoration(
                color: context.dc.surfaceLight, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.dc.border),
                image: selectedImageBytes != null 
                    ? DecorationImage(image: MemoryImage(selectedImageBytes!), fit: BoxFit.cover) 
                    : (!removeExistingPhoto && land.imageUrl != null)
                        ? DecorationImage(image: NetworkImage(land.imageUrl!), fit: BoxFit.cover)
                        : null,
              ),
              child: (selectedImageBytes == null && (removeExistingPhoto || land.imageUrl == null))
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.add_a_photo_outlined, color: AppColors.cyan, size: 30),
                      const SizedBox(height: 8),
                      Text('Ubah Foto (4:3)', style: GoogleFonts.inter(color: context.dc.textMuted, fontSize: 12)),
                    ])
                  : Align(alignment: Alignment.topRight, child: Container(margin: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 16), onPressed: () => setDialogState(() { selectedImageBytes = null; removeExistingPhoto = true; })))),
            ),
          ),
          const SizedBox(height: 16),
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nama Lahan', prefixIcon: Icon(Icons.terrain))),
          const SizedBox(height: 12),
          TextField(controller: sizeController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Luas (Hektar)', prefixIcon: Icon(Icons.straighten))),
          const SizedBox(height: 12),
          TextField(controller: treeCountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jumlah Batang', prefixIcon: Icon(Icons.nature_people))),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _stakeholders.any((s) => s.id == selectedStakeholderId) ? selectedStakeholderId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Pemilik (Stakeholder)', prefixIcon: Icon(Icons.person)),
            items: _stakeholders.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name.isEmpty ? s.email : s.name, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (val) => setDialogState(() => selectedStakeholderId = val),
          ),
        ])),
        actions: [
          TextButton(onPressed: isUploading ? null : () => Navigator.pop(ctx), child: const Text('Batal')),
          Container(decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(10)),
            child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
              onPressed: isUploading ? null : () async {
                final navigator = Navigator.of(ctx);
                final messenger = ScaffoldMessenger.of(context);
                if (nameController.text.isEmpty || sizeController.text.isEmpty) {
                  messenger.showSnackBar(const SnackBar(content: Text('Nama dan luas wajib diisi'))); return;
                }
                setDialogState(() => isUploading = true);
                try {
                  String? uploadedUrl;
                  if (selectedImageBytes != null) {
                    uploadedUrl = await LandRepository().uploadLandImage(land.id, 'image.jpg', selectedImageBytes!, '.jpg');
                  } else if (removeExistingPhoto) {
                    uploadedUrl = ''; // Akan diproses sebentar lagi, atau bisa null string jika diset di repo 
                  }
                  
                  await LandRepository().updateLand(land.id, name: nameController.text.trim(),
                    sizeHectares: double.tryParse(sizeController.text), treeCount: int.tryParse(treeCountController.text), 
                    stakeholderId: selectedStakeholderId, imageUrl: uploadedUrl ?? land.imageUrl);
                    
                  if (!mounted) return;
                  navigator.pop();
                  _loadData();
                  messenger.showSnackBar(const SnackBar(content: Text('Lahan diperbarui')));
                } catch (e) {
                  setDialogState(() => isUploading = false);
                  if (mounted) messenger.showSnackBar(SnackBar(content: Text('Gagal memperbarui: $e')));
                }
              }, child: isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Simpan'))),
        ],
      )));
  }

  Future<void> _confirmDelete(LandModel land, DColors c) async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Hapus Lahan?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      content: Text('Yakin ingin menghapus "${land.name}"? Semua data panen terkait juga akan dihapus.', style: GoogleFonts.inter(color: c.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        Container(decoration: BoxDecoration(gradient: AppColors.gradientRose, borderRadius: BorderRadius.circular(10)),
          child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus'))),
      ]));
    if (confirm == true) {
      try { await LandRepository().deleteLand(land.id); _loadData(); }
      catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e'))); }
    }
  }

  void _showLandFinanceForm(LandModel land) {
    final c = context.dc;
    int selM = DateTime.now().month;
    int selY = DateTime.now().year;

    final fCtl = TextEditingController();
    final wCtl = TextEditingController();
    final pCtl = TextEditingController();
    final prCtl = TextEditingController();
    final kgCtl = TextEditingController(text: "2500");

    double pricePerKg = 2500;
    double fertilizerMonthly = 0;
    double workerMonthly = 0;
    double pesticideYearly = 0;
    double pruningYearly = 0;
    String? currentId;

    void loadForPeriod() {
      final fin = _finances.where((f) => f.landId == land.id && f.periodMonth == selM && f.periodYear == selY).firstOrNull;
      if (fin != null) {
        currentId = fin.id;
        fCtl.text = fin.fertilizerCost > 0 ? fin.fertilizerCost.toStringAsFixed(0) : '';
        wCtl.text = fin.workerCost > 0 ? fin.workerCost.toStringAsFixed(0) : '';
        pCtl.text = fin.pesticideYearlyCost > 0 ? fin.pesticideYearlyCost.toStringAsFixed(0) : '';
        prCtl.text = fin.pruningYearlyCost > 0 ? fin.pruningYearlyCost.toStringAsFixed(0) : '';
        kgCtl.text = fin.pricePerKg > 0 ? fin.pricePerKg.toStringAsFixed(0) : '2500';
      } else {
        currentId = null;
        fCtl.text = ''; wCtl.text = ''; kgCtl.text = '2500';
        final yrFin = _finances.where((f) => f.landId == land.id && f.periodYear == selY).toList();
        yrFin.sort((a,b) => b.periodMonth.compareTo(a.periodMonth));
        if (yrFin.isNotEmpty) {
          pCtl.text = yrFin.first.pesticideYearlyCost > 0 ? yrFin.first.pesticideYearlyCost.toStringAsFixed(0) : '';
          prCtl.text = yrFin.first.pruningYearlyCost > 0 ? yrFin.first.pruningYearlyCost.toStringAsFixed(0) : '';
        } else {
          pCtl.text = ''; prCtl.text = '';
        }
      }
    }
    
    loadForPeriod();

    final fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        void calc() {
          pricePerKg = double.tryParse(kgCtl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          fertilizerMonthly = double.tryParse(fCtl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          workerMonthly = double.tryParse(wCtl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          pesticideYearly = double.tryParse(pCtl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          pruningYearly = double.tryParse(prCtl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        }
        calc();

        double totalTonnage = _harvests.where((h) => h.landId == land.id && h.harvestDate.month == selM && h.harvestDate.year == selY)
            .fold(0.0, (sum, h) => sum + h.weightKg);

        double pestMonthly = pesticideYearly / 12;
        double prunMonthly = pruningYearly / 12;
        double totalMonthlyCost = fertilizerMonthly + workerMonthly + pestMonthly + prunMonthly;
        double grossRevenue = totalTonnage * pricePerKg; 
        double margin = grossRevenue - totalMonthlyCost; 

        Widget inputField(String label, String suffix, TextEditingController ctrl) {
           return Padding(
             padding: const EdgeInsets.only(bottom: 12),
             child: TextField(
               controller: ctrl, keyboardType: TextInputType.number,
               onChanged: (_) => setDialogState(calc),
               style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
               decoration: InputDecoration(
                 labelText: label, suffixText: suffix, labelStyle: GoogleFonts.inter(fontSize: 12),
                 contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                 filled: true, fillColor: c.surfaceLight,
               ),
             ),
           );
        }
        
        Widget tr(String label, double val, {bool isB = false, Color? color}) {
          return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(label, style: GoogleFonts.inter(fontSize: 12, color: isB ? c.textPrimary : c.textSecondary, fontWeight: isB ? FontWeight.w700 : FontWeight.w500)),
              Text(fmt.format(val), style: GoogleFonts.inter(fontSize: 13, color: color ?? c.textPrimary, fontWeight: isB ? FontWeight.w800 : FontWeight.w600)),
            ]));
        }

        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: c.surfaceLight, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Catat Pengeluaran Bulanan', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
            Text('${land.name} (${land.sizeHectares} Ha)', style: GoogleFonts.inter(fontSize: 13, color: c.textMuted)),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
              Expanded(child: DropdownButtonFormField<int>(
                value: selM,
                items: List.generate(12, (i) => DropdownMenuItem(value: i+1, child: Text('Bulan ${i+1}'))),
                onChanged: (v) { setDialogState(() { selM = v!; loadForPeriod(); calc(); }); },
                decoration: const InputDecoration(labelText: 'Bulan', border: OutlineInputBorder()),
              )),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonFormField<int>(
                value: selY,
                items: List.generate(10, (i) {
                  final y = DateTime.now().year - 5 + i;
                  return DropdownMenuItem(value: y, child: Text('$y'));
                }),
                onChanged: (v) { setDialogState(() { selY = v!; loadForPeriod(); calc(); }); },
                decoration: const InputDecoration(labelText: 'Tahun', border: OutlineInputBorder()),
              )),
            ])),
            const Divider(height: 24),
            Expanded(child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Text('1. Variabel Harga & Biaya (Rp)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                const SizedBox(height: 12),
                inputField('Harga Sawit saat ini (per KG)', '/kg', kgCtl),
                inputField('Kebutuhan Pupuk (Bulan Ini)', '/bln', fCtl),
                inputField('Jasa Pekerja (Bulan Ini)', '/bln', wCtl),
                inputField('Kebutuhan Pestisida (Tahunan)', '/thn', pCtl),
                inputField('Kebutuhan Pruning (Tahunan)', '/thn', prCtl),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.violet.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.violet.withValues(alpha: 0.2))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('2. Kalkulasi Rincian Bulanan', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.violet)),
                    const SizedBox(height: 12),
                    tr('Pupuk', fertilizerMonthly),
                    tr('Pekerja', workerMonthly),
                    tr('Pestisida (Dibagi 12 bln)', pestMonthly),
                    tr('Pruning (Dibagi 12 bln)', prunMonthly),
                    const Divider(height: 16),
                    tr('Total Pengeluaran Bulan Ini', totalMonthlyCost, isB: true),
                  ]),
                ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('3. Ringkasan Margin Bulan Ini', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Text('Berdasarkan total tonase bulan $selM/$selY: ${totalTonnage.toStringAsFixed(1)} KG', 
                        style: GoogleFonts.inter(fontSize: 11, height: 1.4, color: c.textMuted)),
                    const SizedBox(height: 12),
                    tr('Pendapatan (Tonase x Harga)', grossRevenue),
                    tr('Total Pengeluaran Lahan', totalMonthlyCost, color: AppColors.rose),
                    const Divider(height: 16),
                    tr('Margin (Laba Bersih)', margin, isB: true, color: margin >= 0 ? Colors.green : AppColors.rose),
                  ]),
                ),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, height: 48, child: Container(
                  decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(12)),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
                    onPressed: () async {
                      final navigator = Navigator.of(ctx);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final fin = LandFinanceModel(
                          id: currentId,
                          landId: land.id,
                          periodMonth: selM,
                          periodYear: selY,
                          pricePerKg: pricePerKg,
                          fertilizerCost: fertilizerMonthly,
                          workerCost: workerMonthly,
                          pesticideYearlyCost: pesticideYearly,
                          pruningYearlyCost: pruningYearly,
                        );
                        await LandRepository().upsertFinance(fin);
                        if (!mounted) return;
                        navigator.pop();
                        _loadData();
                        messenger.showSnackBar(const SnackBar(content: Text('Catatan pengeluaran disimpan!')));
                      } catch (e) {
                         if (mounted) messenger.showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
                      }
                    },
                    child: Text('Simpan Rekapan Finance', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                )),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), side: const BorderSide(color: AppColors.rose)),
                    icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.rose, size: 18),
                    label: Text('Export PDF', style: GoogleFonts.inter(color: AppColors.rose, fontWeight: FontWeight.w600, fontSize: 13)),
                    onPressed: () async {
                       try {
                         final fin = LandFinanceModel(id: currentId ?? 'temp', landId: land.id, periodMonth: selM, periodYear: selY, pricePerKg: pricePerKg, fertilizerCost: fertilizerMonthly, workerCost: workerMonthly, pesticideYearlyCost: pesticideYearly, pruningYearlyCost: pruningYearly);
                         final mH = _harvests.where((h) => h.landId == land.id && h.harvestDate.month == selM && h.harvestDate.year == selY).toList();
                         await ExportService.exportFinanceToPDF(context, land, fin, mH);
                       } catch (e) {
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal export PDF: $e')));
                       }
                    },
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), side: const BorderSide(color: Colors.green)),
                    icon: const Icon(Icons.table_chart_rounded, color: Colors.green, size: 18),
                    label: Text('Export Excel', style: GoogleFonts.inter(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13)),
                    onPressed: () async {
                       try {
                         final fin = LandFinanceModel(id: currentId ?? 'temp', landId: land.id, periodMonth: selM, periodYear: selY, pricePerKg: pricePerKg, fertilizerCost: fertilizerMonthly, workerCost: workerMonthly, pesticideYearlyCost: pesticideYearly, pruningYearlyCost: pruningYearly);
                         final mH = _harvests.where((h) => h.landId == land.id && h.harvestDate.month == selM && h.harvestDate.year == selY).toList();
                         await ExportService.exportFinanceToExcel(land, fin, mH);
                       } catch (e) {
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal export Excel: $e')));
                       }
                    },
                  )),
                ]),
                const SizedBox(height: 40),
              ],
            )),
          ]),
        );
      }),
    );
  }
}

class _CB { final String l; double t; _CB(this.l, this.t); }
