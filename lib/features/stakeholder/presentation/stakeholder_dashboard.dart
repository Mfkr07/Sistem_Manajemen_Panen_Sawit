import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/presentation/harvest_history_page.dart';
import '../../../core/repositories/harvest_repository.dart';
import '../../../core/repositories/land_repository.dart';
import '../../../core/models/models.dart';
import '../../../core/services/export_service.dart';

class StakeholderDashboardPage extends StatefulWidget {
  const StakeholderDashboardPage({super.key});

  @override
  State<StakeholderDashboardPage> createState() => _StakeholderDashboardPageState();
}

class _StakeholderDashboardPageState extends State<StakeholderDashboardPage> {
  final HarvestRepository _harvestRepo = HarvestRepository();
  final LandRepository _landRepo = LandRepository();

  List<HarvestModel> _harvests = [];
  List<LandModel> _myLands = [];
  Map<String, String> _landNameMap = {};
  bool _isLoading = true;
  String? _currentUserId;
  String _currentUserEmail = '';
  String _currentUserName = '';

  // Chart timeframe
  String _chartTimeframe = '1 Bulan';
  final List<String> _chartTimeframes = ['2 Minggu', '1 Bulan', '3 Bulan'];

  // Monthly total
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    final user = Supabase.instance.client.auth.currentUser;
    _currentUserId = user?.id;
    _currentUserEmail = user?.email ?? '';
    _loadData();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      if (_currentUserId != null) {
        final data = await Supabase.instance.client
            .from('users').select('name').eq('id', _currentUserId!).single();
        if (mounted) setState(() => _currentUserName = data['name'] ?? '');
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (_currentUserId == null) { setState(() => _isLoading = false); return; }
      _myLands = await _landRepo.getLandsByStakeholder(_currentUserId!);
      _landNameMap = {for (var l in _myLands) l.id: l.name};
      final landIds = _myLands.map((l) => l.id).toList();
      _harvests = landIds.isNotEmpty ? await _harvestRepo.getHarvestsByLandIds(landIds) : [];
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data: $e')));
    }
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
        title: const Text('Dashboard Stakeholder'),
        backgroundColor: Colors.teal.shade700,
        leading: Builder(
          builder: (ctx) => IconButton(icon: const Icon(Icons.menu), tooltip: 'Menu',
            onPressed: () => Scaffold.of(ctx).openDrawer()),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () { setState(() => _isLoading = true); _loadData(); }),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lands horizontal list
                      Text('Lahan Anda', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      if (_myLands.isEmpty)
                        Card(color: Colors.orange.shade50, child: const Padding(padding: EdgeInsets.all(16),
                          child: Row(children: [Icon(Icons.info_outline, color: Colors.orange), SizedBox(width: 10),
                            Expanded(child: Text('Belum ada lahan yang terdaftar atas nama Anda. Hubungi admin.'))])))
                      else
                        SizedBox(height: 100, child: ListView.separated(
                          scrollDirection: Axis.horizontal, itemCount: _myLands.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (_, i) {
                            final land = _myLands[i];
                            final landTotal = _harvests.where((h) => h.landId == land.id).fold(0.0, (sum, h) => sum + h.weightKg);
                            return SizedBox(width: 180, child: Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Icon(Icons.terrain, size: 16, color: Colors.teal.shade600), const SizedBox(width: 6),
                                  Expanded(child: Text(land.name, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                                ]),
                                const Spacer(),
                                Text('${land.sizeHectares} Ha', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                Text('${landTotal.toStringAsFixed(1)} KG', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
                              ]))));
                          },
                        )),
                      const SizedBox(height: 24),

                      // Summary cards
                      Row(children: [
                        Expanded(child: _buildMonthlyTotalCard()),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSummaryCard(context, 'Jumlah Lahan', '${_myLands.length}', Icons.terrain)),
                      ]),
                      const SizedBox(height: 24),

                      // Chart with timeframe
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Tren Panen', style: Theme.of(context).textTheme.titleLarge),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                            value: _chartTimeframe, isDense: true,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.teal.shade700),
                            items: _chartTimeframes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) { if (v != null) setState(() => _chartTimeframe = v); },
                          ))),
                      ]),
                      const SizedBox(height: 12),
                      SizedBox(height: 260,
                        child: _chartHarvests.isEmpty
                            ? Center(child: Text('Belum ada data pada periode $_chartTimeframe'))
                            : _buildLineChart()),
                      const SizedBox(height: 16),

                      // Export
                      SizedBox(width: double.infinity, child: OutlinedButton.icon(
                        icon: const Icon(Icons.download), label: const Text('Export Rekapitulasi'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        onPressed: _harvests.isEmpty ? null : () => _showExportDialog(context),
                      )),
                      const SizedBox(height: 24),

                      // Recent history (5 items)
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Histori Panen Terkini', style: Theme.of(context).textTheme.titleLarge),
                        TextButton.icon(icon: const Icon(Icons.arrow_forward, size: 16), label: const Text('Lihat Semua'),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => HarvestHistoryPage(harvests: _harvests, landNameMap: _landNameMap, isAdmin: false),
                            ));
                          }),
                      ]),
                      const SizedBox(height: 8),
                      if (_harvests.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Belum ada data panen')))
                      else
                        ..._harvests.take(5).map((h) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
                            Container(padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.grass, color: Colors.teal.shade600, size: 22)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_landNameMap[h.landId] ?? h.landName ?? h.landId, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('Panen: ${DateFormat('dd MMM yyyy').format(h.harvestDate)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            ])),
                            Text('${h.weightKg} KG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal.shade700)),
                          ])))),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ============================================================
  // MONTHLY TOTAL CARD
  // ============================================================

  Widget _buildMonthlyTotalCard() {
    final now = DateTime.now();
    final isCurrentMonth = _selectedMonth == now.month && _selectedYear == now.year;

    return GestureDetector(
      onTap: () => _showMonthYearPicker(),
      child: Card(child: Padding(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(children: [
          Icon(Icons.monitor_weight, size: 28, color: Colors.teal.shade600),
          const SizedBox(height: 6),
          Text('${_selectedMonthTotal.toStringAsFixed(1)} KG',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal.shade700)),
          const SizedBox(height: 2),
          Text(isCurrentMonth ? 'Panen Bulan Ini' : _selectedMonthLabel,
              style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade500),
        ]))),
    );
  }

  void _showMonthYearPicker() {
    int tempMonth = _selectedMonth;
    int tempYear = _selectedYear;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'];

    showModalBottomSheet(context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Pilih Bulan & Tahun', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setSheetState(() => tempYear--)),
              Text('$tempYear', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.chevron_right),
                  onPressed: tempYear < DateTime.now().year ? () => setSheetState(() => tempYear++) : null),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: List.generate(12, (i) {
              final m = i + 1; final isSelected = m == tempMonth;
              final isFuture = tempYear == DateTime.now().year && m > DateTime.now().month;
              return ChoiceChip(
                label: SizedBox(width: 40, child: Text(months[i], textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : isFuture ? Colors.grey.shade400 : null))),
                selected: isSelected, selectedColor: Colors.teal.shade700,
                onSelected: isFuture ? null : (_) => setSheetState(() => tempMonth = m),
              );
            })),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () { setState(() { _selectedMonth = tempMonth; _selectedYear = tempYear; }); Navigator.pop(ctx); },
              child: const Text('Terapkan'))),
          ]))));
  }

  // ============================================================
  // DRAWER
  // ============================================================

  Widget _buildDrawer(BuildContext context) {
    return Drawer(child: Column(children: [
      UserAccountsDrawerHeader(
        decoration: BoxDecoration(color: Colors.teal.shade700),
        accountName: Text(_currentUserName.isEmpty ? 'Stakeholder' : _currentUserName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        accountEmail: Text(_currentUserEmail),
        currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white,
            child: Icon(Icons.person, size: 36, color: Colors.teal)),
      ),
      ListTile(leading: const Icon(Icons.history), title: const Text('Histori Panen'),
        subtitle: const Text('Lihat semua data panen'),
        onTap: () { Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => HarvestHistoryPage(harvests: _harvests, landNameMap: _landNameMap, isAdmin: false)));
        }),
      ListTile(leading: const Icon(Icons.download), title: const Text('Export Rekapitulasi'),
        onTap: () { Navigator.pop(context); if (_harvests.isNotEmpty) _showExportDialog(context); }),
      const Spacer(),
      const Divider(height: 1),
      ListTile(leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text('Keluar', style: TextStyle(color: Colors.red)),
        onTap: () { Navigator.pop(context); _logout(); }),
      const SizedBox(height: 16),
    ]));
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

    final Map<String, double> grouped = {};
    for (var h in data) {
      final key = DateFormat(dateFormat).format(h.harvestDate);
      grouped[key] = (grouped[key] ?? 0) + h.weightKg;
    }
    final entries = grouped.entries.toList();
    if (entries.isEmpty) return const Center(child: Text('Tidak ada data'));
    final maxY = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Card(elevation: 2, child: Padding(padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      child: LineChart(LineChartData(
        minY: 0, maxY: maxY * 1.2,
        gridData: FlGridData(show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: 1,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= entries.length) return const SizedBox();
              final step = entries.length > 10 ? 3 : entries.length > 6 ? 2 : 1;
              if (idx % step != 0 && idx != entries.length - 1) return const SizedBox();
              return Padding(padding: const EdgeInsets.only(top: 8),
                child: Text(entries[idx].key, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500)));
            })),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 48,
            getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)))),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => Colors.blueGrey.shade800,
          getTooltipItems: (spots) => spots.map((spot) {
            final idx = spot.spotIndex;
            return LineTooltipItem('${entries[idx].key}\n${spot.y.toStringAsFixed(1)} KG',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12));
          }).toList())),
        lineBarsData: [LineChartBarData(
          spots: List.generate(entries.length, (i) => FlSpot(i.toDouble(), entries[i].value)),
          isCurved: true, curveSmoothness: 0.3,
          gradient: LinearGradient(colors: [Colors.teal.shade400, Colors.teal.shade700]),
          barWidth: 3, isStrokeCapRound: true,
          dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) =>
              FlDotCirclePainter(radius: 4, color: Colors.teal.shade700, strokeWidth: 2, strokeColor: Colors.white)),
          belowBarData: BarAreaData(show: true, gradient: LinearGradient(
              colors: [Colors.teal.withOpacity(0.2), Colors.teal.withOpacity(0.02)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        )],
      ))));
  }

  // ============================================================
  // DIALOGS
  // ============================================================

  void _showExportDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('Export Data Lahan Anda'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.date_range, color: Colors.blue), title: const Text('6 Bulan Terakhir'),
          onTap: () { Navigator.pop(ctx); _exportWithRange(180, '6 Bulan Terakhir'); }),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.calendar_today, color: Colors.green), title: const Text('1 Tahun Terakhir'),
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

  Widget _buildSummaryCard(BuildContext context, String title, String value, IconData icon) {
    return Card(elevation: 2, child: Padding(padding: const EdgeInsets.all(16.0),
      child: Column(children: [
        Icon(icon, size: 32, color: Colors.teal.shade600), const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.bodyMedium), const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal.shade700)),
      ])));
  }
}
