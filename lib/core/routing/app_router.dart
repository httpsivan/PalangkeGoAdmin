import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';
import '../../features/accounts/accounts_page.dart';
import '../../features/audit_log/audit_log_page.dart';
import '../../features/admin_settings/admin_settings_page.dart';
import '../../features/authentication/login_page.dart';
import '../../features/overview/overview_page.dart';
import '../../features/announcements/announcement_history_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/reports/reports_page.dart';
import '../../features/sales_reports/sales_reports_page.dart';
import '../../features/renewals/renewals_page.dart';
import '../../features/vendor_applications/vendor_applications_page.dart';
import '../widgets/admin_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  final router = GoRouter(
    initialLocation: ref.read(authProvider) ? '/overview' : '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = ref.read(authProvider);
      final isLogin = state.matchedLocation == '/login';
      if (!signedIn && !isLogin) return '/login';
      if (signedIn && isLogin) return '/overview';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdminShell(child: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/overview',
                builder: (context, state) => const OverviewPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sales-reports',
                builder: (context, state) => const SalesReportsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/accounts',
                builder: (context, state) => AccountsPage(
                  selectedAccountId: state.uri.queryParameters['accountId'],
                  openDetailsOnLoad: state.uri.queryParameters['open'] == '1',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/applications',
                builder: (context, state) => const VendorApplicationsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/renewal',
                builder: (context, state) => const RenewalsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/announcements',
                builder: (context, state) => const AnnouncementHistoryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/audit-log',
                builder: (context, state) => const AuditLogPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/notifications',
                builder: (context, state) => const NotificationsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/admin-settings',
                builder: (context, state) => const AdminSettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    refresh.dispose();
    router.dispose();
  });
  return router;
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen<bool>(authProvider, (previous, next) => notifyListeners());
  }
}
