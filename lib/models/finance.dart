import 'package:flutter/material.dart';

import 'expiry_item.dart';

/// Kind of money movement.
enum FinanceKind { expense, income }

extension FinanceKindX on FinanceKind {
  String get label => this == FinanceKind.expense ? 'Expense' : 'Income';

  IconData get icon =>
      this == FinanceKind.expense ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded;

  Color get color => this == FinanceKind.expense ? Colors.red : Colors.green;
}

/// Spending categories. `renewals` is the category Wazy auto-uses when a
/// renewal payment is logged from the outlook section.
enum FinanceCategory {
  renewals,
  salaries,
  rent,
  utilities,
  suppliers,
  marketing,
  transport,
  software,
  sales,
  other,
}

extension FinanceCategoryX on FinanceCategory {
  String get displayName {
    switch (this) {
      case FinanceCategory.renewals:
        return 'Renewals';
      case FinanceCategory.salaries:
        return 'Salaries';
      case FinanceCategory.rent:
        return 'Rent';
      case FinanceCategory.utilities:
        return 'Utilities';
      case FinanceCategory.suppliers:
        return 'Suppliers';
      case FinanceCategory.marketing:
        return 'Marketing';
      case FinanceCategory.transport:
        return 'Transport';
      case FinanceCategory.software:
        return 'Software';
      case FinanceCategory.sales:
        return 'Sales';
      case FinanceCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case FinanceCategory.renewals:
        return Icons.refresh_rounded;
      case FinanceCategory.salaries:
        return Icons.badge_rounded;
      case FinanceCategory.rent:
        return Icons.home_rounded;
      case FinanceCategory.utilities:
        return Icons.bolt_rounded;
      case FinanceCategory.suppliers:
        return Icons.local_shipping_rounded;
      case FinanceCategory.marketing:
        return Icons.campaign_rounded;
      case FinanceCategory.transport:
        return Icons.directions_car_rounded;
      case FinanceCategory.software:
        return Icons.computer_rounded;
      case FinanceCategory.sales:
        return Icons.storefront_rounded;
      case FinanceCategory.other:
        return Icons.category_rounded;
    }
  }

  static FinanceCategory fromName(String? name) =>
      FinanceCategory.values.firstWhere(
        (c) => c.name == name,
        orElse: () => FinanceCategory.other,
      );
}

/// A single money movement (expense or income) inside a collection.
class FinanceTransaction {
  final String id;
  final String collectionId;
  final FinanceKind kind;
  final FinanceCategory category;
  final String title;
  final double amount;
  final String currency;
  final DateTime occurredAt;
  final String? note;

  /// Set when this transaction was logged against an expiry-tracked document
  /// (e.g. "Trade licence renewal paid").
  final String? documentId;

  const FinanceTransaction({
    required this.id,
    required this.collectionId,
    required this.kind,
    required this.category,
    required this.title,
    required this.amount,
    this.currency = 'AED',
    required this.occurredAt,
    this.note,
    this.documentId,
  });

  FinanceTransaction copyWith({
    String? id,
    String? collectionId,
    FinanceKind? kind,
    FinanceCategory? category,
    String? title,
    double? amount,
    String? currency,
    DateTime? occurredAt,
    String? note,
    String? documentId,
    bool clearDocumentId = false,
  }) {
    return FinanceTransaction(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      kind: kind ?? this.kind,
      category: category ?? this.category,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      occurredAt: occurredAt ?? this.occurredAt,
      note: note ?? this.note,
      documentId: clearDocumentId ? null : (documentId ?? this.documentId),
    );
  }

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) {
    return FinanceTransaction(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String? ?? 'personal',
      kind: json['kind'] == 'income' ? FinanceKind.income : FinanceKind.expense,
      category: FinanceCategoryX.fromName(json['category'] as String?),
      title: json['title'] as String? ?? 'Transaction',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'AED',
      occurredAt: DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
          DateTime.now(),
      note: json['note'] as String?,
      documentId: json['documentId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'collectionId': collectionId,
        'kind': kind.name,
        'category': category.name,
        'title': title,
        'amount': amount,
        'currency': currency,
        'occurredAt': occurredAt.toIso8601String(),
        'note': note,
        'documentId': documentId,
      };
}

/// How often a recurring transaction repeats.
enum RecurrenceFrequency { monthly, quarterly, yearly }

extension RecurrenceFrequencyX on RecurrenceFrequency {
  String get label {
    switch (this) {
      case RecurrenceFrequency.monthly:
        return 'Monthly';
      case RecurrenceFrequency.quarterly:
        return 'Quarterly';
      case RecurrenceFrequency.yearly:
        return 'Yearly';
    }
  }

  /// Average days between occurrences — used for forecasts and pacing.
  double get approxDaysPerCycle {
    switch (this) {
      case RecurrenceFrequency.monthly:
        return 30.44;
      case RecurrenceFrequency.quarterly:
        return 91.31;
      case RecurrenceFrequency.yearly:
        return 365.25;
    }
  }

  static RecurrenceFrequency fromName(String? name) =>
      RecurrenceFrequency.values.firstWhere(
        (f) => f.name == name,
        orElse: () => RecurrenceFrequency.monthly,
      );
}

/// A transaction template that auto-logs itself every month/quarter/year —
/// rent, salaries, software subscriptions. Pure data; the auto-logging rules
/// live in [RecurrenceMath], the execution in FinanceService.
class RecurringTransaction {
  final String id;
  final String collectionId;
  final FinanceKind kind;
  final FinanceCategory category;
  final String title;
  final double amount;
  final String currency;

  /// How often this template repeats. Monthly covers the backlog item
  /// (rent/salaries/software); quarterly and yearly support insurance,
  /// licences and annual subscriptions.
  final RecurrenceFrequency frequency;

  /// Day of month (1–31) the transaction should land on. Months without that
  /// day clamp to the last day (day 31 in April → April 30).
  final int dayOfMonth;

  /// First occurrence on or after this date. Defaults to the creation date;
  /// a future date delays the first auto-log.
  final DateTime startDate;

  /// Auto-log stops after this month (inclusive) when set; null = forever.
  final DateTime? endDate;

  final bool isActive;

  /// Timestamp of the last transaction this template generated (local book-
  /// keeping for idempotency); null until the first run.
  final DateTime? lastLoggedAt;

  const RecurringTransaction({
    required this.id,
    required this.collectionId,
    required this.kind,
    required this.category,
    required this.title,
    required this.amount,
    this.currency = 'AED',
    this.frequency = RecurrenceFrequency.monthly,
    this.dayOfMonth = 1,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    this.lastLoggedAt,
  });

  RecurringTransaction copyWith({
    String? collectionId,
    FinanceKind? kind,
    FinanceCategory? category,
    String? title,
    double? amount,
    String? currency,
    RecurrenceFrequency? frequency,
    int? dayOfMonth,
    DateTime? startDate,
    Object? endDate = _unset,
    bool? isActive,
    DateTime? lastLoggedAt,
  }) {
    return RecurringTransaction(
      id: id,
      collectionId: collectionId ?? this.collectionId,
      kind: kind ?? this.kind,
      category: category ?? this.category,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      frequency: frequency ?? this.frequency,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      startDate: startDate ?? this.startDate,
      endDate: identical(endDate, _unset) ? this.endDate : endDate as DateTime?,
      isActive: isActive ?? this.isActive,
      lastLoggedAt: lastLoggedAt ?? this.lastLoggedAt,
    );
  }

  static const Object _unset = Object();

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) {
    return RecurringTransaction(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String? ?? 'personal',
      kind: json['kind'] == 'income' ? FinanceKind.income : FinanceKind.expense,
      category: FinanceCategoryX.fromName(json['category'] as String?),
      title: json['title'] as String? ?? 'Recurring',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'AED',
      frequency: RecurrenceFrequencyX.fromName(json['frequency'] as String?),
      dayOfMonth: (json['dayOfMonth'] as num?)?.toInt() ?? 1,
      startDate:
          DateTime.tryParse(json['startDate'] as String? ?? '') ?? DateTime.now(),
      endDate: json['endDate'] == null
          ? null
          : DateTime.tryParse(json['endDate'] as String),
      isActive: json['isActive'] as bool? ?? true,
      lastLoggedAt: json['lastLoggedAt'] == null
          ? null
          : DateTime.tryParse(json['lastLoggedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'collectionId': collectionId,
        'kind': kind.name,
        'category': category.name,
        'title': title,
        'amount': amount,
        'currency': currency,
        'frequency': frequency.name,
        'dayOfMonth': dayOfMonth,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'isActive': isActive,
        'lastLoggedAt': lastLoggedAt?.toIso8601String(),
      };
}

/// Pure (UI-free, I/O-free) rules for computing when a
/// [RecurringTransaction] should generate transactions. Unit-tested in
/// test/recurring_test.dart.
class RecurrenceMath {
  RecurrenceMath._();

  /// Clamp [day] onto [year]/[month] — day 31 in a 30-day month becomes the
  /// month's last day.
  static DateTime occurrenceInMonth(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day.clamp(1, lastDay));
  }

  /// Advance [date] by [frequency], preserving day-of-month semantics.
  static DateTime advance(DateTime date, RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.monthly:
        return DateTime(date.year, date.month + 1, date.day);
      case RecurrenceFrequency.quarterly:
        return DateTime(date.year, date.month + 3, date.day);
      case RecurrenceFrequency.yearly:
        return DateTime(date.year + 1, date.month, date.day);
    }
  }

  /// The next occurrence strictly after [after], or null when the schedule
  /// has ended ([after] past [endDate], or the cadence can't be advanced).
  ///
  /// Normalises to the template's [dayOfMonth] so clamped months (e.g. the
  /// 30th in February) don't drift the schedule forward permanently.
  static DateTime? nextOccurrence(
    RecurringTransaction r,
    RecurrenceFrequency frequency,
    DateTime after,
  ) {
    if (r.endDate != null && after.isAfter(r.endDate!)) return null;

    var candidate = occurrenceInMonth(r.startDate.year, r.startDate.month, r.dayOfMonth);
    // Guard against pathological loops (max ~50 years of monthly steps).
    var guard = 0;
    while (!candidate.isAfter(after) && guard < 600) {
      candidate = advance(
        DateTime(candidate.year, candidate.month, 1),
        frequency,
      );
      candidate = occurrenceInMonth(candidate.year, candidate.month, r.dayOfMonth);
      guard++;
    }
    if (guard >= 600) return null;
    return candidate;
  }

  /// Every occurrence in [from, until] that hasn't been logged yet (i.e. is
  /// strictly after [lastLoggedAt], or all of them when nothing was logged).
  /// [lastLoggedAt] defaults to the template's own [RecurringTransaction
  /// .lastLoggedAt]. Sorted oldest first. Used to catch up missed months on
  /// app start.
  static List<DateTime> dueOccurrences(
    RecurringTransaction r,
    RecurrenceFrequency frequency,
    DateTime from,
    DateTime until, {
    DateTime? lastLoggedAt,
  }) {
    if (!r.isActive) return [];
    final loggedUpTo = lastLoggedAt ?? r.lastLoggedAt;
    final results = <DateTime>[];
    DateTime? next =
        nextOccurrence(r, frequency, from.subtract(const Duration(microseconds: 1)));
    var guard = 0;
    while (next != null && !next.isAfter(until) && guard < 600) {
      if (loggedUpTo == null || next.isAfter(loggedUpTo)) {
        results.add(next);
      }
      // Strictly after the occurrence we just handled — always advances.
      next = nextOccurrence(r, frequency, next);
      guard++;
    }
    return results;
  }
}

/// Monthly spending limit for one category inside a collection.
class CategoryBudget {
  final String id;
  final String collectionId;
  final FinanceCategory category;
  final double monthlyLimit;

  const CategoryBudget({
    required this.id,
    required this.collectionId,
    required this.category,
    required this.monthlyLimit,
  });

  CategoryBudget copyWith({double? monthlyLimit}) => CategoryBudget(
        id: id,
        collectionId: collectionId,
        category: category,
        monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      );

  factory CategoryBudget.fromJson(Map<String, dynamic> json) {
    return CategoryBudget(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String? ?? 'personal',
      category: FinanceCategoryX.fromName(json['category'] as String?),
      monthlyLimit: (json['monthlyLimit'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'collectionId': collectionId,
        'category': category.name,
        'monthlyLimit': monthlyLimit,
      };
}

/// Alert thresholds as a fraction of a budget's monthly limit. At ≥80% the
/// user gets a "close to budget" nudge; at ≥100% an "over budget" warning.
abstract final class BudgetThresholds {
  static const double near = 0.80;
  static const double exceeded = 1.00;
}

/// How far a budget has been consumed relative to its 80% / 100% thresholds.
enum BudgetAlertLevel { none, near, exceeded }

/// The evaluated state of one [CategoryBudget] for the current month.
/// Pure data — unit-tested in test/finance_test.dart.
class BudgetStatusResult {
  final CategoryBudget budget;

  /// Amount spent this month in the budget's category.
  final double spent;

  const BudgetStatusResult({required this.budget, required this.spent});

  double get limit => budget.monthlyLimit;

  /// Spent / limit. Zero limits never divide — they report 0 (nothing can
  /// be spent "against" a zero budget, and a zero limit shouldn't alert).
  double get ratio => limit <= 0 ? 0 : spent / limit;

  BudgetAlertLevel get status {
    if (ratio >= BudgetThresholds.exceeded) return BudgetAlertLevel.exceeded;
    if (ratio >= BudgetThresholds.near) return BudgetAlertLevel.near;
    return BudgetAlertLevel.none;
  }

  /// True when crossing [threshold] means this result should raise a fresh
  /// alert: the threshold is met and no alert for this budget + month +
  /// threshold was recorded in [alreadyAlerted].
  bool shouldAlertAt(double threshold, Set<String> alreadyAlerted) {
    if (ratio < threshold) return false;
    return !alreadyAlerted.contains(alertKey(threshold));
  }

  /// Dedupe key: one alert per budget per month per threshold, e.g.
  /// "`budgetId|2026|9|0.8`". A raised limit crossed again in the same month
  /// re-alerts only via the other threshold key.
  String alertKey(double threshold) {
    final now = DateTime.now();
    return '${budget.id}|${now.year}|${now.month}|$threshold';
  }
}

/// A set-aside savings goal ("envelope"). Tracking only — no money moves,
/// per the fintech roadmap's pre-licence guidance.
class SavingsEnvelope {
  final String id;
  final String collectionId;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final double monthlyContribution;

  /// Optional link to a document this envelope funds (e.g. trade licence).
  final String? documentId;

  const SavingsEnvelope({
    required this.id,
    required this.collectionId,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0,
    this.monthlyContribution = 0,
    this.documentId,
  });

  double get progress =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0.0, 1.0);

  double get remaining =>
      (targetAmount - savedAmount).clamp(0.0, double.infinity);

  bool get isComplete => targetAmount > 0 && savedAmount >= targetAmount;

  SavingsEnvelope copyWith({
    String? name,
    double? targetAmount,
    double? savedAmount,
    double? monthlyContribution,
    String? documentId,
  }) {
    return SavingsEnvelope(
      id: id,
      collectionId: collectionId,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      documentId: documentId ?? this.documentId,
    );
  }

  factory SavingsEnvelope.fromJson(Map<String, dynamic> json) {
    return SavingsEnvelope(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String? ?? 'personal',
      name: json['name'] as String? ?? 'Envelope',
      targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0,
      savedAmount: (json['savedAmount'] as num?)?.toDouble() ?? 0,
      monthlyContribution:
          (json['monthlyContribution'] as num?)?.toDouble() ?? 0,
      documentId: json['documentId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'collectionId': collectionId,
        'name': name,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
        'monthlyContribution': monthlyContribution,
        'documentId': documentId,
      };
}

/// Shared money helpers.
class MoneyFormat {
  MoneyFormat._();

  /// "AED 12,345.50" — manual thousands separator, no locale init needed.
  static String aed(double value, {String symbol = 'AED '}) {
    final negative = value < 0;
    final fixed = value.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final buffered = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      final remaining = intPart.length - i;
      buffered.write(intPart[i]);
      if (remaining > 1 && remaining % 3 == 1) buffered.write(',');
    }
    return '${negative ? '-' : ''}$symbol${buffered.toString()}.${parts[1]}';
  }
}

/// Pure computation helpers for the finance module — unit-tested in
/// test/finance_test.dart, no I/O.
class FinanceMath {
  FinanceMath._();

  static bool _inMonth(DateTime date, DateTime month) =>
      date.year == month.year && date.month == month.month;

  /// Income/expense/net totals for [month]. Scoped to [collectionId] when
  /// given, across all collections when null.
  static ({double income, double expense, double net}) summaryForMonth(
    List<FinanceTransaction> transactions,
    DateTime month, {
    String? collectionId,
  }) {
    var income = 0.0;
    var expense = 0.0;
    for (final t in transactions) {
      if (collectionId != null && t.collectionId != collectionId) continue;
      if (!_inMonth(t.occurredAt, month)) continue;
      if (t.kind == FinanceKind.income) {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    return (income: income, expense: expense, net: income - expense);
  }

  /// Expenses per category for [month].
  static Map<FinanceCategory, double> spendByCategory(
    List<FinanceTransaction> transactions,
    DateTime month, {
    String? collectionId,
  }) {
    final result = <FinanceCategory, double>{};
    for (final t in transactions) {
      if (t.kind != FinanceKind.expense) continue;
      if (collectionId != null && t.collectionId != collectionId) continue;
      if (!_inMonth(t.occurredAt, month)) continue;
      result[t.category] = (result[t.category] ?? 0) + t.amount;
    }
    return result;
  }

  /// Total sum of category monthly budget limits.
  static double totalBudgetAllocated(List<CategoryBudget> budgets) {
    return budgets.fold(0.0, (sum, b) => sum + b.monthlyLimit);
  }

  /// Remaining unallocated monthly budget given an overall budget limit.
  /// If [excludingCategoryId] is provided (e.g., when editing an existing budget),
  /// that category's existing limit is excluded from the allocated sum.
  static double remainingUnallocatedBudget(
    double overallBudget,
    List<CategoryBudget> budgets, {
    String? excludingCategoryId,
  }) {
    var allocated = 0.0;
    for (final b in budgets) {
      if (excludingCategoryId != null && b.id == excludingCategoryId) continue;
      allocated += b.monthlyLimit;
    }
    return overallBudget - allocated;
  }

  /// Returns the first existing transaction that [candidate] duplicates:
  /// same title (case-insensitive, trimmed), same amount and the same
  /// calendar day, scoped to the candidate's collection. The candidate's
  /// own id is ignored so the edit flow doesn't self-match. Returns null
  /// Returns the first existing transaction that [candidate] duplicates.
  /// Matches on the same title (case-insensitive, trimmed) and kind (expense vs expense,
  /// income vs income), scoped to the candidate's collection. The candidate's
  /// own id is ignored so the edit flow doesn't self-match. Returns null
  /// when the record looks unique — used as a soft "confirm before saving"
  /// guard, not a hard block.
  static FinanceTransaction? findDuplicateTransaction(
    List<FinanceTransaction> transactions,
    FinanceTransaction candidate,
  ) {
    final title = candidate.title.trim().toLowerCase();
    if (title.isEmpty) return null;

    FinanceTransaction? fallbackMatch;

    for (final t in transactions) {
      if (t.id == candidate.id) continue;
      if (t.collectionId != candidate.collectionId) continue;
      if (t.kind != candidate.kind) continue;
      if (t.title.trim().toLowerCase() != title) continue;

      final sameDay = t.occurredAt.year == candidate.occurredAt.year &&
          t.occurredAt.month == candidate.occurredAt.month &&
          t.occurredAt.day == candidate.occurredAt.day;
      final sameAmount = t.amount == candidate.amount;

      // Exact match (same day + same amount) is the highest priority candidate
      if (sameDay && sameAmount) return t;

      // Otherwise remember title match as fallback
      fallbackMatch ??= t;
    }

    return fallbackMatch;
  }

  /// Evaluates every category budget against [spendByCategory] and returns
  /// one result per budget. Pure — drives the 80/100 percent alert engine.
  static List<BudgetStatusResult> budgetStatuses(
    List<CategoryBudget> budgets,
    Map<FinanceCategory, double> spendByCategory,
  ) {
    return [
      for (final b in budgets)
        BudgetStatusResult(
          budget: b,
          spent: spendByCategory[b.category] ?? 0,
        ),
    ];
  }

  /// The single most important alert across [results] for badge purposes:
  /// any 100% beats any 80%, otherwise the budget closest to its limit wins.
  /// Returns null when nothing has reached the 80% threshold.
  static BudgetStatusResult? worstBudgetStatus(
    List<BudgetStatusResult> results,
  ) {
    final hit = results
        .where((r) => r.status == BudgetAlertLevel.exceeded)
        .toList()
      ..sort((a, b) => b.ratio.compareTo(a.ratio));
    if (hit.isNotEmpty) return hit.first;
    final near = results
        .where((r) => r.status == BudgetAlertLevel.near)
        .toList()
      ..sort((a, b) => b.ratio.compareTo(a.ratio));
    if (near.isNotEmpty) return near.first;
    return null;
  }

  /// Renewal cost outlook: sum of known renewal fees for active documents
  /// expiring within [withinDays].
  static double renewalOutlook(List<ExpiryItem> items, int withinDays) {
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: withinDays));
    var total = 0.0;
    for (final item in items) {
      if (!item.isActive) continue;
      if (item.expiresAt.isBefore(now)) continue;
      if (item.expiresAt.isAfter(cutoff)) continue;
      total += item.renewalFee ?? 0;
    }
    return total;
  }

  /// Calculates a 90-day cash flow forecast simulating daily balances based on:
  /// - Starting balance (historical net transactions up to [now])
  /// - Upcoming recurring transactions (income & expense)
  /// - Upcoming document renewal fees from [expiryItems]
  static CashFlowForecast calculate90DayCashFlow({
    required List<FinanceTransaction> transactions,
    required List<RecurringTransaction> recurringTemplates,
    required List<ExpiryItem> expiryItems,
    double? initialBalance,
    DateTime? now,
    int days = 90,
  }) {
    final baseDate = now ?? DateTime.now();
    final startDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    final endDate = startDate.add(Duration(days: days));

    // 1. Determine starting balance
    double startBal = initialBalance ?? 0.0;
    if (initialBalance == null) {
      for (final t in transactions) {
        final tDate = DateTime(t.occurredAt.year, t.occurredAt.month, t.occurredAt.day);
        if (!tDate.isAfter(startDate)) {
          if (t.kind == FinanceKind.income) {
            startBal += t.amount;
          } else {
            startBal -= t.amount;
          }
        }
      }
    }

    // Map of YYYY-MM-DD -> List<CashFlowEvent>
    final eventsByDay = <String, List<CashFlowEvent>>{};

    String dayKey(DateTime dt) =>
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

    // 2. Add recurring transactions
    for (final r in recurringTemplates) {
      if (!r.isActive) continue;
      final occurrences = RecurrenceMath.dueOccurrences(
        r,
        r.frequency,
        startDate,
        endDate,
        lastLoggedAt: r.lastLoggedAt,
      );
      for (final occ in occurrences) {
        final occKey = dayKey(occ);
        eventsByDay.putIfAbsent(occKey, () => []).add(
              CashFlowEvent(
                title: r.title,
                amount: r.amount,
                kind: r.kind,
                isDocumentRenewal: r.category == FinanceCategory.renewals,
              ),
            );
      }
    }

    // 3. Add document renewal outflows
    for (final doc in expiryItems) {
      if (!doc.isActive) continue;
      if (doc.renewalFee == null || doc.renewalFee! <= 0) continue;
      final docExpiry = DateTime(doc.expiresAt.year, doc.expiresAt.month, doc.expiresAt.day);
      if (docExpiry.isAfter(startDate) && !docExpiry.isAfter(endDate)) {
        final docKey = dayKey(docExpiry);
        eventsByDay.putIfAbsent(docKey, () => []).add(
              CashFlowEvent(
                title: '${doc.displayName} Renewal',
                amount: doc.renewalFee!,
                kind: FinanceKind.expense,
                isDocumentRenewal: true,
              ),
            );
      }
    }

    // 4. Build daily points
    final points = <CashFlowPoint>[];
    double currentBal = startBal;
    double lowestBal = startBal;
    DateTime lowestDate = startDate;
    double totalInflow = 0.0;
    double totalOutflow = 0.0;
    double totalRenewal = 0.0;

    for (int d = 0; d <= days; d++) {
      final date = startDate.add(Duration(days: d));
      final k = dayKey(date);
      final dayEvents = eventsByDay[k] ?? const [];

      double dayIn = 0.0;
      double dayOut = 0.0;
      double dayRenewalOut = 0.0;

      for (final ev in dayEvents) {
        if (ev.kind == FinanceKind.income) {
          dayIn += ev.amount;
        } else {
          dayOut += ev.amount;
          if (ev.isDocumentRenewal) {
            dayRenewalOut += ev.amount;
          }
        }
      }

      currentBal = currentBal + dayIn - dayOut;
      totalInflow += dayIn;
      totalOutflow += dayOut;
      totalRenewal += dayRenewalOut;

      if (currentBal < lowestBal) {
        lowestBal = currentBal;
        lowestDate = date;
      }

      points.add(
        CashFlowPoint(
          date: date,
          dayIndex: d,
          balance: currentBal,
          inflow: dayIn,
          outflow: dayOut,
          renewalOutflow: dayRenewalOut,
          events: dayEvents,
        ),
      );
    }

    return CashFlowForecast(
      startDate: startDate,
      endDate: endDate,
      startingBalance: startBal,
      projectedEndBalance: currentBal,
      lowestBalance: lowestBal,
      lowestBalanceDate: lowestDate,
      totalProjectedInflow: totalInflow,
      totalProjectedOutflow: totalOutflow,
      totalRenewalOutflow: totalRenewal,
      points: points,
    );
  }

  static String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// RFC-4180-ish CSV export of transactions.
  static String toCsv(List<FinanceTransaction> transactions) {
    final buffer = StringBuffer('date,kind,category,title,amount,currency,note\n');
    final sorted = [...transactions]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    for (final t in sorted) {
      buffer.write([
        t.occurredAt.toIso8601String().split('T').first,
        t.kind.name,
        t.category.name,
        _csvEscape(t.title),
        t.amount.toStringAsFixed(2),
        t.currency,
        _csvEscape(t.note ?? ''),
      ].join(','));
      buffer.write('\n');
    }
    return buffer.toString();
  }
}

/// Single cash-flow event in a forecast (e.g. document renewal or recurring item).
class CashFlowEvent {
  final String title;
  final double amount;
  final FinanceKind kind;
  final bool isDocumentRenewal;

  const CashFlowEvent({
    required this.title,
    required this.amount,
    required this.kind,
    this.isDocumentRenewal = false,
  });
}

/// Projected state for one single day in the forecast window.
class CashFlowPoint {
  final DateTime date;
  final int dayIndex;
  final double balance;
  final double inflow;
  final double outflow;
  final double renewalOutflow;
  final List<CashFlowEvent> events;

  const CashFlowPoint({
    required this.date,
    required this.dayIndex,
    required this.balance,
    required this.inflow,
    required this.outflow,
    required this.renewalOutflow,
    required this.events,
  });
}

/// Complete 90-day cash flow forecast data model. Pure calculation result.
class CashFlowForecast {
  final DateTime startDate;
  final DateTime endDate;
  final double startingBalance;
  final double projectedEndBalance;
  final double lowestBalance;
  final DateTime lowestBalanceDate;
  final double totalProjectedInflow;
  final double totalProjectedOutflow;
  final double totalRenewalOutflow;
  final List<CashFlowPoint> points;

  const CashFlowForecast({
    required this.startDate,
    required this.endDate,
    required this.startingBalance,
    required this.projectedEndBalance,
    required this.lowestBalance,
    required this.lowestBalanceDate,
    required this.totalProjectedInflow,
    required this.totalProjectedOutflow,
    required this.totalRenewalOutflow,
    required this.points,
  });

  /// Net projected change over the forecast period.
  double get netChange => projectedEndBalance - startingBalance;

  /// Percentage change relative to starting balance (0 if starting balance is 0).
  double get percentChange => startingBalance == 0
      ? 0
      : (netChange / startingBalance.abs()) * 100;
}

