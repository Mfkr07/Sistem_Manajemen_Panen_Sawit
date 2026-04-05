import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/repositories/harvest_repository.dart';
import '../../../core/repositories/land_repository.dart';
import '../../../core/models/models.dart';
import '../../../core/services/export_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';

class StakeholderDashboardPage extends ConsumerStatefulWidget {
  const StakeholderDashboardPage({super.key});
  @override
  ConsumerState<StakeholderDashboardPage> createState() => _StakeholderState();
}

class _StakeholderState extends ConsumerState<StakeholderDashboardPage> {
  List<HarvestModel> _harvests = [];
  List<LandModel> _myLands = [];
  Map<String, String> _landNameMap = {};
  bool _isLoading = true;
  String? _uid;
  String _email = '';
  String _name = '';
  int _tabIndex = 0;

  String _chartTf = '2 Minggu';
  final List<String> _tfs = ['Harian', '2 Minggu', '1 Bulan', '3 Bulan'];
  late int _selMonth;
  late int _selYear;

  // History filter
  String _histFilter = 'Semua';
  DateTime? _histStart;
  DateTime? _histEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selMonth = now.month; _selYear = now.year;
    final u = Supabase.instance.client.auth.currentUser;
    _uid = u?.id; _email = u?.email ?? '';
    _loadData(); _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      if (_uid != null) {
        final d = await Supabase.instance.client.from('users').select('name').eq('id', _uid!).single();
        if (mounted) setState(() => _name = d['name'] ?? '');
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (_uid == null) { setState(() => _isLoading = false); return; }
      _myLands = await LandRepository().getLandsByStakeholder(_uid!);
      _landNameMap = {for (var l in _myLands) l.id: l.name};
      final ids = _myLands.map((l) => l.id).toList();
      _harvests = ids.isNotEmpty ? await HarvestRepository().getHarvestsByLandIds(ids) : [];
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  void _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  double get _monthTotal => _harvests
      .where((h) => h.harvestDate.month == _selMonth && h.harvestDate.year == _selYear)
      .fold(0.0, (s, h) => s + h.weightKg);
  String get _monthLabel {
    const m = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agt','Sep','Okt','Nov','Des'];
    return '${m[_selMonth - 1]} $_selYear';
  }
  double get _totalAll => _harvests.fold(0.0, (s, h) => s + h.weightKg);
  List<HarvestModel> get _filteredHist {
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
    {'icon': Icons.person_rounded, 'label': 'Profil'},
  ];

  String get _userInitials {
    if (_name.isEmpty) return 'S';
    final parts = _name.trim().split(' ');
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
              colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Row(children: [
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
              Text(_name.isEmpty ? 'Stakeholder' : _name,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(_email, style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                  overflow: TextOverflow.ellipsis),
            ])),
          ]),
        ),
        const SizedBox(height: 12),
        // Nav items with active bar
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
                    color: active ? AppColors.violet.withOpacity(0.1) : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 3, height: active ? 24 : 0,
                      decoration: BoxDecoration(
                        color: active ? AppColors.violet : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: active ? 10 : 13),
                    Icon(item['icon'] as IconData,
                        color: active ? AppColors.violet : c.textMuted, size: 21),
                    const SizedBox(width: 12),
                    Expanded(child: Text(item['label'] as String, style: GoogleFonts.inter(
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        color: active ? AppColors.violet : c.textPrimary, fontSize: 14))),
                  ]),
                ),
              ),
            ),
          );
        }),
        const Spacer(),
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

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final titles = ['Portofolio Anda','Histori Panen','Portofolio Lahan','Profil Stakeholder'];
    
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
                  Text('Halo, ${_name.isEmpty ? 'Stakeholder' : _name} \uD83D\uDC4B',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: c.textPrimary)),
                  Text('Lihat performa lahan Anda', style: GoogleFonts.inter(fontSize: 12, color: c.textMuted)),
                ])
              : Text(titles[_tabIndex]),
          actions: [
            if (_tabIndex == 0)
              Padding(padding: const EdgeInsets.only(right: 8), child: IconButton(
                icon: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(
                    color: c.surfaceLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border)),
                  child: Icon(Icons.refresh_rounded, size: 18, color: c.textSecondary)),
                onPressed: () { setState(() => _isLoading = true); _loadData(); })),
          ],
        ),
        drawer: isMobile ? _buildDrawer(c) : null,
        body: SafeArea(child: _isLoading
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(), const SizedBox(height: 16),
                Text('Memuat portofolio...', style: GoogleFonts.inter(color: c.textMuted))
              ]))
            : IndexedStack(index: _tabIndex, children: [_homeTab(isDesktop), _historyTab(), _landsTab(), _profileTab()])),
        bottomNavigationBar: isMobile ? BottomNavigationBar(
          currentIndex: _tabIndex,
          onTap: (i) => setState(() => _tabIndex = i),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Beranda'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Histori'),
            BottomNavigationBarItem(icon: Icon(Icons.terrain_rounded), label: 'Lahan'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profil'),
          ],
        ) : null,
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

  // ═══════════════════════════════════════════════════
  // TAB 0 – HOME
  // ═══════════════════════════════════════════════════
  Widget _homeTab(bool isDesktop) {
    final c = context.dc;
    final avgMonth = _harvests.isEmpty ? 0.0 : _totalAll / ((_harvests.map((h) => '${h.harvestDate.year}-${h.harvestDate.month}').toSet().length).clamp(1, 999));
    return RefreshIndicator(color: AppColors.primary, backgroundColor: c.surface, onRefresh: _loadData,
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(isDesktop ? 24 : 16, 8, isDesktop ? 24 : 16, 32), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Lands scroll
            _sec('Lahan Anda'),
            const SizedBox(height: 12),
            if (_myLands.isEmpty)
              _infoBanner('Belum ada lahan terdaftar. Hubungi admin.', c)
            else
              SizedBox(height: 120, child: ListView.separated(scrollDirection: Axis.horizontal,
                itemCount: _myLands.length, separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _landCard(_myLands[i], c))),
            const SizedBox(height: 24),
            // Stats — 4 cols on desktop, 3 on mobile
            if (isDesktop)
              Row(children: [
                Expanded(child: _stat(Icons.scale_rounded, '${_monthTotal.toStringAsFixed(1)}', 'KG',
                    _selMonth == DateTime.now().month && _selYear == DateTime.now().year ? 'Bulan Ini' : _monthLabel,
                    AppColors.gradientPrimary, onTap: _showMonthPicker, chevron: true)),
                const SizedBox(width: 12),
                Expanded(child: _stat(Icons.terrain_rounded, '${_myLands.length}', null, 'Lahan', AppColors.gradientViolet)),
                const SizedBox(width: 12),
                Expanded(child: _stat(Icons.inventory_2_rounded, '${_totalAll.toStringAsFixed(0)}', 'KG', 'Total',
                    const LinearGradient(colors: [AppColors.cyan, Color(0xFF38BDF8)]))),
                const SizedBox(width: 12),
                Expanded(child: _stat(Icons.trending_up_rounded, '${avgMonth.toStringAsFixed(1)}', 'KG', 'Rata-rata/Bulan',
                    const LinearGradient(colors: [AppColors.amber, Color(0xFFFBBF24)]))),
              ])
            else
              Row(children: [
                Expanded(child: _stat(Icons.scale_rounded, '${_monthTotal.toStringAsFixed(1)}', 'KG',
                    _selMonth == DateTime.now().month && _selYear == DateTime.now().year ? 'Bulan Ini' : _monthLabel,
                    AppColors.gradientPrimary, onTap: _showMonthPicker, chevron: true)),
                const SizedBox(width: 10),
                Expanded(child: _stat(Icons.terrain_rounded, '${_myLands.length}', null, 'Lahan', AppColors.gradientViolet)),
                const SizedBox(width: 10),
                Expanded(child: _stat(Icons.inventory_2_rounded, '${_totalAll.toStringAsFixed(0)}', 'KG', 'Total',
                    const LinearGradient(colors: [AppColors.cyan, Color(0xFF38BDF8)]))),
              ]),
            const SizedBox(height: 24),

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
                              _sec('Tren Panen'),
                              SizedBox(width: 280, child: _tfPills(c)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _harvests.isEmpty ? _empty('Belum ada data', Icons.show_chart_rounded, c) : _chart(c),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _exportBtn(c),
                        const SizedBox(height: 20),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          _sec('Histori Terkini'),
                          TextButton(onPressed: () => setState(() => _tabIndex = 1), child: const Text('Semua →')),
                        ]),
                        const SizedBox(height: 8),
                        if (_harvests.isEmpty) _empty('Belum ada data', Icons.inbox_rounded, c)
                        else ..._harvests.take(5).map((h) => _hCard(h, c)),
                      ],
                    ),
                  )
                ],
              )
            else ...[
              _sec('Tren Panen'), const SizedBox(height: 12),
              _tfPills(c), const SizedBox(height: 12),
              _harvests.isEmpty ? _empty('Belum ada data', Icons.show_chart_rounded, c) : _chart(c),
              const SizedBox(height: 24),
              _exportBtn(c),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _sec('Histori Terkini'),
                TextButton(onPressed: () => setState(() => _tabIndex = 1), child: const Text('Semua →')),
              ]),
              const SizedBox(height: 8),
              if (_harvests.isEmpty) _empty('Belum ada data', Icons.inbox_rounded, c)
              else ..._harvests.take(5).map((h) => _hCard(h, c)),
            ]
          ])))),
    );
  }

  // ═══════════════════════════════════════════════════
  // TAB 1 – HISTORY
  // ═══════════════════════════════════════════════════
  Widget _historyTab() {
    final c = context.dc;
    final filters = ['Semua','7 Hari','1 Bulan','3 Bulan','6 Bulan','1 Tahun','Kustom'];
    final fil = _filteredHist;
    final tot = fil.fold(0.0, (s, h) => s + h.weightKg);
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 700;
      return Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.border))),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              isWide
                  ? Wrap(spacing: 6, runSpacing: 6,
                      children: filters.map((f) {
                        final sel = _histFilter == f;
                        return GestureDetector(
                          onTap: () => _applyHist(f),
                          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(gradient: sel ? AppColors.gradientPrimary : null,
                              color: sel ? null : c.surfaceLight, borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sel ? Colors.transparent : c.border)),
                            child: Text(f, style: GoogleFonts.inter(fontSize: 12,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                color: sel ? Colors.white : c.textMuted))));
                      }).toList())
                  : SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
                      children: filters.map((f) {
                        final sel = _histFilter == f;
                        return Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
                          onTap: () => _applyHist(f),
                          child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(gradient: sel ? AppColors.gradientPrimary : null,
                              color: sel ? null : c.surfaceLight, borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sel ? Colors.transparent : c.border)),
                            child: Text(f, style: GoogleFonts.inter(fontSize: 12,
                                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                color: sel ? Colors.white : c.textMuted)))));
                      }).toList())),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: Text(_histStart != null && _histEnd != null
                    ? '${DateFormat('dd MMM yyyy').format(_histStart!)} — ${DateFormat('dd MMM yyyy').format(_histEnd!)}'
                    : 'Semua waktu', style: GoogleFonts.inter(fontSize: 12, color: c.textMuted))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('${fil.length} data • ${tot.toStringAsFixed(1)} KG',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
              ]),
            ]),
          ))),
        Expanded(child: fil.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.inbox_rounded, size: 56, color: c.textMuted), const SizedBox(height: 12),
                Text('Tidak ada data', style: GoogleFonts.inter(color: c.textMuted))]))
            : Center(child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: isWide
                    ? GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: constraints.maxWidth >= 1000 ? 2 : 1,
                          mainAxisSpacing: 8, crossAxisSpacing: 12, mainAxisExtent: 76),
                        itemCount: fil.length,
                        itemBuilder: (_, i) => _hCard(fil[i], c))
                    : ListView.builder(padding: const EdgeInsets.all(16), itemCount: fil.length,
                        itemBuilder: (_, i) => _hCard(fil[i], c)),
              ))),
      ]);
    });
  }

  void _applyHist(String f) {
    setState(() {
      _histFilter = f; final now = DateTime.now();
      switch (f) {
        case 'Semua': _histStart = null; _histEnd = null; break;
        case '7 Hari': _histStart = now.subtract(const Duration(days: 7)); _histEnd = now; break;
        case '1 Bulan': _histStart = DateTime(now.year, now.month - 1, now.day); _histEnd = now; break;
        case '3 Bulan': _histStart = DateTime(now.year, now.month - 3, now.day); _histEnd = now; break;
        case '6 Bulan': _histStart = now.subtract(const Duration(days: 180)); _histEnd = now; break;
        case '1 Tahun': _histStart = now.subtract(const Duration(days: 365)); _histEnd = now; break;
        case 'Kustom': _pickHistRange(); return;
      }
    });
  }

  Future<void> _pickHistRange() async {
    final p = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(),
      initialDateRange: _histStart != null && _histEnd != null
          ? DateTimeRange(start: _histStart!, end: _histEnd!)
          : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()),
      builder: (ctx, child) => Theme(data: Theme.of(ctx), child: child!));
    if (p != null) setState(() { _histStart = p.start; _histEnd = p.end; _histFilter = 'Kustom'; });
  }

  // ═══════════════════════════════════════════════════
  // TAB 2 – LANDS
  // ═══════════════════════════════════════════════════
  Widget _landsTab() {
    final c = context.dc;
    Widget landItem(LandModel l) {
      final tot = _harvests.where((h) => h.landId == l.id).fold(0.0, (s, h) => s + h.weightKg);
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
            Text(tot.toStringAsFixed(1), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: c.textPrimary)),
            Text('KG', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: c.textMuted)),
          ]),
        ]));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 700;
      return _myLands.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.terrain_rounded, size: 56, color: c.textMuted), const SizedBox(height: 12),
              Text('Belum ada lahan', style: GoogleFonts.inter(color: c.textMuted))]))
          : Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: isWide
                  ? GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: constraints.maxWidth >= 1000 ? 3 : 2,
                        mainAxisSpacing: 10, crossAxisSpacing: 12, mainAxisExtent: 78),
                      itemCount: _myLands.length,
                      itemBuilder: (_, i) => landItem(_myLands[i]))
                  : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _myLands.length,
                      itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 8), child: landItem(_myLands[i]))),
            ));
    });
  }

  // ═══════════════════════════════════════════════════
  // TAB 3 – PROFILE
  // ═══════════════════════════════════════════════════
  Widget _profileTab() {
    final c = context.dc;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(children: [
        // User card
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(
            color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(
                gradient: AppColors.gradientViolet, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.person_rounded, size: 28, color: Colors.white)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_name.isEmpty ? 'Stakeholder' : _name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: c.textPrimary)),
              const SizedBox(height: 2),
              Text(_email, style: GoogleFonts.inter(fontSize: 13, color: c.textMuted)),
            ])),
          ])),
        const SizedBox(height: 16),
        // Theme
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
          ])),
        const SizedBox(height: 12),
        _sTile(c, Icons.download_rounded, 'Export Rekapitulasi', () {
          if (_harvests.isNotEmpty) _showExportDialog();
        }),
        const SizedBox(height: 24),
        _sTile(c, Icons.logout_rounded, 'Keluar', _logout, color: AppColors.rose),
      ]),
    )));
  }

  Widget _sTile(DColors c, IconData icon, String t, VoidCallback onTap, {Color? color}) {
    return Container(decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border)),
      child: ListTile(
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(
            color: (color ?? AppColors.primary).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: color ?? c.textSecondary)),
        title: Text(t, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: color ?? c.textPrimary)),
        trailing: Icon(Icons.chevron_right_rounded, color: c.textMuted),
        onTap: onTap, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
  }

  // ═══════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════
  Widget _sec(String t) => Text(t, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: context.dc.textPrimary));

  Widget _stat(IconData icon, String val, String? unit, String label, LinearGradient grad,
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

  Widget _landCard(LandModel l, DColors c) {
    final t = _harvests.where((h) => h.landId == l.id).fold(0.0, (s, h) => s + h.weightKg);
    final cls = [[const Color(0xFF059669), const Color(0xFF34D399)], [const Color(0xFF7C3AED), const Color(0xFFA78BFA)],
      [const Color(0xFF0891B2), const Color(0xFF22D3EE)], [const Color(0xFFD97706), const Color(0xFFFBBF24)]];
    final ci = _myLands.indexOf(l) % cls.length;
    return SizedBox(width: 170, child: Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cls[ci][0].withOpacity(0.15), cls[ci][1].withOpacity(0.05)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: cls[ci][0].withOpacity(0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(
              color: cls[ci][0].withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.terrain_rounded, size: 14, color: cls[ci][1])),
          const SizedBox(width: 8),
          Expanded(child: Text(l.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: c.textPrimary),
              overflow: TextOverflow.ellipsis)),
        ]),
        const Spacer(),
        Text('${l.sizeHectares} Ha', style: GoogleFonts.inter(fontSize: 11, color: c.textMuted)),
        const SizedBox(height: 2),
        Text('${t.toStringAsFixed(1)} KG', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: cls[ci][1])),
      ])));
  }

  Widget _tfPills(DColors c) => Container(padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.border)),
    child: Row(children: _tfs.map((tf) {
      final a = tf == _chartTf;
      return Expanded(child: GestureDetector(onTap: () => setState(() => _chartTf = tf),
        child: AnimatedContainer(duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(gradient: a ? AppColors.gradientPrimary : null, borderRadius: BorderRadius.circular(9)),
          child: Text(tf, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12,
              fontWeight: a ? FontWeight.w700 : FontWeight.w500, color: a ? Colors.white : c.textMuted)))));
    }).toList()));

  Widget _empty(String t, IconData i, DColors c) => Container(width: double.infinity, padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(i, size: 40, color: c.textMuted), const SizedBox(height: 12),
      Text(t, style: GoogleFonts.inter(color: c.textMuted, fontSize: 14))]));

  Widget _infoBanner(String t, DColors c) => Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AppColors.amber.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withOpacity(0.2))),
    child: Row(children: [Icon(Icons.info_outline_rounded, color: AppColors.amber, size: 16),
      const SizedBox(width: 10), Expanded(child: Text(t, style: GoogleFonts.inter(color: AppColors.amber, fontSize: 13)))]));

  Widget _exportBtn(DColors c) => Container(width: double.infinity,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: c.borderLight)),
    child: Material(color: c.surface, borderRadius: BorderRadius.circular(14),
      child: InkWell(borderRadius: BorderRadius.circular(14), onTap: _harvests.isEmpty ? null : () => _showExportDialog(),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.download_rounded, color: _harvests.isEmpty ? c.textMuted : AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text('Export Rekapitulasi', style: GoogleFonts.inter(
                color: _harvests.isEmpty ? c.textMuted : AppColors.primary, fontWeight: FontWeight.w600, fontSize: 14))])))));

  Widget _hCard(HarvestModel h, DColors c) {
    final n = _landNameMap[h.landId] ?? h.landName ?? h.landId;
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Row(children: [
        Container(width: 4, height: 44, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: c.textPrimary)),
          const SizedBox(height: 4),
          Row(children: [Icon(Icons.calendar_today_rounded, size: 11, color: c.textMuted), const SizedBox(width: 4),
            Text(DateFormat('dd MMM yyyy').format(h.harvestDate), style: GoogleFonts.inter(fontSize: 11, color: c.textMuted))])
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${h.weightKg}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: c.textPrimary)),
          Text('KG', style: GoogleFonts.inter(fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w600)),
        ]),
      ]));
  }

  // ═══════════════════════════════════════════════════
  // CHART
  // ═══════════════════════════════════════════════════
  String _gk(DateTime d) {
    switch (_chartTf) {
      case 'Harian': return DateFormat('dd MMM yy').format(d);
      case '2 Minggu': return DateFormat('dd MMM yy').format(_bw(d));
      case '1 Bulan': return DateFormat('MMM yyyy').format(d);
      case '3 Bulan': return 'Q${((d.month - 1) ~/ 3) + 1} ${d.year}';
      default: return DateFormat('dd MMM yy').format(d);
    }
  }
  DateTime _sk(DateTime d) {
    switch (_chartTf) {
      case 'Harian': return DateTime(d.year, d.month, d.day);
      case '2 Minggu': return _bw(d);
      case '1 Bulan': return DateTime(d.year, d.month);
      case '3 Bulan': return DateTime(d.year, ((d.month - 1) ~/ 3) * 3 + 1);
      default: return DateTime(d.year, d.month, d.day);
    }
  }
  DateTime _bw(DateTime d) { final e = DateTime(2020,1,6); final ds = d.difference(e).inDays; return e.add(Duration(days: ds-(ds%14))); }

  Widget _chart(DColors c) {
    final Map<DateTime, _B> bk = {};
    for (var h in _harvests) { final sk = _sk(h.harvestDate); final lb = _gk(h.harvestDate);
      bk.putIfAbsent(sk, () => _B(lb, 0)); bk[sk]!.t += h.weightKg; }
    final keys = bk.keys.toList()..sort();
    final e = keys.map((k) => bk[k]!).toList();
    if (e.isEmpty) return _empty('Tidak ada data', Icons.show_chart_rounded, c);
    final my = e.map((x) => x.t).reduce((a, b) => a > b ? a : b);
    return Container(height: 280, padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      child: LineChart(LineChartData(minY: 0, maxY: my * 1.2,
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
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false))),
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
              begin: Alignment.topCenter, end: Alignment.bottomCenter)))])));
  }

  // ═══════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════
  void _showMonthPicker() {
    int tm = _selMonth, ty = _selYear;
    const mn = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agt','Sep','Okt','Nov','Des'];
    showModalBottomSheet(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, ss) { final c = context.dc; return Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: c.surfaceBright, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Pilih Bulan & Tahun', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => ss(() => ty--)),
            Text('$ty', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary)),
            IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: ty < DateTime.now().year ? () => ss(() => ty++) : null),
          ]),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: List.generate(12, (i) {
            final m = i + 1; final sel = m == tm; final fut = ty == DateTime.now().year && m > DateTime.now().month;
            return GestureDetector(onTap: fut ? null : () => ss(() => tm = m),
              child: AnimatedContainer(duration: const Duration(milliseconds: 150), width: 58, height: 38, alignment: Alignment.center,
                decoration: BoxDecoration(gradient: sel ? AppColors.gradientPrimary : null, color: sel ? null : c.surfaceLight,
                    borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? Colors.transparent : c.border)),
                child: Text(mn[i], style: GoogleFonts.inter(fontSize: 13, fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: fut ? c.textMuted : sel ? Colors.white : c.textSecondary))));
          })),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: Container(
            decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(12)),
            child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
              onPressed: () { setState(() { _selMonth = tm; _selYear = ty; }); Navigator.pop(ctx); },
              child: const Text('Terapkan')))),
        ])); }));
  }

  void _showExportDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Export Data', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _eTile(ctx, Icons.date_range_rounded, '6 Bulan Terakhir', AppColors.cyan, () { Navigator.pop(ctx); _eRange(180, '6 Bulan Terakhir'); }),
        const SizedBox(height: 8),
        _eTile(ctx, Icons.calendar_today_rounded, '1 Tahun Terakhir', AppColors.primary, () { Navigator.pop(ctx); _eRange(365, '1 Tahun Terakhir'); }),
      ])));
  }
  Widget _eTile(BuildContext ctx, IconData i, String t, Color cl, VoidCallback onTap) => Material(
    color: cl.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
    child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap,
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [Icon(i, color: cl, size: 20), const SizedBox(width: 12),
          Expanded(child: Text(t, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: context.dc.textPrimary))),
          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.dc.textMuted)]))));

  void _eRange(int d, String l) {
    final now = DateTime.now(); final s = now.subtract(Duration(days: d));
    final f = _harvests.where((h) => h.harvestDate.isAfter(s) && h.harvestDate.isBefore(now.add(const Duration(days: 1)))).toList();
    _fmtDialog(f, l);
  }
  void _fmtDialog(List<HarvestModel> data, String label) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text('Format — $label', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _eTile(ctx, Icons.picture_as_pdf_rounded, 'PDF', AppColors.rose, () async { Navigator.pop(ctx);
          try { await ExportService.exportToPDF(context, data, label, _landNameMap); }
          catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'))); } }),
        const SizedBox(height: 8),
        _eTile(ctx, Icons.table_chart_rounded, 'Excel', AppColors.primary, () async { Navigator.pop(ctx);
          try { await ExportService.exportToExcel(data, label, _landNameMap);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File Excel diunduh!')));
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'))); } }),
      ])));
  }
}

class _B { final String l; double t; _B(this.l, this.t); }
