import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/models.dart';
import '../../../core/repositories/land_repository.dart';
import '../../../core/theme/app_colors.dart';

class ManageLandsPage extends StatefulWidget {
  const ManageLandsPage({super.key});

  @override
  State<ManageLandsPage> createState() => _ManageLandsPageState();
}

class _ManageLandsPageState extends State<ManageLandsPage> {
  final LandRepository _repo = LandRepository();
  List<LandModel> _lands = [];
  List<UserModel> _stakeholders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final lands = await _repo.getAllLands();
      final stakeholders = await _repo.getAllStakeholders();
      setState(() {
        _lands = lands;
        _stakeholders = stakeholders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e')),
        );
      }
    }
  }

  void _showAddLandDialog() {
    final nameController = TextEditingController();
    final sizeController = TextEditingController();
    String? selectedStakeholderId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Tambah Lahan Baru', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lahan',
                    prefixIcon: Icon(Icons.terrain),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sizeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Luas (Hektar)',
                    prefixIcon: Icon(Icons.straighten),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedStakeholderId,
                  decoration: const InputDecoration(
                    labelText: 'Pemilik (Stakeholder)',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: _stakeholders.map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.name.isEmpty ? s.email : s.name),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => selectedStakeholderId = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.gradientPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
                onPressed: () async {
                  if (nameController.text.isEmpty || sizeController.text.isEmpty || selectedStakeholderId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Semua field wajib diisi')),
                    );
                    return;
                  }
                  try {
                    final land = LandModel(
                      name: nameController.text,
                      sizeHectares: double.parse(sizeController.text),
                      stakeholderId: selectedStakeholderId!,
                    );
                    await _repo.addLand(land);
                    if (mounted) Navigator.pop(ctx);
                    _loadData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lahan berhasil ditambahkan')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal menambahkan lahan: $e')),
                    );
                  }
                },
                child: const Text('Simpan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditLandDialog(LandModel land) {
    final nameController = TextEditingController(text: land.name);
    final sizeController = TextEditingController(text: land.sizeHectares.toString());
    String? selectedStakeholderId = land.stakeholderId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final c = context.dc;
          return AlertDialog(
            title: Text('Edit Lahan', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lahan',
                      prefixIcon: Icon(Icons.terrain),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: sizeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Luas (Hektar)',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _stakeholders.any((s) => s.id == selectedStakeholderId) ? selectedStakeholderId : null,
                    decoration: const InputDecoration(
                      labelText: 'Pemilik (Stakeholder)',
                      prefixIcon: Icon(Icons.person),
                    ),
                    items: _stakeholders.map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.name.isEmpty ? s.email : s.name),
                    )).toList(),
                    onChanged: (val) => setDialogState(() => selectedStakeholderId = val),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
                  onPressed: () async {
                    if (nameController.text.isEmpty || sizeController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nama dan luas wajib diisi')),
                      );
                      return;
                    }
                    try {
                      await _repo.updateLand(
                        land.id,
                        name: nameController.text.trim(),
                        sizeHectares: double.parse(sizeController.text),
                        stakeholderId: selectedStakeholderId,
                      );
                      if (mounted) Navigator.pop(ctx);
                      _loadData();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lahan berhasil diperbarui'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal memperbarui: $e')),
                      );
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Lahan'),
        actions: [
          // Desktop-friendly add button in AppBar
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('Tambah', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              onPressed: _showAddLandDialog,
            ),
          ),
        ],
      ),
      floatingActionButton: MediaQuery.of(context).size.width < 600
          ? FloatingActionButton.extended(
              onPressed: _showAddLandDialog,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Lahan'),
            )
          : null,
      body: SafeArea(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lands.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.terrain_rounded, size: 64, color: c.textMuted),
                      const SizedBox(height: 16),
                      Text('Belum ada lahan terdaftar',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: c.textSecondary)),
                      const SizedBox(height: 8),
                      Text('Tap tombol + untuk menambahkan lahan baru',
                          style: GoogleFonts.inter(color: c.textMuted)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 700;
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: isWide
                              ? GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: constraints.maxWidth >= 1000 ? 3 : 2,
                                    mainAxisSpacing: 12, crossAxisSpacing: 12,
                                    mainAxisExtent: 120,
                                  ),
                                  itemCount: _lands.length,
                                  itemBuilder: (_, index) => _buildLandCard(_lands[index], c),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _lands.length,
                                  itemBuilder: (_, index) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _buildLandCard(_lands[index], c),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
      ),
    );
  }

  Widget _buildLandCard(LandModel land, DColors c) {
    final owner = _stakeholders.where((s) => s.id == land.stakeholderId).firstOrNull;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: AppColors.gradientPrimary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.terrain_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(land.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: c.textPrimary)),
            const SizedBox(height: 4),
            Text('${land.sizeHectares} Ha', style: GoogleFonts.inter(fontSize: 12, color: c.textMuted)),
            const SizedBox(height: 2),
            Text(
              'Pemilik: ${owner?.name ?? owner?.email ?? 'Tidak diketahui'}',
              style: GoogleFonts.inter(fontSize: 11, color: c.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        )),
        PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'edit') _showEditLandDialog(land);
            if (action == 'delete') _confirmDelete(land, c);
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_rounded, color: AppColors.cyan, size: 18),
                const SizedBox(width: 10),
                Text('Edit', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              ]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline_rounded, color: AppColors.rose, size: 18),
                const SizedBox(width: 10),
                Text('Hapus', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: AppColors.rose)),
              ]),
            ),
          ],
        ),
      ]),
    );
  }

  Future<void> _confirmDelete(LandModel land, DColors c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Lahan?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text('Apakah Anda yakin ingin menghapus "${land.name}"? Semua data panen terkait juga akan dihapus.',
            style: GoogleFonts.inter(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          Container(
            decoration: BoxDecoration(gradient: AppColors.gradientRose, borderRadius: BorderRadius.circular(10)),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus'),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _repo.deleteLand(land.id);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus: $e')),
          );
        }
      }
    }
  }
}
