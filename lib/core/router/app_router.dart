import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/admin/presentation/admin_dashboard.dart';
import '../../features/admin/presentation/manage_lands_page.dart';
import '../../features/admin/presentation/manage_accounts_page.dart';
import '../../features/stakeholder/presentation/stakeholder_dashboard.dart';
import '../../features/auth/presentation/login_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
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
        path: '/admin/lands',
        builder: (context, state) => const ManageLandsPage(),
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
