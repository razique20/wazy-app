import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_collection.dart';
import '../models/expiry_item.dart';
import '../models/finance.dart';
import '../models/subscription_tier.dart';
import '../services/alert_preferences_service.dart';
import '../services/anomaly_detection_service.dart';
import '../services/collection_service.dart';
import '../services/document_scanner_service.dart';
import '../services/entitlement_service.dart';
import '../services/finance_service.dart';
import '../services/theme_service.dart';
import '../services/urgency_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/upgrade_dialog.dart';
import '../widgets/widgets.dart';
import 'money_screen.dart';

/// Home tab: cross-tier dashboard.
///
/// Only the essentials: what needs attention (documents), where the money
/// stands this month (budget summary), and the next renewals. Details live in
/// the Documents and Money tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DocumentCollection? _activeCollection;
  List<ExpiryItem> _items = [];
  bool _loading = true;

  /// The "renewals need attention" banner was closed by the user this
  /// session. Re-appears on restart or when data reloads with a *new* count.
  int? _dismissedAttentionCount;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkFirstTimeGuide();
    FinanceService.instance.addListener(_reloadMoney);
    DocumentScannerService.instance.addListener(_onServiceChanged);
  }

  /// Auto-show the interactive app guide on first ever launch.
  Future<void> _checkFirstTimeGuide() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('hasSeenAppGuide') ?? false;
    if (!hasSeen && mounted) {
      // Small delay so the home screen renders first before overlaying the guide.
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) showAppGuideDialog(context);
    }
  }

  @override
  void dispose() {
    FinanceService.instance.removeListener(_reloadMoney);
    DocumentScannerService.instance.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    _loadData();
  }

  void _reloadMoney() {
    if (mounted) setState(() {});
  }

  /// Active documents already past their expiry date.
  List<ExpiryItem> get _expiredItems {
    final now = DateTime.now();
    return _items.where((i) => i.isActive && i.expiresAt.isBefore(now)).toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
  }

  Future<void> _loadData() async {
    final collection = await DocumentCollectionService.instance
        .getActiveCollection();
    final items = await DocumentScannerService().getAllItems(
      includeExpired: true,
    );
    await FinanceService.instance.init();
    if (mounted) {
      setState(() {
        _activeCollection = collection;
        _items = items;
        _loading = false;
      });
    }
  }

  /// Open the collection switcher sheet and apply the selection.
  Future<void> _showCollectionSwitcher() async {
    final service = DocumentCollectionService.instance;
    final collections = service.collections;
    if (!mounted) return;

    final theme = Theme.of(context);
    final entitlements = EntitlementService.instance;
    final companyCount = collections.where((c) => !c.isPersonal).length;
    final canCreateMore = entitlements.canAddCompanyCollections(companyCount);

    final selectedId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Switch collection',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final collection in collections)
                    Builder(
                      builder: (tileCtx) {
                        final isLocked = entitlements.isCollectionLocked(collection);
                        final reqTier = entitlements.requiredTierForCollection(collection);
                        final reqFeature = entitlements.requiredFeatureForCollection(collection);

                        return ListTile(
                          leading: isLocked
                              ? const Icon(Icons.lock_rounded, color: WazyColors.warning)
                              : Icon(collection.icon),
                          title: Row(
                            children: [
                              Expanded(child: Text(collection.name)),
                              if (isLocked)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: WazyColors.warning.withAlpha(35),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: WazyColors.warning.withAlpha(120),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Text(
                                    'LOCKED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: WazyColors.warning,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text(
                            isLocked
                                ? 'Plan limit reached • Requires ${TierInfo.all[reqTier]!.name}'
                                : collection.subtitle,
                            style: isLocked
                                ? TextStyle(color: theme.colorScheme.outline, fontSize: 12)
                                : null,
                          ),
                          trailing: isLocked
                              ? const Icon(Icons.lock_outline_rounded, size: 18, color: WazyColors.warning)
                              : (collection.id == service.activeCollectionId
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : null),
                          onTap: () {
                            if (isLocked) {
                              Navigator.pop(ctx);
                              showUpgradeDialog(context, reqFeature);
                            } else {
                              Navigator.pop(ctx, collection.id);
                            }
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                canCreateMore
                    ? Icons.add_circle_outline
                    : Icons.lock_outline_rounded,
                color: canCreateMore ? null : WazyColors.warning,
              ),
              title: const Text('New collection'),
              trailing: !canCreateMore
                  ? const TierBadge(compact: true, tier: SubscriptionTier.plus)
                  : null,
              onTap: () => Navigator.pop(ctx, _createAction),
            ),
          ],
        ),
      ),
    );

    if (!mounted || selectedId == null) return;

    if (selectedId == _createAction) {
      if (!await enforceCompanyCollectionLimit(context)) return;
      final res = await showCreateCollectionDialog(context);
      if (!mounted || res == null) return;
      try {
        final created = await service.createCollection(
          res.name,
          countryCode: res.countryCode,
        );
        await service.setActive(created.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not create "${res.name}": $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } else {
      await service.setActive(selectedId);
    }

    await DocumentScannerService.instance.refresh();
    // Notify the Money tab too: FinanceService filters by the active
    // collection and MoneyScreen listens to its ChangeNotifier.
    await FinanceService.instance.refresh();
    await _loadData();
  }

  static const String _createAction = '__create__';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgency = UrgencyEngine().compute(_items);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // Ink backdrop behind the hero; the content sheet covers the rest.
      backgroundColor: isDark ? WazyColors.obsidian : WazyColors.ink,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                color: theme.colorScheme.secondary,
                onRefresh: _loadData,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildHeroHeader(theme, urgency),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            _buildCategoriesGrid(theme, urgency),
                            _buildPlanRestrictionBanner(theme),
                            // Both banners own their top margin internally and
                            // collapse to zero height when not applicable, so
                            // no reserved gap can ever appear between sections.
                            _buildAttentionBanner(theme, urgency),
                            if (_expiredItems.isNotEmpty)
                              _buildExpiredAlert(theme),
                            const SizedBox(height: 20),
                            _buildUpcomingSection(theme, urgency),
                            // Keep the last tile scrollable clear of the
                            // floating nav pill (height + margins ≈ 80).
                            SizedBox(
                              height:
                                  8 + MediaQuery.of(context).padding.bottom + 80,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // White filler: extends the sheet across the rest of the
                    // viewport when content is short, and into overscroll
                    // (iOS bounce) — the navy backdrop never peeks out below
                    // the content, behind the floating nav pill. Kept empty:
                    // a fill-remaining sliver queries the child's intrinsics
                    // during overscroll, which a shrinkWrap grid can't do.
                    SliverFillRemaining(
                      hasScrollBody: false,
                      fillOverscroll: true,
                      child: ColoredBox(color: theme.colorScheme.surface),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Open the scan flow after enforcing the free-tier document limit.
  Future<void> _openScanner() async {
    if (!await enforceDocumentLimit(context)) return;
    if (mounted) await context.push('/scan');
  }

  /// Quick-add a money record without leaving Home: the same form sheet the
  /// Money tab uses; FinanceService notifies and the hero totals refresh.
  Future<void> _quickAddRecord() async {
    final created = await showModalBottomSheet<FinanceTransaction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const TransactionFormSheet(),
    );
    if (created == null) return;
    await FinanceService.instance.addTransaction(created);
  }

  // ------------------------------------------------------------------
  // Categories grid (top of white content sheet, like the reference)
  // ------------------------------------------------------------------
  Widget _buildCategoriesGrid(ThemeData theme, UrgencySnapshot urgency) {
    final pending = urgency.pendingActions.length;
    final isDark = theme.brightness == Brightness.dark;
    final tileBg = isDark ? WazyColors.slate.withOpacity(0.5) : Colors.white;
    final labelColor = isDark ? WazyColors.textSecondary : WazyColors.textPrimaryLight;

    Widget tile(BentoIconTile iconTile, String label, VoidCallback onTap) =>
        Material(
          color: tileBg,
          borderRadius: BorderRadius.circular(WazyRadius.tile),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  iconTile,
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 10.5,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Categories',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (pending > 0)
                Text(
                  '$pending need attention',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: WazyColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Explicit zero: without it the scroll view inherits the shell's
            // extendBody bottom inset (nav-pill height) as implicit sliver
            // padding — a ~120px blank band under the tiles on device.
            padding: EdgeInsets.zero,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.95,
            children: [
              tile(
                const BentoIconTile(icon: Icons.description_rounded, color: WazyColors.blue),
                'Documents',
                () => context.go('/documents'),
              ),
              tile(
                const BentoIconTile(icon: Icons.calendar_month_rounded, color: WazyColors.red),
                'Renewals',
                () => context.push('/expiry-list'),
              ),
              tile(
                const BentoIconTile(icon: Icons.savings_rounded, color: WazyColors.green),
                'Envelopes',
                () => context.push('/envelopes'),
              ),
              tile(
                const BentoIconTile(icon: Icons.receipt_long_rounded, color: WazyColors.orange),
                'Records',
                () => context.push('/records'),
              ),
              tile(
                const BentoIconTile(icon: Icons.trending_up_rounded, color: WazyColors.lilac),
                'Forecast',
                () => context.push('/cash-flow-forecast'),
              ),
              tile(
                const BentoIconTile(icon: Icons.auto_awesome_rounded, color: WazyColors.amber),
                'AI Summary',
                () => context.push('/ai-summary'),
              ),
              tile(
                const BentoIconTile(icon: Icons.flag_rounded, color: WazyColors.sky),
                'AI Planner',
                () => context.push('/ai-budget-plan'),
              ),
              tile(
                const BentoIconTile(icon: Icons.document_scanner_rounded, color: WazyColors.indigo),
                'Scan',
                () {
                  // Free plan document limit — paywall when the quota is full.
                  unawaited(_openScanner());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Header: greeting + collection switcher
  // ------------------------------------------------------------------

  /// Navy gradient hero: greeting + collection switcher, dark-mode quick
  /// toggle, notification bell, then the month balance and action pills.
  Widget _buildHeroHeader(ThemeData theme, UrgencySnapshot urgency) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final isDark = theme.brightness == Brightness.dark;

    final now = DateTime.now();
    final summary = FinanceMath.summaryForMonth(
      FinanceService.instance.activeTransactions,
      now,
    );
    final nextRenewal = _nextRenewalLabel();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Left: collection avatar + switcher.
              InkWell(
                onTap: _showCollectionSwitcher,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          _activeCollection?.icon ?? Icons.person_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                _activeCollection?.name ?? 'Personal',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Icon(
                                Icons.expand_more_rounded,
                                size: 16,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Dark mode toggle.
              _HeroIconButton(
                icon: isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_outlined,
                onTap: () async {
                  final mode = ThemeService.instance.mode;
                  await ThemeService.instance.setMode(
                    mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildNotificationBell(theme),
            ],
          ),
          const SizedBox(height: 22),
          // Balance block.
          Text(
            'Net this month',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Flexible: inside a Row the FittedBox would otherwise get
              // unbounded width and never scale down — long balances
              // overflowed the hero on narrow screens.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    MoneyFormat.aed(summary.net),
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
              ),
              if (summary.income > 0 || summary.expense > 0) ...[
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DocumentCollectionService.instance.activeCurrency,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${MoneyFormat.aed(summary.income)} in · ${MoneyFormat.aed(summary.expense)} out'
            '${nextRenewal == null ? '' : ' · next: $nextRenewal'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          // Action pills.
          Row(
            children: [
              _HeroActionPill(
                icon: Icons.south_west_rounded,
                label: 'Record',
                outlined: true,
                onTap: _quickAddRecord,
              ),
              const SizedBox(width: 10),
              _HeroActionPill(
                icon: Icons.north_east_rounded,
                label: 'Budget',
                filled: true,
                onTap: () => context.push('/budgets'),
              ),
              const SizedBox(width: 10),
              _HeroActionPill(
                icon: Icons.more_horiz_rounded,
                label: '',
                outlined: true,
                onTap: () => _showCollectionSwitcher(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "12 Mar" of the nearest upcoming renewal, or null when none tracked.
  String? _nextRenewalLabel() {
    final now = DateTime.now();
    ExpiryItem? next;
    for (final item in _items) {
      if (!item.isActive || item.expiresAt.isBefore(now)) continue;
      if (next == null || item.expiresAt.isBefore(next.expiresAt)) {
        next = item;
      }
    }
    if (next == null) return null;
    return '${next.expiresAt.day} ${_monthAbbrev(next.expiresAt.month)}';
  }

  static String _monthAbbrev(int month) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][month - 1];

  // ------------------------------------------------------------------
  // Notifications bell (header) + alert list sheet
  // ------------------------------------------------------------------

  int get _notificationCount {
    final expired = _items.where((i) => i.isActive && i.isExpired).length;
    final pending = _items
        .where(
          (i) =>
              i.isActive &&
              !i.isExpired &&
              i.daysRemaining <= 30 &&
              i.daysRemaining != _dismissedAttentionCount,
        )
        .length;
    var spikes = 0;
    if (AlertPreferencesService.instance.billSpikesEnabled) {
      spikes = AnomalyDetectionService.instance
          .detectRecentAnomalies(FinanceService.instance.activeTransactions)
          .length;
    }
    return expired + pending + spikes;
  }

  Widget _buildNotificationBell(ThemeData theme) {
    final count = _notificationCount;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: _showNotificationsSheet,
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.notifications_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: WazyColors.danger,
                shape: BoxShape.circle,
                border: Border.all(color: WazyColors.ink, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Bottom sheet listing every current notification: documents needing
  /// attention (upcoming + expired), bill spikes, and budget alerts.
  void _showNotificationsSheet() {
    final now = DateTime.now();
    final rows = <Widget>[];

    // --- Upcoming renewals (within 30 days) ---
    final pending =
        _items
            .where((i) => i.isActive && !i.isExpired && i.daysRemaining <= 30)
            .toList()
          ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    for (final item in pending) {
      rows.add(
        _NotificationRow(
          icon: Icons.hourglass_top_rounded,
          color: item.daysRemaining <= 7
              ? WazyColors.danger
              : WazyColors.warning,
          title: item.displayName,
          subtitle:
              'Expires in ${item.daysRemaining} day${item.daysRemaining == 1 ? '' : 's'} — renew soon',
          onTap: () => context.go('/documents'),
        ),
      );
    }

    // --- Expired documents ---
    for (final item in _items.where((i) => i.isActive && i.isExpired)) {
      final days = now.difference(item.expiresAt).inDays;
      rows.add(
        _NotificationRow(
          icon: Icons.error_outline_rounded,
          color: WazyColors.danger,
          title: item.displayName,
          subtitle:
              'Expired ${days <= 0 ? 'today' : '$days day${days == 1 ? '' : 's'} ago'} — act now',
          onTap: () => context.go('/documents'),
        ),
      );
    }

    // --- Bill spikes ---
    if (AlertPreferencesService.instance.billSpikesEnabled) {
      for (final anomaly
          in AnomalyDetectionService.instance.detectRecentAnomalies(
            FinanceService.instance.activeTransactions,
          )) {
        rows.add(
          _NotificationRow(
            icon: Icons.trending_up_rounded,
            color: WazyColors.warning,
            title: 'Bill spike: ${anomaly.transaction.title}',
            subtitle: anomaly.message,
            onTap: () => context.go('/money'),
          ),
        );
      }
    }

    // --- Budget alerts ---
    if (AlertPreferencesService.instance.budgetAlertsEnabled) {
      final budgets = FinanceService.instance.activeBudgets;
      if (budgets.isNotEmpty) {
        final spend = FinanceMath.spendByCategory(
          FinanceService.instance.activeTransactions,
          DateTime.now(),
          collectionId: FinanceService.instance.activeCollectionIdSafe,
        );
        final statuses = FinanceMath.budgetStatuses(budgets, spend);
        for (final s in statuses) {
          if (s.status == BudgetAlertLevel.none) continue;
          final pct = (s.ratio * 100).toStringAsFixed(0);
          final exceeded = s.status == BudgetAlertLevel.exceeded;
          rows.add(
            _NotificationRow(
              icon: Icons.account_balance_wallet_rounded,
              color: exceeded ? WazyColors.danger : WazyColors.warning,
              title:
                  '${exceeded ? "Budget exceeded" : "Close to budget"} — ${s.budget.category.displayName}',
              subtitle: '$pct% of the monthly budget used this month.',
              onTap: () => context.go('/money'),
            ),
          );
        }
      }
    }

    final theme = Theme.of(context);
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
                      Icon(
                        Icons.notifications_off_rounded,
                        size: 40,
                        color: theme.colorScheme.outline,
                      ),
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

  // ------------------------------------------------------------------
  // Plan expired & locked collections alert
  // ------------------------------------------------------------------

  Widget _buildPlanRestrictionBanner(ThemeData theme) {
    final entitlements = EntitlementService.instance;
    final isExpired = entitlements.isPlanExpired;
    final lockedCount = entitlements.lockedCollectionsCount;

    if (!isExpired && lockedCount == 0) {
      return const SizedBox.shrink();
    }

    final isDark = theme.brightness == Brightness.dark;
    final bannerBg = isDark ? const Color(0xFF2A2110) : WazyColors.amberTint;
    const iconColor = WazyColors.amber;
    final textColor = isDark ? Colors.white : const Color(0xFF92400E);
    final subtitleColor = isDark
        ? const Color(0xFFFDE68A)
        : const Color(0xFFB45309);

    final title = isExpired
        ? 'Subscription plan expired'
        : '$lockedCount collection${lockedCount == 1 ? '' : 's'} locked';
    final subtitle = isExpired
        ? 'Renew your plan to unlock all workspaces and premium features.'
        : 'Your current plan limits company collections. Upgrade to unlock all.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: InkWell(
        onTap: () => showTierRequestSheet(context),
        borderRadius: BorderRadius.circular(WazyRadius.card),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bannerBg,
            borderRadius: BorderRadius.circular(WazyRadius.card),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(isDark ? 0.18 : 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: iconColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: subtitleColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : WazyColors.ink,
                  foregroundColor: isDark ? WazyColors.ink : Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => showTierRequestSheet(context),
                child: const Text('Renew', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Attention banner (documents)
  // ------------------------------------------------------------------

  Widget _buildAttentionBanner(ThemeData theme, UrgencySnapshot urgency) {
    final pending = urgency.pendingActions;
    // Nothing urgent, or the user closed this exact alert count: render
    // nothing. (The old green "all on track" banner was dropped — the hero
    // header already carries the status, and it left a phantom gap.)
    if (pending.isEmpty || _dismissedAttentionCount == pending.length) {
      return const SizedBox.shrink();
    }
    final isDark = theme.brightness == Brightness.dark;

    final bannerBg = isDark ? const Color(0xFF451A1A) : const Color(0xFFFEF2F2);
    final bannerBorder = isDark
        ? const Color(0xFFEF4444).withOpacity(0.4)
        : const Color(0xFFFCA5A5);
    final iconColor = isDark
        ? const Color(0xFFF87171)
        : const Color(0xFFDC2626);
    final textColor = isDark ? Colors.white : const Color(0xFF991B1B);
    final subtitleColor = isDark
        ? const Color(0xFFFCA5A5)
        : const Color(0xFFB91C1C);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: InkWell(
        onTap: () => context.go('/documents'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bannerBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: bannerBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${pending.length} renewal${pending.length == 1 ? '' : 's'} need attention',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pending
                                .take(2)
                                .map((a) => a.displayName)
                                .join(', ') +
                          (pending.length > 2
                              ? ' +${pending.length - 2}'
                              : ''),
                      style: TextStyle(fontSize: 13, color: subtitleColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: textColor.withOpacity(0.7),
              ),
              if (pending.isNotEmpty)
                // Close button: hides the banner until the pending count
                // changes (or the app restarts).
                Tooltip(
                  message: 'Dismiss alert',
                  child: InkWell(
                    onTap: () => setState(
                      () => _dismissedAttentionCount = pending.length,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: textColor.withOpacity(0.8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Expired documents alert
  // ------------------------------------------------------------------

  Widget _buildExpiredAlert(ThemeData theme) {
    final expired = _expiredItems;
    final worst = expired.first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: InkWell(
        onTap: () => context.push('/document/${worst.id}'),
        borderRadius: BorderRadius.circular(WazyRadius.card),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: WazyColors.redTint,
            borderRadius: BorderRadius.circular(WazyRadius.card),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: WazyColors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.event_busy_rounded,
                  color: WazyColors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${expired.length} document${expired.length == 1 ? '' : 's'} already expired',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: WazyColors.red,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      expired.length == 1
                          ? '${worst.displayName} — expired ${(-worst.daysRemaining)} day${-worst.daysRemaining == 1 ? '' : 's'} ago'
                          : 'Most urgent: ${worst.displayName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: WazyColors.red),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Upcoming renewals — 3 tiles, full list in Documents tab
  // ------------------------------------------------------------------

  Widget _buildUpcomingSection(ThemeData theme, UrgencySnapshot urgency) {
    final now = DateTime.now();
    final upcoming =
        _items.where((i) => i.isActive && i.expiresAt.isAfter(now)).toList()
          ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Next renewals · ${upcoming.length}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (upcoming.isNotEmpty)
                TextButton(
                  onPressed: () => context.push('/expiry-list'),
                  child: const Text('View all'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (upcoming.isEmpty)
            _buildEmptyState(theme)
          else
            ...upcoming
                .take(3)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _UpcomingTile(item: item),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          EmptyStateIllustration(scene: EmptyStateScene.document, size: 104),
          const SizedBox(height: 12),
          Text(
            'Nothing tracked yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Scan a trade licence, visa or Ejari to start tracking its expiry.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  final ExpiryItem item;

  const _UpcomingTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCritical = item.daysRemaining <= 7;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.push('/document/${item.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCritical
                      ? Colors.red.withOpacity(0.12)
                      : theme.colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    item.docType.icon,
                    color: isCritical ? Colors.red : theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.docType.displayName} • ${item.expiresAt.day}/${item.expiresAt.month}/${item.expiresAt.year}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${item.daysRemaining}d',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isCritical
                      ? WazyColors.danger
                      : item.daysRemaining <= 30
                      ? WazyColors.warning
                      : WazyColors.safe,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Frosted glass icon button used in the hero header (dark-mode toggle).
class _HeroIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeroIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// Outlined / filled action pill inside the hero header (Request / Transfer
/// style from the reference).
class _HeroActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool outlined;
  final VoidCallback onTap;

  const _HeroActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    assert(!(filled && outlined));
    final Color bg;
    final Color fg;
    final BorderSide side;
    if (filled) {
      bg = Colors.white;
      fg = WazyColors.ink;
      side = BorderSide.none;
    } else {
      bg = Colors.white.withOpacity(0.10);
      fg = Colors.white;
      side = BorderSide(color: Colors.white.withOpacity(0.22));
    }

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: side,
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: label.isEmpty ? 14 : 18,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
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
