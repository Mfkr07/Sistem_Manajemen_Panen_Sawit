import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'input_harvest_form.dart';
import 'edit_harvest_form.dart';
import 'manage_lands_page.dart';
import 'manage_accounts_page.dart';
import '../../shared/presentation/harvest_history_page.dart';
import '../../../core/database/local_db.dart';
import '../../../core/models/models.dart';
import '../../../core/repositories/harvest_repository.dart';
import '../../../core/repositories/land_repository.dart';
import '../../../core/services/export_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  List<HarvestModel> _harvests = [];
  Map<String, String> _landNameMap = {};
  bool _isLoading = true;
  bool _isSyncing = false;
  int _pendingCount = 0;
  String _currentUserEmail = '';
  String _currentUserName = '';

  // Chart timeframe
  String _chartTimeframe = '1 Bulan';
  final List<String> _chartTimeframes = ['2 Minggu', '1 Bulan', '3 Bulan'];

  // Monthly total card — selected month/year
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    final user = Supabase.instance.client.auth.currentUser;
    _currentUserEmail = user?.email ?? '';
    _loadData();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final data = await Supabase.instance.client
            .from('users').select('name').eq('id', userId).single();
        if (mounted) setState(() => _currentUserName = data['name'] ?? '');
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final lands = await LandRepository().getAllLands();
      _landNameMap = {for (var l in lands) l.id: l.name};

      final localData = await LocalDatabase.instance.getAllHarvests();
      _pendingCount = localData.where((h) => h.syncStatus == 'pending').length;

      List<HarvestModel> serverData = [];
      try { serverData = await HarvestRepository().getAllHarvestsFromServer(); } catch (_) {}

      final localIds = localData.map((h) => h.id).toSet();
      final mergedList = <HarvestModel>[
        ...localData,
        ...serverData.where((h) => !localIds.contains(h.id)),
      ];
      mergedList.sort((a, b) => b.harvestDate.compareTo(a.harvestDate));

      setState(() { _harvests = mergedList; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncData() async {
    setState(() => _isSyncing = true);
    try {
      final synced = await HarvestRepository().syncPendingHarvests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$synced data berhasil disinkronkan!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal sinkronisasi: $e')));
      }
    }
    setState(() => _isSyncing = false);
    await _loadData();
  }

  void _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  // ============================================================
  // HELPERS
  // ============================================================

  double get _selectedMonthTotal {
    return _harvests.where((h) =>
        h.harvestDate.month == _selectedMonth && h.harvestDate.year == _selectedYear
    ).fold(0.0, (sum, h) => sum + h.weightKg);
  }

  String get _selectedMonthLabel {
    final months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${months[_selectedMonth - 1]} $_selectedYear';
  }

  List<HarvestModel> get _chartHarvests {
    final now = DateTime.now();
    late DateTime cutoff;
    switch (_chartTimeframe) {
      case '2 Minggu': cutoff = now.subtract(const Duration(days: 14)); break;
      case '1 Bulan': cutoff = DateTime(now.year, now.month - 1, now.day); break;
      case '3 Bulan': cutoff = DateTime(now.year, now.month - 3, now.day); break;
      default: cutoff = DateTime(now.year, now.month - 1, now.day);
    }
    return _harvests.where((h) => h.harvestDate.isAfter(cutoff)).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(context),
      appBar: AppBar(
        title: const Text('Dashboard Admin'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu), tooltip: 'Menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else
            IconButton(
              icon: Badge(
                isLabelVisible: _pendingCount > 0, label: Text('$_pendingCount'),
                child: const Icon(Icons.sync),
              ),
              tooltip: 'Sync Offline Data', onPressed: _syncData,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const InputHarvestForm()));
          if (result == true) _loadData();
        },
        icon: const Icon(Icons.add), label: const Text('Input Panen'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_pendingCount > 0) ...[_buildSyncWarningBanner(), const SizedBox(height: 16)],

                      // ===== SUMMARY CARDS =====
                      Row(
                        children: [
                          // Total Panen Bulan Ini (tappable)
                          Expanded(child: _buildMonthlyTotalCard()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildSummaryCard(
                            'Jumlah Data', '${_harvests.length}', Icons.list_alt, Colors.blue,
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _buildSummaryCard(
                            'Menunggu Sync', '$_pendingCount', Icons.cloud_upload,
                            _pendingCount > 0 ? Colors.orange : Colors.grey,
                          )),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ===== CHART WITH TIMEFRAME SELECTOR =====
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tren Panen', style: Theme.of(context).textTheme.titleLarge),
                          // Timeframe selector
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _chartTimeframe,
                                isDense: true,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Theme.of(context).primaryColor),
                                items: _chartTimeframes.map((t) =>
                                    DropdownMenuItem(value: t, child: Text(t))
                                ).toList(),
                                onChanged: (v) { if (v != null) setState(() => _chartTimeframe = v); },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 260,
                        child: _chartHarvests.isEmpty
                            ? Center(child: Text('Belum ada data pada periode $_chartTimeframe'))
                            : _buildLineChart(),
                      ),
                      const SizedBox(height: 24),

                      // ===== PIE CHART =====
                      Text('Distribusi per Lahan', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 220,
                        child: _harvests.isEmpty ? const Center(child: Text('Belum ada data')) : _buildPieChart(),
                      ),
                      const SizedBox(height: 24),

                      // ===== EXPORT =====
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.download), label: const Text('Export Rekapitulasi'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          onPressed: () => _showExportDialog(context),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ===== RECENT HISTORY (5 items) =====
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Histori Panen Terkini', style: Theme.of(context).textTheme.titleLarge),
                          TextButton.icon(
                            icon: const Icon(Icons.arrow_forward, size: 16),
                            label: const Text('Lihat Semua'),
                            onPressed: () async {
                              final result = await Navigator.push(context, MaterialPageRoute(
                                builder: (_) => HarvestHistoryPage(
                                  harvests: _harvests, landNameMap: _landNameMap, isAdmin: true,
                                ),
                              ));
                              if (result == true) _loadData();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_harvests.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Belum ada data panen')))
                      else
                        ..._harvests.take(5).map((h) => _buildHarvestCard(h)),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // ============================================================
  // MONTHLY TOTAL CARD (Tappable)
  // ============================================================

  Widget _buildMonthlyTotalCard() {
    final now = DateTime.now();
    final isCurrentMonth = _selectedMonth == now.month && _selectedYear == now.year;

    return GestureDetector(
      onTap: () => _showMonthYearPicker(),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Column(
            children: [
              Icon(Icons.monitor_weight, color: Colors.green, size: 24),
              const SizedBox(height: 6),
              Text(
                '${_selectedMonthTotal.toStringAsFixed(1)} KG',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
              ),
              const SizedBox(height: 2),
              Text(
                isCurrentMonth ? 'Panen Bulan Ini' : _selectedMonthLabel,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  void _showMonthYearPicker() {
    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Pilih Bulan & Tahun', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),

              // Year selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setSheetState(() => tempYear--),
                  ),
                  Text('$tempYear', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: tempYear < DateTime.now().year ? () => setSheetState(() => tempYear++) : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Month grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(12, (i) {
                  final m = i + 1;
                  final isSelected = m == tempMonth;
                  final isFuture = tempYear == DateTime.now().year && m > DateTime.now().month;
                  return ChoiceChip(
                    label: SizedBox(width: 40, child: Text(months[i], textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : isFuture ? Colors.grey.shade400 : null))),
                    selected: isSelected,
                    selectedColor: Theme.of(context).primaryColor,
                    onSelected: isFuture ? null : (_) => setSheetState(() => tempMonth = m),
                  );
                }),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedMonth = tempMonth;
                      _selectedYear = tempYear;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Terapkan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DRAWER
  // ============================================================

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            accountName: Text(_currentUserName.isEmpty ? 'Admin' : _currentUserName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            accountEmail: Text(_currentUserEmail),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.admin_panel_settings, size: 36, color: Theme.of(context).primaryColor),
            ),
          ),
          ListTile(leading: const Icon(Icons.terrain), title: const Text('Manajemen Lahan'),
            subtitle: const Text('Kelola lahan & pemilik'),
            onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageLandsPage())).then((_) => _loadData()); },
          ),
          ListTile(leading: const Icon(Icons.people_outline), title: const Text('Manajemen Akun'),
            subtitle: const Text('Kelola user & role'),
            onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageAccountsPage())); },
          ),
          ListTile(leading: const Icon(Icons.history), title: const Text('Histori Panen'),
            subtitle: const Text('Lihat semua data panen'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => HarvestHistoryPage(harvests: _harvests, landNameMap: _landNameMap, isAdmin: true),
              )).then((result) { if (result == true) _loadData(); });
            },
          ),
          const Divider(),
          ListTile(leading: Icon(Icons.delete_sweep, color: Colors.orange.shade700), title: const Text('Hapus Data Offline'),
            onTap: () { Navigator.pop(context); _showClearConfirm(); },
          ),
          const Spacer(),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Keluar', style: TextStyle(color: Colors.red)),
            onTap: () { Navigator.pop(context); _logout(); },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ============================================================
  // LINE CHART
  // ============================================================

  Widget _buildLineChart() {
    final data = _chartHarvests;
    final String dateFormat;
    switch (_chartTimeframe) {
      case '2 Minggu': dateFormat = 'dd MMM'; break;
      case '1 Bulan': dateFormat = 'dd MMM'; break;
      case '3 Bulan': dateFormat = 'MMM yy'; break;
      default: dateFormat = 'dd MMM';
    }

    // Group by date key
    final Map<String, double> grouped = {};
    for (var h in data) {
      final key = DateFormat(dateFormat).format(h.harvestDate);
      grouped[key] = (grouped[key] ?? 0) + h.weightKg;
    }

    final entries = grouped.entries.toList();
    if (entries.isEmpty) return const Center(child: Text('Tidak ada data'));

    final maxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
        child: LineChart(
          LineChartData(
            minY: 0, maxY: maxY * 1.2,
            gridData: FlGridData(show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= entries.length) return const SizedBox();
                  // Show every Nth label to avoid overlap
                  final step = entries.length > 10 ? 3 : entries.length > 6 ? 2 : 1;
                  if (idx % step != 0 && idx != entries.length - 1) return const SizedBox();
                  return Padding(padding: const EdgeInsets.only(top: 8),
                    child: Text(entries[idx].key, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500)));
                },
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 48,
                getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)))),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.blueGrey.shade800,
                getTooltipItems: (spots) => spots.map((spot) {
                  final idx = spot.spotIndex;
                  return LineTooltipItem(
                    '${entries[idx].key}\n${spot.y.toStringAsFixed(1)} KG',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  );
                }).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(entries.length, (i) => FlSpot(i.toDouble(), entries[i].value)),
                isCurved: true, curveSmoothness: 0.3,
                gradient: LinearGradient(colors: [Theme.of(context).primaryColor.withOpacity(0.8), Theme.of(context).primaryColor]),
                barWidth: 3, isStrokeCapRound: true,
                dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(radius: 4, color: Theme.of(context).primaryColor, strokeWidth: 2, strokeColor: Colors.white)),
                belowBarData: BarAreaData(show: true, gradient: LinearGradient(
                    colors: [Theme.of(context).primaryColor.withOpacity(0.2), Theme.of(context).primaryColor.withOpacity(0.02)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PIE CHART
  // ============================================================

  Widget _buildPieChart() {
    final Map<String, double> landData = {};
    for (var h in _harvests) {
      final name = _landNameMap[h.landId] ?? h.landName ?? h.landId;
      landData[name] = (landData[name] ?? 0) + h.weightKg;
    }
    if (landData.isEmpty) return const Center(child: Text('Tidak ada data'));

    final colors = [Colors.green.shade600, Colors.blue.shade600, Colors.orange.shade600,
      Colors.purple.shade600, Colors.teal.shade600, Colors.red.shade600, Colors.indigo.shade600, Colors.amber.shade700];
    final entries = landData.entries.toList();
    final total = entries.fold(0.0, (sum, e) => sum + e.value);

    return Row(
      children: [
        Expanded(flex: 3, child: PieChart(PieChartData(
          sectionsSpace: 2, centerSpaceRadius: 32,
          sections: List.generate(entries.length, (i) {
            final pct = (entries[i].value / total * 100);
            return PieChartSectionData(value: entries[i].value,
              title: '${pct.toStringAsFixed(0)}%',
              titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              color: colors[i % colors.length], radius: 50);
          }),
        ))),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(entries.length, (i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[i % colors.length], borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              Expanded(child: Text(entries[i].key, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
            ]),
          )),
        )),
      ],
    );
  }

  // ============================================================
  // WIDGETS
  // ============================================================

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Column(children: [
        Icon(icon, color: color, size: 28), const SizedBox(height: 8),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        const SizedBox(height: 4),
        Text(title, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
      ])));
  }

  Widget _buildHarvestCard(HarvestModel h) {
    final landName = _landNameMap[h.landId] ?? h.landName ?? h.landId;
    final isPending = h.syncStatus == 'pending';
    return Card(margin: const EdgeInsets.only(bottom: 8), child: InkWell(
      borderRadius: BorderRadius.circular(12), onTap: () => _showDetailSheet(h),
      child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(
          color: (isPending ? Colors.orange : Colors.green).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(isPending ? Icons.cloud_off : Icons.cloud_done, color: isPending ? Colors.orange : Colors.green, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(landName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Panen: ${DateFormat('dd MMM yyyy').format(h.harvestDate)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text('Upload: ${DateFormat('dd MMM yyyy HH:mm').format(h.createdAt)} • Edit: ${DateFormat('dd MMM yyyy HH:mm').format(h.updatedAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${h.weightKg} KG', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          InkWell(onTap: () async {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditHarvestForm(harvest: h)));
            if (result == true) _loadData();
          }, borderRadius: BorderRadius.circular(4),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.edit, size: 14, color: Theme.of(context).primaryColor), const SizedBox(width: 4),
                Text('Edit', style: TextStyle(fontSize: 12, color: Theme.of(context).primaryColor, fontWeight: FontWeight.w500)),
              ]))),
        ]),
      ]))));
  }

  Widget _buildSyncWarningBanner() {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
      color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
      child: Row(children: [
        const Icon(Icons.cloud_off, color: Colors.orange, size: 20), const SizedBox(width: 10),
        Expanded(child: Text('$_pendingCount data menunggu sinkronisasi.',
            style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.w500, fontSize: 13))),
        TextButton(onPressed: _isSyncing ? null : _syncData, child: const Text('SYNC')),
      ]));
  }

  // ============================================================
  // DIALOGS
  // ============================================================

  void _showDetailSheet(HarvestModel h) {
    final landName = _landNameMap[h.landId] ?? h.landName ?? h.landId;
    showModalBottomSheet(context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text('Detail Panen', style: Theme.of(context).textTheme.titleLarge), const Divider(height: 24),
          _detailRow('Lahan', landName), _detailRow('Berat Panen', '${h.weightKg} KG'),
          _detailRow('Tanggal Panen', DateFormat('dd MMMM yyyy, HH:mm').format(h.harvestDate)),
          _detailRow('Waktu Upload', DateFormat('dd MMMM yyyy, HH:mm').format(h.createdAt)),
          _detailRow('Terakhir Diedit', DateFormat('dd MMMM yyyy, HH:mm').format(h.updatedAt)),
          _detailRow('Status Sync', h.syncStatus == 'pending' ? '⏳ Menunggu' : '✅ Tersinkron'),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.edit), label: const Text('Edit Data Ini'),
            onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => EditHarvestForm(harvest: h)))
                .then((result) { if (result == true) _loadData(); }); })),
        ])));
  }

  Widget _detailRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
      ]));
  }

  void _showExportDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Export Rekapitulasi'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.date_range, color: Colors.blue), title: const Text('6 Bulan Terakhir'),
          subtitle: Text('${DateFormat('dd MMM yyyy').format(DateTime.now().subtract(const Duration(days: 180)))} — ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: const TextStyle(fontSize: 11)),
          onTap: () { Navigator.pop(ctx); _exportWithRange(180, '6 Bulan Terakhir'); }),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.calendar_today, color: Colors.green), title: const Text('1 Tahun Terakhir'),
          subtitle: Text('${DateFormat('dd MMM yyyy').format(DateTime.now().subtract(const Duration(days: 365)))} — ${DateFormat('dd MMM yyyy').format(DateTime.now())}', style: const TextStyle(fontSize: 11)),
          onTap: () { Navigator.pop(ctx); _exportWithRange(365, '1 Tahun Terakhir'); }),
      ])));
  }

  void _exportWithRange(int days, String label) {
    final now = DateTime.now(); final start = now.subtract(Duration(days: days));
    final filtered = _harvests.where((h) => h.harvestDate.isAfter(start) && h.harvestDate.isBefore(now.add(const Duration(days: 1)))).toList();
    _showFormatDialog(filtered, label);
  }

  void _showFormatDialog(List<HarvestModel> data, String label) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text('Format Export — $label'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.picture_as_pdf, color: Colors.red), title: const Text('Export ke PDF'),
          subtitle: Text('${data.length} data panen'),
          onTap: () async { Navigator.pop(ctx);
            try { await ExportService.exportToPDF(context, data, label, _landNameMap); }
            catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export PDF gagal: $e'))); } }),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.table_chart, color: Colors.green), title: const Text('Export ke Excel'),
          subtitle: Text('${data.length} data panen'),
          onTap: () async { Navigator.pop(ctx);
            try { await ExportService.exportToExcel(data, label, _landNameMap);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File Excel telah diunduh!'), backgroundColor: Colors.green));
            } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export Excel gagal: $e'))); } }),
      ])));
  }

  void _showClearConfirm() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Hapus Data Offline?'),
      content: const Text('Semua data yang tersimpan secara lokal (termasuk yang belum disinkronkan) akan dihapus. Data yang sudah ada di server tidak terpengaruh.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async { Navigator.pop(ctx); await LocalDatabase.instance.clearDatabase();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data offline berhasil dihapus')));
            _loadData(); },
          child: const Text('Hapus')),
      ]));
  }
}
