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
      final selectedLand = _lands.where((l) => l.id == _selectedLandId).firstOrNull;

      final newHarvest = HarvestModel(
        landId: _selectedLandId!,
        landName: selectedLand?.name,
        weightKg: weight,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
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
                          color: AppColors.cyan.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cyan.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: AppColors.cyan, size: 18),
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
                                    color: AppColors.amber.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.amber.withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    'Belum ada lahan terdaftar. Tambahkan lahan terlebih dahulu di menu Manajemen Lahan.',
                                    style: GoogleFonts.inter(color: AppColors.amber, fontSize: 13),
                                  ),
                                )
                              : DropdownButtonFormField<String>(
                                  value: _selectedLandId,
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.terrain),
                                    hintText: 'Pilih lahan...',
                                  ),
                                  items: _lands.map((land) => DropdownMenuItem(
                                    value: land.id,
                                    child: Text('${land.name} (${land.sizeHectares} Ha)'),
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
                      const SizedBox(height: 32),

                      // Submit button
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: AppColors.gradientPrimary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
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
}
