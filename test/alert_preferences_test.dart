import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finavig/models/finance.dart';
import 'package:finavig/services/alert_preferences_service.dart';
import 'package:finavig/services/anomaly_detection_service.dart';

FinanceTransaction _tx({
  required String id,
  required String title,
  required double amount,
  required DateTime at,
  FinanceKind kind = FinanceKind.expense,
  FinanceCategory category = FinanceCategory.rent,
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AlertPreferencesService.instance.reset();
  });

  group('AlertPreferencesService', () {
    test('defaults to enabled before load', () {
      expect(AlertPreferencesService.instance.billSpikesEnabled, isTrue);
      expect(AlertPreferencesService.instance.budgetAlertsEnabled, isTrue);
    });

    test('loads persisted disabled values', () async {
      SharedPreferences.setMockInitialValues({
        'alerts.billSpikesEnabled': false,
        'alerts.budgetAlertsEnabled': false,
      });

      await AlertPreferencesService.instance.load();

      expect(AlertPreferencesService.instance.billSpikesEnabled, isFalse);
      expect(AlertPreferencesService.instance.budgetAlertsEnabled, isFalse);
    });

    test('setters persist and apply immediately', () async {
      await AlertPreferencesService.instance.load();
      expect(AlertPreferencesService.instance.billSpikesEnabled, isTrue);

      await AlertPreferencesService.instance.setBillSpikesEnabled(false);
      await AlertPreferencesService.instance.setBudgetAlertsEnabled(false);

      expect(AlertPreferencesService.instance.billSpikesEnabled, isFalse);
      expect(AlertPreferencesService.instance.budgetAlertsEnabled, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('alerts.billSpikesEnabled'), isFalse);
      expect(prefs.getBool('alerts.budgetAlertsEnabled'), isFalse);
    });

    test('re-enable persists true', () async {
      await AlertPreferencesService.instance.load();
      await AlertPreferencesService.instance.setBudgetAlertsEnabled(false);
      await AlertPreferencesService.instance.setBudgetAlertsEnabled(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('alerts.budgetAlertsEnabled'), isTrue);
      expect(AlertPreferencesService.instance.budgetAlertsEnabled, isTrue);
    });
  });

  group('Bill spike dismissal filtering', () {
    final service = AnomalyDetectionService.instance;

    test('dismissed anomalies are excluded from the visible list', () {
      final now = DateTime.now();
      // Clean history for "Office Rent": 3 months around 5000.
      final history = [
        _tx(id: 'h1', title: 'Office Rent', amount: 4800, at: now.subtract(const Duration(days: 90))),
        _tx(id: 'h2', title: 'Office Rent', amount: 5000, at: now.subtract(const Duration(days: 60))),
        _tx(id: 'h3', title: 'Office Rent', amount: 5200, at: now.subtract(const Duration(days: 30))),
        // Recent spike: 10000 vs mean 5000 → +100% (critical).
        _tx(id: 'spike-1', title: 'Office Rent', amount: 10000, at: now.subtract(const Duration(days: 5))),
        // Another clean history series.
        _tx(id: 'h4', title: 'DEWA', amount: 990, at: now.subtract(const Duration(days: 80))),
        _tx(id: 'h5', title: 'DEWA', amount: 1000, at: now.subtract(const Duration(days: 50))),
        _tx(id: 'h6', title: 'DEWA', amount: 1010, at: now.subtract(const Duration(days: 20))),
        _tx(id: 'spike-2', title: 'DEWA', amount: 2000, at: now.subtract(const Duration(days: 3))),
      ];

      final anomalies = service.detectRecentAnomalies(history);
      expect(anomalies.length, 2);

      // Simulate the screen's dismissal filter (user closed the card).
      final dismissed = {'spike-1'};
      final visible = anomalies
          .where((a) => !dismissed.contains(a.transaction.id))
          .toList();

      expect(visible.length, 1);
      expect(visible.single.transaction.id, 'spike-2');
    });

    test('no anomalies when bill spike alerts are filtered with none left', () {
      final now = DateTime.now();
      final history = [
        _tx(id: 'h1', title: 'Office Rent', amount: 4800, at: now.subtract(const Duration(days: 90))),
        _tx(id: 'h2', title: 'Office Rent', amount: 5000, at: now.subtract(const Duration(days: 60))),
        _tx(id: 'h3', title: 'Office Rent', amount: 5200, at: now.subtract(const Duration(days: 30))),
        _tx(id: 'spike-1', title: 'Office Rent', amount: 10000, at: now.subtract(const Duration(days: 5))),
      ];

      final anomalies = service.detectRecentAnomalies(history);
      expect(anomalies.length, 1);

      final dismissed = anomalies.map((a) => a.transaction.id).toSet();
      final visible = anomalies
          .where((a) => !dismissed.contains(a.transaction.id))
          .toList();

      expect(visible, isEmpty);
    });
  });
}
