import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/database/local_db.dart';
import '../../../core/models/models.dart';
import '../../../core/repositories/land_repository.dart';
import '../../../core/theme/app_colors.dart';

class EditHarvestForm extends StatefulWidget {
  final HarvestModel harvest;

  const EditHarvestForm({super.key, required this.harvest});

  @override
  State<EditHarvestForm> createState() => _EditHarvestFormState();
}

class _EditHarvestFormState extends State<EditHarvestForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;

  List<LandModel> _lands = [];
  late String? _selectedLandId;
  late DateTime _selectedDate;
  bool _isLoadingLands = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.harvest.weightKg.toString());
    _selectedLandId = widget.harvest.landId;
    _selectedDate = widget.harvest.harvestDate;
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
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      setState(() {
        _selectedDate = DateTime(
          picked.year, picked.month, picked.day,
          time?.hour ?? _selectedDate.hour, time?.minute ?? _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _saveEdit() async {
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

      final updatedHarvest = widget.harvest.copyWith(
        landId: _selectedLandId,
        landName: selectedLand?.name,
        weightKg: weight,
        harvestDate: _selectedDate,
        updatedAt: DateTime.now(),
        syncStatus: 'pending',
      );

      await LocalDatabase.instance.updateHarvest(updatedHarvest);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data panen berhasil diperbarui!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui: $e')),
        );
      }
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
        title: const Text('Edit Data Panen'),
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
                      // Info card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cyan.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.edit_note_rounded, color: AppColors.cyan, size: 18),
                                const SizedBox(width: 8),
                                Text('Mengedit Data Panen',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.cyan, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload: ${DateFormat('dd MMM yyyy HH:mm').format(widget.harvest.createdAt)}',
                              style: GoogleFonts.inter(fontSize: 12, color: c.textMuted),
                            ),
                            Text(
                              'Terakhir diedit: ${DateFormat('dd MMM yyyy HH:mm').format(widget.harvest.updatedAt)}',
                              style: GoogleFonts.inter(fontSize: 12, color: c.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Land Dropdown
                      Text('Lahan', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
                      const SizedBox(height: 8),
                      _isLoadingLands
                          ? const LinearProgressIndicator()
                          : DropdownButtonFormField<String>(
                              initialValue: _lands.any((l) => l.id == _selectedLandId) ? _selectedLandId : null,
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

                      // Date
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

                      // Save button
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
                          label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Perubahan',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: Colors.white)),
                          onPressed: _isSaving ? null : _saveEdit,
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
