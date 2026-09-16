import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/document_type.dart';
import '../models/expiry_item.dart';
import '../models/finance.dart';
import '../services/document_scanner_service.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';

/// The Money tab: renewal cost outlook, monthly budget tracking, savings
/// envelopes and a transaction log with CSV export.
class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  List<FinanceTransaction> _transactions = [];
  List<CategoryBudget> _budgets = [];
  List<SavingsEnvelope> _envelopes = [];
  List<ExpiryItem> _items = [];
  double _renewalOutlook90 = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    FinanceService.instance.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    FinanceService.instance.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    await FinanceService.instance.init();
    final items = await DocumentScannerService().getAllItems();
    if (!mounted) return;
    setState(() {
      _transactions = FinanceService.instance.activeTransactions;
      _budgets = FinanceService.instance.activeBudgets;
      _envelopes = FinanceService.instance.activeEnvelopes;
      _items = items;
      _renewalOutlook90 = FinanceMath.renewalOutlook(items, 90);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final summary = FinanceMath.summaryForMonth(_transactions, now);
    final spendByCategory =
        FinanceMath.spendByCategory(_transactions, now);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Money'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FilledButton.icon(
              onPressed: _showAddTransactionSheet,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Fund / Record', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: FilledButton.styleFrom(
                backgroundColor: WazyColors.violetAccent,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export CSV',
            onPressed: _transactions.isEmpty ? null : _exportCsv,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTransactionSheet,
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('Add Fund / Record', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: WazyColors.violetAccent,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                _buildOutlookCard(theme),
                const SizedBox(height: 16),
                _buildMonthSummary(theme, summary),
                const SizedBox(height: 16),
                _buildPaceCard(theme, summary),
                const SizedBox(height: 24),
                _buildWeeklyChart(theme),
                const SizedBox(height: 24),
                _buildRenewalBreakdown(theme),
                const SizedBox(height: 24),
                _buildCategoryBreakdown(theme, spendByCategory, summary.expense),
                const SizedBox(height: 24),
                _buildTopExpenses(theme),
                const SizedBox(height: 24),
                _buildBudgetsSection(theme, spendByCategory),
                const SizedBox(height: 24),
                _buildEnvelopesSection(theme),
                const SizedBox(height: 24),
                _buildTransactionsSection(theme),
              ],
            ),
    );
  }

  // ------------------------------------------------------------------
  // Renewal outlook
  // ------------------------------------------------------------------

  Widget _buildOutlookCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1B4B),
            const Color(0xFF312E81),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_repeat_rounded,
                  size: 20, color: WazyColors.cyanAccent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Renewal outlook (90 days)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddTransactionSheet,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Fund', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WazyColors.cyanAccent,
                  foregroundColor: const Color(0xFF0A0E1A),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            MoneyFormat.aed(_renewalOutlook90),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _renewalOutlook90 > 0
                ? 'Set this aside before the due dates hit.'
                : 'No renewal fees recorded on upcoming documents.',
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Month summary
  // ------------------------------------------------------------------

  Widget _buildMonthSummary(
    ThemeData theme,
    ({double income, double expense, double net}) summary,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final greenColor = isDark ? Colors.greenAccent : const Color(0xFF059669);
    final redColor = isDark ? Colors.redAccent : const Color(0xFFDC2626);

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Income',
            value: MoneyFormat.aed(summary.income),
            valueColor: greenColor,
            icon: Icons.arrow_downward_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Spent',
            value: MoneyFormat.aed(summary.expense),
            valueColor: redColor,
            icon: Icons.arrow_outward_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Net',
            value: MoneyFormat.aed(summary.net),
            valueColor: summary.net >= 0 ? greenColor : redColor,
            icon: Icons.account_balance_wallet_rounded,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Daily pace card
  // ------------------------------------------------------------------

  Widget _buildPaceCard(
    ThemeData theme,
    ({double income, double expense, double net}) summary,
  ) {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final dailyPace = summary.expense / now.day;
    final projected = dailyPace * daysInMonth;
    final remainingDays = daysInMonth - now.day;
    final affordableDaily = remainingDays > 0 && summary.net > 0
        ? summary.net / remainingDays
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Spending pace · day ${now.day} of $daysInMonth',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _paceColumn(
                  theme,
                  'Avg / day',
                  MoneyFormat.aed(dailyPace),
                ),
              ),
              Expanded(
                child: _paceColumn(
                  theme,
                  'Projected month-end',
                  MoneyFormat.aed(projected),
                  color: summary.net < 0 ? Colors.red : Colors.teal,
                ),
              ),
              Expanded(
                child: _paceColumn(
                  theme,
                  'Safe to spend / day',
                  summary.net > 0
                      ? MoneyFormat.aed(affordableDaily)
                      : '—',
                  color: summary.net > 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          if (summary.net < 0 && remainingDays > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'You are spending more than you earn this month — consider cutting back for the remaining $remainingDays days.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.red,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _paceColumn(ThemeData theme, String label, String value,
      {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
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
      ],
    );
  }

  // ------------------------------------------------------------------
  // Weekly spend chart (last 6 weeks, simple bars)
  // ------------------------------------------------------------------

  Widget _buildWeeklyChart(ThemeData theme) {
    final now = DateTime.now();
    // Start of the current week (Monday).
    final thisMonday = now.subtract(Duration(days: now.weekday - 1));
    final mondayDate = DateTime(thisMonday.year, thisMonday.month, thisMonday.day);

    final buckets = List<_WeekBucket>.generate(
      6,
      (i) {
        final start = mondayDate.subtract(Duration(days: (5 - i) * 7));
        return _WeekBucket(start, start.add(const Duration(days: 7)));
      },
    );

    for (final t in _transactions) {
      if (t.kind != FinanceKind.expense) continue;
      for (final b in buckets) {
        if (!t.occurredAt.isBefore(b.start) && t.occurredAt.isBefore(b.end)) {
          b.spend += t.amount;
        }
      }
    }

    final maxSpend = buckets
        .map((b) => b.spend)
        .fold(0.0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, 'Last 6 weeks', Icons.bar_chart_rounded),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final b in buckets) ...[
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (b.spend > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  _shortMoney(b.spend),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 9,
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ),
                            Container(
                              height: maxSpend <= 0
                                  ? 4
                                  : 8 + (b.spend / maxSpend) * 84,
                              width: 22,
                              decoration: BoxDecoration(
                                color: b.spend > 0
                                    ? theme.colorScheme.primary.withOpacity(0.75)
                                    : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (b != buckets.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final b in buckets) ...[
                    Expanded(
                      child: Text(
                        '${b.start.day}/${b.start.month}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 9,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                    if (b != buckets.last) const SizedBox(width: 10),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _shortMoney(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }

  // ------------------------------------------------------------------
  // Category breakdown with share bars
  // ------------------------------------------------------------------

  Widget _buildCategoryBreakdown(
    ThemeData theme,
    Map<FinanceCategory, double> spendByCategory,
    double totalExpense,
  ) {
    final entries = spendByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, 'Where money goes', Icons.pie_chart_rounded),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          _hintCard(theme, 'Add expenses to see a breakdown by category.')
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (final e in entries) ...[
                  Row(
                    children: [
                      Icon(e.key.icon, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.key.displayName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${(e.value / (totalExpense <= 0 ? 1 : totalExpense) * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        MoneyFormat.aed(e.value),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: totalExpense <= 0
                          ? 0
                          : (e.value / totalExpense).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary.withOpacity(0.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Top expenses this month
  // ------------------------------------------------------------------

  Widget _buildTopExpenses(ThemeData theme) {
    final now = DateTime.now();
    final expenses = _transactions
        .where((t) =>
            t.kind == FinanceKind.expense &&
            t.occurredAt.year == now.year &&
            t.occurredAt.month == now.month)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final top = expenses.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, 'Biggest expenses', Icons.local_fire_department_rounded),
        const SizedBox(height: 12),
        if (top.isEmpty)
          _hintCard(theme, 'No expenses recorded this month yet.')
        else
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (var i = 0; i < top.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 52, color: theme.dividerColor),
                  ListTile(
                    dense: true,
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '#${i + 1}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      top[i].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${top[i].category.displayName} • ${top[i].occurredAt.day}/${top[i].occurredAt.month}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    trailing: Text(
                      MoneyFormat.aed(top[i].amount),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Renewal breakdown — which documents drive the outlook
  // ------------------------------------------------------------------

  Widget _buildRenewalBreakdown(ThemeData theme) {
    final now = DateTime.now();
    final cutoff = now.add(const Duration(days: 90));
    final upcoming = _items
        .where((i) =>
            i.isActive &&
            i.expiresAt.isAfter(now) &&
            i.expiresAt.isBefore(cutoff) &&
            (i.renewalFee ?? 0) > 0)
        .toList()
      ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(theme, 'Upcoming renewals', Icons.event_repeat_rounded),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              for (var idx = 0; idx < upcoming.length; idx++) ...[
                if (idx > 0)
                  Divider(height: 1, indent: 56, color: theme.dividerColor),
                ListTile(
                  dense: true,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: upcoming[idx].docType.primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      upcoming[idx].docType.icon,
                      size: 18,
                      color: upcoming[idx].docType.primaryColor,
                    ),
                  ),
                  title: Text(
                    upcoming[idx].displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Due ${ExpiryItem.formatDate(upcoming[idx].expiresAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  trailing: Text(
                    MoneyFormat.aed(upcoming[idx].renewalFee!),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Budgets
  // ------------------------------------------------------------------

  Widget _buildBudgetsSection(
    ThemeData theme,
    Map<FinanceCategory, double> spendByCategory,
  ) {
    final overallBudget = FinanceService.instance.activeOverallBudget;
    final totalAllocated = FinanceMath.totalBudgetAllocated(_budgets);
    final isOverAllocated = overallBudget != null && totalAllocated > overallBudget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          theme,
          'Monthly budgets',
          Icons.speed_rounded,
          actionLabel: 'Add category',
          onAction: _showBudgetSheet,
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isOverAllocated
                  ? theme.colorScheme.error
                  : theme.colorScheme.outlineVariant,
            ),
          ),
          color: isOverAllocated
              ? theme.colorScheme.errorContainer.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.account_balance_rounded,
                          size: 20,
                          color: isOverAllocated
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Overall Monthly Budget',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _showOverallBudgetSheet,
                      icon: Icon(
                        overallBudget == null ? Icons.add_rounded : Icons.edit_rounded,
                        size: 16,
                      ),
                      label: Text(
                        overallBudget == null ? 'Set budget' : 'Edit',
                      ),
                    ),
                  ],
                ),
                if (overallBudget != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    MoneyFormat.aed(overallBudget),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Allocated: ${MoneyFormat.aed(totalAllocated)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isOverAllocated
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: isOverAllocated ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      Text(
                        isOverAllocated
                            ? 'Over: ${MoneyFormat.aed(totalAllocated - overallBudget)}'
                            : 'Remaining: ${MoneyFormat.aed(overallBudget - totalAllocated)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isOverAllocated
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (totalAllocated / overallBudget).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      color: isOverAllocated
                          ? theme.colorScheme.error
                          : (totalAllocated == overallBudget
                              ? Colors.orange
                              : theme.colorScheme.primary),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    'No overall monthly budget set. Tap "Set budget" to set a total monthly spending limit across all categories.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_budgets.isEmpty)
          _hintCard(
            theme,
            overallBudget != null
                ? 'No category budgets added yet. Tap "Add category" to allocate your monthly budget.'
                : 'Set a monthly limit for any category to see progress here.',
          )
        else
          ..._budgets.map((budget) {
            final spent = spendByCategory[budget.category] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BudgetRow(
                budget: budget,
                spent: spent,
                onEdit: () => _showBudgetSheet(existing: budget),
                onDelete: () => FinanceService.instance.deleteBudget(budget.id),
              ),
            );
          }),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Envelopes
  // ------------------------------------------------------------------

  Widget _buildEnvelopesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          theme,
          'Savings envelopes',
          Icons.savings_rounded,
          actionLabel: 'Add',
          onAction: _showEnvelopeSheet,
        ),
        const SizedBox(height: 12),
        if (_envelopes.isEmpty)
          _hintCard(
            theme,
            'Set aside money for big renewals — tracked only, no real money moves.',
          )
        else
          ..._envelopes.map(
            (envelope) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EnvelopeCard(
                envelope: envelope,
                onAdd: () => _adjustEnvelope(envelope, 100),
                onWithdraw: () => _adjustEnvelope(envelope, -100),
                onDelete: () => FinanceService.instance.deleteEnvelope(envelope.id),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _adjustEnvelope(SavingsEnvelope envelope, double delta) async {
    await FinanceService.instance.adjustEnvelope(envelope.id, delta);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          delta > 0
              ? 'Set aside ${MoneyFormat.aed(delta)} in ${envelope.name}'
              : 'Withdrew ${MoneyFormat.aed(-delta)} from ${envelope.name}',
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Transactions
  // ------------------------------------------------------------------

  Widget _buildTransactionsSection(ThemeData theme) {
    final sorted = [..._transactions]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final recent = sorted.take(20).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          theme,
          'Transactions',
          Icons.receipt_long_rounded,
        ),
        const SizedBox(height: 12),
        if (recent.isEmpty)
          _hintCard(theme, 'No records yet. Add your first expense or income.')
        else
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                for (var i = 0; i < recent.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 56, color: theme.dividerColor),
                  _TransactionTile(transaction: recent[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Sheets & dialogs
  // ------------------------------------------------------------------

  Future<void> _showAddTransactionSheet() async {
    final created = await showModalBottomSheet<FinanceTransaction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _TransactionFormSheet(),
    );
    if (created == null) return;
    await FinanceService.instance.addTransaction(created);
  }

  Future<void> _showOverallBudgetSheet() async {
    final current = FinanceService.instance.activeOverallBudget;
    final result = await showModalBottomSheet<double?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _OverallBudgetFormSheet(currentLimit: current),
      ),
    );
    if (result == null) return;
    await FinanceService.instance.setOverallBudget(result < 0 ? null : result);
  }

  Future<void> _showBudgetSheet({CategoryBudget? existing}) async {
    final overallBudget = FinanceService.instance.activeOverallBudget;
    final double? maxAllowed = overallBudget != null
        ? FinanceMath.remainingUnallocatedBudget(
            overallBudget,
            _budgets,
            excludingCategoryId: existing?.id,
          )
        : null;

    final result = await showModalBottomSheet<(FinanceCategory, double)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _BudgetFormSheet(
          existing: existing,
          maxAllowedLimit: maxAllowed,
        ),
      ),
    );
    if (result == null) return;
    await FinanceService.instance.upsertBudget(result.$1, result.$2);
  }

  Future<void> _showEnvelopeSheet() async {
    final result = await showModalBottomSheet<(String, double, double)>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _EnvelopeFormSheet(),
    );
    if (result == null) return;
    await FinanceService.instance
        .addEnvelope(result.$1, result.$2, result.$3);
  }

  // ------------------------------------------------------------------
  // CSV export
  // ------------------------------------------------------------------

  Future<void> _exportCsv() async {
    final csv = FinanceMath.toCsv(_transactions);
    try {
      final path = await FilePicker.platform.saveFile(
        fileName:
            'wazy-finance-${DateTime.now().toIso8601String().split('T').first}.csv',
        bytes: Uint8List.fromList(csv.codeUnits),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path != null ? 'CSV saved to $path' : 'Export cancelled',
          ),
        ),
      );
    } catch (_) {
      // saveFile unsupported on this platform — fall back to clipboard.
      await Clipboard.setData(ClipboardData(text: csv));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV copied to clipboard')),
      );
    }
  }

  // ------------------------------------------------------------------
  // Small builders
  // ------------------------------------------------------------------

  Widget _sectionHeader(
    ThemeData theme,
    String title,
    IconData icon, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.outline),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }

  Widget _hintCard(ThemeData theme, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}

// ====================================================================
// Summary card
// ====================================================================

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final neutralIconColor = isDark ? WazyColors.textSecondary : WazyColors.textSecondaryLight;
    final neutralLabelColor = isDark ? WazyColors.textMuted : WazyColors.textMutedLight;

    return Container(
      padding: const EdgeInsets.all(12),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: neutralIconColor),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: valueColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: neutralLabelColor,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Budget row
// ====================================================================

class _BudgetRow extends StatelessWidget {
  final CategoryBudget budget;
  final double spent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BudgetRow({
    required this.budget,
    required this.spent,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = budget.monthlyLimit;
    final ratio = limit <= 0 ? 0.0 : (spent / limit).clamp(0.0, 1.0);
    final over = spent > limit;
    final barColor = over
        ? Colors.red
        : ratio > 0.8
            ? Colors.orange
            : theme.colorScheme.primary;

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(budget.category.icon, size: 18, color: barColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    budget.category.displayName,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '${MoneyFormat.aed(spent)} / ${MoneyFormat.aed(limit)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: over ? Colors.red : theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  tooltip: 'Remove budget',
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            if (over) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Over budget by ${MoneyFormat.aed(spent - limit)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.red, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Envelope card
// ====================================================================

class _EnvelopeCard extends StatelessWidget {
  final SavingsEnvelope envelope;
  final VoidCallback onAdd;
  final VoidCallback onWithdraw;
  final VoidCallback onDelete;

  const _EnvelopeCard({
    required this.envelope,
    required this.onAdd,
    required this.onWithdraw,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.savings_rounded, size: 18, color: Colors.teal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  envelope.name,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${MoneyFormat.aed(envelope.savedAmount)} / ${MoneyFormat.aed(envelope.targetAmount)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                tooltip: 'Delete envelope',
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: envelope.progress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (envelope.monthlyContribution > 0)
                Text(
                  '${MoneyFormat.aed(envelope.monthlyContribution)}/mo plan',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontSize: 11,
                  ),
                ),
              const Spacer(),
              _pillButton(context, Icons.remove_rounded, onWithdraw),
              const SizedBox(width: 8),
              _pillButton(context, Icons.add_rounded, onAdd),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pillButton(BuildContext context, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.teal.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: Colors.teal),
      ),
    );
  }
}

// ====================================================================
// Transaction tile
// ====================================================================

class _TransactionTile extends StatelessWidget {
  final FinanceTransaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = transaction.kind == FinanceKind.income;
    final amountColor = isIncome ? Colors.green : Colors.red;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: amountColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(transaction.category.icon,
                size: 18, color: amountColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${transaction.category.displayName} • ${transaction.occurredAt.day}/${transaction.occurredAt.month}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${MoneyFormat.aed(transaction.amount)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Transaction form sheet
// ====================================================================

class _TransactionFormSheet extends StatefulWidget {
  const _TransactionFormSheet();

  @override
  State<_TransactionFormSheet> createState() => _TransactionFormSheetState();
}

class _TransactionFormSheetState extends State<_TransactionFormSheet> {
  FinanceKind _kind = FinanceKind.expense;
  FinanceCategory _category = FinanceCategory.other;
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    final title = _titleController.text.trim();
    if (title.isEmpty || amount == null || amount <= 0) return;

    Navigator.pop(
      context,
      FinanceTransaction(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        collectionId: '',
        kind: _kind,
        category: _category,
        title: title,
        amount: amount,
        occurredAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add record',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            SegmentedButton<FinanceKind>(
              segments: const [
                ButtonSegment(
                  value: FinanceKind.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_outward_rounded),
                ),
                ButtonSegment(
                  value: FinanceKind.income,
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_downward_rounded),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) =>
                  setState(() => _kind = selection.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. Trade licence renewal',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (AED)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FinanceCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: FinanceCategory.values
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Icon(c.icon, size: 18),
                          const SizedBox(width: 8),
                          Text(c.displayName),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (c) => setState(() => _category = c ?? FinanceCategory.other),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submit,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Overall Budget form sheet
// ====================================================================

class _OverallBudgetFormSheet extends StatefulWidget {
  final double? currentLimit;

  const _OverallBudgetFormSheet({this.currentLimit});

  @override
  State<_OverallBudgetFormSheet> createState() => _OverallBudgetFormSheetState();
}

class _OverallBudgetFormSheetState extends State<_OverallBudgetFormSheet> {
  late final TextEditingController _limitController;

  @override
  void initState() {
    super.initState();
    _limitController = TextEditingController(
      text: widget.currentLimit != null ? widget.currentLimit!.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _submit() {
    final val = double.tryParse(_limitController.text.trim());
    if (val == null || val <= 0) return;
    Navigator.pop(context, val);
  }

  void _clear() {
    Navigator.pop(context, -1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.currentLimit == null
                  ? 'Set overall monthly budget'
                  : 'Edit overall monthly budget',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Set the overall monthly limit across all spending categories. Individual category budgets will be constrained within this amount.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _limitController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Total Monthly Budget (AED)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_rounded),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submit,
              child: const Text('Save overall budget'),
            ),
            if (widget.currentLimit != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _clear,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: const Text('Remove overall budget cap'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Budget form sheet
// ====================================================================

class _BudgetFormSheet extends StatefulWidget {
  final CategoryBudget? existing;
  final double? maxAllowedLimit;

  const _BudgetFormSheet({this.existing, this.maxAllowedLimit});

  @override
  State<_BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends State<_BudgetFormSheet> {
  late FinanceCategory _category;
  late final TextEditingController _limitController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _category = widget.existing?.category ?? FinanceCategory.other;
    _limitController = TextEditingController(
      text: widget.existing == null
          ? ''
          : widget.existing!.monthlyLimit.toStringAsFixed(0),
    );
    _limitController.addListener(_validate);
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _validate() {
    final text = _limitController.text.trim();
    if (text.isEmpty) {
      if (_errorText != null) setState(() => _errorText = null);
      return;
    }
    final val = double.tryParse(text);
    if (val == null || val <= 0) {
      if (_errorText != 'Enter a valid amount') {
        setState(() => _errorText = 'Enter a valid amount');
      }
      return;
    }

    if (widget.maxAllowedLimit != null && val > widget.maxAllowedLimit! + 0.01) {
      final maxStr = MoneyFormat.aed(widget.maxAllowedLimit! < 0 ? 0 : widget.maxAllowedLimit!);
      final msg = widget.maxAllowedLimit! <= 0
          ? 'Overall monthly budget is fully allocated'
          : 'Exceeds remaining monthly budget ($maxStr)';
      if (_errorText != msg) {
        setState(() => _errorText = msg);
      }
    } else {
      if (_errorText != null) setState(() => _errorText = null);
    }
  }

  void _submit() {
    _validate();
    if (_errorText != null) return;
    final limit = double.tryParse(_limitController.text.trim());
    if (limit == null || limit <= 0) return;
    if (widget.maxAllowedLimit != null && limit > widget.maxAllowedLimit! + 0.01) return;
    Navigator.pop(context, (_category, limit));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxLimit = widget.maxAllowedLimit;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'Add budget' : 'Edit budget',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (maxLimit != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: maxLimit <= 0
                      ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
                      : theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      maxLimit <= 0 ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                      size: 16,
                      color: maxLimit <= 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        maxLimit <= 0
                            ? 'Overall monthly budget is 100% allocated.'
                            : 'Available from overall monthly budget: ${MoneyFormat.aed(maxLimit)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: maxLimit <= 0
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<FinanceCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: FinanceCategory.values
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Icon(c.icon, size: 18),
                          const SizedBox(width: 8),
                          Text(c.displayName),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (c) => setState(() => _category = c ?? FinanceCategory.other),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _limitController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Monthly limit (AED)',
                border: const OutlineInputBorder(),
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _errorText != null ? null : _submit,
              child: const Text('Save budget'),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Envelope form sheet
// ====================================================================

class _EnvelopeFormSheet extends StatefulWidget {
  const _EnvelopeFormSheet();

  @override
  State<_EnvelopeFormSheet> createState() => _EnvelopeFormSheetState();
}

class _EnvelopeFormSheetState extends State<_EnvelopeFormSheet> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _monthlyController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _monthlyController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final target = double.tryParse(_targetController.text.trim());
    final monthly =
        double.tryParse(_monthlyController.text.trim()) ?? 0;
    if (name.isEmpty || target == null || target <= 0) return;
    Navigator.pop(context, (name, target, monthly));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'New savings envelope',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Trade licence renewal',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Target amount (AED)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _monthlyController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monthly contribution (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submit,
              child: const Text('Create envelope'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mutable spend accumulator for one week in the 6-week chart.
class _WeekBucket {
  final DateTime start;
  final DateTime end;
  double spend = 0.0;

  _WeekBucket(this.start, this.end);
}
