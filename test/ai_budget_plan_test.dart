import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wazy/models/finance.dart';
import 'package:wazy/models/subscription_tier.dart';
import 'package:wazy/services/ai_budget_plan_service.dart';
import 'package:wazy/services/entitlement_service.dart';

FinanceTransaction _tx(
  FinanceCategory category,
  double amount,
  DateTime at, {
  FinanceKind kind = FinanceKind.expense,
}) =>
    FinanceTransaction(
      id: 't-$category-$amount-${at.millisecondsSinceEpoch}',
      collectionId: 'personal',
      kind: kind,
      category: category,
      title: 'Test $category',
      amount: amount,
      occurredAt: at,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await EntitlementService.instance.refresh();
    await AiBudgetPlanService.instance.resetUsageCounter();
  });

  group('Tier Quotas for AI Budget Planning', () {
    test('Free tier allows exactly 2 monthly plans', () async {
      await SharedPreferences.getInstance().then(
        (p) => p.setString(EntitlementService.tierOverrideKey, 'free'),
      );
      await EntitlementService.instance.refresh();

      expect(EntitlementService.instance.tier, SubscriptionTier.free);
      final service = AiBudgetPlanService.instance;
      expect(service.getMonthlyQuotaLimit(), 2);

      expect(await service.canGeneratePlan(), isTrue);
      expect(await service.getRemainingQuotaThisMonth(), 2);
    });

    test('Plus tier allows exactly 20 monthly plans', () async {
      await SharedPreferences.getInstance().then(
        (p) => p.setString(EntitlementService.tierOverrideKey, 'plus'),
      );
      await EntitlementService.instance.refresh();

      expect(EntitlementService.instance.tier, SubscriptionTier.plus);
      final service = AiBudgetPlanService.instance;
      expect(service.getMonthlyQuotaLimit(), 20);
    });

    test('Business tier allows exactly 60 monthly plans', () async {
      await SharedPreferences.getInstance().then(
        (p) => p.setString(EntitlementService.tierOverrideKey, 'business'),
      );
      await EntitlementService.instance.refresh();

      expect(EntitlementService.instance.tier, SubscriptionTier.business);
      final service = AiBudgetPlanService.instance;
      expect(service.getMonthlyQuotaLimit(), 60);
    });
  });

  group('AiBudgetPlanService Generation & Fallback', () {
    test('generates plan from Groq override and increments monthly counter',
        () async {
      final service = AiBudgetPlanService.instance;
      service.groqCallOverride = (system, user) async =>
          '{"title": "Plan: MacBook", "summary": "Save AED 1,500 per month.", '
          '"feasible": true, "monthsToGoal": 7, "monthlySavingTarget": 1500, '
          '"actions": [{"title": "Trim Shopping", "detail": "Cut shopping by '
          'AED 400.", "categoryName": "shopping", "monthlyAmount": 400, '
          '"suggestedEnvelopeName": "MacBook Fund"}]}';

      final now = DateTime(2026, 9, 21);
      final result = await service.generatePlan(
        goalDescription: 'Buy a MacBook',
        targetAmount: 10500,
        targetMonths: 7,
        forceRegenerate: true,
        now: now,
      );

      expect(result.usedGroq, isTrue);
      expect(result.quotaExceeded, isFalse);
      expect(result.plan.title, 'Plan: MacBook');
      expect(result.plan.feasible, isTrue);
      expect(result.plan.monthsToGoal, 7);
      expect(result.plan.monthlySavingTargetAed, 1500);
      expect(result.plan.actions, hasLength(1));
      expect(result.plan.actions.first.category?.name, 'shopping');
      expect(result.plan.actions.first.suggestedEnvelopeName, 'MacBook Fund');
      expect(await service.getUsedQuotaThisMonth(now), 1);
      expect(await service.getRemainingQuotaThisMonth(now), 1);
    });

    test('enforces quota limit when limit is reached', () async {
      final service = AiBudgetPlanService.instance;
      service.groqCallOverride = (system, user) async =>
          '{"title": "Plan", "summary": "Save more.", "feasible": true, '
          '"monthlySavingTarget": 500, "actions": []}';

      final now = DateTime(2026, 9, 21);
      // Free tier limit = 2.
      await service.generatePlan(
        goalDescription: 'Goal A',
        targetAmount: 1000,
        forceRegenerate: true,
        now: now,
      );
      await service.generatePlan(
        goalDescription: 'Goal B',
        targetAmount: 2000,
        forceRegenerate: true,
        now: now,
      );

      expect(await service.getUsedQuotaThisMonth(now), 2);
      expect(await service.canGeneratePlan(now), isFalse);

      // 3rd generation should trigger quotaExceeded with a fallback plan.
      final overflow = await service.generatePlan(
        goalDescription: 'Goal C',
        targetAmount: 3000,
        forceRegenerate: true,
        now: now,
      );
      expect(overflow.quotaExceeded, isTrue);
      expect(overflow.usedGroq, isFalse);
      expect(overflow.plan.feasible, isA<bool>());
    });

    test('returns cached plan without consuming quota', () async {
      final service = AiBudgetPlanService.instance;
      service.groqCallOverride = (system, user) async =>
          '{"title": "Cached Plan", "summary": "Save.", "feasible": true, '
          '"monthlySavingTarget": 100, "actions": []}';

      final now = DateTime(2026, 9, 21);
      await service.generatePlan(
        goalDescription: 'Goal',
        targetAmount: 500,
        forceRegenerate: true,
        now: now,
      );
      expect(await service.getUsedQuotaThisMonth(now), 1);

      // Second call without forceRegenerate hits the cache.
      final cached = await service.generatePlan(
        goalDescription: 'Goal',
        targetAmount: 500,
        now: now,
      );
      expect(cached.plan.title, 'Cached Plan');
      expect(await service.getUsedQuotaThisMonth(now), 1);
    });
  });

  group('parsePlanResponse', () {
    test('parses strict JSON', () {
      final plan = AiBudgetPlanService.parsePlanResponse(
        '{"title": "T", "summary": "S", "feasible": false, '
        '"monthsToGoal": 12, "monthlySavingTarget": 250, '
        '"actions": [{"title": "A", "detail": "D", "categoryName": "rent", '
        '"monthlyAmount": 100, "suggestedEnvelopeName": null}]}',
      );

      expect(plan, isNotNull);
      expect(plan!.feasible, isFalse);
      expect(plan.monthsToGoal, 12);
      expect(plan.actions.first.category, isNotNull);
      expect(plan.actions.first.suggestedEnvelopeName, isNull);
    });

    test('parses JSON wrapped in markdown fences', () {
      final plan = AiBudgetPlanService.parsePlanResponse(
        '```json\n{"title": "T", "summary": "S", "feasible": true, '
        '"monthlySavingTarget": 0, "actions": []}\n```',
      );

      expect(plan, isNotNull);
      expect(plan!.title, 'T');
    });

    test('returns null for garbage', () {
      expect(AiBudgetPlanService.parsePlanResponse('not json at all'), isNull);
      expect(AiBudgetPlanService.parsePlanResponse(''), isNull);
    });
  });

  group('Action types', () {
    test('parses explicit action types', () {
      final plan = AiBudgetPlanService.parsePlanResponse(
        '{"title": "T", "summary": "S", "feasible": true, '
        '"monthlySavingTarget": 100, "actions": ['
        '{"title": "A", "detail": "D", "type": "budget", '
        '"categoryName": "shopping", "monthlyAmount": 800}, '
        '{"title": "B", "detail": "D", "type": "envelope", '
        '"suggestedEnvelopeName": "Umrah Trip", "monthlyAmount": 300}, '
        '{"title": "C", "detail": "D", "type": "tip"}]}',
      );

      expect(plan, isNotNull);
      expect(plan!.actions, hasLength(3));
      expect(plan.actions[0].type, AiBudgetPlanActionType.budget);
      expect(plan.actions[0].category, FinanceCategory.shopping);
      expect(plan.actions[1].type, AiBudgetPlanActionType.envelope);
      expect(plan.actions[1].suggestedEnvelopeName, 'Umrah Trip');
      expect(plan.actions[2].type, AiBudgetPlanActionType.tip);
    });

    test('infers envelope type from suggestedEnvelopeName (backward compat)',
        () {
      final plan = AiBudgetPlanService.parsePlanResponse(
        '{"title": "T", "summary": "S", "feasible": true, '
        '"monthlySavingTarget": 1, "actions": [{"title": "A", '
        '"detail": "D", "suggestedEnvelopeName": "MacBook Fund"}]}',
      );

      expect(plan!.actions.single.type, AiBudgetPlanActionType.envelope);
    });

    test('fallback plan mixes action types', () async {
      final service = AiBudgetPlanService.instance;
      service.groqCallOverride = (system, user) async => 'not json at all';

      final result = await service.generatePlan(
        goalDescription: 'Buy a MacBook',
        targetAmount: 1000,
        forceRegenerate: true,
        now: DateTime(2026, 9, 21),
      );

      expect(result.usedGroq, isFalse);
      final types = result.plan.actions.map((a) => a.type).toSet();
      expect(types, contains(AiBudgetPlanActionType.envelope));
      expect(types, contains(AiBudgetPlanActionType.tip));
    });
  });

  group('Budget templates & goal mood', () {
    test('goal-first template frees at least the saving target', () {
      final service = AiBudgetPlanService.instance;
      final now = DateTime(2026, 9, 21);
      final txs = [
        for (var i = 0; i < 3; i++) ...[
          _tx(FinanceCategory.foodAndBeverages, 800,
              now.subtract(Duration(days: 10 + i * 30))),
          _tx(FinanceCategory.shopping, 600,
              now.subtract(Duration(days: 15 + i * 30))),
          _tx(FinanceCategory.entertainment, 200,
              now.subtract(Duration(days: 20 + i * 30))),
          // Essentials must never be trimmed by templates.
          _tx(FinanceCategory.rent, 3000,
              now.subtract(Duration(days: 5 + i * 30))),
          _tx(FinanceCategory.utilities, 1000,
              now.subtract(Duration(days: 8 + i * 30))),
        ],
      ];

      final templates = service.buildBudgetTemplates(
        monthlySavingTarget: 400,
        transactions: txs,
        now: now,
      );
      expect(templates.map((t) => t.id),
          containsAll(['comfortable', 'balanced', 'goal_first']));

      final spend = service.averageMonthlySpendByCategory(
          transactions: txs, now: now);
      double freedOf(Map<FinanceCategory, double> caps) {
        var freed = 0.0;
        for (final e in caps.entries) {
          freed += (spend[e.key] ?? 0) - e.value;
        }
        return freed;
      }

      final goalFirst = templates.firstWhere((t) => t.id == 'goal_first');
      expect(freedOf(goalFirst.caps), greaterThanOrEqualTo(399.9));

      // Templates only touch flexible categories.
      for (final t in templates) {
        expect(t.caps.containsKey(FinanceCategory.rent), isFalse);
        expect(t.caps.containsKey(FinanceCategory.utilities), isFalse);
      }
    });

    test('returns no templates when there is no spend data', () {
      final templates = AiBudgetPlanService.instance.buildBudgetTemplates(
        monthlySavingTarget: 500,
        transactions: const [],
        now: DateTime(2026, 9, 21),
      );
      expect(templates, isEmpty);
    });

    test('goalMood maps coverage to friendly labels', () {
      expect(AiBudgetPlanService.goalMood(coverage: 1.3).label,
          'On track — with room to spare');
      expect(AiBudgetPlanService.goalMood(coverage: 1.05).emoji, '🙂');
      expect(AiBudgetPlanService.goalMood(coverage: 0.9).label,
          'A little tight');
      expect(AiBudgetPlanService.goalMood(coverage: 0.6).label,
          'Hard to reach');
      expect(AiBudgetPlanService.goalMood(coverage: 0.2).label, 'Off track');
    });
  });
}
