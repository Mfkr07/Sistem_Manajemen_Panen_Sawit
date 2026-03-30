import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../core/repositories/land_repository.dart';

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
          title: const Text('Tambah Lahan Baru'),
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
            ElevatedButton(
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Lahan'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLandDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Lahan'),
      ),
      body: SafeArea(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lands.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.terrain, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Belum ada lahan terdaftar',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Tap tombol + untuk menambahkan lahan baru'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _lands.length,
                    itemBuilder: (context, index) {
                      final land = _lands[index];
                      final owner = _stakeholders
                          .where((s) => s.id == land.stakeholderId)
                          .firstOrNull;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                            child: Icon(Icons.terrain, color: Theme.of(context).primaryColor),
                          ),
                          title: Text(land.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Luas: ${land.sizeHectares} Ha'),
                              Text(
                                'Pemilik: ${owner?.name ?? owner?.email ?? 'Tidak diketahui'}',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Hapus Lahan?'),
                                  content: Text('Apakah Anda yakin ingin menghapus "${land.name}"? Semua data panen terkait juga akan dihapus.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Hapus'),
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
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
      ),
    );
  }
}
