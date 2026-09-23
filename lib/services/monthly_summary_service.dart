import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/finance.dart';
import 'collection_service.dart';
import 'finance_service.dart';
import 'gemini_api_service.dart';

/// One item of the monthly narrative: a category move, budget overrun, or
/// savings-envelope projection. Carries pre-formatted display strings so
/// narrative generation stays presentation-agnostic.
class MonthlySummaryInsight {
  /// Insight kind — drives the icon/color in the UI and the narrative line.
  final MonthlyInsightKind kind;

  /// Human-readable narrative sentence, e.g.
  /// "Spending on Rent rose 12% vs July (AED 15,000 vs 13,392)."
  final String sentence;

  /// Pre-formatted AED amounts for the UI card.
  final String? amountLabel;

  /// Extra detail label, e.g. the month name or budget usage percent.
  final String? detailLabel;

  const MonthlySummaryInsight({
    required this.kind,
    required this.sentence,
    this.amountLabel,
    this.detailLabel,
  });
}

/// Kind of a [MonthlySummaryInsight] — order matters: narrative lists
/// spending movers first, then budgets, then savings.
enum MonthlyInsightKind { spendingMove, budgetAlert, savings, positive }

/// Pure aggregation of everything the executive summary narrates.
///
/// Computes this-month vs last-month comparisons with zero Flutter/UI
/// dependencies so it is fully unit-testable with fixed [now] values.
class MonthlySummaryData {
  final int year;
  final int month;

  /// Month name like "August".
  final String monthName;

  final double income;
  final double expense;
  final double net;

  /// Previous month's totals for comparison (null when no data existed).
  final double? prevExpense;
  final double? prevIncome;

  /// Percent change of expense vs previous month (negative = spent less).
  /// Null when no previous data or prev expense was 0.
  final double? expenseChangePct;

  /// Top spending moves vs last month, biggest absolute increase first.
  final List<({FinanceCategory category, double current, double previous, double changePct})>
      topMoves;

  /// Biggest single expense transaction of the month (if any).
  final FinanceTransaction? topTransaction;

  /// Budget overruns: category budgets exceeded this month.
  final List<({CategoryBudget budget, double spent})> budgetOverruns;

  /// Envelope projections: months remaining to hit target at the current
  /// monthly contribution pace.
  final List<({SavingsEnvelope envelope, int? monthsRemaining, double projectedSaving})>
      envelopeProjections;

  /// True when there is no meaningful data to summarize.
  final bool isEmpty;

  const MonthlySummaryData({
    required this.year,
    required this.month,
    required this.monthName,
    required this.income,
    required this.expense,
    required this.net,
    this.prevExpense,
    this.prevIncome,
    this.expenseChangePct,
    this.topMoves = const [],
    this.topTransaction,
    this.budgetOverruns = const [],
    this.envelopeProjections = const [],
    this.isEmpty = false,
  });
}

/// Aggregates transactions, budgets and envelopes into a [MonthlySummaryData].
class MonthlySummaryAggregator {
  const MonthlySummaryAggregator();

  /// [now] is injectable for tests. [collectionId] scopes to the active
  /// collection, matching how Money screen filters data.
  MonthlySummaryData aggregate({
    required List<FinanceTransaction> transactions,
    required List<CategoryBudget> budgets,
    required List<SavingsEnvelope> envelopes,
    DateTime? now,
    String? collectionId,
  }) {
    final ref = now ?? DateTime.now();
    final prevMonth = DateTime(ref.year, ref.month - 1);
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December',
    ];
    final monthName = monthNames[ref.month - 1];

    // ── This month totals ──
    var income = 0.0;
    var expense = 0.0;
    var prevIncome = 0.0;
    var prevExpense = 0.0;
    FinanceTransaction? topTx;
    final thisByCategory = <FinanceCategory, double>{};
    final prevByCategory = <FinanceCategory, double>{};

    for (final t in transactions) {
      if (collectionId != null && t.collectionId != collectionId) continue;
      final d = t.occurredAt;
      if (d.year == ref.year && d.month == ref.month) {
        if (t.kind == FinanceKind.income) {
          income += t.amount;
        } else {
          expense += t.amount;
          if (topTx == null || t.amount > topTx.amount) topTx = t;
        }
        thisByCategory[t.category] = (thisByCategory[t.category] ?? 0) + t.amount;
      } else if (d.year == prevMonth.year && d.month == prevMonth.month) {
        if (t.kind == FinanceKind.income) {
          prevIncome += t.amount;
        } else {
          prevExpense += t.amount;
        }
        prevByCategory[t.category] = (prevByCategory[t.category] ?? 0) + t.amount;
      }
    }

    final hasPrev = prevIncome > 0 || prevExpense > 0;
    final expenseChangePct =
        (hasPrev && prevExpense > 0) ? ((expense - prevExpense) / prevExpense) * 100 : null;

    // ── Top category moves (increase or decrease, biggest |delta| first) ──
    final moves = <({FinanceCategory category, double current, double previous, double changePct})>[];
    for (final entry in thisByCategory.entries) {
      final prev = prevByCategory[entry.key] ?? 0;
      final delta = entry.value - prev;
      if (delta.abs() < 1.0) continue; // ignore noise under AED 1
      if (prev <= 0 && entry.value < 50) continue; // ignore tiny new categories
      final pct = prev > 0 ? (delta / prev) * 100 : null;
      moves.add((
        category: entry.key,
        current: entry.value,
        previous: prev,
        changePct: pct ?? 100.0,
      ));
    }
    moves.sort((a, b) => (b.current - b.previous).compareTo(a.current - a.previous));
    final topMoves = moves.take(3).toList();

    // ── Budget overruns ──
    final overruns = <({CategoryBudget budget, double spent})>[];
    for (final b in budgets) {
      if (collectionId != null && b.collectionId != collectionId) continue;
      final spent = thisByCategory[b.category] ?? 0;
      if (b.monthlyLimit > 0 && spent > b.monthlyLimit) {
        overruns.add((budget: b, spent: spent));
      }
    }
    overruns.sort((a, b) => (b.spent - b.budget.monthlyLimit)
        .compareTo(a.spent - a.budget.monthlyLimit));

    // ── Envelope projections ──
    final projections = <({SavingsEnvelope envelope, int? monthsRemaining, double projectedSaving})>[];
    for (final e in envelopes) {
      if (collectionId != null && e.collectionId != collectionId) continue;
      if (e.monthlyContribution <= 0 || e.isComplete) continue;
      final remaining = e.remaining;
      final months = (remaining / e.monthlyContribution).ceil();
      projections.add((
        envelope: e,
        monthsRemaining: months,
        projectedSaving: e.savedAmount + e.monthlyContribution * months,
      ));
    }

    final isEmpty = income == 0 && expense == 0 && !hasPrev;

    return MonthlySummaryData(
      year: ref.year,
      month: ref.month,
      monthName: monthName,
      income: income,
      expense: expense,
      net: income - expense,
      prevExpense: hasPrev ? prevExpense : null,
      prevIncome: hasPrev ? prevIncome : null,
      expenseChangePct: expenseChangePct,
      topMoves: topMoves,
      topTransaction: topTx,
      budgetOverruns: overruns,
      envelopeProjections: projections,
      isEmpty: isEmpty,
    );
  }
}

/// Generates the natural-language executive summary.
///
/// Two modes:
/// 1. **Template narrative** (always available, offline, deterministic) —
///    rule-based sentences from [MonthlySummaryData].
/// 2. **LLM polish** (optional) — [buildLlmPrompt] produces a compact,
///    data-faithful prompt; [MonthlySummaryService.refresh] sends it to the
///    Gemini API when the user has configured a key, falling back to the
///    template narrative on any failure.
class MonthlySummaryNarrator {
  const MonthlySummaryNarrator();

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];

  /// Name of the month preceding [data]'s month, e.g. "July" for August.
  static String prevMonthName(MonthlySummaryData data) {
    final idx = (data.month + 10) % 12; // month-1, wrapped to 0..11
    return _monthNames[idx];
  }

  /// Builds the insight list shown on the card and used by the LLM prompt.
  List<MonthlySummaryInsight> buildInsights(MonthlySummaryData data) {
    if (data.isEmpty) return const [];
    final insights = <MonthlySummaryInsight>[];
    final prevName = prevMonthName(data);

    // 1. Headline spending move vs last month.
    if (data.expenseChangePct != null && data.prevExpense != null) {
      final pct = data.expenseChangePct!.abs().toStringAsFixed(0);
      final dir = data.expenseChangePct! >= 0 ? 'rose' : 'dropped';
      final driver = data.topMoves.isNotEmpty
          ? ' driven by ${data.topMoves.first.category.displayName}'
          : '';
      insights.add(MonthlySummaryInsight(
        kind: data.expenseChangePct! >= 0
            ? MonthlyInsightKind.spendingMove
            : MonthlyInsightKind.positive,
        sentence:
            'In ${data.monthName}, spending $dir by $pct% vs $prevName$driver.',
        amountLabel: '${_cur()} ${_fmt(data.expense)}',
        detailLabel:
            '$pct% vs ${_fmt(data.prevExpense!)} in $prevName',
      ));
    }

    // 2. Top category moves.
    for (final move in data.topMoves.take(2)) {
      final up = move.current >= move.previous;
      final pct = move.changePct.toStringAsFixed(0);
      final sentence = move.previous > 0
          ? '${move.category.displayName} ${up ? 'up' : 'down'} $pct% vs $prevName '
              '(${_cur()} ${_fmt(move.current)} vs ${_fmt(move.previous)}).'
          : '${move.category.displayName} is a new spend area this month '
              '(${_cur()} ${_fmt(move.current)}).';
      insights.add(MonthlySummaryInsight(
        kind: up ? MonthlyInsightKind.spendingMove : MonthlyInsightKind.positive,
        sentence: sentence,
        amountLabel: '${_cur()} ${_fmt(move.current)}',
        detailLabel: move.previous > 0 ? '$pct% vs ${_fmt(move.previous)}' : 'New',
      ));
    }

    // 3. Biggest single expense.
    final topTx = data.topTransaction;
    if (topTx != null && topTx.amount >= 100) {
      insights.add(MonthlySummaryInsight(
        kind: MonthlyInsightKind.spendingMove,
        sentence:
            'Largest single expense: "${topTx.title}" at ${_cur()} ${_fmt(topTx.amount)}.',
        amountLabel: '${_cur()} ${_fmt(topTx.amount)}',
        detailLabel: topTx.category.displayName,
      ));
    }

    // 4. Budget overruns.
    for (final o in data.budgetOverruns.take(2)) {
      final overPct =
          (((o.spent - o.budget.monthlyLimit) / o.budget.monthlyLimit) * 100)
              .toStringAsFixed(0);
      insights.add(MonthlySummaryInsight(
        kind: MonthlyInsightKind.budgetAlert,
        sentence:
            '${o.budget.category.displayName} budget exceeded by $overPct% '
            '(${_cur()} ${_fmt(o.spent)} of ${_fmt(o.budget.monthlyLimit)}).',
        amountLabel: '${_cur()} ${_fmt(o.spent - o.budget.monthlyLimit)} over',
        detailLabel: 'Limit ${_fmt(o.budget.monthlyLimit)}',
      ));
    }

    // 5. Savings-envelope projection — the "on track to save" line.
    for (final p in data.envelopeProjections.take(2)) {
      final months = p.monthsRemaining;
      final eta = months == null
          ? ''
          : months == 1
              ? ' next month'
              : ' in $months months';
      insights.add(MonthlySummaryInsight(
        kind: MonthlyInsightKind.savings,
        sentence:
            'You are on track to save ${_cur()} ${_fmt(p.projectedSaving)} in your '
            '${p.envelope.name} envelope$eta at the current pace.',
        amountLabel: '${_cur()} ${_fmt(p.projectedSaving)}',
        detailLabel: months == null ? null : '$months months left',
      ));
    }

    // 6. Net position close.
    insights.add(MonthlySummaryInsight(
      kind: data.net >= 0 ? MonthlyInsightKind.positive : MonthlyInsightKind.budgetAlert,
      sentence: data.net >= 0
          ? 'Net position is positive: income ${_cur()} ${_fmt(data.income)} '
              'against ${_cur()} ${_fmt(data.expense)} spent.'
          : 'You spent ${_cur()} ${_fmt(data.expense - data.income)} more than you '
              'earned this month.',
      amountLabel: '${_cur()} ${_fmt(data.net)}',
      detailLabel: 'Net',
    ));

    return insights;
  }

  /// Template executive summary — deterministic, offline fallback.
  String templateNarrative(MonthlySummaryData data) {
    if (data.isEmpty) {
      return 'No financial activity recorded for ${data.monthName} yet. '
          'Log expenses or income to see your executive summary here.';
    }
    final insights = buildInsights(data);
    final buf = StringBuffer('In ${data.monthName}, ');
    if (data.expenseChangePct != null) {
      final pct = data.expenseChangePct!.abs().toStringAsFixed(0);
      buf.write(
          'spending ${data.expenseChangePct! >= 0 ? 'rose' : 'dropped'} by $pct%');
      if (data.topMoves.isNotEmpty) {
        buf.write(' due to ${data.topMoves.first.category.displayName.toLowerCase()}');
      }
      buf.write('. ');
    } else {
      buf.write('you spent ${_cur()} ${_fmt(data.expense)}. ');
    }
    // The savings line is the wow-factor sentence from the feature spec.
    final savings = insights
        .where((i) => i.kind == MonthlyInsightKind.savings)
        .map((i) => i.sentence);
    for (final s in savings) {
      buf.write('$s ');
    }
    final overruns = insights
        .where((i) => i.kind == MonthlyInsightKind.budgetAlert)
        .take(1)
        .map((i) => i.sentence);
    for (final s in overruns) {
      buf.write('$s ');
    }
    return buf.toString().trim();
  }

  /// Compact, data-faithful LLM prompt for an LLM polish pass.
  String buildLlmPrompt(MonthlySummaryData data) {
    final prevName = prevMonthName(data);
    final sb = StringBuffer()
      ..writeln('You are a concise CFO assistant for a GCC small business.')
      ..writeln(
          'Write a 2-3 sentence executive summary for ${data.monthName} ${data.year}.')
      ..writeln('Use only the facts below; do not invent numbers.')
      ..writeln('Mention the biggest spending driver and savings progress.')
      ..writeln('Currency is local GCC currency.')
      ..writeln()
      ..writeln('DATA:')
      ..writeln('- Income: ${_cur()} ${_fmt(data.income)}')
      ..writeln('- Expenses: ${_cur()} ${_fmt(data.expense)}')
      ..writeln('- Net: ${_cur()} ${_fmt(data.net)}');
    if (data.prevExpense != null) {
      sb.writeln('- $prevName expenses: ${_cur()} ${_fmt(data.prevExpense!)}');
      if (data.expenseChangePct != null) {
        sb.writeln('- Expense change vs $prevName: '
            '${data.expenseChangePct!.toStringAsFixed(1)}%');
      }
    }
    for (final move in data.topMoves) {
      sb.writeln('- ${move.category.displayName}: ${_cur()} ${_fmt(move.current)} '
          '(prev ${_fmt(move.previous)})');
    }
    final topTx = data.topTransaction;
    if (topTx != null) {
      sb.writeln('- Largest expense: "${topTx.title}" ${_cur()} ${_fmt(topTx.amount)}');
    }
    for (final o in data.budgetOverruns) {
      sb.writeln('- Budget overrun: ${o.budget.category.displayName} '
          'spent ${_fmt(o.spent)} of ${_fmt(o.budget.monthlyLimit)}');
    }
    for (final p in data.envelopeProjections) {
      sb.writeln('- Savings envelope "${p.envelope.name}": saved '
          '${_fmt(p.envelope.savedAmount)} of ${_fmt(p.envelope.targetAmount)}, '
          'contributing ${_fmt(p.envelope.monthlyContribution)}/month, '
          'projected ${_fmt(p.projectedSaving)}'
          '${p.monthsRemaining != null ? ' in ${p.monthsRemaining} months' : ''}');
    }
    return sb.toString();
  }

  static String _cur() => DocumentCollectionService.instance.activeCurrency;

  static String _fmt(double v) {
    final rounded = (v * 100).round() / 100;
    if (rounded == rounded.roundToDouble()) {
      return rounded.round().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    }
    return rounded.toStringAsFixed(2);
  }
}

/// Orchestrates the executive summary lifecycle: aggregation, template
/// narrative, optional LLM polish, and month-keyed caching.
///
/// Cache key: `monthlySummary.<collectionId|all>.<yyyy-mm>`. Changing data
/// or pulling to refresh re-generates; the LLM pass only runs when a Gemini
/// API key is configured (see [GeminiApiService]).
class MonthlySummaryService {
  MonthlySummaryService._();

  static final MonthlySummaryService instance = MonthlySummaryService._();

  static const String _cachePrefix = 'monthlySummary.v1';

  final MonthlySummaryAggregator _aggregator = const MonthlySummaryAggregator();
  final MonthlySummaryNarrator _narrator = const MonthlySummaryNarrator();

  /// Injectable overrides (used by tests).
  @visibleForTesting
  Future<String> Function(String prompt)? llmCallOverride;

  /// Cache keyed per collection + month so re-opening the screen is instant.
  final Map<String, String> _memoryCache = {};

  /// Current result for the active collection.
  MonthlySummaryData? _lastData;
  String? _lastNarrative;
  List<MonthlySummaryInsight> _lastInsights = const [];
  bool _lastUsedLlm = false;

  MonthlySummaryData? get lastData => _lastData;
  String? get lastNarrative => _lastNarrative;
  List<MonthlySummaryInsight> get lastInsights => _lastInsights;

  /// True when the displayed narrative came from the LLM rather than the
  /// template fallback (drives a subtle "AI" chip in the UI).
  bool get lastUsedLlm => _lastUsedLlm;

  /// Aggregates + generates the narrative synchronously (template mode) and
  /// kicks off an optional async LLM polish. Returns the template narrative
  /// immediately; callers listening to [narrativeStream] receive the polished
  /// version when it arrives.
  final StreamController<({String narrative, bool usedLlm})> _narrativeController =
      StreamController.broadcast();

  Stream<({String narrative, bool usedLlm})> get narrativeStream =>
      _narrativeController.stream;

  MonthlySummaryData generate({String? collectionId, DateTime? now}) {
    final ref = now ?? DateTime.now();
    final data = _aggregator.aggregate(
      transactions: FinanceService.instance.activeTransactions,
      budgets: FinanceService.instance.activeBudgets,
      envelopes: FinanceService.instance.activeEnvelopes,
      collectionId: collectionId,
      now: ref,
    );
    final narrative = _narrator.templateNarrative(data);
    final insights = _narrator.buildInsights(data);

    _lastData = data;
    _lastNarrative = narrative;
    _lastInsights = insights;
    _lastUsedLlm = false;

    final key = _cacheKey(collectionId, ref);
    _memoryCache[key] = narrative;
    _narrativeController.add((narrative: narrative, usedLlm: false));

    _maybePolishWithLlm(data, collectionId, ref);
    return data;
  }

  Future<void> _maybePolishWithLlm(
    MonthlySummaryData data,
    String? collectionId,
    DateTime ref,
  ) async {
    if (data.isEmpty) return;
    if (!GeminiApiService.instance.isConfigured) return;
    final prompt = _narrator.buildLlmPrompt(data);
    try {
      final text = llmCallOverride != null
          ? await llmCallOverride!(prompt)
          : await GeminiApiService.instance.generateContent(prompt);
      if (text.trim().isEmpty) return;
      _lastNarrative = text.trim();
      _lastUsedLlm = true;
      final key = _cacheKey(collectionId, ref);
      _memoryCache[key] = text.trim();
      _narrativeController.add((narrative: text.trim(), usedLlm: true));
    } catch (e) {
      debugPrint('MonthlySummary LLM polish failed (template fallback kept): $e');
    }
  }

  String _cacheKey(String? collectionId, DateTime ref) =>
      '$_cachePrefix.${collectionId ?? 'all'}.${ref.year}-${ref.month.toString().padLeft(2, '0')}';
}
