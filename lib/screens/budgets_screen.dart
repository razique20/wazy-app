import 'package:flutter/material.dart';

import '../models/finance.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/indicators/empty_state_illustration.dart';
import 'money_screen.dart';

/// Budgets-only page opened from the Home categories grid: the overall
/// monthly cap and per-category limits without the rest of the Money tab.
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  List<CategoryBudget> _budgets = [];
  double? _overallBudget;
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
    if (!mounted) return;
    setState(() {
      _budgets = FinanceService.instance.activeBudgets;
      _overallBudget = FinanceService.instance.activeOverallBudget;
      _loading = false;
    });
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
      builder: (_) => OverallBudgetFormSheet(currentLimit: current),
    );
    if (result == null) return;
    await FinanceService.instance.setOverallBudget(result < 0 ? null : result);
    await _reload();
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
      builder: (_) => CategoryBudgetFormSheet(
        existing: existing,
        maxAllowedLimit: maxAllowed,
      ),
    );
    if (result == null) return;
    await FinanceService.instance.upsertBudget(result.$1, result.$2);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final spendByCategory = FinanceMath.spendByCategory(
      FinanceService.instance.activeTransactions,
      now,
    );
    final totalAllocated = FinanceMath.totalBudgetAllocated(_budgets);
    final isOverAllocated =
        _overallBudget != null && totalAllocated > _overallBudget!;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Budgets')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'budgets_add',
        onPressed: () => _showBudgetSheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add category',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: WazyColors.violetAccent,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  // Overall cap card.
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
                        ? theme.colorScheme.errorContainer.withValues(
                            alpha: 0.15,
                          )
                        : theme.colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
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
                                    Flexible(
                                      child: Text(
                                        'Overall Monthly Budget',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _showOverallBudgetSheet,
                                icon: Icon(
                                  _overallBudget == null
                                      ? Icons.add_rounded
                                      : Icons.edit_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  _overallBudget == null
                                      ? 'Set budget'
                                      : 'Edit',
                                ),
                              ),
                            ],
                          ),
                          if (_overallBudget != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              MoneyFormat.aed(_overallBudget!),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Allocated: ${MoneyFormat.aed(totalAllocated)}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isOverAllocated
                                        ? theme.colorScheme.error
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: isOverAllocated
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  isOverAllocated
                                      ? 'Over: ${MoneyFormat.aed(totalAllocated - _overallBudget!)}'
                                      : 'Remaining: ${MoneyFormat.aed(_overallBudget! - totalAllocated)}',
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
                                value: (totalAllocated / _overallBudget!)
                                    .clamp(0.0, 1.0),
                                minHeight: 8,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                color: isOverAllocated
                                    ? theme.colorScheme.error
                                    : (totalAllocated == _overallBudget
                                          ? Colors.orange
                                          : theme.colorScheme.primary),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 4),
                            Text(
                              'No overall monthly budget set. Tap "Set budget" to cap your total monthly spending across all categories.',
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
                      _overallBudget != null
                          ? 'No category budgets added yet. Tap "Add category" to allocate your monthly budget.'
                          : 'Set a monthly limit for any category to see progress here.',
                      scene: EmptyStateScene.growth,
                    )
                  else
                    ..._budgets.map((budget) {
                      final spent = spendByCategory[budget.category] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: BudgetRow(
                          budget: budget,
                          spent: spent,
                          onEdit: () => _showBudgetSheet(existing: budget),
                          onDelete: () =>
                              FinanceService.instance.deleteBudget(budget.id),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _hintCard(ThemeData theme, String text,
      {EmptyStateScene scene = EmptyStateScene.wallet}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          EmptyStateIllustration(scene: scene, size: 88),
          const SizedBox(height: 10),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
