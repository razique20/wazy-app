import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/finance.dart';
import 'finance_service.dart';
import 'notification_service.dart';

/// One fired budget alert.
class BudgetAlertEvent {
  /// Which budget tripped (category + limit).
  final CategoryBudget budget;

  /// Spent amount at the time of evaluation.
  final double spent;

  /// The threshold that was crossed (0.8 or 1.0).
  final double threshold;

  const BudgetAlertEvent({
    required this.budget,
    required this.spent,
    required this.threshold,
  });

  bool get isExceeded => threshold >= BudgetThresholds.exceeded;

  String get title =>
      isExceeded ? 'Budget exceeded — ${budget.category.displayName}' : 'Close to budget — ${budget.category.displayName}';

  String get body {
    final pct = (threshold * 100).toStringAsFixed(0);
    return isExceeded
        ? 'You have used ${MoneyFormat.aed(spent)} of the ${MoneyFormat.aed(budget.monthlyLimit)} ${budget.category.displayName} budget (over the $pct% limit).'
        : 'You have used ${MoneyFormat.aed(spent)} of the ${MoneyFormat.aed(budget.monthlyLimit)} ${budget.category.displayName} budget ($pct% reached).';
  }
}

/// Budget alert engine.
///
/// Listens to [FinanceService] and evaluates every category budget against
/// this month's spend whenever the finance data changes. When a budget
/// crosses the 80% ("near") or 100% ("exceeded") threshold:
/// * an OS-level local notification is shown ([NotificationService]), and
/// * an in-app event is pushed onto [stream] (MoneyScreen turns it into a
///   snackbar; the router reads [worstStatus] for the Money tab badge).
///
/// Dedupe: one alert per (budget, month, threshold) per calendar month,
/// tracked in SharedPreferences so re-opening the app doesn't re-fire the
/// same alert. A new month, or a raised limit being crossed again, can
/// re-arm a budget.
class BudgetAlertService {
  BudgetAlertService._();

  static final BudgetAlertService instance = BudgetAlertService._();

  static const String _firedKey = 'budgetAlerts.fired.v1';

  StreamController<BudgetAlertEvent>? _controller;
  bool _initialized = false;

  /// Keys like "`budgetId|year|month|threshold`" already alerted this
  /// session's month. Persisted so re-launches don't re-fire.
  Set<String> _firedKeys = {};

  /// Fires for every newly-crossed threshold, including while the app is in
  /// the background (listeners decide whether to snackbar or badge).
  Stream<BudgetAlertEvent> get stream {
    _controller ??= StreamController<BudgetAlertEvent>.broadcast();
    return _controller!.stream;
  }

  /// Latest [BudgetStatusResult] for the badge: the most-alerting budget in
  /// the active collection, or null when nothing is ≥80%.
  BudgetStatusResult? get worstStatus {
    final budgets = FinanceService.instance.activeBudgets;
    if (budgets.isEmpty) return null;
    final spend = FinanceMath.spendByCategory(
      FinanceService.instance.activeTransactions,
      DateTime.now(),
      collectionId: FinanceService.instance.activeCollectionIdSafe,
    );
    return FinanceMath.worstBudgetStatus(
      FinanceMath.budgetStatuses(budgets, spend),
    );
  }

  /// Start listening. Call once from [main]; safe to call again.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _firedKeys = prefs.getStringList(_firedKey)?.toSet() ?? {};

    FinanceService.instance.addListener(_onFinanceChanged);
  }

  void dispose() {
    FinanceService.instance.removeListener(_onFinanceChanged);
    _controller?.close();
    _controller = null;
    _initialized = false;
  }

  /// Re-evaluate every budget in the active collection.
  Future<void> evaluateNow() => _evaluate();

  // ------------------------------------------------------------------

  void _onFinanceChanged() {
    // Debounce to the end of the frame so a burst of add/update calls
    // (e.g. recurring catch-up) evaluates once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_initialized) return;
      _evaluate();
    });
  }

  Future<void> _evaluate() async {
    final budgets = FinanceService.instance.activeBudgets;
    if (budgets.isEmpty) return;

    final spend = FinanceMath.spendByCategory(
      FinanceService.instance.activeTransactions,
      DateTime.now(),
      collectionId: FinanceService.instance.activeCollectionIdSafe,
    );
    final results = FinanceMath.budgetStatuses(budgets, spend);

    var fired = false;
    for (final r in results) {
      // 100% first so a budget that jumps straight past 80% to 100% only
      // fires the stronger alert.
      for (final threshold in const [BudgetThresholds.exceeded, BudgetThresholds.near]) {
        if (!r.shouldAlertAt(threshold, _firedKeys)) continue;
        _firedKeys.add(r.alertKey(threshold));
        fired = true;

        final event = BudgetAlertEvent(
          budget: r.budget,
          spent: r.spent,
          threshold: threshold,
        );

        // OS-level notification (best-effort).
        await NotificationService.instance.showBudgetAlertNotification(
          title: event.title,
          body: event.body,
        );

        // In-app listeners (snackbar on MoneyScreen, badge in router).
        _controller?.add(event);
      }
    }

    if (fired) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_firedKey, _firedKeys.toList());
    }
  }
}
