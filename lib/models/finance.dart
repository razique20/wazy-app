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
