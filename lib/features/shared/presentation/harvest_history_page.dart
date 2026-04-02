import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_colors.dart';
import '../../admin/presentation/edit_harvest_form.dart';

class HarvestHistoryPage extends StatefulWidget {
  final List<HarvestModel> harvests;
  final Map<String, String> landNameMap;
  final bool isAdmin;

  const HarvestHistoryPage({super.key, required this.harvests, required this.landNameMap, this.isAdmin = false});

  @override
  State<HarvestHistoryPage> createState() => _HarvestHistoryPageState();
}

class _HarvestHistoryPageState extends State<HarvestHistoryPage> {
  late List<HarvestModel> _filtered;
  String _selectedFilter = 'Semua';
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _filterOptions = ['Semua', '7 Hari', '1 Bulan', '3 Bulan', '6 Bulan', '1 Tahun', 'Kustom'];

  @override
  void initState() { super.initState(); _filtered = List.from(widget.harvests); }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      final now = DateTime.now();
      switch (filter) {
        case 'Semua': _filtered = List.from(widget.harvests); _startDate = null; _endDate = null; break;
        case '7 Hari': _startDate = now.subtract(const Duration(days: 7)); _endDate = now; break;
        case '1 Bulan': _startDate = DateTime(now.year, now.month - 1, now.day); _endDate = now; break;
        case '3 Bulan': _startDate = DateTime(now.year, now.month - 3, now.day); _endDate = now; break;
        case '6 Bulan': _startDate = now.subtract(const Duration(days: 180)); _endDate = now; break;
        case '1 Tahun': _startDate = now.subtract(const Duration(days: 365)); _endDate = now; break;
        case 'Kustom': _pickDateRange(); return;
      }
      if (_startDate != null && _endDate != null) {
        _filtered = widget.harvests.where((h) =>
            h.harvestDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
            h.harvestDate.isBefore(_endDate!.add(const Duration(days: 1)))).toList();
      }
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()),
      builder: (ctx, child) => Theme(data: Theme.of(ctx), child: child!));
    if (picked != null) {
      setState(() {
        _startDate = picked.start; _endDate = picked.end; _selectedFilter = 'Kustom';
        _filtered = widget.harvests.where((h) =>
            h.harvestDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
            h.harvestDate.isBefore(_endDate!.add(const Duration(days: 1)))).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final totalWeight = _filtered.fold(0.0, (sum, h) => sum + h.weightKg);

    return Scaffold(
      appBar: AppBar(title: Text('Histori Panen', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18))),
      body: SafeArea(child: Column(children: [
        // Filter bar
        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: c.surface, border: Border(bottom: BorderSide(color: c.border))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(
              children: _filterOptions.map((opt) {
                final sel = _selectedFilter == opt;
                return Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
                  onTap: () => _applyFilter(opt),
                  child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: sel ? AppColors.gradientPrimary : null,
                      color: sel ? null : c.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? Colors.transparent : c.border)),
                    child: Text(opt, style: GoogleFonts.inter(fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? Colors.white : c.textMuted))),
                ));
              }).toList())),
            const SizedBox(height: 10),
            Row(children: [
              if (_startDate != null && _endDate != null)
                Expanded(child: Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 12, color: c.textMuted), const SizedBox(width: 6),
                  Text('${DateFormat('dd MMM yyyy').format(_startDate!)} — ${DateFormat('dd MMM yyyy').format(_endDate!)}',
                      style: GoogleFonts.inter(fontSize: 12, color: c.textSecondary))]))
              else
                Expanded(child: Text('Semua waktu', style: GoogleFonts.inter(fontSize: 12, color: c.textMuted))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('${_filtered.length} data • ${totalWeight.toStringAsFixed(1)} KG',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
            ]),
          ]),
        ),
        // List
        Expanded(child: _filtered.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.inbox_rounded, size: 56, color: c.textMuted), const SizedBox(height: 16),
                Text('Tidak ada data panen\npada periode ini', textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: c.textMuted, fontSize: 14))]))
            : ListView.builder(padding: const EdgeInsets.all(16), itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final h = _filtered[index];
                  final landName = widget.landNameMap[h.landId] ?? h.landName ?? h.landId;
                  final isPending = h.syncStatus == 'pending';
                  final accentColor = isPending ? AppColors.amber : AppColors.primary;

                  return Container(margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.border)),
                    child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(14),
                      child: InkWell(borderRadius: BorderRadius.circular(14), onTap: () => _showDetail(h, landName),
                        child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                          Container(width: 4, height: 44, decoration: BoxDecoration(
                              color: accentColor, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(landName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: c.textPrimary)),
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.calendar_today_rounded, size: 11, color: c.textMuted), const SizedBox(width: 4),
                              Text(DateFormat('dd MMM yyyy').format(h.harvestDate),
                                  style: GoogleFonts.inter(fontSize: 11, color: c.textMuted)),
                              if (isPending) ...[const SizedBox(width: 8),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(color: AppColors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                  child: Text('PENDING', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.amber)))],
                            ]),
                            Text('Upload: ${DateFormat('dd MMM yyyy HH:mm').format(h.createdAt)}',
                                style: GoogleFonts.inter(fontSize: 10, color: c.textMuted)),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('${h.weightKg}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: c.textPrimary)),
                            Text('KG', style: GoogleFonts.inter(fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w600)),
                          ]),
                          if (widget.isAdmin) ...[const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () async {
                                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditHarvestForm(harvest: h)));
                                if (result == true && mounted) Navigator.pop(context, true);
                              },
                              child: Container(padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(color: c.surfaceLight, borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: c.border)),
                                child: Icon(Icons.edit_rounded, size: 14, color: c.textSecondary)))],
                        ])))));
                })),
      ])),
    );
  }

  void _showDetail(HarvestModel h, String landName) {
    final c = context.dc;
    showModalBottomSheet(context: context, builder: (ctx) => Padding(padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: c.surfaceBright, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        Text('Detail Panen', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 16), const Divider(), const SizedBox(height: 8),
        _detailRow('Lahan', landName), _detailRow('Berat', '${h.weightKg} KG'),
        _detailRow('Tanggal Panen', DateFormat('dd MMMM yyyy, HH:mm').format(h.harvestDate)),
        _detailRow('Upload', DateFormat('dd MMMM yyyy, HH:mm').format(h.createdAt)),
        _detailRow('Terakhir Edit', DateFormat('dd MMMM yyyy, HH:mm').format(h.updatedAt)),
        _detailRow('Status', h.syncStatus == 'pending' ? '⏳ Menunggu' : '✅ Tersinkron'),
        if (widget.isAdmin) ...[const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: Container(
            decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(12)),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
              icon: const Icon(Icons.edit_rounded), label: const Text('Edit Data Ini'),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => EditHarvestForm(harvest: h)))
                    .then((result) { if (result == true && mounted) Navigator.pop(context, true); });
              })))],
      ])));
  }

  Widget _detailRow(String label, String value) {
    final c = context.dc;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 120, child: Text(label, style: GoogleFonts.inter(color: c.textMuted, fontSize: 13))),
      Expanded(child: Text(value, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: c.textPrimary))),
    ]));
  }
}
