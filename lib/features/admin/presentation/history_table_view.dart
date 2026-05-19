import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/models.dart';

class HistoryTableView extends StatefulWidget {
  final List<HarvestModel> harvests;
  final List<LandModel> lands;
  final DColors c;
  final Function(HarvestModel)? onEdit;
  final VoidCallback onExport;
  final String? landFilter;
  final Function(String?) onLandFilterChanged;
  final String dateFilter;
  final Function(String) onDateFilterChanged;

  const HistoryTableView({
    super.key,
    required this.harvests,
    required this.lands,
    required this.c,
    this.onEdit,
    required this.onExport,
    required this.landFilter,
    required this.onLandFilterChanged,
    required this.dateFilter,
    required this.onDateFilterChanged,
  });

  @override
  State<HistoryTableView> createState() => _HistoryTableViewState();
}

class _HistoryTableViewState extends State<HistoryTableView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final harvests = widget.harvests;
    final onEdit = widget.onEdit;

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Export
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Riwayat Panen', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: c.textPrimary)),
                          const SizedBox(height: 4),
                          Text('Kelola histori panen, edit data, dan pantau sinkronisasi.', style: GoogleFonts.inter(fontSize: 14, color: c.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(10)),
                      child: TextButton.icon(
                        style: TextButton.styleFrom(iconColor: Colors.white, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: Text('Export Data', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        onPressed: widget.onExport,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Filter Row
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.borderLight),
                  ),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      _filterCol('TANGGAL', _buildDropdown(
                        value: widget.dateFilter,
                        items: ['Semua', '7 Hari', '1 Bulan', '3 Bulan', '6 Bulan', '1 Tahun', 'Kustom'],
                        onChanged: (v) => widget.onDateFilterChanged(v!),
                        width: 200,
                      )),
                      _filterCol('KATEGORI LAHAN', _buildDropdown<String?>(
                        value: widget.landFilter,
                        items: [null, ...widget.lands.map((l) => l.id)],
                        displayMap: {null: 'Semua Lahan', ...Map.fromEntries(widget.lands.map((l) => MapEntry(l.id, l.name)))},
                        onChanged: widget.onLandFilterChanged,
                        width: 250,
                      )),
                      _filterCol('STATUS', _buildDropdown(
                        value: 'Semua Status',
                        items: ['Semua Status'],
                        onChanged: (v) {},
                        width: 200,
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Content: Table on desktop, Cards on mobile
                if (isMobile)
                  _buildMobileCardList(harvests, c, onEdit)
                else
                  _buildDesktopTable(harvests, c, onEdit),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ═══════════════════════════════════════════════════
  // DESKTOP TABLE
  // ═══════════════════════════════════════════════════
  Widget _buildDesktopTable(List<HarvestModel> harvests, DColors c, Function(HarvestModel)? onEdit) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borderLight),
      ),
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: true,
        trackVisibility: true,
        thickness: 8,
        radius: const Radius.circular(4),
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 1000),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.borderLight)),
                  ),
                  child: Row(
                    children: [
                      _colH('ID PANEN', 120),
                      _colH('NAMA LAHAN', 280),
                      _colH('TOTAL TANDAN', 160),
                      _colH('STATUS', 180),
                      _colH('BERAT (KG)', 200),
                      _colH('WAKTU (PANEN - INPUT)', 260),
                      if (onEdit != null) _colH('AKSI', 120),
                    ],
                  ),
                ),
                // Rows
                if (harvests.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(48),
                    child: Text('Tidak ada data pada periode ini', style: GoogleFonts.inter(color: c.textMuted)),
                  )
                else
                  ...harvests.map((h) {
                    final land = widget.lands.firstWhere((l) => l.id == h.landId, orElse: () => LandModel(id: '', name: 'Lahan Terhapus', stakeholderId: '', sizeHectares: 0, treeCount: 0));
                    final pending = h.syncStatus == 'pending';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: c.borderLight)),
                      ),
                      child: Row(
                        children: [
                          // ID
                          SizedBox(width: 120, child: Text('#PH-${h.id.substring(0, 4).toUpperCase()}', style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary))),
                          
                          // Lahan
                          SizedBox(
                            width: 280,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.violet.withValues(alpha: 0.15),
                                  child: Text(land.name.isNotEmpty ? land.name[0].toUpperCase() : 'P', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.violet)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(land.name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary))),
                              ],
                            ),
                          ),

                          // Tandan
                          SizedBox(
                            width: 160,
                            child: Text('${h.bunchCount} Tandan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
                          ),

                          // Status
                          SizedBox(
                            width: 180,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: pending ? AppColors.amber.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                  border: Border.all(color: pending ? AppColors.amber : Colors.green),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: pending ? AppColors.amber : Colors.green)),
                                    const SizedBox(width: 6),
                                    Text(pending ? 'PENDING' : 'TERSINKRON', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: pending ? AppColors.amber : Colors.green)),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Berat
                          SizedBox(
                            width: 200,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${h.weightKg.toStringAsFixed(1)} KG', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green)),
                                Text('Avg: ${h.avgWeightPerBunch.toStringAsFixed(1)} KG', style: GoogleFonts.inter(fontSize: 11, color: c.textSecondary)),
                              ],
                            ),
                          ),

                          // Waktu
                          SizedBox(
                            width: 260,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${DateFormat('dd MMM yyyy, HH:mm').format(h.harvestDate)} panen', style: GoogleFonts.inter(fontSize: 12, color: c.textSecondary)),
                                Text('${DateFormat('dd MMM yyyy, HH:mm').format(h.createdAt)} input', style: GoogleFonts.inter(fontSize: 12, color: AppColors.violet)),
                              ],
                            ),
                          ),

                          // Aksi
                          if (onEdit != null)
                            SizedBox(
                              width: 120,
                              child: OutlinedButton.icon(
                                onPressed: () => onEdit(h),
                                icon: const Icon(Icons.edit_rounded, size: 14),
                                label: Text('EDIT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                  side: const BorderSide(color: Colors.green),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  minimumSize: Size.zero,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  // MOBILE CARD LIST
  // ═══════════════════════════════════════════════════
  Widget _buildMobileCardList(List<HarvestModel> harvests, DColors c, Function(HarvestModel)? onEdit) {
    if (harvests.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: c.borderLight)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.inbox_rounded, size: 40, color: c.textMuted),
          const SizedBox(height: 12),
          Text('Tidak ada data pada periode ini', style: GoogleFonts.inter(color: c.textMuted, fontSize: 14)),
        ]),
      );
    }

    return Column(
      children: harvests.map((h) {
        final land = widget.lands.firstWhere((l) => l.id == h.landId, orElse: () => LandModel(id: '', name: 'Lahan Terhapus', stakeholderId: '', sizeHectares: 0, treeCount: 0));
        final pending = h.syncStatus == 'pending';
        final accent = pending ? AppColors.amber : AppColors.primary;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.borderLight),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onEdit != null ? () => onEdit(h) : null,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: land name + status badge
                    Row(
                      children: [
                        Container(width: 4, height: 36, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 10),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.violet.withValues(alpha: 0.15),
                          child: Text(land.name.isNotEmpty ? land.name[0].toUpperCase() : 'P',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.violet)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(land.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: c.textPrimary), overflow: TextOverflow.ellipsis)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: pending ? AppColors.amber.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                            border: Border.all(color: pending ? AppColors.amber : Colors.green),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: pending ? AppColors.amber : Colors.green)),
                            const SizedBox(width: 4),
                            Text(pending ? 'PENDING' : 'SYNC', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: pending ? AppColors.amber : Colors.green)),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Stats row
                    Row(
                      children: [
                        _mobileStatChip(Icons.scale_rounded, '${h.weightKg.toStringAsFixed(1)} KG', Colors.green, c),
                        const SizedBox(width: 8),
                        _mobileStatChip(Icons.grass_rounded, '${h.bunchCount} Tandan', AppColors.violet, c),
                        if (h.bunchCount > 0) ...[
                          const SizedBox(width: 8),
                          _mobileStatChip(Icons.balance_rounded, '${h.avgWeightPerBunch.toStringAsFixed(1)} KG/T', AppColors.cyan, c),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Date row
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 11, color: c.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${DateFormat('dd MMM yyyy, HH:mm').format(h.harvestDate)} panen  •  ${DateFormat('dd MMM yyyy').format(h.createdAt)} input',
                            style: GoogleFonts.inter(fontSize: 11, color: c.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (onEdit != null)
                          GestureDetector(
                            onTap: () => onEdit(h),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: c.surfaceLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.borderLight)),
                              child: Icon(Icons.edit_rounded, size: 14, color: c.textSecondary),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _mobileStatChip(IconData icon, String text, Color color, DColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget _filterCol(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: widget.c.textMuted)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildDropdown<T>({required T value, required List<T> items, required Function(T?) onChanged, Map<T, String>? displayMap, required double width}) {
    return Container(
      width: width,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: widget.c.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.c.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: widget.c.surface,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: widget.c.textMuted),
          style: GoogleFonts.inter(fontSize: 13, color: widget.c.textPrimary, fontWeight: FontWeight.w500),
          items: items.map((i) => DropdownMenuItem<T>(
            value: i,
            child: Text(displayMap != null ? displayMap[i]! : i.toString(), overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _colH(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(text, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: widget.c.textMuted)),
    );
  }
}
