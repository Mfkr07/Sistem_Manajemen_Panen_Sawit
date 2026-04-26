import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/database/local_db.dart';
import '../../../core/models/models.dart';
import '../../../core/repositories/land_repository.dart';
import '../../../core/theme/app_colors.dart';

class InputHarvestForm extends StatefulWidget {
  const InputHarvestForm({super.key});

  @override
  State<InputHarvestForm> createState() => _InputHarvestFormState();
}

class _InputHarvestFormState extends State<InputHarvestForm> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _bunchCountController = TextEditingController();
  
  List<LandModel> _lands = [];
  String? _selectedLandId;
  DateTime _selectedDate = DateTime.now();
  bool _isLoadingLands = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadLands();
  }

  Future<void> _loadLands() async {
    setState(() => _isLoadingLands = true);
    try {
      final lands = await LandRepository().getAllLands();
      setState(() {
        _lands = lands;
        _isLoadingLands = false;
      });
    } catch (e) {
      // Fallback to cached
      final cached = await LocalDatabase.instance.getCachedLands();
      setState(() {
        _lands = cached;
        _isLoadingLands = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      if (!mounted) return;
      // Also pick time
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      setState(() {
        _selectedDate = DateTime(
          picked.year, picked.month, picked.day,
          time?.hour ?? picked.hour, time?.minute ?? picked.minute,
        );
      });
    }
  }

  Future<void> _submitOffline() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLandId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih lahan terlebih dahulu')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final double weight = double.parse(_weightController.text);
      final int bunchCount = int.tryParse(_bunchCountController.text) ?? 0;
      final selectedLand = _lands.where((l) => l.id == _selectedLandId).firstOrNull;

      final newHarvest = HarvestModel(
        landId: _selectedLandId!,
        landName: selectedLand?.name,
        weightKg: weight,
        bunchCount: bunchCount,
        harvestDate: _selectedDate,
        syncStatus: 'pending',
      );

      await LocalDatabase.instance.insertHarvest(newHarvest);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil disimpan lokal! Menunggu sinkronisasi.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _bunchCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Data Panen'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.border),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cyan.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: AppColors.cyan, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Data akan disimpan secara lokal dan otomatis disinkronkan saat online.',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.cyan),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Land Dropdown
                      Text('Pilih Lahan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
                      const SizedBox(height: 8),
                      _isLoadingLands
                          ? const LinearProgressIndicator()
                          : _lands.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.amber.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.amber.withValues(alpha: 0.2)),
                                  ),
                                  child: Text(
                                    'Belum ada lahan terdaftar. Tambahkan lahan terlebih dahulu di menu Manajemen Lahan.',
                                    style: GoogleFonts.inter(color: AppColors.amber, fontSize: 13),
                                  ),
                                )
                              : DropdownButtonFormField<String>(
                                  initialValue: _selectedLandId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.terrain),
                                    hintText: 'Pilih lahan...',
                                  ),
                                  items: _lands.map((land) => DropdownMenuItem(
                                    value: land.id,
                                    child: Text('${land.name} (${land.sizeHectares} Ha)', overflow: TextOverflow.ellipsis),
                                  )).toList(),
                                  onChanged: (val) => setState(() => _selectedLandId = val),
                                  validator: (val) => val == null ? 'Pilih lahan' : null,
                                ),
                      const SizedBox(height: 20),

                      // Weight
                      Text('Berat Panen', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          hintText: 'Masukkan berat dalam KG',
                          prefixIcon: Icon(Icons.monitor_weight),
                          suffixText: 'KG',
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Wajib diisi';
                          if (double.tryParse(val) == null) return 'Harus berupa angka';
                          if (double.parse(val) <= 0) return 'Berat harus lebih dari 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Bunch Count
                      Text('Jumlah Tandan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _bunchCountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Masukkan jumlah tandan',
                          prefixIcon: Icon(Icons.grass_rounded),
                          suffixText: 'Tandan',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Wajib diisi';
                          if (int.tryParse(val) == null) return 'Harus berupa angka bulat';
                          if (int.parse(val) <= 0) return 'Jumlah tandan harus lebih dari 0';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Date Picker
                      Text('Tanggal Panen', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            DateFormat('dd MMMM yyyy, HH:mm').format(_selectedDate),
                            style: GoogleFonts.inter(fontSize: 15, color: c.textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Summary Card — Jumlah Tandan & Rata-rata Berat
                      Builder(builder: (context) {
                        final weight = double.tryParse(_weightController.text);
                        final bunches = int.tryParse(_bunchCountController.text);
                        final hasData = weight != null && weight > 0 && bunches != null && bunches > 0;
                        final avg = hasData ? (weight / bunches) : 0.0;

                        return AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          child: hasData
                              ? Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primary.withValues(alpha: 0.08),
                                        AppColors.cyan.withValues(alpha: 0.06),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 16),
                                          const SizedBox(width: 8),
                                          Text('Ringkasan Panen', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _summaryItem(
                                              'Total Berat',
                                              '${weight.toStringAsFixed(1)} KG',
                                              Icons.monitor_weight_outlined,
                                              c,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _summaryItem(
                                              'Jumlah Tandan',
                                              '$bunches Tandan',
                                              Icons.grass_rounded,
                                              c,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                        decoration: BoxDecoration(
                                          color: AppColors.cyan.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.cyan.withValues(alpha: 0.25)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.balance_rounded, color: AppColors.cyan, size: 18),
                                            const SizedBox(width: 8),
                                            Text('Rata-rata: ', style: GoogleFonts.inter(fontSize: 13, color: c.textSecondary)),
                                            Text('${avg.toStringAsFixed(2)} KG/Tandan',
                                                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.cyan)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                        );
                      }),
                      const SizedBox(height: 24),

                      // Submit button
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: AppColors.gradientPrimary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent, elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _isSaving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save, color: Colors.white),
                          label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Data (Offline)',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                          onPressed: _isSaving ? null : _submitOffline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon, DColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: c.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 10, color: c.textMuted)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
