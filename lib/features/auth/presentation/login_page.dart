import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  String? _error;

  late AnimationController _animCtl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtl, curve: Curves.easeOutCubic));
    _animCtl.forward();
  }

  @override
  void dispose() { _animCtl.dispose(); _emailCtl.dispose(); _passCtl.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      final resp = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtl.text.trim(), password: _passCtl.text);
      if (!mounted) return;
      final uid = resp.user?.id;
      if (uid == null) { setState(() { _error = 'Login gagal.'; _isLoading = false; }); return; }
      final data = await Supabase.instance.client.from('users').select('role').eq('id', uid).single();
      if (!mounted) return;
      context.go(data['role'] == 'admin' ? '/admin' : '/stakeholder');
    } on AuthException catch (e) {
      setState(() { _error = e.message; _isLoading = false; });
    } catch (e) {
      setState(() { _error = 'Terjadi kesalahan: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget buildLoginForm() {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Logo
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.gradientPrimary,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: const Icon(Icons.eco_rounded, size: 44, color: Colors.white),
          ),
          const SizedBox(height: 24),
          Text('Sistem Manajemen\nPemanenan Sawit',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: c.textPrimary, height: 1.3)),
          const SizedBox(height: 8),
          Text('Masuk ke akun Anda', style: GoogleFonts.inter(fontSize: 14, color: c.textMuted)),
          const SizedBox(height: 32),
          // Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06), blurRadius: 32, offset: const Offset(0, 16))],
            ),
            child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_error != null) ...[
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppColors.rose.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.rose.withValues(alpha: 0.25))),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.rose, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: GoogleFonts.inter(color: AppColors.rose, fontSize: 13)))
                        ])),
                    const SizedBox(height: 16),
                  ],
                  // Email
                  Text('Email', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: _emailCtl,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.inter(color: c.textPrimary),
                      decoration: InputDecoration(
                          hintText: 'nama@email.com',
                          prefixIcon: Icon(Icons.email_outlined, size: 20, color: c.textMuted),
                          filled: true,
                          fillColor: c.surfaceLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2))),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email wajib diisi';
                        if (!v.contains('@')) return 'Format email tidak valid';
                        return null;
                      }),
                  const SizedBox(height: 16),
                  // Password
                  Text('Password', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: c.textSecondary)),
                  const SizedBox(height: 8),
                  TextFormField(
                      controller: _passCtl,
                      obscureText: _obscure,
                      style: GoogleFonts.inter(color: c.textPrimary),
                      decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: Icon(Icons.lock_outlined, size: 20, color: c.textMuted),
                          suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: c.textMuted),
                              onPressed: () => setState(() => _obscure = !_obscure)),
                          filled: true,
                          fillColor: c.surfaceLight,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 2))),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password wajib diisi';
                        return null;
                      },
                      onFieldSubmitted: (_) => _login()),
                  const SizedBox(height: 24),
                  // Button
                  Container(
                      height: 50,
                      decoration: BoxDecoration(
                          gradient: AppColors.gradientPrimary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: _isLoading ? null : _login,
                          child: _isLoading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text('Masuk', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)))),
                ])),
          ),
        ]),
      );
    }

    final bgGradient = LinearGradient(
      colors: isDark
          ? [const Color(0xFF0B0F19), const Color(0xFF111827), const Color(0xFF0B0F19)]
          : [const Color(0xFFF0F9FF), const Color(0xFFECFDF5), const Color(0xFFF0F9FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            // ── DESKTOP SPLIT-SCREEN ──
            return Row(
              children: [
                // Left branding panel
                Expanded(
                  flex: 5,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF06B6D4), Color(0xFF0891B2)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Decorative floating orbs
                        Positioned(top: -60, left: -40, child: _orb(180, 0.08)),
                        Positioned(bottom: -80, right: -60, child: _orb(220, 0.06)),
                        Positioned(top: 120, right: 60, child: _orb(80, 0.12)),
                        Positioned(bottom: 200, left: 80, child: _orb(50, 0.15)),
                        Positioned(top: 300, left: 200, child: _orb(30, 0.1)),
                        // Content
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 56),
                            child: FadeTransition(
                              opacity: _fadeAnim,
                              child: SlideTransition(
                                position: _slideAnim,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Logo
                                    Container(
                                      padding: const EdgeInsets.all(28),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                                      ),
                                      child: const Icon(Icons.eco_rounded, size: 64, color: Colors.white),
                                    ),
                                    const SizedBox(height: 40),
                                    Text(
                                      'Selamat Datang',
                                      style: GoogleFonts.inter(fontSize: 44, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1, letterSpacing: -1),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Kelola panen sawit dengan efisien dan\nterpusat dalam satu platform cerdas.',
                                      style: GoogleFonts.inter(fontSize: 17, color: Colors.white.withValues(alpha: 0.9), height: 1.6),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 48),
                                    // Feature highlights
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _featureChip(Icons.show_chart_rounded, 'Analitik\nReal-time'),
                                        const SizedBox(width: 16),
                                        _featureChip(Icons.cloud_done_rounded, 'Sinkronisasi\nOtomatis'),
                                        const SizedBox(width: 16),
                                        _featureChip(Icons.devices_rounded, 'Multi\nPlatform'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Bottom version text
                        Positioned(
                          bottom: 24, left: 0, right: 0,
                          child: Center(
                            child: Text('Palm Harvest v1.0', style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Right login form
                Expanded(
                  flex: 4,
                  child: Container(
                    color: c.bg,
                    child: Center(
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                            child: buildLoginForm(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          // ── MOBILE / TABLET ──
          return Container(
            decoration: BoxDecoration(gradient: bgGradient),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: buildLoginForm(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Decorative orb for branding panel
  Widget _orb(double size, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );

  // Feature highlight chip
  Widget _featureChip(IconData icon, String label) => Container(
    width: 110, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 28),
      const SizedBox(height: 10),
      Text(label, textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.95), fontSize: 12, fontWeight: FontWeight.w600, height: 1.3)),
    ]),
  );
}
