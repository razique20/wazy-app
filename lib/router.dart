import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/finance.dart';
import 'theme/app_theme.dart';
import 'models/expiry_item.dart';
import 'services/alert_preferences_service.dart';
import 'services/budget_alert_service.dart';
import 'services/document_scanner_service.dart';
import 'services/finance_service.dart';
import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/document_scan_screen.dart';
import 'screens/document_detail_screen.dart';
import 'screens/expiry_list_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/money_screen.dart';
import 'screens/budgets_screen.dart';
import 'screens/envelopes_screen.dart';
import 'screens/records_screen.dart';
import 'screens/cash_flow_forecast_screen.dart';
import 'screens/global_search_screen.dart';
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
    final isAuthRoute = path == '/login' || path == '/welcome';

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
      path: '/welcome',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const WelcomeScreen(),
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
      builder: (context, state) {
        final extraItem = state.extra as ExpiryItem?;
        return DocumentScanScreen(initialItem: extraItem);
      },
    ),
    GoRoute(
      path: '/document/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return DocumentDetailScreen(documentId: id);
      },
    ),
    GoRoute(
      path: '/document/:id/edit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        final extraItem = state.extra as ExpiryItem?;
        return DocumentScanScreen(documentId: id, initialItem: extraItem);
      },
    ),
    GoRoute(
      path: '/search',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const GlobalSearchScreen(),
    ),
    GoRoute(
      path: '/expiry-list',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExpiryListScreen(),
    ),
    GoRoute(
      path: '/cash-flow-forecast',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CashFlowForecastScreen(),
    ),
    // Focused pages behind the Home categories grid (Money sub-features).
    GoRoute(
      path: '/budgets',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BudgetsScreen(),
    ),
    GoRoute(
      path: '/envelopes',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const EnvelopesScreen(),
    ),
    GoRoute(
      path: '/records',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RecordsScreen(),
    ),
    // 4-tab bottom-nav shell:
    //   Home      — cross-tier dashboard (documents + money summary)
    //   Money     — Tier 2: budgets, envelopes, transactions
    //   Documents — Tier 1: full expiry tracking
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
          navigatorKey: _moneyShellKey,
          routes: [
            GoRoute(
              path: '/money',
              builder: (context, state) => const MoneyScreen(),
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
);/// Bottom navigation shell with the four main tabs.
///
/// Floating dark pill design: icon-only destinations with a filled circular
/// indicator for the active tab.
///
/// Destinations carry live context:
/// * Documents — red badge when any tracked document needs action (≤30 days).
/// * Money — amber dot when a budget is ≥80% used, red when ≥100%.
///
/// Global search stays reachable from the Home categories grid, the
/// Documents hero, and the Money/Settings quick actions.
class _AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const _AppShell({required this.navigationShell});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  List<ExpiryItem> _items = [];
  BudgetStatusResult? _budgetStatus;

  @override
  void initState() {
    super.initState();
    _loadItems();
    DocumentScannerService.instance.addListener(_onItemsChanged);
    FinanceService.instance.addListener(_onFinanceChanged);
    _refreshBudgetStatus();
  }

  @override
  void dispose() {
    DocumentScannerService.instance.removeListener(_onItemsChanged);
    FinanceService.instance.removeListener(_onFinanceChanged);
    super.dispose();
  }

  void _onFinanceChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshBudgetStatus();
    });
  }

  void _refreshBudgetStatus() {
    // Badge mirrors the alerts: hidden entirely when the user disabled
    // budget alerts in Profile.
    if (!AlertPreferencesService.instance.budgetAlertsEnabled) {
      setState(() => _budgetStatus = null);
      return;
    }
    setState(() => _budgetStatus = BudgetAlertService.instance.worstStatus);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: widget.navigationShell,
      extendBody: true,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            // Near-black like the reference bar — must stay clearly distinct
            // from the navy hero backdrop on the Home tab.
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFF0B1020),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          // Fixed height: the Center inside each item would otherwise
          // expand into the loose height constraints of the nav slot.
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                _NavPillItem(
                  icon: widget.navigationShell.currentIndex == 0
                      ? Icons.home_rounded
                      : Icons.home_outlined,
                  active: widget.navigationShell.currentIndex == 0,
                  tooltip: 'Home',
                  onTap: () => _goBranch(0),
                ),
                _NavPillItem(
                  icon: widget.navigationShell.currentIndex == 1
                      ? Icons.account_balance_wallet_rounded
                      : Icons.account_balance_wallet_outlined,
                  active: widget.navigationShell.currentIndex == 1,
                  tooltip: 'Money',
                  showDot: _budgetStatus != null,
                  dotColor:
                      _budgetStatus?.status == BudgetAlertLevel.exceeded
                          ? WazyColors.danger
                          : WazyColors.warning,
                  onTap: () => _goBranch(1),
                ),
                _NavPillItem(
                  icon: widget.navigationShell.currentIndex == 2
                      ? Icons.description_rounded
                      : Icons.description_outlined,
                  active: widget.navigationShell.currentIndex == 2,
                  tooltip: 'Documents',
                  showDot: pendingDocs > 0,
                  dotColor: WazyColors.danger,
                  onTap: () => _goBranch(2),
                ),
                _NavPillItem(
                  icon: widget.navigationShell.currentIndex == 3
                      ? Icons.person_rounded
                      : Icons.person_outline_rounded,
                  active: widget.navigationShell.currentIndex == 3,
                  tooltip: 'Profile',
                  onTap: () => _goBranch(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goBranch(int index) => widget.navigationShell.goBranch(
        index,
        initialLocation: index == widget.navigationShell.currentIndex,
      );
}

/// One icon-only destination inside the floating nav pill. The active tab
/// gets a filled circular backdrop; status dots mirror the shell badges.
class _NavPillItem extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;
  final bool showDot;
  final Color? dotColor;

  const _NavPillItem({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
    this.showDot = false,
    this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? Colors.white.withOpacity(0.16)
                          : Colors.transparent,
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: active
                          ? Colors.white
                          : Colors.white.withOpacity(0.55),
                    ),
                  ),
                  if (showDot)
                    Positioned(
                      right: 4,
                      top: 3,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: dotColor ?? WazyColors.danger,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.9),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

