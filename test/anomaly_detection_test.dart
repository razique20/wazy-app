import 'package:flutter_test/flutter_test.dart';
import 'package:wazy/models/finance.dart';
import 'package:wazy/services/anomaly_detection_service.dart';

void main() {
  group('AnomalyDetectionService Unit Tests', () {
    final service = AnomalyDetectionService.instance;
    final now = DateTime.now();

    final historicalDewaBills = [
      FinanceTransaction(
        id: 'tx1',
        collectionId: 'personal',
        kind: FinanceKind.expense,
        category: FinanceCategory.utilities,
        title: 'DEWA Bill',
        amount: 400.0,
        occurredAt: now.subtract(const Duration(days: 90)),
      ),
      FinanceTransaction(
        id: 'tx2',
        collectionId: 'personal',
        kind: FinanceKind.expense,
        category: FinanceCategory.utilities,
        title: 'DEWA Bill',
        amount: 420.0,
        occurredAt: now.subtract(const Duration(days: 60)),
      ),
      FinanceTransaction(
        id: 'tx3',
        collectionId: 'personal',
        kind: FinanceKind.expense,
        category: FinanceCategory.utilities,
        title: 'DEWA Bill',
        amount: 410.0,
        occurredAt: now.subtract(const Duration(days: 30)),
      ),
    ];

    test('Ignores normal minor price fluctuation (+5%)', () {
      final normalTx = FinanceTransaction(
        id: 'tx_normal',
        collectionId: 'personal',
        kind: FinanceKind.expense,
        category: FinanceCategory.utilities,
        title: 'DEWA Bill',
        amount: 430.0, // ~4.8% above 410 average
        occurredAt: now,
      );

      final history = [...historicalDewaBills, normalTx];
      final anomaly = service.evaluateTransaction(normalTx, history);

      expect(anomaly, isNull);
    });

    test('Detects High Price Spike (+35%)', () {
      final spikedTx = FinanceTransaction(
        id: 'tx_spike',
        collectionId: 'personal',
        kind: FinanceKind.expense,
        category: FinanceCategory.utilities,
        title: 'DEWA Bill',
        amount: 555.0, // ~35.3% above 410 average
        occurredAt: now,
      );

      final history = [...historicalDewaBills, spikedTx];
      final anomaly = service.evaluateTransaction(spikedTx, history);

      expect(anomaly, isNotNull);
      expect(anomaly!.percentIncrease, greaterThanOrEqualTo(35.0));
      expect(anomaly.severity, equals(AnomalySeverity.high));
      expect(anomaly.message, contains('DEWA Bill bill'));
    });

    test('Detects Critical Price Spike (+50% or higher)', () {
      final criticalTx = FinanceTransaction(
        id: 'tx_critical',
        collectionId: 'personal',
        kind: FinanceKind.expense,
        category: FinanceCategory.utilities,
        title: 'DEWA Bill',
        amount: 650.0, // ~58.5% above average
        occurredAt: now,
      );

      final history = [...historicalDewaBills, criticalTx];
      final anomaly = service.evaluateTransaction(criticalTx, history);

      expect(anomaly, isNotNull);
      expect(anomaly!.percentIncrease, greaterThan(50.0));
      expect(anomaly.severity, equals(AnomalySeverity.critical));
    });

    test('detectRecentAnomalies returns list sorted by highest spike first', () {
      final spike1 = FinanceTransaction(
        id: 'sp1',
        collectionId: 'personal',
        kind: FinanceKind.expense,
        category: FinanceCategory.utilities,
        title: 'DEWA Bill',
        amount: 560.0, // +36% spike
        occurredAt: now.subtract(const Duration(days: 2)),
      );

      final spike2 = FinanceTransaction(
        id: 'sp2',
        collectionId: 'personal',
        kind: FinanceKind.expense,
        category: FinanceCategory.transport,
        title: 'Uber Ride',
        amount: 150.0, // +200% spike over 50 avg
        occurredAt: now.subtract(const Duration(days: 1)),
      );

      final uberHistory = [
        FinanceTransaction(
          id: 'u1',
          collectionId: 'personal',
          kind: FinanceKind.expense,
          category: FinanceCategory.transport,
          title: 'Uber Ride',
          amount: 50.0,
          occurredAt: now.subtract(const Duration(days: 40)),
        ),
        FinanceTransaction(
          id: 'u2',
          collectionId: 'personal',
          kind: FinanceKind.expense,
          category: FinanceCategory.transport,
          title: 'Uber Ride',
          amount: 50.0,
          occurredAt: now.subtract(const Duration(days: 20)),
        ),
      ];

      final history = [...historicalDewaBills, ...uberHistory, spike1, spike2];
      final anomalies = service.detectRecentAnomalies(history, recentDays: 10);

      expect(anomalies.length, greaterThanOrEqualTo(2));
      expect(anomalies.first.transaction.title, equals('Uber Ride'));
      expect(anomalies.first.percentIncrease, greaterThan(anomalies.last.percentIncrease));
    });
  });
}
