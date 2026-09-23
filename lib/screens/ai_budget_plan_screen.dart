import 'package:flutter/material.dart';

import '../models/finance.dart';
import '../models/subscription_tier.dart';
import '../services/ai_budget_plan_service.dart';
import '../services/entitlement_service.dart';
import '../services/finance_service.dart';
import '../services/groq_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/upgrade_dialog.dart';

/// AI Budget Planner page: the user states a goal (buy something, save an
/// amount, …), Groq builds a concrete plan from their real finance data,
/// and the monthly tier quota limits generations — same engine as the AI
/// Executive Summary.
class AiBudgetPlanScreen extends StatefulWidget {
  const AiBudgetPlanScreen({super.key});

  @override
  State<AiBudgetPlanScreen> createState() => _AiBudgetPlanScreenState();
}

class _AiBudgetPlanScreenState extends State<AiBudgetPlanScreen> {
  final _goalController = TextEditingController();
  final _amountController = TextEditingController();
  int? _targetMonths;
  bool _showMonths = false;

  bool _generating = false;
  AiBudgetPlan? _plan;
  bool _usedGroq = false;
  bool _quotaExceeded = false;
  int _usedQuota = 0;
  int _quotaLimit = 2;

  // Applied one-tap actions (index into the current plan's action list).
  final Set<int> _appliedActionIndexes = {};

  // Budget adjuster state: slider caps per category, active template id and
  // the categories whose budgets were already written to FinanceService.
  Map<FinanceCategory, double>? _adjustCaps;
  String? _activeTemplateId;
  final Set<String> _appliedBudgetCategories = {};

  @override
  void initState() {
    super.initState();
    _refreshQuota();
  }

  @override
  void dispose() {
    _goalController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _refreshQuota() async {
    final service = AiBudgetPlanService.instance;
    final used = await service.getUsedQuotaThisMonth();
    final limit = service.getMonthlyQuotaLimit();
    if (!mounted) return;
    setState(() {
      _usedQuota = used;
      _quotaLimit = limit;
    });
  }

  bool get _inputValid =>
      _goalController.text.trim().isNotEmpty &&
      (double.tryParse(_amountController.text.trim()) ?? 0) > 0;

  Future<void> _generate() async {
    if (!_inputValid || _generating) return;

    final goal = _goalController.text.trim();
    final amount = double.parse(_amountController.text.trim());

    setState(() => _generating = true);

    final result = await AiBudgetPlanService.instance.generatePlan(
      goalDescription: goal,
      targetAmount: amount,
      targetMonths: _showMonths ? _targetMonths : null,
      forceRegenerate: true,
    );

    final used = await AiBudgetPlanService.instance.getUsedQuotaThisMonth();

    if (!mounted) return;
    setState(() {
      _plan = result.plan;
      _usedGroq = result.usedGroq;
      _quotaExceeded = result.quotaExceeded;
      _usedQuota = used;
      _generating = false;
      _appliedActionIndexes.clear();
      _appliedBudgetCategories.clear();
      _activeTemplateId = null;
      _adjustCaps = null;
    });

    if (result.quotaExceeded) {
      await showUpgradeDialog(context, EntitlementFeature.aiBudgetPlanning);
    }
  }

  Future<void> _createEnvelopeFromAction(
    AiBudgetPlanAction action,
    int index,
  ) async {
    final name = action.suggestedEnvelopeName?.isNotEmpty == true
        ? action.suggestedEnvelopeName!
        : action.title;
    final monthly = action.monthlyAmountAed ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Create savings envelope'),
        content: Text(
          'Create an envelope "$name"'
          '${monthly > 0 ? ' with AED ${monthly.toStringAsFixed(0)}/month contributions' : ''}? '
          'You can adjust it anytime in the Envelopes tab.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: WazyColors.navyPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    await FinanceService.instance.addEnvelope(
      name,
      amount > 0 ? amount : monthly,
      monthly,
    );

    if (!mounted) return;
    setState(() => _appliedActionIndexes.add(index));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Envelope "$name" created — see the Envelopes tab.'),
        backgroundColor: WazyColors.emerald,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Applies a "budget" action: caps the action's category at the suggested
  /// monthly limit via FinanceService.
  Future<void> _applyBudgetFromAction(
    AiBudgetPlanAction action,
    int index,
  ) async {
    final category = action.category;
    final limit = action.monthlyAmountAed;
    if (category == null || limit == null || limit <= 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Set ${category.displayName} budget'),
        content: Text(
          'Cap ${category.displayName} at AED ${limit.toStringAsFixed(0)} '
          'per month? Wazy will track it in the Budgets tab and warn you '
          'when you get close.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: WazyColors.navyPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Set budget'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FinanceService.instance.upsertBudget(category, limit);
    if (!mounted) return;
    setState(() => _appliedActionIndexes.add(index));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${category.displayName} budget set to AED ${limit.toStringAsFixed(0)}/month.',
        ),
        backgroundColor: WazyColors.emerald,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  IconData _actionIcon(AiBudgetPlanAction action) {
    switch (action.type) {
      case AiBudgetPlanActionType.envelope:
        return Icons.savings_rounded;
      case AiBudgetPlanActionType.budget:
        return Icons.account_balance_wallet_rounded;
      case AiBudgetPlanActionType.tip:
        return action.category?.icon ?? Icons.tips_and_updates_rounded;
    }
  }

  Widget _actionAmountChip(ThemeData theme, AiBudgetPlanAction action) {
    final amt = action.monthlyAmountAed!;
    final (String label, Color color) = switch (action.type) {
      AiBudgetPlanActionType.envelope => (
        'AED ${amt.toStringAsFixed(0)}/mo',
        WazyColors.emerald,
      ),
      AiBudgetPlanActionType.budget => (
        'cap AED ${amt.toStringAsFixed(0)}/mo',
        WazyColors.navyPrimary,
      ),
      AiBudgetPlanActionType.tip => amt >= 0
          ? ('frees AED ${amt.toStringAsFixed(0)}/mo', WazyColors.emerald)
          : (
            'needs AED ${amt.abs().toStringAsFixed(0)}/mo',
            Colors.orangeAccent,
          ),
    };
    return Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  List<Widget> _actionButtons(
    ThemeData theme,
    AiBudgetPlanAction action,
    int index,
  ) {
    final applied = _appliedActionIndexes.contains(index);
    final List<({String label, IconData icon, VoidCallback? onTap})> defs;
    switch (action.type) {
      case AiBudgetPlanActionType.envelope:
        defs = [
          (
            label: applied
                ? 'Envelope created ✓'
                : 'Create "${action.suggestedEnvelopeName ?? 'envelope'}"',
            icon: applied
                ? Icons.check_circle_outline_rounded
                : Icons.add_circle_outline_rounded,
            onTap: applied ? null : () => _createEnvelopeFromAction(action, index),
          ),
        ];
      case AiBudgetPlanActionType.budget:
        final category = action.category;
        if (category == null || (action.monthlyAmountAed ?? 0) <= 0) return const [];
        defs = [
          (
            label: applied
                ? 'Budget set ✓'
                : 'Set ${category.displayName} budget to '
                    'AED ${action.monthlyAmountAed!.toStringAsFixed(0)}/mo',
            icon: applied
                ? Icons.check_circle_outline_rounded
                : Icons.tune_rounded,
            onTap: applied ? null : () => _applyBudgetFromAction(action, index),
          ),
        ];
      case AiBudgetPlanActionType.tip:
        return const [];
    }

    return [
      for (final d in defs) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: d.onTap,
            icon: Icon(d.icon, size: 16),
            label: Text(d.label),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  applied ? WazyColors.emerald : WazyColors.navyPrimary,
              side: BorderSide(
                color: (applied ? WazyColors.emerald : WazyColors.navyPrimary)
                    .withOpacity(0.4),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentTier = EntitlementService.instance.tier;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Budget Planner'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Groq API Settings',
            onPressed: _showKeySettingsDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuotaHeaderCard(theme, isDark, currentTier),
            const SizedBox(height: 16),
            _buildGoalForm(theme),
            const SizedBox(height: 20),
            if (_generating)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Analyzing your finances & building a plan...'),
                    ],
                  ),
                ),
              )
            else if (_plan != null) ...[
              _buildPlanCard(theme, isDark),
              const SizedBox(height: 20),
              Text(
                'Recommended Actions',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              for (final entry in _plan!.actions.asMap().entries)
                _buildActionTile(theme, isDark, entry.value, entry.key),
              const SizedBox(height: 28),
              _buildBudgetAdjuster(theme, isDark),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Quota header — mirrors the AI Summary quota banner
  // ------------------------------------------------------------------

  Widget _buildQuotaHeaderCard(
    ThemeData theme,
    bool isDark,
    SubscriptionTier tier,
  ) {
    final usedPct = _quotaLimit <= 0 ? 1.0 : (_usedQuota / _quotaLimit).clamp(0.0, 1.0);
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
                  color: WazyColors.violetAccent.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: WazyColors.violetAccent,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Groq AI Engine',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: WazyColors.violetAccent,
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
                'Monthly AI Planning Quota',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$_usedQuota / $_quotaLimit plans used',
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
                usedPct >= 1.0 ? WazyColors.danger : WazyColors.emerald,
              ),
            ),
          ),
          if (_usedQuota >= _quotaLimit) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    showUpgradeDialog(context, EntitlementFeature.aiBudgetPlanning),
                icon: const Icon(Icons.bolt_rounded, size: 16),
                label: const Text('Upgrade Plan for More AI Plans'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WazyColors.caution,
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

  // ------------------------------------------------------------------
  // Goal form
  // ------------------------------------------------------------------

  Widget _buildGoalForm(ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.flag_rounded,
                  color: WazyColors.navyPrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'What are you planning for?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _goalController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Your goal',
                hintText: 'e.g. Buy a MacBook Pro, save for Hajj trip...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Target amount (AED)',
                hintText: 'e.g. 10000',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('I have a deadline'),
              subtitle: Text(
                _showMonths && _targetMonths != null
                    ? 'Reach the goal in $_targetMonths month${_targetMonths == 1 ? '' : 's'}'
                    : 'Optionally set a target timeframe',
                style: theme.textTheme.bodySmall,
              ),
              value: _showMonths,
              onChanged: (v) => setState(() {
                _showMonths = v;
                _targetMonths ??= 6;
              }),
            ),
            if (_showMonths)
              Wrap(
                spacing: 8,
                children: [
                  for (final m in const [3, 6, 12, 18, 24])
                    ChoiceChip(
                      label: Text('$m mo'),
                      selected: _targetMonths == m,
                      onSelected: (_) => setState(() => _targetMonths = m),
                      selectedColor: WazyColors.navyPrimary.withAlpha(46),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _targetMonths == m
                            ? WazyColors.navyPrimary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      side: BorderSide(
                        color: _targetMonths == m
                            ? WazyColors.navyPrimary
                            : theme.colorScheme.outlineVariant,
                      ),
                      showCheckmark: false,
                    ),
                ],
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_inputValid &&
                        _usedQuota < _quotaLimit &&
                        !_generating)
                    ? _generate
                    : null,
                icon: _generating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  _usedQuota >= _quotaLimit
                      ? 'Monthly AI quota reached'
                      : 'Generate AI Plan',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: WazyColors.navyPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      theme.colorScheme.outlineVariant.withOpacity(0.4),
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

  // ------------------------------------------------------------------
  // Plan result
  // ------------------------------------------------------------------

  Widget _buildPlanCard(ThemeData theme, bool isDark) {
    final plan = _plan!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF14261E), const Color(0xFF0F1A16)]
              : [const Color(0xFF0E2A1E), const Color(0xFF14352A)],
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
              Icon(
                plan.feasible
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                color: plan.feasible ? WazyColors.emerald : WazyColors.caution,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (_usedGroq)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: WazyColors.emerald.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Groq AI',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: WazyColors.emerald,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            plan.summary,
            style: const TextStyle(
              color: Colors.white,
              height: 1.45,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _planChip(
                plan.feasible ? 'Achievable' : 'Challenging',
                plan.feasible ? WazyColors.emerald : WazyColors.caution,
              ),
              if (plan.monthlySavingTargetAed > 0)
                _planChip(
                  'Save AED ${plan.monthlySavingTargetAed.toStringAsFixed(0)}/mo',
                  WazyColors.cyanSecondary,
                ),
              if (plan.monthsToGoal != null)
                _planChip(
                  '~${plan.monthsToGoal} months',
                  WazyColors.violetAccent,
                ),
            ],
          ),
          if (_quotaExceeded) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: WazyColors.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Monthly Groq AI quota reached. Showing offline plan template.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: WazyColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _planChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionTile(
    ThemeData theme,
    bool isDark,
    AiBudgetPlanAction action,
    int index,
  ) {
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
              color: WazyColors.navyPrimary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _actionIcon(action),
              size: 18,
              color: WazyColors.navyPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        action.title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (action.monthlyAmountAed != null)
                      _actionAmountChip(theme, action),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  action.detail,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                ),
                ..._actionButtons(theme, action, index),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Budget adjuster — templates, sliders and the live goal-health meter
  // ------------------------------------------------------------------

  Widget _buildBudgetAdjuster(ThemeData theme, bool isDark) {
    final service = AiBudgetPlanService.instance;
    final spend = service.averageMonthlySpendByCategory();
    final categories = spend.entries
        .where((e) => e.value >= 20)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (categories.isEmpty) return const SizedBox.shrink();

    // Sliders start at the user's current spending pace.
    _adjustCaps ??= {for (final e in categories) e.key: e.value};
    final caps = _adjustCaps!;

    final templates = service.buildBudgetTemplates(
      monthlySavingTarget: _plan?.monthlySavingTargetAed ?? 0,
    );

    // ── Goal-health (happy index) math ──
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final months = _showMonths ? _targetMonths : null;
    final fin = service.financesSnapshot();
    final required = months != null && months > 0 && amount > 0
        ? amount / months
        : (_plan?.monthlySavingTargetAed ?? 0);
    var freed = 0.0;
    for (final e in caps.entries) {
      final avg = spend[e.key] ?? 0;
      if (e.value < avg) freed += avg - e.value;
    }
    final newSpare = fin.monthlySpare + freed;
    final coverage = required > 0 ? (newSpare / required).clamp(0.0, 2.0) : 1.0;
    final mood = AiBudgetPlanService.goalMood(coverage: coverage);
    final monthsToGoal =
        (newSpare > 0 && amount > 0) ? (amount / newSpare).ceil() : null;

    final Color moodColor;
    if (mood.score >= 80) {
      moodColor = WazyColors.emerald;
    } else if (mood.score >= 55) {
      moodColor = Colors.amber.shade700;
    } else {
      moodColor = Colors.redAccent;
    }

    // Categories trimmed below their current pace and not yet written.
    final changed = caps.entries
        .where((e) => (spend[e.key] ?? e.value) - e.value > 0.5)
        .toList();
    final allApplied = changed.isNotEmpty &&
        changed.every((e) => _appliedBudgetCategories.contains(e.key.name));

    final selectedTemplate = templates
        .where((t) => t.id == _activeTemplateId)
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded,
                  size: 18, color: WazyColors.navyPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Adjust budgets to reach your goal',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Drag the sliders or pick a template — the goal meter below '
            'updates instantly.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 14),

          // ── Goal-health (happy index) card ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: moodColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: moodColor.withOpacity(0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(mood.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mood.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: moodColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: mood.score / 100,
                    minHeight: 8,
                    backgroundColor: moodColor.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(moodColor),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  mood.hint,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _miniChip(theme, 'Freed: AED ${freed.toStringAsFixed(0)}/mo'),
                    if (required > 0)
                      _miniChip(
                          theme, 'Need: AED ${required.toStringAsFixed(0)}/mo'),
                    if (monthsToGoal != null)
                      _miniChip(theme, 'Goal in ~$monthsToGoal months'),
                  ],
                ),
              ],
            ),
          ),

          // ── Quick templates ──
          if (templates.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Quick templates',
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in templates)
                  ChoiceChip(
                    label: Text('${t.emoji} ${t.label}'),
                    selected: _activeTemplateId == t.id,
                    onSelected: (sel) {
                      if (!sel) return;
                      setState(() {
                        _activeTemplateId = t.id;
                        _appliedBudgetCategories.clear();
                        for (final c in t.caps.entries) {
                          if (_adjustCaps!.containsKey(c.key)) {
                            _adjustCaps![c.key] = c.value;
                          }
                        }
                      });
                    },
                  ),
              ],
            ),
            if (selectedTemplate != null) ...[
              const SizedBox(height: 8),
              Text(
                selectedTemplate.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],

          // ── Per-category sliders ──
          const SizedBox(height: 10),
          for (final e in categories)
            _capSlider(theme, e, (e.value * 1.5).ceilToDouble()),

          // ── Apply ──
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: changed.isEmpty || allApplied
                  ? null
                  : () => _applyAdjustedBudgets(changed),
              icon: Icon(
                allApplied
                    ? Icons.check_circle_outline_rounded
                    : Icons.save_rounded,
                size: 18,
              ),
              label: Text(
                allApplied
                    ? 'Budgets applied ✓'
                    : changed.isEmpty
                        ? 'Trim a category to apply budgets'
                        : 'Apply ${changed.length} budget${changed.length == 1 ? '' : 's'}',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: WazyColors.navyPrimary,
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
    );
  }

  Widget _capSlider(
    ThemeData theme,
    MapEntry<FinanceCategory, double> entry,
    double maxCap,
  ) {
    final value = (_adjustCaps![entry.key] ?? entry.value).clamp(0.0, maxCap);
    final trimmed = entry.value - value;
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: WazyColors.navyPrimary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(entry.key.icon, size: 15, color: WazyColors.navyPrimary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key.displayName,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Now ~AED ${entry.value.toStringAsFixed(0)}/mo',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'AED ${value.toStringAsFixed(0)}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: trimmed > 0.5 ? WazyColors.emerald : null,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: maxCap,
          divisions: (maxCap / 25).round().clamp(4, 40),
          label: 'AED ${value.round()}',
          onChanged: (v) {
            setState(() {
              _adjustCaps![entry.key] = v;
              _activeTemplateId = null;
              _appliedBudgetCategories.remove(entry.key.name);
            });
          },
        ),
      ],
    );
  }

  Future<void> _applyAdjustedBudgets(
    List<MapEntry<FinanceCategory, double>> changed,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Apply these budgets?'),
        content: Text(
          'Set monthly caps for ${changed.length} categor'
          '${changed.length == 1 ? 'y' : 'ies'} as adjusted? You can change '
          'them anytime in Money → Budgets.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: WazyColors.navyPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    for (final e in changed) {
      await FinanceService.instance.upsertBudget(e.key, e.value);
    }
    if (!mounted) return;
    setState(() {
      for (final e in changed) {
        _appliedBudgetCategories.add(e.key.name);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${changed.length} budget${changed.length == 1 ? '' : 's'} updated '
          '— see Money → Budgets.',
        ),
        backgroundColor: WazyColors.emerald,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _miniChip(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: WazyColors.navyPrimary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Groq key settings (same dialog as AI Summary)
  // ------------------------------------------------------------------

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
            Icon(Icons.key_rounded, color: WazyColors.violetAccent),
            SizedBox(width: 8),
            Text('Groq API Settings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Wazy includes an in-app Groq API key by default. You can optional enter a custom key below.',
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
              await _refreshQuota();
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
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: WazyColors.navyPrimary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Key'),
          ),
        ],
      ),
    );
  }
}
