import 'package:flutter/material.dart';

import '../models/finance.dart';
import '../models/subscription_tier.dart';
import '../services/entitlement_service.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/upgrade_dialog.dart';
import '../widgets/indicators/empty_state_illustration.dart';
import 'money_screen.dart';

/// Records page opened from the Home categories grid: the full transaction
/// log (the Money tab shows only the latest 20) with quick add and export.
class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  List<FinanceTransaction> _transactions = [];
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
      _transactions = FinanceService.instance.activeTransactions;
      _loading = false;
    });
  }

  void _showAddTransactionSheet() {
    showModalBottomSheet<FinanceTransaction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const TransactionFormSheet(),
    ).then((created) async {
      if (created == null) return;
      await FinanceService.instance.addTransaction(created);
      await _reload();
    });
  }

  Future<void> _exportCsv() async {
    // Track 1 gate: CSV/PDF report export is a Plus feature.
    if (!EntitlementService.instance.allows(EntitlementFeature.reportExport)) {
      await showUpgradeDialog(context, EntitlementFeature.reportExport);
      return;
    }
    if (!mounted) return;
    // Full export lives on the Money tab toolbar.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Open the Money tab and tap the share icon to export.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [..._transactions]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    // Group by month, newest first.
    final groups = <String, List<FinanceTransaction>>{};
    for (final t in sorted) {
      final key = '${t.occurredAt.year}-${t.occurredAt.month.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(t);
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Records'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: 'Export CSV',
            onPressed: _transactions.isEmpty ? null : _exportCsv,
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 115),
        child: FloatingActionButton.extended(
          heroTag: 'records_add',
          onPressed: _showAddTransactionSheet,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Add Record',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: FinavigColors.violetAccent,
          foregroundColor: Colors.white,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _reload,
              child: sorted.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        _hintCard(
                          theme,
                          'No records yet. Tap "Add Record" to log your first expense or income.',
                          scene: EmptyStateScene.wallet,
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 180),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final key = groups.keys.elementAt(index);
                        final monthTx = groups[key]!;
                        final month = DateTime(
                          int.parse(key.split('-')[0]),
                          int.parse(key.split('-')[1]),
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                              child: Text(
                                '${_monthName(month.month)} ${month.year}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withOpacity(0.4),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  for (var i = 0; i < monthTx.length; i++) ...[
                                    if (i > 0)
                                      Divider(
                                        height: 1,
                                        indent: 56,
                                        color: theme.dividerColor,
                                      ),
                                    TransactionTile(transaction: monthTx[i]),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
    );
  }

  static String _monthName(int month) => const [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ][month - 1];

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
