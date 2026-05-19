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
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isLoading = false;

  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  void _loadCurrentProfile() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _emailCtrl.text = user.email ?? '';
      _nameCtrl.text = user.userMetadata?['name'] ?? '';
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Sesi tidak valid');

      // Verify old password if trying to set a new one
      if (_passCtrl.text.isNotEmpty) {
        if (_oldPassCtrl.text.isEmpty) {
          throw Exception('Masukkan password lama Anda untuk mengubah password');
        }
        try {
          await _supabase.auth.signInWithPassword(
            email: user.email!,
            password: _oldPassCtrl.text,
          );
        } catch (_) {
          throw Exception('Password lama yang Anda masukkan salah');
        }
      }

      final updates = UserAttributes(
        email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        password: _passCtrl.text.isNotEmpty ? _passCtrl.text : null,
        data: {'name': _nameCtrl.text.trim()},
      );

      // Update auth user
      final res = await _supabase.auth.updateUser(updates);

      // Update public.users table as well
      if (res.user != null) {
         await ref.read(landRepositoryProvider).updateUser(
           res.user!.id, 
           name: _nameCtrl.text.trim()
         );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil berhasil diperbarui'), backgroundColor: Colors.green),
        );
        _passCtrl.clear(); // Clear password field after success
        _oldPassCtrl.clear();
        _confirmPassCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _oldPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Profil')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              color: c.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: c.border)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Informasi Profil', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
                      const SizedBox(height: 8),
                      Text('Perbarui nama, email, dan kata sandi Anda di sini.', style: GoogleFonts.inter(color: c.textSecondary, fontSize: 13)),
                      const SizedBox(height: 24),

                      Text('Nama Lengkap', style: GoogleFonts.inter(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(hintText: 'Masukkan nama Anda'),
                        validator: (v) => v == null || v.isEmpty ? 'Nama tidak boleh kosong' : null,
                      ),
                      const SizedBox(height: 16),

                      Text('Alamat Email', style: GoogleFonts.inter(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(hintText: 'email@contoh.com'),
                        validator: (v) => v == null || v.isEmpty || !v.contains('@') ? 'Email tidak valid' : null,
                      ),
                      const SizedBox(height: 16),

                      Text('Password Lama', style: GoogleFonts.inter(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _oldPassCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(hintText: 'Masukkan password saat ini jika ingin mengubah'),
                      ),
                      const SizedBox(height: 16),

                      Text('Kata Sandi Baru (Opsional)', style: GoogleFonts.inter(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(hintText: 'Biarkan kosong jika tidak ingin mengubah'),
                        validator: (v) {
                          if (_oldPassCtrl.text.isNotEmpty && (v == null || v.isEmpty)) return 'Masukkan password baru';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Text('Konfirmasi Kata Sandi Baru', style: GoogleFonts.inter(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _confirmPassCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(hintText: 'Ulangi password baru'),
                        validator: (v) {
                          if (_passCtrl.text.isNotEmpty && v != _passCtrl.text) return 'Password tidak cocok';
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(gradient: AppColors.gradientPrimary, borderRadius: BorderRadius.circular(12)),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, elevation: 0),
                            onPressed: _isLoading ? null : _updateProfile,
                            child: _isLoading 
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Simpan Perubahan'),
                          ),
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
