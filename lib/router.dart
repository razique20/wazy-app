import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'models/finance.dart';
import 'theme/app_theme.dart';
import 'models/expiry_item.dart';
import 'services/alert_preferences_service.dart';
import 'services/anomaly_detection_service.dart';
import 'services/budget_alert_service.dart';
import 'services/document_scanner_service.dart';
import 'services/finance_service.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/documents_screen.dart';
import 'screens/document_scan_screen.dart';
import 'screens/document_detail_screen.dart';
import 'screens/expiry_list_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/money_screen.dart';
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
);

/// Bottom navigation shell with the four main tabs.
///
/// Destinations carry live context:
/// * Documents — red badge when any tracked document needs action (≤30 days).
/// * Money — amber dot when a budget is ≥80% used, red when ≥100%.
class _AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const _AppShell({required this.navigationShell});

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  List<ExpiryItem> _items = [];
  BudgetStatusResult? _budgetStatus;
  int _spikeCount = 0;

  /// Navbar index of the bell (opens the notifications sheet, not a tab).
  /// Profile sits one position after it, mapping to branch 3.
  static const int _bellNavIndex = 3;

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
    setState(() {
      // Badge mirrors the alerts: hidden entirely when the user disabled
      // budget alerts in Profile.
      _budgetStatus = AlertPreferencesService.instance.budgetAlertsEnabled
          ? BudgetAlertService.instance.worstStatus
          : null;

      // Bell badge: bill spike count (0 when spikes are muted).
      _spikeCount = AlertPreferencesService.instance.billSpikesEnabled
          ? AnomalyDetectionService.instance
              .detectRecentAnomalies(FinanceService.instance.activeTransactions)
              .length
          : 0;
    });
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

  /// Bottom sheet listing every current notification: documents needing
  /// attention (upcoming + expired), bill spikes, and budget alerts.
  void _showNotificationsSheet(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    final rows = <Widget>[];

    // --- Document reminders ---
    final pending = _items
        .where((i) => i.isActive && !i.isExpired && i.daysRemaining <= 30)
        .toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    for (final item in pending) {
      rows.add(_NotificationRow(
        icon: Icons.event_available_rounded,
        color: item.daysRemaining <= 7 ? WazyColors.danger : WazyColors.warning,
        title: item.displayName,
        subtitle:
            'Expires in ${item.daysRemaining} day${item.daysRemaining == 1 ? '' : 's'} — renew soon',
        onTap: () => context.go('/documents'),
      ));
    }

    // --- Expired documents ---
    for (final item in _items.where((i) => i.isActive && i.isExpired)) {
      final days = now.difference(item.expiresAt).inDays;
      rows.add(_NotificationRow(
        icon: Icons.error_outline_rounded,
        color: WazyColors.danger,
        title: item.displayName,
        subtitle: 'Expired ${days <= 0 ? 'today' : '$days day${days == 1 ? '' : 's'} ago'} — act now',
        onTap: () => context.go('/documents'),
      ));
    }

    // --- Bill spikes ---
    if (AlertPreferencesService.instance.billSpikesEnabled) {
      for (final anomaly in AnomalyDetectionService.instance
          .detectRecentAnomalies(FinanceService.instance.activeTransactions)) {
        rows.add(_NotificationRow(
          icon: Icons.trending_up_rounded,
          color: WazyColors.warning,
          title: 'Bill spike: ${anomaly.transaction.title}',
          subtitle: anomaly.message,
          onTap: () => context.go('/money'),
        ));
      }
    }

    // --- Budget alerts ---
    final budget = _budgetStatus;
    if (budget != null) {
      final pct = (budget.ratio * 100).toStringAsFixed(0);
      final exceeded = budget.status == BudgetAlertLevel.exceeded;
      rows.add(_NotificationRow(
        icon: Icons.account_balance_wallet_rounded,
        color: exceeded ? WazyColors.danger : WazyColors.warning,
        title:
            '${exceeded ? "Budget exceeded" : "Close to budget"} — ${budget.budget.category.displayName}',
        subtitle:
            '$pct% of the monthly budget used this month.',
        onTap: () => context.go('/money'),
      ));
    }

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_rounded, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Notifications',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(sheetContext),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.notifications_off_rounded,
                          size: 40, color: theme.colorScheme.outline),
                      const SizedBox(height: 12),
                      Text(
                        'You are all caught up',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'No alerts right now.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: rows,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingDocs = _items
        .where((i) => i.isActive && !i.isExpired && i.daysRemaining <= 30)
        .length;
    final expiredDocs = _items.where((i) => i.isActive && i.isExpired).length;
    final notificationCount = pendingDocs + expiredDocs + _spikeCount + (_budgetStatus != null ? 1 : 0);

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
              selectedIndex: widget.navigationShell.currentIndex > _bellNavIndex
                  ? widget.navigationShell.currentIndex + 1
                  : widget.navigationShell.currentIndex,
              onDestinationSelected: (index) {
                if (index == _bellNavIndex) {
                  _showNotificationsSheet(context);
                  return;
                }
                // Bell occupies navbar position 3; branches are 0-3.
                final branch = index > _bellNavIndex ? index - 1 : index;
                widget.navigationShell.goBranch(
                  branch,
                  initialLocation: branch == widget.navigationShell.currentIndex,
                );
              },
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: _BadgeIcon(
                    icon: Icons.account_balance_wallet_outlined,
                    showDot: _budgetStatus != null,
                    color: _budgetStatus?.status == BudgetAlertLevel.exceeded
                        ? WazyColors.danger
                        : WazyColors.warning,
                  ),
                  selectedIcon: _BadgeIcon(
                    icon: Icons.account_balance_wallet_rounded,
                    showDot: _budgetStatus != null,
                    color: _budgetStatus?.status == BudgetAlertLevel.exceeded
                        ? WazyColors.danger
                        : WazyColors.warning,
                  ),
                  label: 'Money',
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
                    icon: Icons.notifications_outlined,
                    showDot: notificationCount > 0,
                    color: WazyColors.danger,
                    tooltip: '$notificationCount notifications',
                  ),
                  selectedIcon: _BadgeIcon(
                    icon: Icons.notifications_rounded,
                    showDot: notificationCount > 0,
                    color: WazyColors.danger,
                    tooltip: '$notificationCount notifications',
                  ),
                  label: 'Alerts',
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

/// One tappable row inside the notifications sheet.
class _NotificationRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NotificationRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withOpacity(0.15),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
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
