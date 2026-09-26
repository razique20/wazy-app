import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finavig/models/finance.dart';
import 'package:finavig/services/smart_category_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmartCategoryEngine Unit Tests', () {
    final engine = SmartCategoryEngine.instance;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await engine.init();
    });

    test('Predicts exact UAE dictionary keywords', () {
      final p1 = engine.predict('Talabat order');
      expect(p1.category, equals(FinanceCategory.foodAndBeverages));
      expect(p1.confidence, greaterThanOrEqualTo(0.85));

      final p2 = engine.predict('Salik toll charge');
      expect(p2.category, equals(FinanceCategory.transport));
      expect(p2.confidence, greaterThanOrEqualTo(0.85));

      final p3 = engine.predict('DEWA monthly bill');
      expect(p3.category, equals(FinanceCategory.utilities));

      final p4 = engine.predict('Ejari contract fee');
      expect(p4.category, equals(FinanceCategory.rent));
    });

    test('Predicts typos via Fuzzy Levenshtein distance', () {
      // "Talabt" instead of "Talabat"
      final p1 = engine.predict('Paid Talabt');
      expect(p1.category, equals(FinanceCategory.foodAndBeverages));
      expect(p1.matchSource, contains('Fuzzy Match'));

      // "Etisalt" instead of "Etisalat"
      final p2 = engine.predict('Etisalt phone bill');
      expect(p2.category, equals(FinanceCategory.utilities));

      // "Uberr" instead of "Uber"
      final p3 = engine.predict('Uberr taxi ride');
      expect(p3.category, equals(FinanceCategory.transport));
    });

    test('Learns user custom category choice and persists habit', () async {
      const customTitle = 'Unicorn Gadget Tech';
      // Initially unknown
      final pInitial = engine.predict(customTitle);
      expect(pInitial.category, equals(FinanceCategory.other));

      // Learn choice
      await engine.learnUserChoice(customTitle, FinanceCategory.shopping);

      // Now predicted from user memory
      final pLearned = engine.predict(customTitle);
      expect(pLearned.category, equals(FinanceCategory.shopping));
      expect(pLearned.confidence, equals(0.95));
      expect(pLearned.matchSource, contains('Learned Habit'));
    });

    test('Retro-applies smart categorization to uncategorized transactions', () {
      final now = DateTime.now();
      final txs = [
        FinanceTransaction(
          id: '1',
          collectionId: 'personal',
          kind: FinanceKind.expense,
          category: FinanceCategory.other,
          title: 'Starbucks Coffee',
          amount: 25.0,
          occurredAt: now,
        ),
        FinanceTransaction(
          id: '2',
          collectionId: 'personal',
          kind: FinanceKind.expense,
          category: FinanceCategory.other,
          title: 'Careem Taxi Ride',
          amount: 45.0,
          occurredAt: now,
        ),
      ];

      final updated = engine.retroApplyCategorization(txs, onlyUncategorized: true);

      expect(updated[0].category, equals(FinanceCategory.foodAndBeverages));
      expect(updated[1].category, equals(FinanceCategory.transport));
    });
  });
}
