import 'package:flutter/material.dart';

import '../models/subscription_tier.dart';
import '../services/ai_executive_summary_service.dart';
import '../services/entitlement_service.dart';
import '../services/groq_api_service.dart';
import '../services/monthly_summary_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/upgrade_dialog.dart';

/// Standalone AI Executive Summary page opened from the Home categories grid.
///
/// Merges document details (expiries, renewal costs) and financial payments
/// into a Groq AI executive summary with strict monthly tier limits.
class AiSummaryScreen extends StatefulWidget {
  const AiSummaryScreen({super.key});

  @override
  State<AiSummaryScreen> createState() => _AiSummaryScreenState();
}

class _AiSummaryScreenState extends State<AiSummaryScreen> {
  bool _loading = true;
  bool _regenerating = false;
  String _narrative = '';
  List<AiSummaryCombinedInsight> _insights = const [];
  bool _usedGroq = false;
  bool _quotaExceeded = false;
  int _usedQuota = 0;
  int _quotaLimit = 3;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary({bool forceRegenerate = false}) async {
    final service = AiExecutiveSummaryService.instance;

    if (forceRegenerate) {
      final remaining = await service.getRemainingQuotaThisMonth();
      if (remaining <= 0) {
        if (!mounted) return;
        final upgrade = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: FinavigColors.warning),
                SizedBox(width: 8),
                Text('Monthly Quota Reached'),
              ],
            ),
            content: Text(
              'You have used all $_usedQuota / $_quotaLimit monthly AI Executive Summaries for your plan.\n\nUpgrade your plan to unlock higher monthly AI quota limit.',
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: const Text('Upgrade Plan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FinavigColors.caution,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        );
        if (upgrade == true && mounted) {
          await showUpgradeDialog(context, EntitlementFeature.groqAiSummary);
        }
        return;
      }

      final confirmed = await _confirmQuotaUsage(remaining);
      if (!confirmed) return;

      setState(() => _regenerating = true);
    } else {
      setState(() => _loading = true);
    }

    final result = await service.generateSummary(forceRegenerate: forceRegenerate);
    final used = await service.getUsedQuotaThisMonth();
    final limit = service.getMonthlyQuotaLimit();

    if (!mounted) return;

    setState(() {
      _narrative = result.narrative;
      _insights = result.insights;
      _usedGroq = result.usedGroq;
      _quotaExceeded = result.quotaExceeded;
      _usedQuota = used;
      _quotaLimit = limit;
      _loading = false;
      _regenerating = false;
    });

    if (forceRegenerate && result.quotaExceeded) {
      await showUpgradeDialog(context, EntitlementFeature.groqAiSummary);
    }
  }

  Future<bool> _confirmQuotaUsage(int remaining) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: FinavigColors.cyanSecondary),
            SizedBox(width: 8),
            Text('Confirm AI Quota Usage'),
          ],
        ),
        content: Text(
          'Generating a fresh AI summary will use 1 credit from your monthly quota ($remaining credit${remaining == 1 ? '' : 's'} remaining this month).\n\nDo you want to proceed?',
          style: const TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.bolt_rounded, size: 16),
            label: const Text('Confirm & Use 1 Credit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FinavigColors.navyPrimary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _showKeySettingsDialog() async {
    final controller = TextEditingController(
      text: GroqApiService.instance.apiKey,
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: FinavigColors.violetAccent),
            SizedBox(width: 8),
            Text('Groq API Settings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Finavig includes an in-app Groq API key by default. You can optional enter a custom key below.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Groq API Key',
                hintText: 'gsk_...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await GroqApiService.instance.clearCustomApiKey();
              if (ctx.mounted) Navigator.pop(ctx);
              _loadSummary(forceRegenerate: true);
            },
            child: const Text('Reset Default'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newKey = controller.text.trim();
              if (newKey.isNotEmpty) {
                await GroqApiService.instance.setCustomApiKey(newKey);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _loadSummary(forceRegenerate: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FinavigColors.navyPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Key'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentTier = EntitlementService.instance.tier;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Executive Summary'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Aggregating documents & payment records...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quota & Header Banner Card
                  _buildQuotaHeaderCard(theme, isDark, currentTier),
                  const SizedBox(height: 16),

                  // Executive Narrative Card
                  _buildNarrativeCard(theme, isDark),
                  const SizedBox(height: 20),

                  // Section Title: Actionable Insights
                  Text(
                    'Executive Insights & Alerts',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_insights.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No document or payment activity to display.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._insights.map((insight) => _buildInsightTile(theme, isDark, insight)),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildQuotaHeaderCard(
    ThemeData theme,
    bool isDark,
    SubscriptionTier tier,
  ) {
    final usedPct = (_usedQuota / _quotaLimit).clamp(0.0, 1.0);
    final tierName = tier.name[0].toUpperCase() + tier.name.substring(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFF0B1020), const Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: FinavigColors.violetAccent.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: FinavigColors.violetAccent,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Groq AI Engine',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: FinavigColors.violetAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$tierName Plan',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly AI Quota',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$_usedQuota / $_quotaLimit summaries used',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: usedPct,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                usedPct >= 1.0 ? FinavigColors.danger : FinavigColors.emerald,
              ),
            ),
          ),
          if (_usedQuota >= _quotaLimit) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => showUpgradeDialog(context, EntitlementFeature.groqAiSummary),
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: const Text('Upgrade Plan for More AI Summaries'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FinavigColors.caution,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNarrativeCard(ThemeData theme, bool isDark) {
    final lastAt = AiExecutiveSummaryService.instance.lastGeneratedAt;
    final timeStr = lastAt != null
        ? '${lastAt.day}/${lastAt.month}/${lastAt.year} ${lastAt.hour.toString().padLeft(2, '0')}:${lastAt.minute.toString().padLeft(2, '0')}'
        : null;

    if (_narrative.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FinavigColors.cyanSecondary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 28,
                  color: FinavigColors.cyanSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No Previous Summary Found',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Generate your first executive summary combining document compliance and financial records.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _regenerating
                      ? null
                      : () => _loadSummary(forceRegenerate: true),
                  icon: _regenerating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text('Generate AI Executive Summary (1 Credit)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FinavigColors.navyPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.psychology_rounded,
                  color: FinavigColors.navyPrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previous AI Executive Summary',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (timeStr != null)
                      Text(
                        'Last generated: $timeStr',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                if (_usedGroq)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: FinavigColors.emerald.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Groq AI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: FinavigColors.emerald,
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            Text(
              _narrative,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
                fontSize: 14,
              ),
            ),
            if (_quotaExceeded) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: FinavigColors.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Monthly Groq AI quota reached. Showing offline template fallback.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: FinavigColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _regenerating
                    ? null
                    : () => _loadSummary(forceRegenerate: true),
                icon: _regenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Generate Fresh AI Summary (Uses 1 Credit)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FinavigColors.navyPrimary,
                  side: BorderSide(color: FinavigColors.navyPrimary.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightTile(
    ThemeData theme,
    bool isDark,
    AiSummaryCombinedInsight insight,
  ) {
    final icon = switch (insight.kind) {
      MonthlyInsightKind.spendingMove => Icons.trending_up_rounded,
      MonthlyInsightKind.budgetAlert => Icons.warning_amber_rounded,
      MonthlyInsightKind.savings => Icons.savings_rounded,
      MonthlyInsightKind.positive => Icons.check_circle_rounded,
    };

    final color = switch (insight.kind) {
      MonthlyInsightKind.spendingMove => FinavigColors.danger,
      MonthlyInsightKind.budgetAlert => FinavigColors.warning,
      MonthlyInsightKind.savings => FinavigColors.emerald,
      MonthlyInsightKind.positive => FinavigColors.emerald,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      insight.categoryLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (insight.metricLabel != null)
                      Text(
                        insight.metricLabel!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  insight.sentence,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
