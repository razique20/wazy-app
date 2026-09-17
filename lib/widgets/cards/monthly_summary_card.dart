import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/finance_service.dart';
import '../../services/monthly_summary_service.dart';
import '../../theme/app_theme.dart';

/// Card on the Money screen rendering the AI Monthly Financial Executive
/// Summary: template narrative instantly, LLM-polished when a Gemini key is
/// configured. Hidden by default — the header row stays visible as a compact
/// toggle bar and the user taps it (or the eye button) to expand/collapse.
/// Visibility choice is persisted in SharedPreferences.
class MonthlySummaryCard extends StatefulWidget {
  const MonthlySummaryCard({super.key});

  @override
  State<MonthlySummaryCard> createState() => _MonthlySummaryCardState();
}

class _MonthlySummaryCardState extends State<MonthlySummaryCard> {
  static const String _visibilityKey = 'monthlySummary.visible';

  StreamSubscription<({String narrative, bool usedLlm})>? _sub;

  bool _refreshing = false;
  bool _visible = false;

  /// Tracks the collection the current narrative was generated for, so the
  /// card re-generates when the user switches collections on Home.
  String _collectionId = FinanceService.instance.activeCollectionIdSafe;

  @override
  void initState() {
    super.initState();
    _loadVisibility();
    // Generate synchronously (template mode) so the card renders instantly.
    MonthlySummaryService.instance.generate();
    _sub = MonthlySummaryService.instance.narrativeStream.listen((update) {
      if (mounted) setState(() => _refreshing = false);
    });
    FinanceService.instance.addListener(_onFinanceChanged);
  }

  @override
  void dispose() {
    _sub?.cancel();
    FinanceService.instance.removeListener(_onFinanceChanged);
    super.dispose();
  }

  void _onFinanceChanged() {
    if (!mounted) return;
    final activeId = FinanceService.instance.activeCollectionIdSafe;
    if (activeId == _collectionId) {
      // Same collection, data changed — refresh only if visible.
      if (_visible) setState(() {});
      return;
    }
    _collectionId = activeId;
    MonthlySummaryService.instance.generate();
  }

  Future<void> _loadVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      // Default hidden: the key only exists after the user expands it once.
      _visible = prefs.getBool(_visibilityKey) ?? false;
    });
  }

  Future<void> _toggleVisibility() async {
    final newValue = !_visible;
    setState(() => _visible = newValue);
    if (newValue && MonthlySummaryService.instance.lastNarrative == null) {
      // First expansion after a cold start with the card hidden: build now.
      MonthlySummaryService.instance.generate();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_visibilityKey, newValue);
  }

  Future<void> _regenerate() async {
    setState(() => _refreshing = false);
    MonthlySummaryService.instance.generate();
    // Stream listener clears _refreshing; also clear after a grace period in
    // case no LLM pass runs (template mode) and no stream event fires.
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _refreshing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = MonthlySummaryService.instance;
    final narrative = service.lastNarrative ?? '';
    final insights = service.lastInsights;
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(60)),
      ),
      color: isDark ? const Color(0xFF1E2430) : Colors.white,
      child: Padding(
        padding: _visible
            ? const EdgeInsets.all(14)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact header: title + eye toggle (and refresh when open).
            Row(
              children: [
                Text(
                  'Executive Summary',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 6),
                if (service.lastUsedLlm && _visible)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: WazyColors.violetAccent.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: WazyColors.violetAccent,
                      ),
                    ),
                  ),
                const Spacer(),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    icon: Icon(_visible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    tooltip: _visible ? 'Hide summary' : 'Show summary',
                    onPressed: _toggleVisibility,
                  ),
                ),
                if (_visible)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: _refreshing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      tooltip: 'Regenerate summary',
                      onPressed: _refreshing ? null : _regenerate,
                    ),
                  ),
              ],
            ),
            // Content only when expanded.
            if (_visible) ...[
              const SizedBox(height: 10),
              if (narrative.isEmpty)
                Text(
                  'Log your first transaction to unlock the monthly executive summary.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.outline,
                  ),
                )
              else
                Text(
                  narrative,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              if (insights.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...insights.take(4).map((insight) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            switch (insight.kind) {
                              MonthlyInsightKind.spendingMove =>
                                Icons.trending_up_rounded,
                              MonthlyInsightKind.budgetAlert =>
                                Icons.warning_amber_rounded,
                              MonthlyInsightKind.savings => Icons.savings_rounded,
                              MonthlyInsightKind.positive =>
                                Icons.check_circle_rounded,
                            },
                            size: 16,
                            color: switch (insight.kind) {
                              MonthlyInsightKind.spendingMove => WazyColors.danger,
                              MonthlyInsightKind.budgetAlert => WazyColors.warning,
                              MonthlyInsightKind.savings => WazyColors.safe,
                              MonthlyInsightKind.positive => WazyColors.safe,
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              insight.sentence,
                              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
