import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/document_collection.dart';
import '../../services/collection_service.dart';
import '../../services/document_scanner_service.dart';
import '../../services/finance_service.dart';
import '../../services/ai_executive_summary_service.dart';
import '../../theme/app_theme.dart';
import '../dialogs/app_guide_dialog.dart';

/// A sleek, interactive "Getting Started" checklist card rendered on the Home dashboard
/// for new users, guiding them step-by-step through Wazy's core capabilities.
class GettingStartedChecklistCard extends StatefulWidget {
  final VoidCallback? onOpenCollectionSwitcher;

  const GettingStartedChecklistCard({
    super.key,
    this.onOpenCollectionSwitcher,
  });

  @override
  State<GettingStartedChecklistCard> createState() =>
      _GettingStartedChecklistCardState();
}

class _GettingStartedChecklistCardState
    extends State<GettingStartedChecklistCard> {
  bool _dismissed = false;
  bool _collapsed = false;
  bool _loading = true;

  bool _hasDocuments = false;
  bool _hasFinances = false;
  bool _hasMultipleCollections = false;
  bool _hasGeneratedAi = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isDismissed = prefs.getBool('gettingStartedChecklistDismissed') ?? false;
    final isCollapsed = prefs.getBool('gettingStartedChecklistCollapsed') ?? false;

    final docs = await DocumentScannerService.instance.getAllItems();
    final hasDocs = docs.isNotEmpty;

    final transactions = FinanceService.instance.activeTransactions;
    final budgets = FinanceService.instance.budgets;
    final hasFin = transactions.isNotEmpty || budgets.isNotEmpty;

    final collections = DocumentCollectionService.instance.collections;
    final hasMultiCol = collections.length > 1;

    final aiUsed = await AiExecutiveSummaryService.instance.getUsedQuotaThisMonth();
    final hasAi = aiUsed > 0;

    if (mounted) {
      setState(() {
        _dismissed = isDismissed;
        _collapsed = isCollapsed;
        _hasDocuments = hasDocs;
        _hasFinances = hasFin;
        _hasMultipleCollections = hasMultiCol;
        _hasGeneratedAi = hasAi;
        _loading = false;
      });
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gettingStartedChecklistDismissed', true);
    if (mounted) setState(() => _dismissed = true);
  }

  Future<void> _toggleCollapse() async {
    final prefs = await SharedPreferences.getInstance();
    final next = !_collapsed;
    await prefs.setBool('gettingStartedChecklistCollapsed', next);
    if (mounted) setState(() => _collapsed = next);
  }

  int get _completedCount {
    var count = 0;
    if (_hasDocuments) count++;
    if (_hasFinances) count++;
    if (_hasMultipleCollections) count++;
    if (_hasGeneratedAi) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _dismissed) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final completed = _completedCount;
    final progress = completed / 4.0;
    final allDone = completed == 4;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? WazyColors.slateLight : WazyColors.mist,
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              InkWell(
                onTap: _toggleCollapse,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: WazyColors.navyPrimary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.checklist_rounded,
                          color: WazyColors.navyPrimary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              allDone
                                  ? 'Setup Completed! 🚀'
                                  : 'Getting Started ($completed/4)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              allDone
                                  ? 'All initial steps completed — you are ready to roll!'
                                  : 'Follow these 4 steps to set up your Wazy cockpit',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _collapsed
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          size: 20,
                        ),
                        onPressed: _toggleCollapse,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        tooltip: 'Dismiss checklist',
                        onPressed: _dismiss,
                      ),
                    ],
                  ),
                ),
              ),

              // Progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      allDone ? WazyColors.emerald : WazyColors.navyPrimary,
                    ),
                  ),
                ),
              ),

              if (!_collapsed) ...[
                const SizedBox(height: 12),
                _checkItem(
                  context: context,
                  title: '1. Scan or add your first document',
                  subtitle: 'Emirates ID, Trade License, Visa, Ejari or Insurance',
                  done: _hasDocuments,
                  actionLabel: 'Scan',
                  onTap: () => context.push('/scan'),
                ),
                _checkItem(
                  context: context,
                  title: '2. Set a category budget or add expense',
                  subtitle: 'Keep your monthly spend on track in GCC currency',
                  done: _hasFinances,
                  actionLabel: 'Budgets',
                  onTap: () => context.push('/budgets'),
                ),
                _checkItem(
                  context: context,
                  title: '3. Explore Collections & Workspaces',
                  subtitle: 'Keep personal docs separate from business LLCs',
                  done: _hasMultipleCollections,
                  actionLabel: 'Switch',
                  onTap: () {
                    if (widget.onOpenCollectionSwitcher != null) {
                      widget.onOpenCollectionSwitcher!();
                    } else {
                      context.go('/profile');
                    }
                  },
                ),
                _checkItem(
                  context: context,
                  title: '4. Generate AI Executive Summary',
                  subtitle: 'Get AI financial health score & recommendations',
                  done: _hasGeneratedAi,
                  actionLabel: 'AI Summary',
                  onTap: () => context.push('/ai-summary'),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => showAppGuideDialog(context),
                        icon: const Icon(Icons.menu_book_rounded, size: 16),
                        label: const Text(
                          'Open Full App Guide',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: WazyColors.navyPrimary,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      TextButton(
                        onPressed: _dismiss,
                        child: const Text('Hide', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ] else
                const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool done,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done
                    ? WazyColors.emerald
                    : (isDark ? WazyColors.slateLight : WazyColors.mist),
              ),
              child: Icon(
                done ? Icons.check_rounded : Icons.circle_outlined,
                size: 14,
                color: done ? Colors.white : theme.colorScheme.outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      decoration: done ? TextDecoration.lineThrough : null,
                      color: done
                          ? theme.colorScheme.outline
                          : (isDark ? WazyColors.textPrimary : WazyColors.textPrimaryLight),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: done
                    ? Colors.transparent
                    : WazyColors.navyPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                done ? 'Done ✓' : actionLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: done
                      ? WazyColors.emerald
                      : WazyColors.navyPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
