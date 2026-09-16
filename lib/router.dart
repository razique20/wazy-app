import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/finance.dart';
import 'theme/app_theme.dart';
import 'models/expiry_item.dart';
import 'services/document_scanner_service.dart';
import 'services/finance_service.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/document_scan_screen.dart';
import 'screens/document_detail_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/money_screen.dart';
import 'services/auth_service.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeShellKey = GlobalKey<NavigatorState>();
final _documentsShellKey = GlobalKey<NavigatorState>();
final _moneyShellKey = GlobalKey<NavigatorState>();
final _profileShellKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  // Auth gate: when Supabase is configured, every route except /login and /
  // requires a session. In local-only mode (no credentials) the gate is off.
  redirect: (context, state) {
    final auth = AuthService.instance;
    if (!auth.isAvailable) return null;

    final signedIn = auth.isSignedIn;
    final path = state.uri.path;
    final isAuthRoute = path == '/login';

    if (!signedIn && !isAuthRoute && path != '/') return '/login';
    if (signedIn && isAuthRoute) return '/home';
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const OnboardingScreen(),
    ),
    // Full-screen flows above the shell.
    GoRoute(
      path: '/scan',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DocumentScanScreen(),
    ),
    GoRoute(
      path: '/document/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return DocumentDetailScreen(documentId: id);
      },
    ),
    // 4-tab bottom-nav shell:
    //   Home      — cross-tier dashboard (documents + money summary)
    //   Documents — Tier 1: full expiry tracking
    //   Money     — Tier 2: budgets, envelopes, transactions
    //   Profile   — settings, collections, account
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => _AppShell(
        navigationShell: navigationShell,
      ),
      branches: [
        StatefulShellBranch(
          navigatorKey: _homeShellKey,
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _documentsShellKey,
          routes: [
            GoRoute(
              path: '/documents',
              builder: (context, state) => const DocumentsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _moneyShellKey,
          routes: [
            GoRoute(
              path: '/money',
              builder: (context, state) => const MoneyScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _profileShellKey,
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text('Page not found: ${state.uri}')),
  ),
);

/// Bottom navigation shell with the four main tabs.
///
/// Destinations carry live context:
/// * Documents — red badge when any tracked document needs action (≤30 days).
/// * Money — green/red dot reflecting this month's net position.
class _AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const _AppShell({required this.navigationShell});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  List<ExpiryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
    DocumentScannerService.instance.addListener(_onItemsChanged);
  }

  @override
  void dispose() {
    DocumentScannerService.instance.removeListener(_onItemsChanged);
    super.dispose();
  }

  Future<void> _loadItems() async {
    final items = await DocumentScannerService.instance.getAllItems();
    if (mounted) setState(() => _items = items);
  }

  void _onItemsChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadItems();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pendingDocs = _items.where((i) => i.daysRemaining <= 30).length;
    final summary = FinanceMath.summaryForMonth(
      FinanceService.instance.activeTransactions,
      DateTime.now(),
    );

    return Scaffold(
      body: widget.navigationShell,
      extendBody: true,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? WazyColors.cyan.withOpacity(0.08)
                      : WazyColors.fog.withOpacity(0.5),
                  width: 0.5,
                ),
              ),
            ),
            child: NavigationBar(
              selectedIndex: widget.navigationShell.currentIndex,
              onDestinationSelected: (index) => widget.navigationShell.goBranch(
                index,
                initialLocation: index == widget.navigationShell.currentIndex,
              ),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: _BadgeIcon(
                    icon: Icons.folder_outlined,
                    showDot: pendingDocs > 0,
                    color: WazyColors.danger,
                    tooltip: '$pendingDocs need attention',
                  ),
                  selectedIcon: _BadgeIcon(
                    icon: Icons.folder_rounded,
                    showDot: pendingDocs > 0,
                    color: WazyColors.danger,
                    tooltip: '$pendingDocs need attention',
                  ),
                  label: 'Documents',
                ),
                NavigationDestination(
                  icon: _BadgeIcon(
                    icon: Icons.account_balance_wallet_outlined,
                    showDot: summary.net != 0,
                    color: summary.net >= 0 ? WazyColors.safe : WazyColors.danger,
                  ),
                  selectedIcon: _BadgeIcon(
                    icon: Icons.account_balance_wallet_rounded,
                    showDot: summary.net != 0,
                    color: summary.net >= 0 ? WazyColors.safe : WazyColors.danger,
                  ),
                  label: 'Money',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon with a small status dot in the top-right corner.
class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final bool showDot;
  final Color color;
  final String? tooltip;

  const _BadgeIcon({
    required this.icon,
    required this.showDot,
    required this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon);
    if (!showDot) return iconWidget;

    return Badge(
      isLabelVisible: true,
      backgroundColor: color,
      smallSize: 8,
      child: iconWidget,
    );
  }
}
