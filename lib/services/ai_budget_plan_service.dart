import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/finance.dart';

import 'anomaly_detection_service.dart';
import 'document_scanner_service.dart';
import 'entitlement_service.dart';
import 'finance_service.dart';
import 'groq_api_service.dart';

/// What kind of step this is — drives the icon and the button shown on the
/// plan screen (create an envelope, set a category budget, or just advice).
enum AiBudgetPlanActionType {
  /// Save money into a dedicated envelope.
  envelope,

  /// Cap a spending category at a monthly budget.
  budget,

  /// Plain advice with no one-tap follow-up.
  tip,
}

/// One concrete step of an AI budget plan (e.g. "Save AED 1,200/month into
/// the 'MacBook' envelope by trimming Shopping to AED 800").
class AiBudgetPlanAction {
  /// What kind of step this is.
  final AiBudgetPlanActionType type;

  /// Short imperative headline, e.g. "Trim Shopping by 25%".
  final String title;

  /// 1-2 sentence explanation grounded in the user's own numbers.
  final String detail;

  /// Impact category when the step moves money in/out of a spend area.
  final FinanceCategory? category;

  /// Positive = frees up money; negative = requires extra spending.
  final double? monthlyAmountAed;

  /// Suggested envelope to create / contribute to, when the step is a
  /// savings step.
  final String? suggestedEnvelopeName;

  const AiBudgetPlanAction({
    required this.title,
    required this.detail,
    this.type = AiBudgetPlanActionType.tip,
    this.category,
    this.monthlyAmountAed,
    this.suggestedEnvelopeName,
  });
}

/// A complete AI-generated plan for reaching the user's stated goal.
class AiBudgetPlan {
  /// Friendly plan title, e.g. "Plan: MacBook in 6 months".
  final String title;

  /// 2-3 sentence feasibility verdict grounded in the user's numbers.
  final String summary;

  /// Whether the goal is considered achievable at the current pace.
  final bool feasible;

  /// Months to reach the goal at the recommended pace (null when unknown).
  final int? monthsToGoal;

  /// Total extra amount the user must set aside / free up each month.
  final double monthlySavingTargetAed;

  /// Concrete, actionable steps ordered by impact.
  final List<AiBudgetPlanAction> actions;      const AiBudgetPlan({
    required this.title,
    required this.summary,
    required this.feasible,
    required this.monthsToGoal,
    required this.monthlySavingTargetAed,
    required this.actions,
  });
}

/// A ready-made set of category budget caps (Comfortable / Balanced /
/// Goal-first) the user can apply in one tap and then fine-tune with
/// sliders on the plan screen.
class BudgetPlanTemplate {
  /// Stable id, e.g. `goal_first`.
  final String id;

  /// Short display name, e.g. "Goal-first".
  final String label;

  /// Emoji shown on the template chip.
  final String emoji;

  /// One-line explanation of what the template does.
  final String description;

  /// Suggested monthly cap per category (only categories that get trimmed).
  final Map<FinanceCategory, double> caps;

  const BudgetPlanTemplate({
    required this.id,
    required this.label,
    required this.emoji,
    required this.description,
    required this.caps,
  });
}

/// Orchestrates the AI Budget Planner: gathers the user's real financial
/// picture (income/expenses, budgets, envelopes, recurring commitments,
/// upcoming renewal fees), asks Groq for a JSON plan toward a stated goal,
/// and enforces the monthly tier quota — the same engine as the AI
/// Executive Summary.
class AiBudgetPlanService {
  AiBudgetPlanService._();

  static final AiBudgetPlanService instance = AiBudgetPlanService._();

  static const String _usagePrefix = 'groqAiBudgetPlan.usage';

  AiBudgetPlan? _lastPlan;
  bool _lastUsedGroq = false;
  bool _lastQuotaExceeded = false;

  AiBudgetPlan? get lastPlan => _lastPlan;
  bool get lastUsedGroq => _lastUsedGroq;
  bool get lastQuotaExceeded => _lastQuotaExceeded;

  /// Injectable override for unit tests.
  @visibleForTesting
  Future<String> Function(String system, String user)? groqCallOverride;

  /// Current month usage key, e.g. `groqAiBudgetPlan.usage.2026-09`.
  String _currentMonthKey([DateTime? now]) {
    final ref = now ?? DateTime.now();
    return '$_usagePrefix.${ref.year}-${ref.month.toString().padLeft(2, '0')}';
  }

  /// Number of AI budget plans generated this calendar month.
  Future<int> getUsedQuotaThisMonth([DateTime? now]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_currentMonthKey(now)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Maximum allowed AI budget plans for the current subscription tier.
  int getMonthlyQuotaLimit() {
    return EntitlementService.instance.limits.aiBudgetPlanMonthlyQuota;
  }

  /// Remaining AI budget plans for this calendar month.
  Future<int> getRemainingQuotaThisMonth([DateTime? now]) async {
    final used = await getUsedQuotaThisMonth(now);
    final limit = getMonthlyQuotaLimit();
    final remaining = limit - used;
    return remaining < 0 ? 0 : remaining;
  }

  /// Check whether the user can generate a plan under their plan limit.
  Future<bool> canGeneratePlan([DateTime? now]) async {
    final remaining = await getRemainingQuotaThisMonth(now);
    return remaining > 0;
  }

  /// Increment monthly usage counter after a successful Groq generation.
  Future<int> _incrementUsageCounter([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _currentMonthKey(now);
    final current = prefs.getInt(key) ?? 0;
    final updated = current + 1;
    await prefs.setInt(key, updated);
    return updated;
  }

  /// Reset usage counter (unit tests / tier updates).
  @visibleForTesting
  Future<void> resetUsageCounter([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentMonthKey(now));
  }

  /// Generates an AI budget plan toward [goalDescription] for [targetAmount]
  /// AED within [targetMonths] (optional).
  ///
  /// Returns the parsed plan plus flags describing how it was produced.
  Future<({AiBudgetPlan plan, bool usedGroq, bool quotaExceeded})>
      generatePlan({
    required String goalDescription,
    required double targetAmount,
    int? targetMonths,
    bool forceRegenerate = false,
    DateTime? now,
  }) async {
    final ref = now ?? DateTime.now();

    // Cached plan shown again unless the user explicitly regenerates.
    if (!forceRegenerate && _lastPlan != null) {
      return (
        plan: _lastPlan!,
        usedGroq: _lastUsedGroq,
        quotaExceeded: false,
      );
    }

    // Enforce the monthly tier quota before a new Groq call.
    final remaining = await getRemainingQuotaThisMonth(ref);
    if (remaining <= 0) {
      final fin = _gatherFinances();
      final fallback = _buildFallbackPlan(
        goalDescription: goalDescription,
        targetAmount: targetAmount,
        targetMonths: targetMonths,
        monthlySpare: fin.monthlySpare,
        now: ref,
      );
      _lastPlan = fallback;
      _lastUsedGroq = false;
      _lastQuotaExceeded = true;
      return (plan: fallback, usedGroq: false, quotaExceeded: true);
    }

    final context = await _buildPromptContext(
      goalDescription: goalDescription,
      targetAmount: targetAmount,
      targetMonths: targetMonths,
      now: ref,
    );

    const systemPrompt =
        'You are Wazy\'s AI Budget Planner for a UAE user. '
        'Create a realistic, concrete plan to reach the user\'s stated goal '
        'using ONLY the financial facts provided — never invent numbers. '
        'Respond with STRICT JSON only (no markdown fences, no commentary) '
        'matching: {"title": string, "summary": string, "feasible": bool, '
        '"monthsToGoal": number|null, "monthlySavingTarget": number, '
        '"actions": [{"title": string, "detail": string, '
        '"type": "envelope"|"budget"|"tip", '
        '"categoryName": "renewals|salaries|rent|utilities|suppliers|'
        'marketing|transport|software|sales|foodAndBeverages|shopping|'
        'medical|entertainment|other"|null, "monthlyAmount": number|null, '
        '"suggestedEnvelopeName": string|null}]}. '
        'Action type rules: "envelope" = create or top up a savings envelope '
        'for the goal itself (set suggestedEnvelopeName; use for at most 1-2 '
        'actions); "budget" = set a monthly cap on one of the user\'s real '
        'categories to free up cash (set categoryName AND monthlyAmount = the '
        'NEW monthly limit, not the saving); "tip" = short practical advice '
        'that needs no in-app change. Mix the types — never make every action '
        'an envelope. Write for a normal person: simple everyday words, use '
        'the user\'s own numbers, no jargon like "discretionary spend". '
        'Give 3-5 actions. Keep the summary under 60 words. '
        'All money values in AED.';

    try {
      final raw = groqCallOverride != null
          ? await groqCallOverride!(systemPrompt, context)
          : await GroqApiService.instance.generateSummary(
              systemPrompt: systemPrompt,
              userPrompt: context,
              maxTokens: 900,
              temperature: 0.2,
            );

      final plan = _parsePlan(raw);
      if (plan != null) {
        await _incrementUsageCounter(ref);
        _lastPlan = plan;
        _lastUsedGroq = true;
        _lastQuotaExceeded = false;
        return (plan: plan, usedGroq: true, quotaExceeded: false);
      }
      debugPrint('AI Budget Plan: Groq returned unparseable JSON.');
    } catch (e) {
      debugPrint('AI Budget Plan generation failed (using fallback): $e');
    }

    // Groq failed or the JSON was unparseable — deterministic fallback.
    final fin = _gatherFinances();
    final fallback = _buildFallbackPlan(
      goalDescription: goalDescription,
      targetAmount: targetAmount,
      targetMonths: targetMonths,
      monthlySpare: fin.monthlySpare,
      now: ref,
    );
    _lastPlan = fallback;
    _lastUsedGroq = false;
    _lastQuotaExceeded = false;
    return (plan: fallback, usedGroq: false, quotaExceeded: false);
  }

  // ------------------------------------------------------------------
  // Context gathering
  // ------------------------------------------------------------------

  ({double income, double expense, double monthlySpare}) _gatherFinances() {
    final now = DateTime.now();
    final txs = FinanceService.instance.activeTransactions;
    // Average the last 3 months so a single unusual month doesn't skew the
    // plan (e.g. one annual insurance payment in an otherwise calm period).
    var income = 0.0;
    var expense = 0.0;
    var monthsCounted = 0;
    for (var i = 0; i < 3; i++) {
      final month = DateTime(now.year, now.month - i);
      final s = FinanceMath.summaryForMonth(txs, month);
      if (s.income > 0 || s.expense > 0) monthsCounted++;
      income += s.income;
      expense += s.expense;
    }
    final divisor = monthsCounted > 0 ? monthsCounted : 1;
    final avgIncome = income / divisor;
    final avgExpense = expense / divisor;
    return (
      income: avgIncome,
      expense: avgExpense,
      monthlySpare: avgIncome - avgExpense,
    );
  }

  /// Average monthly spend per expense category over the last [months]
  /// months (defaults to the live FinanceService data). Used by the budget
  /// templates and the sliders on the plan screen.
  Map<FinanceCategory, double> averageMonthlySpendByCategory({
    int months = 3,
    List<FinanceTransaction>? transactions,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final txs = transactions ?? FinanceService.instance.activeTransactions;
    final byCategory = <FinanceCategory, double>{};
    for (final t in txs) {
      if (t.kind != FinanceKind.expense) continue;
      final d = t.occurredAt;
      if (d.isBefore(ref.subtract(Duration(days: 30 * months)))) continue;
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
    }
    return {
      for (final e in byCategory.entries) e.key: e.value / months,
    };
  }

  /// Income / expense / spare snapshot (3-month average) used by the budget
  /// adjuster's goal-health meter.
  ({double income, double expense, double monthlySpare}) financesSnapshot({
    List<FinanceTransaction>? transactions,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final txs = transactions ?? FinanceService.instance.activeTransactions;
    var income = 0.0;
    var expense = 0.0;
    var monthsCounted = 0;
    for (var i = 0; i < 3; i++) {
      final month = DateTime(ref.year, ref.month - i);
      final s = FinanceMath.summaryForMonth(txs, month);
      if (s.income > 0 || s.expense > 0) monthsCounted++;
      income += s.income;
      expense += s.expense;
    }
    final divisor = monthsCounted > 0 ? monthsCounted : 1;
    final avgIncome = income / divisor;
    final avgExpense = expense / divisor;
    return (
      income: avgIncome,
      expense: avgExpense,
      monthlySpare: avgIncome - avgExpense,
    );
  }

  /// Categories where spending is easiest to trim without hurting the
  /// essentials (rent, salaries, utilities, medical stay out).
  static const Set<FinanceCategory> _flexibleCategories = {
    FinanceCategory.foodAndBeverages,
    FinanceCategory.shopping,
    FinanceCategory.entertainment,
    FinanceCategory.transport,
    FinanceCategory.other,
    FinanceCategory.marketing,
  };

  /// Ready-made budget templates that pre-fill category caps to help the
  /// user reach their goal. The screen lets them fine-tune each cap with a
  /// slider and shows a live goal-health meter as they adjust.
  List<BudgetPlanTemplate> buildBudgetTemplates({
    required double monthlySavingTarget,
    List<FinanceTransaction>? transactions,
    DateTime? now,
  }) {
    final spend = averageMonthlySpendByCategory(
      transactions: transactions,
      now: now,
    );
    if (spend.isEmpty) return const [];

    // Only categories with meaningful spend, biggest first.
    final flexible = spend.entries
        .where((e) => _flexibleCategories.contains(e.key) && e.value >= 20)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (flexible.isEmpty) return const [];

    Map<FinanceCategory, double> capsForTrim(double trimPct) {
      final caps = <FinanceCategory, double>{};
      for (final e in flexible) {
        final cap = e.value * (1 - trimPct);
        // Round to the nearest 5 so caps read as real budgets.
        final rounded = (cap / 5).round() * 5.0;
        if (rounded < e.value - 1) caps[e.key] = rounded;
      }
      return caps;
    }

    // Goal-first: deepen trims on the biggest flexible categories until the
    // plan's monthly saving target is met (or everything is trimmed 30%).
    Map<FinanceCategory, double> goalFirstCaps() {
      final caps = <FinanceCategory, double>{};
      var freed = 0.0;
      for (final e in flexible) {
        if (monthlySavingTarget > 0 && freed >= monthlySavingTarget) break;
        final cap = (e.value * 0.70 / 5).round() * 5.0;
        final applied = e.value - cap;
        if (applied <= 0) continue;
        caps[e.key] = cap;
        freed += applied;
      }
      return caps;
    }

    return [
      BudgetPlanTemplate(
        id: 'comfortable',
        label: 'Comfortable',
        emoji: '😌',
        description:
            'A light 8% trim on your most flexible categories — easy to keep up.',
        caps: capsForTrim(0.08),
      ),
      BudgetPlanTemplate(
        id: 'balanced',
        label: 'Balanced',
        emoji: '⚖️',
        description:
            'Trims flexible spending by 15% — steady progress, still comfortable.',
        caps: capsForTrim(0.15),
      ),
      BudgetPlanTemplate(
        id: 'goal_first',
        label: 'Goal-first',
        emoji: '🎯',
        description: monthlySavingTarget > 0
            ? 'Cuts your biggest flexible budgets until you free up AED ${_fmt(monthlySavingTarget)}/month for the goal.'
            : 'Cuts your biggest flexible budgets by 30% to free up cash faster.',
        caps: goalFirstCaps(),
      ),
    ];
  }

  /// "Happy index" for the budget adjuster: how comfortably the adjusted
  /// budgets reach the goal. [coverage] = monthly spare after trims ÷ the
  /// monthly amount the goal needs. Returns a 0-100 score, an emoji and a
  /// plain-language label + hint a normal user instantly understands.
  static ({int score, String emoji, String label, String hint}) goalMood({
    required double coverage,
  }) {
    assert(coverage >= 0, 'coverage must not be negative');
    if (coverage >= 1.2) {
      return (
        score: 100,
        emoji: '😄',
        label: 'On track — with room to spare',
        hint: 'Even with these budgets you still have spare cash each month. Nice!',
      );
    }
    if (coverage >= 1.0) {
      return (
        score: 85,
        emoji: '🙂',
        label: 'On track',
        hint: 'These budgets get you to the goal right on time.',
      );
    }
    if (coverage >= 0.8) {
      return (
        score: 60,
        emoji: '😐',
        label: 'A little tight',
        hint: 'Almost there — trim one more category or add a few months to the deadline.',
      );
    }
    if (coverage >= 0.5) {
      return (
        score: 35,
        emoji: '😕',
        label: 'Hard to reach',
        hint: 'This saves too little for the goal — try the 🎯 Goal-first template.',
      );
    }
    return (
      score: 10,
      emoji: '😟',
      label: 'Off track',
      hint: 'These budgets won\'t get you there — trim more, or move the deadline out.',
    );
  }

  /// Builds the structured user prompt with everything the model needs.
  Future<String> _buildPromptContext({
    required String goalDescription,
    required double targetAmount,
    required int? targetMonths,
    required DateTime now,
  }) async {
    final fin = _gatherFinances();
    final txs = FinanceService.instance.activeTransactions;
    final budgets = FinanceService.instance.activeBudgets;
    final envelopes = FinanceService.instance.activeEnvelopes;
    final recurring = FinanceService.instance.activeRecurring;
    final docs = await DocumentScannerService.instance.getAllItems();

    final sb = StringBuffer();

    // ── The goal ──
    sb.writeln('USER GOAL:');
    sb.writeln('- Goal: $goalDescription');
    sb.writeln('- Target amount: AED ${_fmt(targetAmount)}');
    sb.writeln(
        '- Target deadline: ${targetMonths != null ? '$targetMonths months' : 'no fixed deadline'}');
    sb.writeln();

    // ── Income & spending ──
    sb.writeln('FINANCIAL SNAPSHOT (3-month average):');
    sb.writeln('- Average monthly income: AED ${_fmt(fin.income)}');
    sb.writeln('- Average monthly expenses: AED ${_fmt(fin.expense)}');
    sb.writeln('- Average monthly spare (income - expenses): AED ${_fmt(fin.monthlySpare)}');

    // Category breakdown, biggest first. The 90-day sum is normalised to a
    // monthly pace so it compares directly against budget limits.
    final byCategory = <FinanceCategory, double>{};
    for (final t in txs) {
      if (t.kind != FinanceKind.expense) continue;
      final d = t.occurredAt;
      final isRecent = d.isAfter(now.subtract(const Duration(days: 90)));
      if (!isRecent) continue;
      byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
    }
    final ranked = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.isNotEmpty) {
      sb.writeln(
          '- Spending habit by category (last 90 days, shown as approx per month):');
      for (final e in ranked.take(8)) {
        sb.writeln('  * ${e.key.displayName}: ~AED ${_fmt(e.value / 3)}/month '
            '(total AED ${_fmt(e.value)} over 90 days)');
      }
    }

    // ── Budgets ──
    if (budgets.isNotEmpty) {
      sb.writeln('- Category budgets (monthly limits):');
      for (final b in budgets.take(6)) {
        sb.writeln(
            '  * ${b.category.displayName}: AED ${_fmt(b.monthlyLimit)}/month');
      }
    }

    // ── Envelopes ──
    if (envelopes.isNotEmpty) {
      sb.writeln('- Existing savings envelopes:');
      for (final e in envelopes.take(6)) {
        sb.writeln('  * ${e.name}: saved ${_fmt(e.savedAmount)} of '
            '${_fmt(e.targetAmount)}, contributing '
            '${_fmt(e.monthlyContribution)}/month');
      }
    }

    // ── Recurring commitments (all cadences, normalised to monthly) ──
    if (recurring.isNotEmpty) {
      sb.writeln('- Recurring commitments (normalised to monthly equivalent):');
      for (final r in recurring.take(8)) {
        final perMonth = r.amount / r.frequency.approxDaysPerCycle * 30.44;
        sb.writeln('  * ${r.title} (${r.kind.name}): AED ${_fmt(r.amount)} '
            '${r.frequency.label.toLowerCase()}, ~AED ${_fmt(perMonth)}/month');
      }
    }

    // ── Upcoming document renewals: named and dated, so the plan can ──
    // ── reserve cash in the months a big fee actually lands.        ──
    final renewal90 = FinanceMath.renewalOutlook(docs, 90);
    if (renewal90 > 0) {
      sb.writeln('- Upcoming document renewal fees (next 90 days, total AED ${_fmt(renewal90)}):');
      final cutoff = now.add(const Duration(days: 90));
      final upcoming = docs
          .where((d) =>
              d.isActive &&
              d.renewalFee != null &&
              d.renewalFee! > 0 &&
              !d.expiresAt.isBefore(now) &&
              !d.expiresAt.isAfter(cutoff))
          .toList()
        ..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
      for (final d in upcoming.take(6)) {
        final daysLeft = d.expiresAt.difference(now).inDays;
        sb.writeln('  * ${d.displayName}: AED ${_fmt(d.renewalFee!)} '
            'in ~$daysLeft days');
      }
    }

    // ── Recent bill spikes: habits currently inflated above their own ──
    // ── average — prime candidates for the plan to trim.             ──
    final spikes = AnomalyDetectionService.instance
        .detectRecentAnomalies(txs, recentDays: 30);
    for (final a in spikes.take(3)) {
      sb.writeln('- Recent bill spike: ${a.transaction.title} '
          '(${a.transaction.category.displayName}) AED ${_fmt(a.transaction.amount)} '
          'is ${a.percentIncrease.toStringAsFixed(0)}% above the usual '
          'AED ${_fmt(a.historicalAverage)} — worth reviewing.');
    }

    sb.writeln();
    sb.writeln('Use the monthly-normalised figures above. Account for upcoming '
        'renewal fees when setting monthly savings so the plan stays cash-safe.');

    return sb.toString();
  }

  // ------------------------------------------------------------------
  // Parsing & fallback
  // ------------------------------------------------------------------

  /// Parses the model's JSON response, tolerating ```json fences.
  @visibleForTesting
  static AiBudgetPlan? parsePlanResponse(String raw) => _parsePlan(raw);

  static AiBudgetPlan? _parsePlan(String raw) {
    if (raw.trim().isEmpty) return null;

    var text = raw.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```', multiLine: true);
    final match = fence.firstMatch(text);
    if (match != null) text = match.group(1)!.trim();

    // Fall back to the outermost {...} block.
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) text = text.substring(start, end + 1);

    try {
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic>) return null;

      final title = (json['title'] as String?)?.trim();
      final summary = (json['summary'] as String?)?.trim();
      if (title == null || title.isEmpty) return null;
      if (summary == null || summary.isEmpty) return null;

      final actionsJson = json['actions'];
      final actions = <AiBudgetPlanAction>[];
      if (actionsJson is List) {
        for (final a in actionsJson) {
          if (a is! Map<String, dynamic>) continue;
          final aTitle = (a['title'] as String?)?.trim();
          final aDetail = (a['detail'] as String?)?.trim();
          if (aTitle == null || aTitle.isEmpty) continue;
          final suggestedEnvelope =
              (a['suggestedEnvelopeName'] as String?)?.trim();
          final hasEnvelope =
              suggestedEnvelope != null && suggestedEnvelope.isNotEmpty;
          final rawType = (a['type'] as String?)?.trim().toLowerCase();
          final type = switch (rawType) {
            'envelope' => AiBudgetPlanActionType.envelope,
            'budget' => AiBudgetPlanActionType.budget,
            'tip' => AiBudgetPlanActionType.tip,
            _ => hasEnvelope
                ? AiBudgetPlanActionType.envelope
                : AiBudgetPlanActionType.tip,
          };
          actions.add(AiBudgetPlanAction(
            type: type,
            title: aTitle,
            detail: aDetail == null || aDetail.isEmpty ? aTitle : aDetail,
            category: a['categoryName'] is String
                ? FinanceCategoryX.fromName(a['categoryName'] as String)
                : null,
            monthlyAmountAed: (a['monthlyAmount'] as num?)?.toDouble(),
            suggestedEnvelopeName: hasEnvelope ? suggestedEnvelope : null,
          ));
        }
      }

      return AiBudgetPlan(
        title: title,
        summary: summary,
        feasible: json['feasible'] is bool ? json['feasible'] as bool : true,
        monthsToGoal: (json['monthsToGoal'] as num?)?.toInt(),
        monthlySavingTargetAed:
            (json['monthlySavingTarget'] as num?)?.toDouble() ?? 0,
        actions: actions,
      );
    } catch (_) {
      return null;
    }
  }

  /// Deterministic rule-based plan used when Groq is unavailable, the quota
  /// is exhausted, or the response can't be parsed. Mirrors the AI Summary's
  /// offline template fallback.
  static AiBudgetPlan _buildFallbackPlan({
    required String goalDescription,
    required double targetAmount,
    required int? targetMonths,
    required double monthlySpare,
    required DateTime now,
  }) {
    final goalLabel = goalDescription.trim().isEmpty
        ? 'your goal'
        : goalDescription.trim();

    // At the current spare, how long would the goal take?
    final monthsAtPace = monthlySpare > 0
        ? (targetAmount / monthlySpare).ceil()
        : null;
    final feasible = monthlySpare > 0 &&
        (targetMonths == null || monthsAtPace! <= targetMonths);

    final summaryBuf = StringBuffer();
    if (monthlySpare > 0) {
      summaryBuf
          .write('With about AED ${_fmt(monthlySpare)} spare each month, ');
      if (targetMonths != null) {
        summaryBuf.write(
            'you need to set aside AED ${_fmt(targetAmount / targetMonths)} per month to reach $goalLabel in $targetMonths months. ');
      } else if (monthsAtPace != null) {
        summaryBuf.write(
            'you could reach $goalLabel in about $monthsAtPace months by saving AED ${_fmt(monthlySpare)} per month. ');
      }
      summaryBuf.write(feasible
          ? 'Your goal looks achievable at the current pace.'
          : 'At the current pace the deadline is tight — consider trimming discretionary spending.');
    } else {
      summaryBuf.write(
          'There is little monthly spare cash right now, so reaching $goalLabel needs new savings room — review discretionary categories or add income.');
    }

    final actions = <AiBudgetPlanAction>[
      AiBudgetPlanAction(
        type: AiBudgetPlanActionType.envelope,
        title: 'Save AED ${(targetMonths != null ? targetAmount / targetMonths : monthlySpare).toStringAsFixed(0)} per month',
        detail: 'Set up a dedicated envelope for "$goalLabel" and contribute '
            'the same amount every month — small and steady wins.',
        suggestedEnvelopeName: goalLabel.length <= 24
            ? goalLabel
            : '${goalLabel.substring(0, 24)}…',
      ),
      AiBudgetPlanAction(
        type: AiBudgetPlanActionType.tip,
        title: 'Cap your biggest spending category',
        detail: 'Open Money → Budgets and set a monthly cap on the category '
            'you spend the most on — about 10-15% below last month. Use the '
            'budget sliders below to try it out.',
      ),
    ];

    return AiBudgetPlan(
      title: 'Plan: $goalLabel',
      summary: summaryBuf.toString().trim(),
      feasible: feasible,
      monthsToGoal: targetMonths ?? monthsAtPace,
      monthlySavingTargetAed: targetMonths != null
          ? targetAmount / targetMonths
          : monthlySpare,
      actions: actions,
    );
  }

  static String _fmt(double v) {
    final rounded = (v * 100).round() / 100;
    if (rounded == rounded.roundToDouble()) {
      return rounded.round().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    }
    return rounded.toStringAsFixed(2);
  }
}
