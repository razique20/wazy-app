import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/document_collection.dart';
import '../models/document_type.dart';
import '../models/expiry_item.dart';
import '../models/finance.dart';
import '../services/collection_service.dart';
import '../services/document_scanner_service.dart';
import '../services/finance_service.dart';
import '../services/urgency_engine.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
    FinanceService.instance.addListener(_reloadMoney);
  }

  @override
  void dispose() {
    FinanceService.instance.removeListener(_reloadMoney);
    super.dispose();
  }

  void _reloadMoney() {
    if (mounted) setState(() {});
  }

  /// Active documents already past their expiry date.
  List<ExpiryItem> get _expiredItems {
    final now = DateTime.now();
    return _items
        .where((i) => i.isActive && i.expiresAt.isBefore(now))
        .toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
  }

  Future<void> _loadData() async {
    final collection =
        await DocumentCollectionService.instance.getActiveCollection();
    final items = await DocumentScannerService().getAllItems(includeExpired: true);
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
                    ListTile(
                      leading: Icon(collection.icon),
                      title: Text(collection.name),
                      subtitle: Text(collection.subtitle),
                      trailing: collection.id == service.activeCollectionId
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      onTap: () => Navigator.pop(ctx, collection.id),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('New collection'),
              onTap: () => Navigator.pop(ctx, _createAction),
            ),
          ],
        ),
      ),
    );

    if (!mounted || selectedId == null) return;

    if (selectedId == _createAction) {
      final name = await showCreateCollectionDialog(context);
      if (!mounted || name == null) return;
      try {
        final created = await service.createCollection(name);
        await service.setActive(created.id);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not create "$name"'),
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
    await _loadData();
  }

  static const String _createAction = '__create__';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgency = UrgencyEngine().compute(_items);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home_add_document',
        onPressed: () => context.push('/scan'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Document'),
        backgroundColor: WazyColors.cyanAccent,
        foregroundColor: const Color(0xFF0A0E1A),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 80),
                  children: [
                    _buildHeader(theme),
                    const SizedBox(height: 12),
                    _buildQuickActionsRow(theme),
                    const SizedBox(height: 16),
                    _buildAttentionBanner(theme, urgency),
                    const SizedBox(height: 16),
                    _buildStatsRow(theme, urgency),
                    const SizedBox(height: 16),
                    _buildBudgetSummary(theme),
                    if (_expiredItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildExpiredAlert(theme),
                    ],
                    const SizedBox(height: 24),
                    _buildUpcomingSection(theme, urgency),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildQuickActionsRow(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/scan'),
                  icon: const Icon(Icons.add_task_rounded, size: 18),
                  label: const Text(
                    'Add Document',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WazyColors.navyPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/money'),
                  icon: const Icon(Icons.add_card_rounded, size: 18),
                  label: const Text(
                    'Add Fund / Record',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WazyColors.cyanSecondary,
                    foregroundColor: const Color(0xFF0A0E1A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final created = await NaturalLanguageAddDialog.show(context);
                if (created != null) _loadData();
              },
              icon: const Icon(Icons.bolt_rounded, size: 18, color: Colors.amber),
              label: const Text(
                '⚡ Quick Add with Natural Language',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
                side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Header: greeting + collection switcher
  // ------------------------------------------------------------------

  Widget _buildHeader(ThemeData theme) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              _activeCollection?.icon ?? Icons.person_rounded,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: _showCollectionSwitcher,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _activeCollection?.name ?? 'Personal',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.expand_more_rounded,
                        size: 18,
                      ),
                    ],
                  ),
                  Text(
                    _activeCollection?.subtitle ?? greeting,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Attention banner (documents)
  // ------------------------------------------------------------------

  Widget _buildAttentionBanner(ThemeData theme, UrgencySnapshot urgency) {
    final pending = urgency.pendingActions;
    final isDark = theme.brightness == Brightness.dark;

    final bannerBg = pending.isEmpty
        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
        : (isDark ? const Color(0xFF451A1A) : const Color(0xFFFEF2F2));
    final bannerBorder = pending.isEmpty
        ? (isDark ? const Color(0xFF059669).withOpacity(0.4) : const Color(0xFFA7F3D0))
        : (isDark ? const Color(0xFFEF4444).withOpacity(0.4) : const Color(0xFFFCA5A5));
    final iconColor = pending.isEmpty
        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
        : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626));
    final textColor = pending.isEmpty
        ? (isDark ? Colors.white : const Color(0xFF065F46))
        : (isDark ? Colors.white : const Color(0xFF991B1B));
    final subtitleColor = pending.isEmpty
        ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857))
        : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  pending.isEmpty
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
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
                      pending.isEmpty
                          ? 'All documents on track'
                          : '${pending.length} renewal${pending.length == 1 ? '' : 's'} need attention',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pending.isEmpty
                          ? (_items.isEmpty
                              ? 'Scan your first document to start tracking.'
                              : 'Nothing expires in the next 30 days.')
                          : pending
                                  .take(2)
                                  .map((a) => a.displayName)
                                  .join(', ') +
                              (pending.length > 2
                                  ? ' +${pending.length - 2}'
                                  : ''),
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleColor,
                      ),
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
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Quick stats row: documents, critical, expiring, budget health
  // ------------------------------------------------------------------

  Widget _buildStatsRow(ThemeData theme, UrgencySnapshot urgency) {
    final transactions = FinanceService.instance.activeTransactions;
    final budgets = FinanceService.instance.activeBudgets;
    final spendByCategory =
        FinanceMath.spendByCategory(transactions, DateTime.now());

    // Budget health: ratio of total spend against total limits.
    var totalLimit = 0.0;
    var totalSpentOnBudgets = 0.0;
    for (final b in budgets) {
      totalLimit += b.monthlyLimit;
      totalSpentOnBudgets += spendByCategory[b.category] ?? 0;
    }
    final healthRatio =
        totalLimit <= 0 ? null : (totalSpentOnBudgets / totalLimit).clamp(0.0, 1.0);

    final isDark = theme.brightness == Brightness.dark;
    final greenColor = isDark ? Colors.greenAccent : const Color(0xFF059669);
    final redColor = isDark ? Colors.redAccent : const Color(0xFFDC2626);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _statTile(
              theme,
              icon: Icons.folder_open_rounded,
              value: '${_items.length}',
              label: 'Documents',
              valueColor: greenColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statTile(
              theme,
              icon: Icons.warning_amber_rounded,
              value: '${urgency.criticalCount}',
              label: 'Critical',
              valueColor: urgency.criticalCount > 0 ? redColor : greenColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statTile(
              theme,
              icon: Icons.schedule_rounded,
              value: '${urgency.highCount}',
              label: '≤30 days',
              valueColor: urgency.highCount > 0 ? redColor : greenColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statTile(
              theme,
              icon: healthRatio != null && healthRatio >= 1.0
                  ? Icons.trending_down_rounded
                  : Icons.trending_up_rounded,
              value: healthRatio == null
                  ? '—'
                  : '${(healthRatio * 100).toStringAsFixed(0)}%',
              label: 'Budget',
              valueColor: healthRatio != null && healthRatio >= 1.0 ? redColor : greenColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(
    ThemeData theme, {
    required IconData icon,
    required String value,
    required String label,
    required Color valueColor,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final neutralIconColor = isDark ? WazyColors.textSecondary : WazyColors.textSecondaryLight;
    final neutralLabelColor = isDark ? WazyColors.textMuted : WazyColors.textMutedLight;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? WazyColors.slate : WazyColors.cloud,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? WazyColors.slateLight.withOpacity(0.3)
              : WazyColors.fog,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: neutralIconColor),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: valueColor,
              ),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: neutralLabelColor,
              fontSize: 10,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Budget summary card (Money tier) — compact, one tap for details
  // ------------------------------------------------------------------

  Widget _buildBudgetSummary(ThemeData theme) {
    final now = DateTime.now();
    final transactions = FinanceService.instance.activeTransactions;
    final summary = FinanceMath.summaryForMonth(transactions, now);
    final outlook = FinanceMath.renewalOutlook(_items, 90);
    final spendByCategory = FinanceMath.spendByCategory(transactions, now);
    final budgets = FinanceService.instance.activeBudgets;

    // Top spending category this month.
    String topCategoryLabel = '';
    double topCategoryAmount = 0;
    for (final entry in spendByCategory.entries) {
      if (entry.value > topCategoryAmount) {
        topCategoryAmount = entry.value;
        topCategoryLabel = entry.key.displayName;
      }
    }

    // Budget health line.
    var totalLimit = 0.0;
    var totalSpentOnBudgets = 0.0;
    for (final b in budgets) {
      totalLimit += b.monthlyLimit;
      totalSpentOnBudgets += spendByCategory[b.category] ?? 0;
    }
    String healthText = '';
    Color? healthColor;
    if (totalLimit > 0) {
      final ratio = totalSpentOnBudgets / totalLimit;
      if (ratio >= 1.0) {
        healthText =
            'Budgets exceeded — ${MoneyFormat.aed(totalSpentOnBudgets - totalLimit)} over';
        healthColor = Colors.red;
      } else if (ratio >= 0.8) {
        healthText =
            'Close to budget — ${(ratio * 100).toStringAsFixed(0)}% used';
        healthColor = Colors.orange;
      } else {
        healthText =
            'On track — ${(ratio * 100).toStringAsFixed(0)}% of budget used';
        healthColor = Colors.green;
      }
    }

    // Daily pace: average spend per day elapsed this month.
    final dayOfMonth = now.day;
    final dailyPace = dayOfMonth > 0 ? summary.expense / dayOfMonth : 0.0;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final projected = dailyPace * daysInMonth;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () => context.go('/money'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This month',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _moneyColumn(
                      theme,
                      'Income',
                      MoneyFormat.aed(summary.income),
                      Colors.green,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: theme.dividerColor,
                  ),
                  Expanded(
                    child: _moneyColumn(
                      theme,
                      'Spent',
                      MoneyFormat.aed(summary.expense),
                      Colors.red,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: theme.dividerColor,
                  ),
                  Expanded(
                    child: _moneyColumn(
                      theme,
                      'Net',
                      MoneyFormat.aed(summary.net),
                      summary.net >= 0 ? Colors.teal : Colors.deepOrange,
                    ),
                  ),
                ],
              ),
              if (topCategoryLabel.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.pie_chart_rounded,
                      size: 13,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Top spend: $topCategoryLabel · ${MoneyFormat.aed(topCategoryAmount)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (summary.expense > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.show_chart_rounded,
                      size: 13,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Pace: ${MoneyFormat.aed(dailyPace)}/day · projected ${MoneyFormat.aed(projected)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (healthText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      healthColor == Colors.red
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 13,
                      color: healthColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        healthText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: healthColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (outlook > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_repeat_rounded,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${MoneyFormat.aed(outlook)} in renewals due within 90 days',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () => context.push('/document/${worst.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.gpp_bad_rounded,
                  color: Colors.red,
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
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
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
              const Icon(Icons.chevron_right_rounded, color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moneyColumn(
    ThemeData theme,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Upcoming renewals — 3 tiles, full list in Documents tab
  // ------------------------------------------------------------------

  Widget _buildUpcomingSection(ThemeData theme, UrgencySnapshot urgency) {
    final now = DateTime.now();
    final upcoming = _items
        .where((i) => i.isActive && i.expiresAt.isAfter(now))
        .toList()
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
            ...upcoming.take(3).map(
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
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: theme.colorScheme.outline,
          ),
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
