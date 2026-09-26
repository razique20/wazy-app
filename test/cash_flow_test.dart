import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/models/document_type.dart';
import 'package:finavig/models/expiry_item.dart';
import 'package:finavig/models/finance.dart';

void main() {
  final testNow = DateTime(2026, 9, 16);

  group('FinanceMath.calculate90DayCashFlow', () {
    test('calculates correct starting balance from historical transactions', () {
      final transactions = [
        FinanceTransaction(
          id: 't1',
          collectionId: 'personal',
          kind: FinanceKind.income,
          category: FinanceCategory.sales,
          title: 'Client Payment',
          amount: 50000,
          currency: 'AED',
          occurredAt: testNow.subtract(const Duration(days: 5)),
        ),
        FinanceTransaction(
          id: 't2',
          collectionId: 'personal',
          kind: FinanceKind.expense,
          category: FinanceCategory.rent,
          title: 'Office Rent',
          amount: 10000,
          currency: 'AED',
          occurredAt: testNow.subtract(const Duration(days: 2)),
        ),
      ];

      final forecast = FinanceMath.calculate90DayCashFlow(
        transactions: transactions,
        recurringTemplates: [],
        expiryItems: [],
        now: testNow,
      );

      expect(forecast.startingBalance, 40000);
      expect(forecast.projectedEndBalance, 40000);
      expect(forecast.points.length, 91); // Day 0 to Day 90 inclusive
    });

    test('projects recurring income and expense over 90 days', () {
      final recurring = [
        RecurringTransaction(
          id: 'r1',
          collectionId: 'personal',
          kind: FinanceKind.income,
          category: FinanceCategory.sales,
          title: 'Retainer Fee',
          amount: 15000,
          currency: 'AED',
          frequency: RecurrenceFrequency.monthly,
          dayOfMonth: 1,
          startDate: DateTime(2026, 9, 1),
          isActive: true,
        ),
        RecurringTransaction(
          id: 'r2',
          collectionId: 'personal',
          kind: FinanceKind.expense,
          category: FinanceCategory.salaries,
          title: 'Staff Payroll',
          amount: 10000,
          currency: 'AED',
          frequency: RecurrenceFrequency.monthly,
          dayOfMonth: 25,
          startDate: DateTime(2026, 9, 1),
          isActive: true,
        ),
      ];

      final forecast = FinanceMath.calculate90DayCashFlow(
        transactions: [],
        recurringTemplates: recurring,
        expiryItems: [],
        initialBalance: 20000,
        now: testNow,
      );

      expect(forecast.startingBalance, 20000);
      // In 90 days (Sep 16 -> Dec 15):
      // Oct 1 + Nov 1 + Dec 1 (3 retainer payments = 45,000 income)
      // Sep 25 + Oct 25 + Nov 25 (3 payroll payments = 30,000 expense)
      expect(forecast.totalProjectedInflow, 45000);
      expect(forecast.totalProjectedOutflow, 30000);
      expect(forecast.projectedEndBalance, 35000);
    });

    test('factors in document renewal fees on specific expiry dates', () {
      final docType = DocumentTypeRegistry.instance.byKey('trade_licence');
      final docs = [
        ExpiryItem(
          collectionId: 'personal',
          id: 'doc1',
          displayName: 'Main Trade Licence',
          docType: docType,
          expiryDate: '2026-10-15',
          daysRemaining: 29,
          urgency: UrgencyLevel.medium,
          expiresAt: DateTime(2026, 10, 15),
          renewalFee: 12500,
        ),
      ];

      final forecast = FinanceMath.calculate90DayCashFlow(
        transactions: [],
        recurringTemplates: [],
        expiryItems: docs,
        initialBalance: 30000,
        now: testNow,
      );

      expect(forecast.totalRenewalOutflow, 12500);
      expect(forecast.projectedEndBalance, 17500);

      final oct15Point = forecast.points.firstWhere(
        (p) => p.date.year == 2026 && p.date.month == 10 && p.date.day == 15,
      );
      expect(oct15Point.renewalOutflow, 12500);
      expect(oct15Point.events.length, 1);
      expect(oct15Point.events.first.title, 'Main Trade Licence Renewal');
      expect(oct15Point.events.first.isDocumentRenewal, isTrue);
    });

    test('identifies lowest balance point and date correctly', () {
      final docs = [
        ExpiryItem(
          collectionId: 'personal',
          id: 'doc1',
          displayName: 'Office Lease',
          docType: DocumentTypeRegistry.instance.byKey('ejari'),
          expiryDate: '2026-10-01',
          daysRemaining: 15,
          urgency: UrgencyLevel.medium,
          expiresAt: DateTime(2026, 10, 1),
          renewalFee: 25000,
        ),
      ];
      final recurring = [
        RecurringTransaction(
          id: 'r1',
          collectionId: 'personal',
          kind: FinanceKind.income,
          category: FinanceCategory.sales,
          title: 'Invoice Payment',
          amount: 30000,
          currency: 'AED',
          frequency: RecurrenceFrequency.monthly,
          dayOfMonth: 15,
          startDate: DateTime(2026, 9, 1),
          isActive: true,
        ),
      ];

      final forecast = FinanceMath.calculate90DayCashFlow(
        transactions: [],
        recurringTemplates: recurring,
        expiryItems: docs,
        initialBalance: 10000,
        now: testNow,
      );

      // On Oct 1: 10,000 - 25,000 = -15,000 (lowest point before Oct 15 income)
      expect(forecast.lowestBalance, -15000);
      expect(forecast.lowestBalanceDate, DateTime(2026, 10, 1));
      // On Oct 15 (+30k), Nov 15 (+30k), Dec 15 (+30k) -> 10k - 25k + 90k = 75,000 balance
      expect(forecast.projectedEndBalance, 75000);
    });
  });
}
