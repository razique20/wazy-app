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
    docType: DocumentType.tradeLicence,
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
}
