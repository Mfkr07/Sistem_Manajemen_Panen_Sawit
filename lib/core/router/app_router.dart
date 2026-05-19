import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/admin/presentation/admin_dashboard.dart';
import '../../features/admin/presentation/manage_accounts_page.dart';
import '../../features/stakeholder/presentation/stakeholder_dashboard.dart';
import '../../features/auth/presentation/login_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isLoginRoute = state.matchedLocation == '/login';

      // Not logged in → force to login page
      if (!isLoggedIn) {
        return isLoginRoute ? null : '/login';
      }

      // Logged in but on login page → redirect to correct dashboard
      if (isLoggedIn && isLoginRoute) {
        try {
          final uid = Supabase.instance.client.auth.currentUser!.id;
          final data = await Supabase.instance.client
              .from('users')
              .select('role')
              .eq('id', uid)
              .single();
          return data['role'] == 'admin' ? '/admin' : '/stakeholder';
        } catch (_) {
          // If role lookup fails, let them stay on login
          return null;
        }
      }

      // Logged in and accessing protected routes → verify role
      if (isLoggedIn && !isLoginRoute) {
        try {
          final uid = Supabase.instance.client.auth.currentUser!.id;
          final data = await Supabase.instance.client
              .from('users')
              .select('role')
              .eq('id', uid)
              .single();
          final role = data['role'] as String;
          final path = state.matchedLocation;

          // Admin trying to access stakeholder routes
          if (role == 'admin' && path.startsWith('/stakeholder')) {
            return '/admin';
          }
          // Stakeholder trying to access admin routes
          if (role == 'stakeholder' && path.startsWith('/admin')) {
            return '/stakeholder';
          }
        } catch (_) {
          // Role check failed → redirect to login for safety
          return '/login';
        }
      }

      return null; // No redirect needed
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboardPage(),
      ),

      GoRoute(
        path: '/admin/accounts',
        builder: (context, state) => const ManageAccountsPage(),
      ),
      GoRoute(
        path: '/stakeholder',
        builder: (context, state) => const StakeholderDashboardPage(),
      ),
    ],
  );
});
