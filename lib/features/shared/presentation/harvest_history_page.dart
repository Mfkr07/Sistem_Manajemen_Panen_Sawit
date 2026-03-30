import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/models.dart';
import '../../admin/presentation/edit_harvest_form.dart';

class HarvestHistoryPage extends StatefulWidget {
  final List<HarvestModel> harvests;
  final Map<String, String> landNameMap;
  final bool isAdmin;

  const HarvestHistoryPage({
    super.key,
    required this.harvests,
    required this.landNameMap,
    this.isAdmin = false,
  });

  @override
  State<HarvestHistoryPage> createState() => _HarvestHistoryPageState();
}

class _HarvestHistoryPageState extends State<HarvestHistoryPage> {
  late List<HarvestModel> _filtered;
  String _selectedFilter = 'Semua';
  DateTime? _startDate;
  DateTime? _endDate;

  final List<String> _filterOptions = [
    'Semua',
    '7 Hari',
    '1 Bulan',
    '3 Bulan',
    '6 Bulan',
    '1 Tahun',
    'Kustom',
  ];

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.harvests);
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      final now = DateTime.now();

      switch (filter) {
        case 'Semua':
          _filtered = List.from(widget.harvests);
          _startDate = null;
          _endDate = null;
          break;
        case '7 Hari':
          _startDate = now.subtract(const Duration(days: 7));
          _endDate = now;
          break;
        case '1 Bulan':
          _startDate = DateTime(now.year, now.month - 1, now.day);
          _endDate = now;
          break;
        case '3 Bulan':
          _startDate = DateTime(now.year, now.month - 3, now.day);
          _endDate = now;
          break;
        case '6 Bulan':
          _startDate = now.subtract(const Duration(days: 180));
          _endDate = now;
          break;
        case '1 Tahun':
          _startDate = now.subtract(const Duration(days: 365));
          _endDate = now;
          break;
        case 'Kustom':
          _pickDateRange();
          return;
      }

      if (_startDate != null && _endDate != null) {
        _filtered = widget.harvests.where((h) =>
            h.harvestDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
            h.harvestDate.isBefore(_endDate!.add(const Duration(days: 1)))
        ).toList();
      }
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
              start: DateTime.now().subtract(const Duration(days: 30)),
              end: DateTime.now(),
            ),
      locale: const Locale('id', 'ID'),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _filtered = widget.harvests.where((h) =>
            h.harvestDate.isAfter(_startDate!.subtract(const Duration(days: 1))) &&
            h.harvestDate.isBefore(_endDate!.add(const Duration(days: 1)))
        ).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalWeight = _filtered.fold(0.0, (sum, h) => sum + h.weightKg);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histori Panen'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter bar
            Container(
              width: double.infinity,
              color: Theme.of(context).primaryColor.withOpacity(0.05),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filterOptions.map((opt) {
                        final isSelected = _selectedFilter == opt;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(opt, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
                            selected: isSelected,
                            selectedColor: Theme.of(context).primaryColor,
                            onSelected: (_) => _applyFilter(opt),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Date range info & summary
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_startDate != null && _endDate != null)
                        Expanded(
                          child: Text(
                            '${DateFormat('dd MMM yyyy').format(_startDate!)} — ${DateFormat('dd MMM yyyy').format(_endDate!)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        )
                      else
                        Expanded(
                          child: Text('Semua waktu', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ),
                      Text(
                        '${_filtered.length} data • ${totalWeight.toStringAsFixed(1)} KG',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Tidak ada data panen\npada periode ini',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final h = _filtered[index];
                        final landName = widget.landNameMap[h.landId] ?? h.landName ?? h.landId;
                        final isPending = h.syncStatus == 'pending';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showDetail(h, landName),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (isPending ? Colors.orange : Colors.green).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isPending ? Icons.cloud_off : Icons.cloud_done,
                                      color: isPending ? Colors.orange : Colors.green,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(landName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Panen: ${DateFormat('dd MMM yyyy').format(h.harvestDate)}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        ),
                                        Text(
                                          'Upload: ${DateFormat('dd MMM yyyy HH:mm').format(h.createdAt)} • Edit: ${DateFormat('dd MMM yyyy HH:mm').format(h.updatedAt)}',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${h.weightKg} KG', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      if (widget.isAdmin) ...[
                                        const SizedBox(height: 4),
                                        InkWell(
                                          onTap: () async {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => EditHarvestForm(harvest: h)),
                                            );
                                            if (result == true && mounted) {
                                              Navigator.pop(context, true); // Return to dashboard to reload
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(4),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.edit, size: 14, color: Theme.of(context).primaryColor),
                                                const SizedBox(width: 4),
                                                Text('Edit', style: TextStyle(
                                                  fontSize: 12, color: Theme.of(context).primaryColor, fontWeight: FontWeight.w500,
                                                )),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(HarvestModel h, String landName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Detail Panen', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 24),
            _detailRow('Lahan', landName),
            _detailRow('Berat Panen', '${h.weightKg} KG'),
            _detailRow('Tanggal Panen', DateFormat('dd MMMM yyyy, HH:mm').format(h.harvestDate)),
            _detailRow('Waktu Upload', DateFormat('dd MMMM yyyy, HH:mm').format(h.createdAt)),
            _detailRow('Terakhir Diedit', DateFormat('dd MMMM yyyy, HH:mm').format(h.updatedAt)),
            _detailRow('Status Sync', h.syncStatus == 'pending' ? '⏳ Menunggu' : '✅ Tersinkron'),
            if (widget.isAdmin) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Data Ini'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => EditHarvestForm(harvest: h),
                    )).then((result) {
                      if (result == true && mounted) {
                        Navigator.pop(context, true);
                      }
                    });
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}
