import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_type.dart';
import '../models/expiry_item.dart';
import '../models/finance.dart';
import '../models/subscription_tier.dart';

import 'collection_service.dart';
import 'auth_service.dart';
import 'document_scanner_service.dart';
import 'entitlement_service.dart';
import 'finance_service.dart';
import 'groq_api_service.dart';
import 'monthly_summary_service.dart';
import 'supabase_service.dart';

/// One insight item on the AI Executive Summary page combining documents + finances.
class AiSummaryCombinedInsight {
  final MonthlyInsightKind kind;
  final String categoryLabel;
  final String sentence;
  final String? metricLabel;

  const AiSummaryCombinedInsight({
    required this.kind,
    required this.categoryLabel,
    required this.sentence,
    this.metricLabel,
  });
}

/// Orchestrates the unified Groq AI Executive Summary combining user document
/// details and payment/financial records, with monthly tier quota tracking.
class AiExecutiveSummaryService {
  AiExecutiveSummaryService._();

  static final AiExecutiveSummaryService instance =
      AiExecutiveSummaryService._();

  static const String _usagePrefix = 'groqAiSummary.usage';

  String? _lastNarrative;
  List<AiSummaryCombinedInsight> _lastInsights = const [];
  bool _lastUsedGroq = false;
  DateTime? _lastGeneratedAt;

  String? get lastNarrative => _lastNarrative;
  List<AiSummaryCombinedInsight> get lastInsights => _lastInsights;
  bool get lastUsedGroq => _lastUsedGroq;
  DateTime? get lastGeneratedAt => _lastGeneratedAt;

  /// Injectable override for unit tests.
  @visibleForTesting
  Future<String> Function(String system, String user)? groqCallOverride;

  String _monthString([DateTime? now]) {
    final ref = now ?? DateTime.now();
    return '${ref.year}-${ref.month.toString().padLeft(2, '0')}';
  }

  /// Current month usage key scoped to the individual signed-in user,
  /// e.g. `groqAiSummary.usage.<userId>.2026-09`.
  String _currentMonthKey([DateTime? now]) {
    final ref = now ?? DateTime.now();
    final userId = AuthService.instance.currentUserId ?? 'local-user';
    return '$_usagePrefix.$userId.${_monthString(ref)}';
  }

  /// Get number of Groq AI summaries generated this calendar month.
  Future<int> getUsedQuotaThisMonth([DateTime? now]) async {
    final ref = now ?? DateTime.now();
    final monthStr = _monthString(ref);
    final userId = AuthService.instance.currentUserId;

    // 1. Attempt Supabase fetch if client is available & user signed in
    final client = SupabaseService.clientOrNull;
    if (client != null && userId != null && userId.isNotEmpty) {
      try {
        final row = await client
            .from('ai_quota_usage')
            .select('used_count')
            .eq('user_id', userId)
            .eq('feature_name', 'groq_ai_summary')
            .eq('usage_month', monthStr)
            .maybeSingle();

        if (row != null && row['used_count'] != null) {
          final count = (row['used_count'] as num).toInt();
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt(_currentMonthKey(ref), count);
          } catch (_) {}
          return count;
        }
      } catch (e) {
        debugPrint('Supabase getUsedQuotaThisMonth (AI summary) failed: $e');
      }
    }

    // 2. Local SharedPreferences fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_currentMonthKey(ref)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Maximum allowed Groq AI summaries for the current subscription tier.
  int getMonthlyQuotaLimit() {
    return EntitlementService.instance.limits.groqAiSummaryMonthlyQuota;
  }

  /// Remaining Groq AI summaries for this calendar month.
  Future<int> getRemainingQuotaThisMonth([DateTime? now]) async {
    final used = await getUsedQuotaThisMonth(now);
    final limit = getMonthlyQuotaLimit();
    final remaining = limit - used;
    return remaining < 0 ? 0 : remaining;
  }

  /// Check whether the user can generate a Groq AI summary under their plan limit.
  Future<bool> canGenerateAiSummary([DateTime? now]) async {
    final remaining = await getRemainingQuotaThisMonth(now);
    return remaining > 0;
  }

  /// Increment monthly usage counter after a successful Groq API generation.
  Future<int> _incrementUsageCounter([DateTime? now]) async {
    final ref = now ?? DateTime.now();
    final monthStr = _monthString(ref);
    final userId = AuthService.instance.currentUserId;

    // Increment locally
    final prefs = await SharedPreferences.getInstance();
    final key = _currentMonthKey(ref);
    final current = prefs.getInt(key) ?? 0;
    final updated = current + 1;
    await prefs.setInt(key, updated);

    // Sync to Supabase database
    final client = SupabaseService.clientOrNull;
    if (client != null && userId != null && userId.isNotEmpty) {
      try {
        await client.from('ai_quota_usage').upsert({
          'user_id': userId,
          'feature_name': 'groq_ai_summary',
          'usage_month': monthStr,
          'used_count': updated,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,feature_name,usage_month');
      } catch (e) {
        debugPrint('Supabase _incrementUsageCounter sync failed: $e');
      }
    }

    return updated;
  }

  /// Reset usage counter (useful for unit tests or tier updates).
  @visibleForTesting
  Future<void> resetUsageCounter([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentMonthKey(now));
    await clearAllQuotaUsage();
  }

  /// Reset current month usage counter to 0 (called when tier changes).
  Future<void> resetCurrentMonthUsage([DateTime? now]) async {
    final ref = now ?? DateTime.now();
    final monthStr = _monthString(ref);
    final userId = AuthService.instance.currentUserId;

    final client = SupabaseService.clientOrNull;
    if (client != null && userId != null && userId.isNotEmpty) {
      try {
        await client.from('ai_quota_usage').upsert({
          'user_id': userId,
          'feature_name': 'groq_ai_summary',
          'usage_month': monthStr,
          'used_count': 0,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,feature_name,usage_month');
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentMonthKey(ref));
    } catch (_) {}
  }

  /// Clear all Groq AI summary quota usage counters for all users from SharedPreferences and Supabase.
  Future<void> clearAllQuotaUsage() async {
    _lastNarrative = null;
    _lastInsights = const [];
    _lastUsedGroq = false;
    _lastGeneratedAt = null;

    final userId = AuthService.instance.currentUserId;
    final client = SupabaseService.clientOrNull;
    if (client != null && userId != null && userId.isNotEmpty) {
      try {
        await client
            .from('ai_quota_usage')
            .delete()
            .eq('user_id', userId)
            .eq('feature_name', 'groq_ai_summary');
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_usagePrefix) || k.contains('groqAiSummary')).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  String _cachedNarrativeKey() {
    final userId = AuthService.instance.currentUserId ?? 'local-user';
    return 'groqAiSummary.lastNarrative.$userId';
  }

  String _cachedTimestampKey() {
    final userId = AuthService.instance.currentUserId ?? 'local-user';
    return 'groqAiSummary.lastGeneratedAt.$userId';
  }

  /// Generates the combined AI Executive Summary.
  ///
  /// Aggregates active document details (expiries, pending actions) and
  /// financial payment details (income, expenses, budgets).
  ///
  /// If [forceRegenerate] is true, checks plan quota before calling Groq API.
  Future<({String narrative, List<AiSummaryCombinedInsight> insights, bool usedGroq, bool quotaExceeded})>
      generateSummary({
    bool forceRegenerate = false,
    DateTime? now,
  }) async {
    final ref = now ?? DateTime.now();
    final docItems = await DocumentScannerService.instance.getAllItems();
    final finData = MonthlySummaryService.instance.generate(now: ref);

    final insights = _buildCombinedInsights(docItems, finData);

    // If cached narrative exists and forceRegenerate is false, return cached.
    if (!forceRegenerate) {
      if (_lastNarrative != null) {
        return (
          narrative: _lastNarrative!,
          insights: _lastInsights,
          usedGroq: _lastUsedGroq,
          quotaExceeded: false,
        );
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        final stored = prefs.getString(_cachedNarrativeKey());
        final timeStr = prefs.getString(_cachedTimestampKey());
        if (stored != null && stored.trim().isNotEmpty) {
          _lastNarrative = stored.trim();
          _lastInsights = insights;
          _lastUsedGroq = true;
          if (timeStr != null) {
            _lastGeneratedAt = DateTime.tryParse(timeStr);
          }
          return (
            narrative: _lastNarrative!,
            insights: _lastInsights,
            usedGroq: true,
            quotaExceeded: false,
          );
        }
      } catch (_) {}

      // No cached narrative stored yet and forceRegenerate is false.
      return (
        narrative: '',
        insights: insights,
        usedGroq: false,
        quotaExceeded: false,
      );
    }

    // Check plan limits before making a new Groq AI call.
    final remaining = await getRemainingQuotaThisMonth(ref);
    if (remaining <= 0) {
      final templateText = _buildFallbackNarrative(docItems, finData);
      _lastNarrative = templateText;
      _lastInsights = insights;
      _lastUsedGroq = false;
      _lastGeneratedAt = DateTime.now();
      return (
        narrative: templateText,
        insights: insights,
        usedGroq: false,
        quotaExceeded: true,
      );
    }

    // Prepare Groq API system & user prompts.
    final systemPrompt =
        'You are Finavig\'s AI Financial & Document Executive Advisor for GCC businesses. '
        'Provide a concise 2-3 sentence executive summary combining document compliance/expiries and financial payments. '
        'Use only the factual metrics provided. Keep tone professional, encouraging, and clear. Money values in local GCC currency.';

    final userPrompt = _buildPromptContext(docItems, finData, ref);

    try {
      final text = groqCallOverride != null
          ? await groqCallOverride!(systemPrompt, userPrompt)
          : await GroqApiService.instance.generateSummary(
              systemPrompt: systemPrompt,
              userPrompt: userPrompt,
            );

      if (text.trim().isNotEmpty) {
        await _incrementUsageCounter(ref);
        _lastNarrative = text.trim();
        _lastInsights = insights;
        _lastUsedGroq = true;
        _lastGeneratedAt = DateTime.now();

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cachedNarrativeKey(), _lastNarrative!);
          if (_lastGeneratedAt != null) {
            await prefs.setString(_cachedTimestampKey(), _lastGeneratedAt!.toIso8601String());
          }
        } catch (_) {}

        return (
          narrative: text.trim(),
          insights: insights,
          usedGroq: true,
          quotaExceeded: false,
        );
      }
    } catch (e) {
      debugPrint('Groq AI Summary generation failed (using fallback): $e');
    }

    // Fallback template narrative if Groq API fails or returned empty text.
    final fallbackText = _buildFallbackNarrative(docItems, finData);
    _lastNarrative = fallbackText;
    _lastInsights = insights;
    _lastUsedGroq = false;
    _lastGeneratedAt = DateTime.now();

    return (
      narrative: fallbackText,
      insights: insights,
      usedGroq: false,
      quotaExceeded: false,
    );
  }

  /// Builds structured prompt context for Groq API.
  String _buildPromptContext(
    List<ExpiryItem> docs,
    MonthlySummaryData fin,
    DateTime ref,
  ) {
    final expiredCount = docs.where((d) => d.isExpired).length;
    final urgentCount = docs.where((d) => d.daysRemaining >= 0 && d.daysRemaining <= 30).length;
    final totalRenewalFees = docs
        .where((d) => d.daysRemaining <= 90)
        .fold<double>(0.0, (sum, d) => sum + (d.renewalFee ?? 0));

    final sb = StringBuffer()
      ..writeln('DOCUMENT COMPLIANCE SUMMARY:')
      ..writeln('- Total tracked documents: ${docs.length}')
      ..writeln('- Expired documents: $expiredCount')
      ..writeln('- Documents expiring within 30 days: $urgentCount')
      ..writeln('- Total estimated renewal fees due (next 90 days): ${_cur()} ${_fmt(totalRenewalFees)}');

    if (urgentCount > 0) {
      final names = docs
          .where((d) => d.daysRemaining >= 0 && d.daysRemaining <= 30)
          .map((d) => '${d.displayName} (${d.daysRemaining} days remaining)')
          .take(3)
          .join(', ');
      sb.writeln('- Urgent documents: $names');
    }

    sb.writeln();
    sb.writeln('FINANCIAL & PAYMENT SUMMARY (${fin.monthName} ${fin.year}):');
    sb.writeln('- Income: ${_cur()} ${_fmt(fin.income)}');
    sb.writeln('- Expenses: ${_cur()} ${_fmt(fin.expense)}');
    sb.writeln('- Net Position: ${_cur()} ${_fmt(fin.net)}');

    if (fin.expenseChangePct != null) {
      sb.writeln('- Expense change vs last month: ${fin.expenseChangePct!.toStringAsFixed(1)}%');
    }

    for (final move in fin.topMoves.take(2)) {
      sb.writeln('- Category move: ${move.category.displayName} ${_cur()} ${_fmt(move.current)} (prev ${_fmt(move.previous)})');
    }

    for (final o in fin.budgetOverruns.take(2)) {
      sb.writeln('- Budget overrun: ${o.budget.category.displayName} spent ${_cur()} ${_fmt(o.spent)} of ${_fmt(o.budget.monthlyLimit)}');
    }

    return sb.toString();
  }

  /// Builds list of actionable combined insights.
  List<AiSummaryCombinedInsight> _buildCombinedInsights(
    List<ExpiryItem> docs,
    MonthlySummaryData fin,
  ) {
    final list = <AiSummaryCombinedInsight>[];

    // Document alerts
    final expired = docs.where((d) => d.isExpired).toList();
    if (expired.isNotEmpty) {
      list.add(AiSummaryCombinedInsight(
        kind: MonthlyInsightKind.budgetAlert,
        categoryLabel: 'Documents',
        sentence: '${expired.length} document${expired.length == 1 ? '' : 's'} expired and require immediate renewal (${expired.first.displayName}).',
        metricLabel: '${expired.length} Expired',
      ));
    }

    final urgent = docs.where((d) => d.daysRemaining >= 0 && d.daysRemaining <= 30).toList();
    if (urgent.isNotEmpty) {
      list.add(AiSummaryCombinedInsight(
        kind: MonthlyInsightKind.spendingMove,
        categoryLabel: 'Renewals',
        sentence: '${urgent.length} document${urgent.length == 1 ? '' : 's'} expiring within 30 days (${urgent.first.displayName}).',
        metricLabel: '${urgent.length} Pending',
      ));
    }

    // Financial alerts
    if (fin.expenseChangePct != null) {
      final dir = fin.expenseChangePct! >= 0 ? 'rose' : 'dropped';
      final pct = fin.expenseChangePct!.abs().toStringAsFixed(0);
      list.add(AiSummaryCombinedInsight(
        kind: fin.expenseChangePct! >= 0 ? MonthlyInsightKind.spendingMove : MonthlyInsightKind.positive,
        categoryLabel: 'Monthly Spending',
        sentence: 'Overall spending $dir by $pct% in ${fin.monthName} vs last month.',
        metricLabel: '${_cur()} ${_fmt(fin.expense)}',
      ));
    }

    for (final o in fin.budgetOverruns.take(2)) {
      list.add(AiSummaryCombinedInsight(
        kind: MonthlyInsightKind.budgetAlert,
        categoryLabel: 'Budget Overrun',
        sentence: '${o.budget.category.displayName} budget exceeded (${_cur()} ${_fmt(o.spent)} spent of ${_fmt(o.budget.monthlyLimit)} limit).',
        metricLabel: '${_cur()} ${_fmt(o.spent - o.budget.monthlyLimit)} over',
      ));
    }

    list.add(AiSummaryCombinedInsight(
      kind: fin.net >= 0 ? MonthlyInsightKind.positive : MonthlyInsightKind.budgetAlert,
      categoryLabel: 'Net Position',
      sentence: fin.net >= 0
          ? 'Net financial balance is positive at ${_cur()} ${_fmt(fin.net)} this month.'
          : 'Expenses exceeded income by ${_cur()} ${_fmt(fin.expense - fin.income)} this month.',
      metricLabel: '${_cur()} ${_fmt(fin.net)}',
    ));

    return list;
  }

  /// Rule-based template fallback narrative.
  String _buildFallbackNarrative(List<ExpiryItem> docs, MonthlySummaryData fin) {
    final urgentCount = docs.where((d) => d.daysRemaining <= 30).length;
    final docSentence = urgentCount > 0
        ? '$urgentCount document${urgentCount == 1 ? '' : 's'} require renewal attention within 30 days.'
        : 'All tracked documents are up to date and in good standing.';

    final finSentence = fin.isEmpty
        ? 'No financial records entered for ${fin.monthName} yet.'
        : 'Total monthly spend is ${_cur()} ${_fmt(fin.expense)} against ${_cur()} ${_fmt(fin.income)} income, resulting in a net of ${_cur()} ${_fmt(fin.net)}.';

    return '$docSentence $finSentence';
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
