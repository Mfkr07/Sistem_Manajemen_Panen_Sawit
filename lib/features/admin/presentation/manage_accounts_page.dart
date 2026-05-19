import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/models.dart';
import '../../../core/repositories/land_repository.dart';
import '../../../core/theme/app_colors.dart';

class ManageAccountsPage extends StatefulWidget {
  const ManageAccountsPage({super.key});

  @override
  State<ManageAccountsPage> createState() => _ManageAccountsPageState();
}

class _ManageAccountsPageState extends State<ManageAccountsPage> {
  final LandRepository _repo = LandRepository();
  List<UserModel> _users = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      _users = await _repo.getAllUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e')),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showEditDialog(UserModel user) {
    final nameController = TextEditingController(text: user.name);
    String selectedRole = user.role;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Edit Profil User', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Email (read-only)
                TextField(
                  controller: TextEditingController(text: user.email),
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: context.dc.surfaceLight,
                  ),
                ),
                const SizedBox(height: 16),
                // Name
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                // Role
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem(value: 'stakeholder', child: Text('Stakeholder')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedRole = val);
                  },
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
              decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(10)),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
                onPressed: () async {
                  final navigator = Navigator.of(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await _repo.updateUser(
                      user.id,
                      name: nameController.text.trim(),
                      role: selectedRole,
                    );
                    if (!mounted) return;
                    navigator.pop();
                    _loadUsers();
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Profil berhasil diperbarui'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Gagal memperbarui: $e')),
                      );
                    }
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

  void _showDeleteConfirm(UserModel user) {
    if (user.id == _currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anda tidak bisa menghapus akun Anda sendiri'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final c = context.dc;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus User?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'Apakah Anda yakin ingin menghapus profil "${user.name.isEmpty ? user.email : user.name}" dari sistem?\n\n'
          'Catatan: Ini hanya menghapus profil dari tabel users. Akun Auth-nya tetap ada di Supabase.',
          style: GoogleFonts.inter(color: c.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          Container(
            decoration: BoxDecoration(gradient: AppColors.gradientRose, borderRadius: BorderRadius.circular(10)),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _repo.deleteUser(user.id);
                  _loadUsers();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('User berhasil dihapus'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gagal menghapus: $e')),
                    );
                  }
                }
              },
              child: const Text('Hapus'),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = 'stakeholder';
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final _ = context.dc;
          return AlertDialog(
            title: Text('Tambah Akun', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'stakeholder', child: Text('Stakeholder')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => role = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              Container(
                decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(10)),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
                  onPressed: isLoading ? null : () async {
                    if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap isi semua field')));
                      return;
                    }
                    final navigator = Navigator.of(ctx);
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => isLoading = true);
                    try {
                      await _repo.createUserByAdmin(emailCtrl.text.trim(), passCtrl.text, nameCtrl.text.trim(), role);
                      if (mounted) {
                        navigator.pop();
                        _loadUsers();
                        messenger.showSnackBar(const SnackBar(content: Text('Akun berhasil dibuat'), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      setState(() => isLoading = false);
                      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Gagal membuat akun: $e')));
                    }
                  },
                  child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Simpan'),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final adminCount = _users.where((u) => u.role == 'admin').length;
    final stakeholderCount = _users.where((u) => u.role == 'stakeholder').length;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Page Header
              Center(child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kelola Pengguna', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: c.textPrimary)),
                                const SizedBox(height: 4),
                                Text('Tambah, edit, atau hapus akun pengguna sistem.', style: GoogleFonts.inter(fontSize: 14, color: c.textSecondary)),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _showAddUserDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Tambah Pengguna', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),
                  // Summary bar
                  Center(child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.borderLight),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            _roleBadge('Admin', adminCount, AppColors.cyan, c),
                            const SizedBox(width: 12),
                            _roleBadge('Stakeholder', stakeholderCount, AppColors.violet, c),
                            const Spacer(),
                            Text(
                              'Total: ${_users.length} Akun',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: c.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
                  // User list
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadUsers,
                      child: _users.isEmpty
                          ? Center(child: Text('Belum ada user terdaftar', style: GoogleFonts.inter(color: c.textMuted)))
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth >= 700;
                                return Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 1200),
                                    child: isWide
                                        ? GridView.builder(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: constraints.maxWidth >= 1000 ? 2 : 1,
                                              mainAxisSpacing: 10, crossAxisSpacing: 12,
                                              mainAxisExtent: 100,
                                            ),
                                            itemCount: _users.length,
                                            itemBuilder: (_, index) => _buildUserCard(_users[index], c),
                                          )
                                        : ListView.builder(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                            itemCount: _users.length,
                                            itemBuilder: (_, index) => Padding(
                                              padding: const EdgeInsets.only(bottom: 10),
                                              child: _buildUserCard(_users[index], c),
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
            ],
          );
  }

  Widget _buildUserCard(UserModel user, DColors c) {
    final isCurrentUser = user.id == _currentUserId;
    final isAdmin = user.role == 'admin';
    final roleGrad = isAdmin
        ? const LinearGradient(colors: [AppColors.cyan, Color(0xFF38BDF8)])
        : AppColors.gradientViolet;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        // Avatar with gradient
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: roleGrad,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
            color: Colors.white, size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [
              Flexible(child: Text(
                user.name.isEmpty ? user.email : user.name,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: c.textPrimary),
                overflow: TextOverflow.ellipsis,
              )),
              if (isCurrentUser) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Anda', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Text(user.email, style: GoogleFonts.inter(fontSize: 12, color: c.textMuted), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (isAdmin ? AppColors.cyan : AppColors.violet).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                user.role.toUpperCase(),
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                    color: isAdmin ? AppColors.cyan : AppColors.violet),
              ),
            ),
          ],
        )),
        PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'edit') _showEditDialog(user);
            if (action == 'delete') _showDeleteConfirm(user);
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                const Icon(Icons.edit_rounded, color: AppColors.cyan, size: 18),
                const SizedBox(width: 10),
                Text('Edit Profil', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              ]),
            ),
            if (!isCurrentUser)
              PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  const Icon(Icons.delete_outline_rounded, color: AppColors.rose, size: 18),
                  const SizedBox(width: 10),
                  Text('Hapus', style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: AppColors.rose)),
                ]),
              ),
          ],
        ),
      ]),
    );
  }

  Widget _roleBadge(String label, int count, Color color, DColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: color, fontSize: 14)),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
