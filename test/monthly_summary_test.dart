import 'package:flutter_test/flutter_test.dart';
import 'package:wazy/models/finance.dart';
import 'package:wazy/services/monthly_summary_service.dart';

FinanceTransaction _tx({
  required String id,
  required FinanceKind kind,
  required FinanceCategory category,
  required double amount,
  required DateTime at,
  String title = 'Tx',
  String collectionId = 'personal',
}) {
  return FinanceTransaction(
    id: id,
    collectionId: collectionId,
    kind: kind,
    category: category,
    title: title,
    amount: amount,
    currency: 'AED',
    occurredAt: at,
  );
}

void main() {
  final aggregator = const MonthlySummaryAggregator();
  final narrator = const MonthlySummaryNarrator();

  // Fixed "now": 15 August 2026.
  final now = DateTime(2026, 8, 15);
  final aug = (int day) => DateTime(2026, 8, day);
  final jul = (int day) => DateTime(2026, 7, day);

  group('MonthlySummaryAggregator', () {
    test('empty data when no transactions exist', () {
      final data = aggregator.aggregate(
        transactions: const [],
        budgets: const [],
        envelopes: const [],
        now: now,
      );
      expect(data.isEmpty, isTrue);
      expect(data.monthName, 'August');
      expect(data.income, 0);
      expect(data.expense, 0);
    });

    test('computes income, expense, net for the current month', () {
      final data = aggregator.aggregate(
        transactions: [
          _tx(
              id: '1',
              kind: FinanceKind.income,
              category: FinanceCategory.sales,
              amount: 20000,
              at: aug(5)),
          _tx(
              id: '2',
              kind: FinanceKind.expense,
              category: FinanceCategory.rent,
              amount: 15000,
              at: aug(2)),
          _tx(
              id: '3',
              kind: FinanceKind.expense,
              category: FinanceCategory.utilities,
              amount: 450,
              at: aug(10)),
        ],
        budgets: const [],
        envelopes: const [],
        now: now,
      );
      expect(data.income, 20000);
      expect(data.expense, 15450);
      expect(data.net, 4550);
      expect(data.topTransaction?.id, '2');
    });

    test('expense change percent vs previous month', () {
      final data = aggregator.aggregate(
        transactions: [
          _tx(
              id: '1',
              kind: FinanceKind.expense,
              category: FinanceCategory.rent,
              amount: 15000,
              at: aug(2)),
          _tx(
              id: '2',
              kind: FinanceKind.expense,
              category: FinanceCategory.rent,
              amount: 13392,
              at: jul(2)),
        ],
        budgets: const [],
        envelopes: const [],
        now: now,
      );
      // (15000 - 13392) / 13392 * 100 ≈ 12.0%
      expect(data.expenseChangePct, closeTo(12.0, 0.2));
      expect(data.prevExpense, 13392);
    });

    test('topMoves ranks categories by absolute delta', () {
      final data = aggregator.aggregate(
        transactions: [
          _tx(
              id: '1',
              kind: FinanceKind.expense,
              category: FinanceCategory.rent,
              amount: 15000,
              at: aug(2)),
          _tx(
              id: '2',
              kind: FinanceKind.expense,
              category: FinanceCategory.rent,
              amount: 10000,
              at: jul(2)),
          _tx(
              id: '3',
              kind: FinanceKind.expense,
              category: FinanceCategory.transport,
              amount: 400,
              at: aug(3)),
          _tx(
              id: '4',
              kind: FinanceKind.expense,
              category: FinanceCategory.transport,
              amount: 350,
              at: jul(3)),
        ],
        budgets: const [],
        envelopes: const [],
        now: now,
      );
      expect(data.topMoves.first.category, FinanceCategory.rent);
      expect(data.topMoves.first.current, 15000);
      expect(data.topMoves.first.previous, 10000);
    });

    test('detects budget overruns', () {
      final data = aggregator.aggregate(
        transactions: [
          _tx(
              id: '1',
              kind: FinanceKind.expense,
              category: FinanceCategory.rent,
              amount: 15000,
              at: aug(2)),
        ],
        budgets: [
          const CategoryBudget(
            id: 'b1',
            collectionId: 'personal',
            category: FinanceCategory.rent,
            monthlyLimit: 12000,
          ),
        ],
        envelopes: const [],
        now: now,
      );
      expect(data.budgetOverruns.length, 1);
      expect(data.budgetOverruns.first.spent, 15000);
      expect(data.budgetOverruns.first.budget.monthlyLimit, 12000);
    });

    test('envelope projection: months remaining and projected saving', () {
      final data = aggregator.aggregate(
        transactions: const [],
        budgets: const [],
        envelopes: [
          const SavingsEnvelope(
            id: 'e1',
            collectionId: 'personal',
            name: 'Trade Licence Renewal',
            targetAmount: 4500,
            savedAmount: 3000,
            monthlyContribution: 500,
          ),
        ],
        now: now,
      );
      expect(data.envelopeProjections.length, 1);
      final p = data.envelopeProjections.first;
      expect(p.monthsRemaining, 3);
      expect(p.projectedSaving, 4500);
    });

    test('collection scoping excludes other collections', () {
      final data = aggregator.aggregate(
        transactions: [
          _tx(
              id: '1',
              kind: FinanceKind.expense,
              category: FinanceCategory.rent,
              amount: 5000,
              at: aug(2),
              collectionId: 'company-a'),
        ],
        budgets: const [],
        envelopes: const [],
        now: now,
        collectionId: 'personal',
      );
      expect(data.isEmpty, isTrue);
    });
  });

  group('MonthlySummaryNarrator', () {
    test('template narrative matches the feature-spec example shape', () {
      final data = aggregator.aggregate(
        transactions: [
          _tx(
              id: '1',
              kind: FinanceKind.expense,
              category: FinanceCategory.rent,
              amount: 15000,
              at: aug(2)),
          _tx(
              id: '2',
              kind: FinanceKind.expense,
              category: FinanceCategory.rent,
              amount: 13392,
              at: jul(2)),
          _tx(
              id: '3',
              kind: FinanceKind.expense,
              category: FinanceCategory.renewals,
              amount: 1500,
              at: aug(4)),
        ],
        budgets: const [],
        envelopes: [
          const SavingsEnvelope(
            id: 'e1',
            collectionId: 'personal',
            name: 'Office Fund',
            targetAmount: 6000,
            savedAmount: 1500,
            monthlyContribution: 1500,
          ),
        ],
        now: now,
      );
      final narrative = narrator.templateNarrative(data);
      expect(narrative, startsWith('In August,'));
      expect(narrative, contains('rose by'));
      expect(narrative, contains('rent'));
      // Savings sentence from the spec: "on track to save AED X in your ... envelope"
      expect(narrative, contains('on track to save AED 6,000'));
      expect(narrative, contains('envelope'));
    });

    test('LLM prompt contains all key facts and guardrails', () {
      final data = aggregator.aggregate(
        transactions: [
          _tx(
              id: '1',
              kind: FinanceKind.expense,
              category: FinanceCategory.rent,
              amount: 15000,
              at: aug(2)),
          _tx(
              id: '2',
              kind: FinanceKind.expense,
              category: FinanceCategory.rent,
              amount: 13392,
              at: jul(2)),
          _tx(
              id: '3',
              kind: FinanceKind.income,
              category: FinanceCategory.sales,
              amount: 20000,
              at: aug(5)),
        ],
        budgets: const [],
        envelopes: const [],
        now: now,
      );
      final prompt = narrator.buildLlmPrompt(data);
      expect(prompt, contains('August 2026'));
      expect(prompt, contains('do not invent numbers'));
      expect(prompt, contains('AED 20,000'));
      expect(prompt, contains('AED 15,000'));
      expect(prompt, contains('12.0%'));
      expect(prompt, contains('July expenses'));
    });

    test('insights include budget overrun and net position', () {
      final data = aggregator.aggregate(
        transactions: [
          _tx(
              id: '1',
              kind: FinanceKind.expense,
              category: FinanceCategory.rent,
              amount: 15000,
              at: aug(2)),
        ],
        budgets: [
          const CategoryBudget(
            id: 'b1',
            collectionId: 'personal',
            category: FinanceCategory.rent,
            monthlyLimit: 12000,
          ),
        ],
        envelopes: const [],
        now: now,
      );
      final insights = narrator.buildInsights(data);
      final kinds = insights.map((i) => i.kind).toSet();
      expect(kinds, contains(MonthlyInsightKind.budgetAlert));
      expect(
        insights.any((i) => i.sentence.contains('budget exceeded')),
        isTrue,
      );
      expect(
        insights.last.sentence,
        anyOf(contains('Net'), contains('more than you earned')),
      );
    });

    test('empty data yields guidance narrative', () {
      final data = aggregator.aggregate(
        transactions: const [],
        budgets: const [],
        envelopes: const [],
        now: now,
      );
      final narrative = narrator.templateNarrative(data);
      expect(narrative, contains('No financial activity'));
    });
  });
}
