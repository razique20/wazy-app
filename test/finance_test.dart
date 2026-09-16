import 'package:flutter_test/flutter_test.dart';

import 'package:wazy/models/finance.dart';
import 'package:wazy/models/document_type.dart';
import 'package:wazy/models/expiry_item.dart';

FinanceTransaction _tx(
  double amount,
  FinanceKind kind,
  FinanceCategory category,
  DateTime when, {
  String collectionId = 'personal',
  String? title,
}) {
  return FinanceTransaction(
    id: title ?? 't-$amount-${when.millisecondsSinceEpoch}',
    collectionId: collectionId,
    kind: kind,
    category: category,
    title: title ?? (kind == FinanceKind.income ? 'Income' : 'Expense'),
    amount: amount,
    occurredAt: when,
  );
}

ExpiryItem _item({
  required int inDays,
  double? fee,
  bool active = true,
  String collectionId = 'personal',
}) {
  return ExpiryItem.create(
    id: 'doc-$inDays-$fee',
    displayName: 'Doc $inDays',
    docType: DocumentTypeRegistry.instance
        .byEnum(DocumentType.tradeLicence),
    expiresAt: DateTime.now().add(Duration(days: inDays)),
    collectionId: collectionId,
    renewalFee: fee,
    isActive: active,
  );
}

void main() {
  group('MoneyFormat.aed', () {
    test('formats thousands separators and decimals', () {
      expect(MoneyFormat.aed(0), 'AED 0.00');
      expect(MoneyFormat.aed(12345.5), 'AED 12,345.50');
      expect(MoneyFormat.aed(1234567.89), 'AED 1,234,567.89');
    });

    test('handles negatives', () {
      expect(MoneyFormat.aed(-250), '-AED 250.00');
    });
  });

  group('FinanceMath.summaryForMonth', () {
    final march = DateTime(2026, 3, 15);

    test('sums income, expense and net within the month', () {
      final transactions = [
        _tx(1000, FinanceKind.income, FinanceCategory.sales, DateTime(2026, 3, 1)),
        _tx(400, FinanceKind.expense, FinanceCategory.rent, DateTime(2026, 3, 5)),
        _tx(100, FinanceKind.expense, FinanceCategory.utilities, DateTime(2026, 3, 20)),
        // Other month and other collection must be ignored.
        _tx(9999, FinanceKind.expense, FinanceCategory.other, DateTime(2026, 4, 1)),
        _tx(5000, FinanceKind.income, FinanceCategory.sales, march,
            collectionId: 'other'),
      ];

      final summary =
          FinanceMath.summaryForMonth(transactions, march, collectionId: 'personal');

      expect(summary.income, 1000);
      expect(summary.expense, 500);
      expect(summary.net, 500);
    });

    test('scopes to a collection when requested', () {
      final transactions = [
        _tx(5000, FinanceKind.income, FinanceCategory.sales, march,
            collectionId: 'other'),
      ];

      final summary = FinanceMath.summaryForMonth(
        transactions,
        march,
        collectionId: 'personal',
      );

      expect(summary.income, 0);
      expect(summary.net, 0);
    });
  });

  group('FinanceMath.spendByCategory', () {
    test('accumulates only expenses in the given month', () {
      final month = DateTime(2026, 3);
      final transactions = [
        _tx(300, FinanceKind.expense, FinanceCategory.rent, DateTime(2026, 3, 2)),
        _tx(200, FinanceKind.expense, FinanceCategory.rent, DateTime(2026, 3, 28)),
        _tx(50, FinanceKind.expense, FinanceCategory.software, DateTime(2026, 3, 10)),
        _tx(700, FinanceKind.income, FinanceCategory.sales, DateTime(2026, 3, 12)),
        _tx(999, FinanceKind.expense, FinanceCategory.other, DateTime(2026, 2, 10)),
      ];

      final spend = FinanceMath.spendByCategory(transactions, month);

      expect(spend.length, 2);
      expect(spend[FinanceCategory.rent], 500);
      expect(spend[FinanceCategory.software], 50);
    });
  });

  group('FinanceMath.renewalOutlook', () {
    test('sums renewal fees for active documents within the window', () {
      final items = [
        _item(inDays: 10, fee: 500), // inside 90 days
        _item(inDays: 89, fee: 1200), // inside
        _item(inDays: 91, fee: 300), // outside the window
        _item(inDays: -5, fee: 800), // already expired — ignored
        _item(inDays: 30, fee: 200, active: false), // inactive — ignored
        _item(inDays: 20, fee: null), // no fee — adds 0
      ];

      expect(FinanceMath.renewalOutlook(items, 90), 1700);
    });
  });

  group('FinanceMath.toCsv', () {
    test('emits a header and escaped rows', () {
      final csv = FinanceMath.toCsv([
        _tx(150.5, FinanceKind.expense, FinanceCategory.rent,
            DateTime(2026, 3, 5),
            title: 'Office, "main"'),
      ]);

      final lines = csv.trim().split('\n');
      expect(lines.first, 'date,kind,category,title,amount,currency,note');
      expect(lines.last, contains('"Office, ""main"""'));
      expect(lines.last, contains('150.50'));
    });
  });

  group('SavingsEnvelope', () {
    test('progress and remaining are clamped', () {
      const done = SavingsEnvelope(
        id: 'e1',
        collectionId: 'personal',
        name: 'Licence',
        targetAmount: 1000,
        savedAmount: 1200,
      );
      expect(done.progress, 1.0);
      expect(done.remaining, 0.0);
      expect(done.isComplete, isTrue);

      const partial = SavingsEnvelope(
        id: 'e2',
        collectionId: 'personal',
        name: 'Licence',
        targetAmount: 1000,
        savedAmount: 250,
      );
      expect(partial.progress, closeTo(0.25, 0.001));
      expect(partial.remaining, 750);
      expect(partial.isComplete, isFalse);
    });

    test('json round-trip preserves values', () {
      const envelope = SavingsEnvelope(
        id: 'e3',
        collectionId: 'personal',
        name: 'Visa fund',
        targetAmount: 3000,
        savedAmount: 500,
        monthlyContribution: 250,
      );

      final restored = SavingsEnvelope.fromJson(envelope.toJson());

      expect(restored.name, 'Visa fund');
      expect(restored.targetAmount, 3000);
      expect(restored.savedAmount, 500);
      expect(restored.monthlyContribution, 250);
    });
  });

  group('FinanceMath overall budget calculations', () {
    test('totalBudgetAllocated sums category monthly limits', () {
      final budgets = [
        const CategoryBudget(
          id: 'b1',
          collectionId: 'c1',
          category: FinanceCategory.rent,
          monthlyLimit: 10000,
        ),
        const CategoryBudget(
          id: 'b2',
          collectionId: 'c1',
          category: FinanceCategory.salaries,
          monthlyLimit: 25000,
        ),
      ];

      expect(FinanceMath.totalBudgetAllocated(budgets), 35000);
    });

    test('remainingUnallocatedBudget calculates unallocated budget correctly', () {
      final budgets = [
        const CategoryBudget(
          id: 'b1',
          collectionId: 'c1',
          category: FinanceCategory.rent,
          monthlyLimit: 10000,
        ),
        const CategoryBudget(
          id: 'b2',
          collectionId: 'c1',
          category: FinanceCategory.salaries,
          monthlyLimit: 25000,
        ),
      ];

      expect(FinanceMath.remainingUnallocatedBudget(50000, budgets), 15000);
      // Excluding b1 (10,000) means remaining is 50,000 - 25,000 = 25,000.
      expect(
        FinanceMath.remainingUnallocatedBudget(
          50000,
          budgets,
          excludingCategoryId: 'b1',
        ),
        25000,
      );
    });
  });

  group('BudgetStatusResult thresholds', () {
    CategoryBudget budget(double limit, {String id = 'b'}) => CategoryBudget(
          id: id,
          collectionId: 'c1',
          category: FinanceCategory.rent,
          monthlyLimit: limit,
        );

    test('ratio below 80% is none', () {
      final r = BudgetStatusResult(budget: budget(1000), spent: 799.99);
      expect(r.status, BudgetAlertLevel.none);
    });

    test('ratio at exactly 80% is near', () {
      final r = BudgetStatusResult(budget: budget(1000), spent: 800);
      expect(r.status, BudgetAlertLevel.near);
    });

    test('ratio between 80% and 100% is near', () {
      final r = BudgetStatusResult(budget: budget(1000), spent: 950);
      expect(r.status, BudgetAlertLevel.near);
    });

    test('ratio at exactly 100% is exceeded', () {
      final r = BudgetStatusResult(budget: budget(1000), spent: 1000);
      expect(r.status, BudgetAlertLevel.exceeded);
    });

    test('ratio beyond 100% is exceeded', () {
      final r = BudgetStatusResult(budget: budget(1000), spent: 1400);
      expect(r.status, BudgetAlertLevel.exceeded);
    });

    test('zero limit never alerts', () {
      final r = BudgetStatusResult(budget: budget(0), spent: 500);
      expect(r.ratio, 0);
      expect(r.status, BudgetAlertLevel.none);
    });
  });

  group('Budget alerting / dedupe', () {
    CategoryBudget budget(String id, double limit) => CategoryBudget(
          id: id,
          collectionId: 'c1',
          category: FinanceCategory.rent,
          monthlyLimit: limit,
        );

    test('shouldAlertAt fires once per threshold then dedupes', () {
      final r = BudgetStatusResult(budget: budget('b1', 1000), spent: 850);
      expect(r.shouldAlertAt(BudgetThresholds.near, {}), isTrue);
      final key = r.alertKey(BudgetThresholds.near);
      expect(r.shouldAlertAt(BudgetThresholds.near, {key}), isFalse);
    });

    test('below threshold never alerts', () {
      final r = BudgetStatusResult(budget: budget('b1', 1000), spent: 500);
      expect(r.shouldAlertAt(BudgetThresholds.near, {}), isFalse);
      expect(r.shouldAlertAt(BudgetThresholds.exceeded, {}), isFalse);
    });

    test('dedupe keys are scoped per budget, month and threshold', () {
      final a = BudgetStatusResult(budget: budget('b1', 1000), spent: 1000);
      final b = BudgetStatusResult(budget: budget('b2', 1000), spent: 1000);
      final month = DateTime.now();
      final expectedSuffix =
          '|${month.year}|${month.month}|${BudgetThresholds.exceeded}';
      expect(a.alertKey(BudgetThresholds.exceeded), 'b1$expectedSuffix');
      expect(b.alertKey(BudgetThresholds.exceeded), 'b2$expectedSuffix');
    });
  });

  group('FinanceMath.findDuplicateTransaction', () {
    FinanceTransaction tx(
      String id,
      String title,
      double amount,
      DateTime when, {
      String collectionId = 'personal',
    }) =>
        FinanceTransaction(
          id: id,
          collectionId: collectionId,
          kind: FinanceKind.expense,
          category: FinanceCategory.rent,
          title: title,
          amount: amount,
          occurredAt: when,
        );

    final day = DateTime(2026, 9, 10);

    test('flags same title (case/space-insensitive), amount and day', () {
      final existing = tx('a', 'DEWA bill', 350, day);
      final candidate = tx('b', '  dewa BILL ', 350, day);
      expect(
        FinanceMath.findDuplicateTransaction([existing], candidate)?.id,
        'a',
      );
    });

    test('different amount, title or day is not a duplicate', () {
      final existing = tx('a', 'DEWA bill', 350, day);
      expect(
        FinanceMath.findDuplicateTransaction(
          [existing],
          tx('b', 'DEWA bill', 400, day),
        ),
        isNull,
      );
      expect(
        FinanceMath.findDuplicateTransaction(
          [existing],
          tx('b', 'SEWA bill', 350, day),
        ),
        isNull,
      );
      expect(
        FinanceMath.findDuplicateTransaction(
          [existing],
          tx('b', 'DEWA bill', 350, day.add(const Duration(days: 1))),
        ),
        isNull,
      );
    });

    test('other months or years do not match', () {
      final existing = tx('a', 'DEWA bill', 350, day);
      final nextMonth = tx('b', 'DEWA bill', 350, DateTime(2026, 10, 10));
      final nextYear = tx('c', 'DEWA bill', 350, DateTime(2027, 9, 10));
      expect(
        FinanceMath.findDuplicateTransaction([existing], nextMonth),
        isNull,
      );
      expect(
        FinanceMath.findDuplicateTransaction([existing], nextYear),
        isNull,
      );
    });

    test('scoped per collection and ignores the candidate\'s own id', () {
      final company = tx('a', 'DEWA bill', 350, day,
          collectionId: 'company');
      final candidate = tx('b', 'DEWA bill', 350, day);
      expect(
        FinanceMath.findDuplicateTransaction([company], candidate),
        isNull,
      );

      // Editing an existing record must not self-match.
      final edited = tx('a', 'DEWA bill', 350, day);
      expect(
        FinanceMath.findDuplicateTransaction([edited], edited),
        isNull,
      );
    });
  });

  group('FinanceMath.budgetStatuses / worstBudgetStatus', () {
    CategoryBudget budget(String id, FinanceCategory c, double limit) =>
        CategoryBudget(
          id: id,
          collectionId: 'c1',
          category: c,
          monthlyLimit: limit,
        );

    test('maps spend onto each budget', () {
      final budgets = [
        budget('b1', FinanceCategory.rent, 1000),
        budget('b2', FinanceCategory.software, 500),
      ];
      final spend = {FinanceCategory.rent: 900.0};
      final results = FinanceMath.budgetStatuses(budgets, spend);
      expect(results.length, 2);
      expect(results[0].spent, 900);
      expect(results[1].spent, 0);
    });

    test('worst picks exceeded over near, highest ratio wins ties', () {
      final near = BudgetStatusResult(
        budget: budget('near', FinanceCategory.rent, 1000),
        spent: 850,
      );
      final exceeded = BudgetStatusResult(
        budget: budget('over', FinanceCategory.software, 500),
        spent: 600,
      );
      final worst = FinanceMath.worstBudgetStatus([near, exceeded]);
      expect(worst?.budget.id, 'over');
    });

    test('worst returns null when nothing is ≥80%', () {
      final ok = BudgetStatusResult(
        budget: budget('ok', FinanceCategory.rent, 1000),
        spent: 100,
      );
      expect(FinanceMath.worstBudgetStatus([ok]), isNull);
      expect(FinanceMath.worstBudgetStatus(const []), isNull);
    });
  });
}
