import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/repositories/land_repository.dart';

class ProfileSettingsPage extends ConsumerStatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  ConsumerState<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends ConsumerState<ProfileSettingsPage> {
  final _infoFormKey = GlobalKey<FormState>();
  final _passFormKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _isLoadingInfo = false;
  bool _isLoadingPass = false;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  void _loadCurrentProfile() {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _emailCtrl.text = user.email ?? '';
      _nameCtrl.text = user.userMetadata?['name'] ?? '';
    }
  }

  Future<void> _updateProfileInfo() async {
    if (!_infoFormKey.currentState!.validate()) return;
    setState(() => _isLoadingInfo = true);
    try {
      final updates = UserAttributes(
        email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        data: {'name': _nameCtrl.text.trim()},
      );

      final res = await _supabase.auth.updateUser(updates);
      if (res.user != null) {
         await ref.read(landRepositoryProvider).updateUser(
           res.user!.id, 
           name: _nameCtrl.text.trim()
         );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Informasi profil berhasil diperbarui'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingInfo = false);
    }
  }

  Future<void> _updatePassword() async {
    if (!_passFormKey.currentState!.validate()) return;
    setState(() => _isLoadingPass = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Sesi tidak valid');

      // Verify old password
      try {
        await _supabase.auth.signInWithPassword(
          email: user.email!,
          password: _oldPassCtrl.text,
        );
      } catch (_) {
        throw Exception('Password lama yang Anda masukkan salah');
      }

      // Update password
      await _supabase.auth.updateUser(UserAttributes(password: _newPassCtrl.text));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password berhasil diperbarui'), backgroundColor: Colors.green),
        );
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPass = false);
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus Akun', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'Apakah Anda yakin ingin menghapus akun Anda? Semua data dan sumber daya akan dihapus secara permanen. '
          'Tindakan ini tidak dapat dibatalkan.',
          style: GoogleFonts.inter(color: context.dc.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Penghapusan akun memerlukan hak akses Admin. Silakan hubungi Administrator.')),
              );
            },
            child: const Text('Hapus Akun', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Header
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pengaturan Profil', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: c.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Kelola informasi profil dan pengaturan keamanan akun Anda.', style: GoogleFonts.inter(fontSize: 14, color: c.textSecondary)),
                  ],
                ),
              ),
              _buildSectionCard(
                  c,
                  title: 'Informasi Profil',
                  description: 'Perbarui informasi profil dan alamat email akun Anda.',
                  child: Form(
                    key: _infoFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Nama Lengkap', c),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(hintText: 'Masukkan nama Anda'),
                          validator: (v) => v == null || v.isEmpty ? 'Nama tidak boleh kosong' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Alamat Email', c),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(hintText: 'email@contoh.com'),
                          validator: (v) => v == null || v.isEmpty || !v.contains('@') ? 'Email tidak valid' : null,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _isLoadingInfo ? null : _updateProfileInfo,
                              child: _isLoadingInfo 
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('SIMPAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionCard(
                  c,
                  title: 'Perbarui Password',
                  description: 'Pastikan akun Anda menggunakan password yang panjang dan acak agar tetap aman.',
                  child: Form(
                    key: _passFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Password Saat Ini', c),
                        TextFormField(
                          controller: _oldPassCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(hintText: 'Password lama'),
                          validator: (v) => v == null || v.isEmpty ? 'Masukkan password saat ini' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Password Baru', c),
                        TextFormField(
                          controller: _newPassCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(hintText: 'Password baru'),
                          validator: (v) => v == null || v.length < 6 ? 'Minimal 6 karakter' : null,
                        ),
                        const SizedBox(height: 16),
                        _buildLabel('Konfirmasi Password', c),
                        TextFormField(
                          controller: _confirmPassCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(hintText: 'Ulangi password baru'),
                          validator: (v) => v != _newPassCtrl.text ? 'Password tidak cocok' : null,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _isLoadingPass ? null : _updatePassword,
                              child: _isLoadingPass 
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('SIMPAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _buildSectionCard(
                  c,
                  title: 'Hapus Akun',
                  description: 'Setelah akun Anda dihapus, semua sumber daya dan datanya akan dihapus secara permanen.',
                  child: Row(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.rose,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _showDeleteAccountDialog,
                        child: const Text('HAPUS AKUN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildLabel(String text, DColors c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: GoogleFonts.inter(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  Widget _buildSectionCard(DColors c, {required String title, required String description, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: c.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 4),
            Text(description, style: GoogleFonts.inter(color: c.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}
