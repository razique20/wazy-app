import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finavig/models/document_type.dart';
import 'package:finavig/models/expiry_item.dart';
import 'package:finavig/models/finance.dart';
import 'package:finavig/screens/money_screen.dart';
import 'package:finavig/services/finance_service.dart';
import 'package:finavig/services/document_scanner_service.dart';

RecurringTransaction _template({
  required int dayOfMonth,
  DateTime? startDate,
  DateTime? endDate,
  bool active = true,
  RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
  DateTime? lastLoggedAt,
  String id = 'r1',
}) {
  return RecurringTransaction(
    id: id,
    collectionId: 'personal',
    kind: FinanceKind.expense,
    category: FinanceCategory.rent,
    title: 'Office rent',
    amount: 5000,
    frequency: frequency,
    dayOfMonth: dayOfMonth,
    startDate: startDate ?? DateTime(2026, 1, 1),
    endDate: endDate,
    isActive: active,
    lastLoggedAt: lastLoggedAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecurrenceMath.occurrenceInMonth (day clamping)', () {
    test('day 31 clamps to the last day of short months', () {
      expect(
        RecurrenceMath.occurrenceInMonth(2026, 4, 31), // April has 30 days
        DateTime(2026, 4, 30),
      );
      expect(
        RecurrenceMath.occurrenceInMonth(2026, 2, 31), // 2026 is not a leap year
        DateTime(2026, 2, 28),
      );
    });

    test('leap year February accepts day 29', () {
      expect(
        RecurrenceMath.occurrenceInMonth(2028, 2, 31),
        DateTime(2028, 2, 29),
      );
    });

    test('normal days pass through unchanged', () {
      expect(
        RecurrenceMath.occurrenceInMonth(2026, 3, 5),
        DateTime(2026, 3, 5),
      );
    });
  });

  group('RecurrenceMath.nextOccurrence', () {
    test('first occurrence honours startDate and dayOfMonth', () {
      final next = RecurrenceMath.nextOccurrence(
        _template(dayOfMonth: 5, startDate: DateTime(2026, 3, 10)),
        RecurrenceFrequency.monthly,
        DateTime(2026, 3, 15),
      );
      expect(next, DateTime(2026, 4, 5));
    });

    test('day-of-month inside the current month comes before next month', () {
      final next = RecurrenceMath.nextOccurrence(
        _template(dayOfMonth: 25, startDate: DateTime(2026, 1, 1)),
        RecurrenceFrequency.monthly,
        DateTime(2026, 3, 15),
      );
      expect(next, DateTime(2026, 3, 25));
    });

    test('clamped occurrence does not drift the schedule', () {
      // Day 31: March 31 → next is April 30 (clamped) → next after that is
      // May 31, NOT May 30 (the clamp must not become the new anchor).
      final next = RecurrenceMath.nextOccurrence(
        _template(dayOfMonth: 31, startDate: DateTime(2026, 1, 1)),
        RecurrenceFrequency.monthly,
        DateTime(2026, 3, 31),
      );
      expect(next, DateTime(2026, 4, 30));

      final afterApril = RecurrenceMath.nextOccurrence(
        _template(dayOfMonth: 31, startDate: DateTime(2026, 1, 1)),
        RecurrenceFrequency.monthly,
        DateTime(2026, 4, 30),
      );
      expect(afterApril, DateTime(2026, 5, 31));
    });

    test('quarterly advances three months', () {
      final next = RecurrenceMath.nextOccurrence(
        _template(dayOfMonth: 10, startDate: DateTime(2026, 1, 1)),
        RecurrenceFrequency.quarterly,
        DateTime(2026, 1, 10),
      );
      expect(next, DateTime(2026, 4, 10));
    });

    test('yearly advances one year', () {
      final next = RecurrenceMath.nextOccurrence(
        _template(dayOfMonth: 10, startDate: DateTime(2026, 1, 1)),
        RecurrenceFrequency.yearly,
        DateTime(2026, 1, 10),
      );
      expect(next, DateTime(2027, 1, 10));
    });

    test('returns null past endDate', () {
      final next = RecurrenceMath.nextOccurrence(
        _template(
          dayOfMonth: 5,
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 6, 30),
        ),
        RecurrenceFrequency.monthly,
        DateTime(2026, 7, 1),
      );
      expect(next, isNull);
    });
  });

  group('RecurrenceMath.dueOccurrences (catch-up)', () {
    test('catches up missed months from startDate', () {
      final due = RecurrenceMath.dueOccurrences(
        _template(dayOfMonth: 1, startDate: DateTime(2026, 1, 1)),
        RecurrenceFrequency.monthly,
        DateTime(2026, 1, 1),
        DateTime(2026, 4, 15),
      );
      expect(
        due,
        equals([
          DateTime(2026, 1, 1),
          DateTime(2026, 2, 1),
          DateTime(2026, 3, 1),
          DateTime(2026, 4, 1),
        ]),
      );
    });

    test('skips occurrences at or before lastLoggedAt (idempotency)', () {
      final due = RecurrenceMath.dueOccurrences(
        _template(
          dayOfMonth: 1,
          startDate: DateTime(2026, 1, 1),
          lastLoggedAt: DateTime(2026, 2, 1),
        ),
        RecurrenceFrequency.monthly,
        DateTime(2026, 1, 1),
        DateTime(2026, 4, 15),
      );
      // Strictly after the last logged occurrence.
      expect(
        due,
        equals([DateTime(2026, 3, 1), DateTime(2026, 4, 1)]),
      );
    });

    test('inactive templates produce nothing', () {
      final due = RecurrenceMath.dueOccurrences(
        _template(dayOfMonth: 1, active: false),
        RecurrenceFrequency.monthly,
        DateTime(2026, 1, 1),
        DateTime(2026, 4, 15),
      );
      expect(due, isEmpty);
    });

    test('nothing due in the future', () {
      final due = RecurrenceMath.dueOccurrences(
        _template(dayOfMonth: 1, startDate: DateTime(2026, 1, 1)),
        RecurrenceFrequency.monthly,
        DateTime(2026, 1, 1),
        DateTime(2025, 12, 31),
      );
      expect(due, isEmpty);
    });
  });

  group('RecurringTransaction (de)serialization', () {
    test('json round-trip preserves all fields', () {
      final original = _template(
        dayOfMonth: 31,
        frequency: RecurrenceFrequency.quarterly,
        startDate: DateTime(2026, 1, 15),
        endDate: DateTime(2027, 1, 1),
        lastLoggedAt: DateTime(2026, 2, 28),
      );

      final restored = RecurringTransaction.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.amount, original.amount);
      expect(restored.frequency, RecurrenceFrequency.quarterly);
      expect(restored.dayOfMonth, 31);
      expect(restored.startDate, original.startDate);
      expect(restored.endDate, original.endDate);
      expect(restored.lastLoggedAt, original.lastLoggedAt);
      expect(restored.isActive, isTrue);
    });
  });

  group('FinanceService.runDueRecurrences (auto-logging)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FinanceService.instance.clearCache();
    });

    test('logs due transactions, stamps lastLoggedAt, is idempotent',
        () async {
      final service = FinanceService.instance;
      // Due on the 1st of every month; 3 months are in the past.
      await service.addRecurring(_template(
        id: 'auto-1',
        dayOfMonth: 1,
        startDate: DateTime(2026, 1, 1),
      ));

      final until = DateTime(2026, 4, 15);
      final logged = await service.runDueRecurrences(until: until);

      expect(logged, 4); // Jan, Feb, Mar, Apr 1st
      final txns = service.activeTransactions
          .where((t) => t.title == 'Office rent')
          .toList();
      expect(txns.length, 4);
      // All auto-logged entries carry the marker note.
      expect(
        txns.every((t) => t.note == 'Auto-logged from recurring template'),
        isTrue,
      );
      // Bookkeeping advanced to the last occurrence.
      final template = service.activeRecurring.single;
      expect(template.lastLoggedAt, DateTime(2026, 4, 1));

      // Running again is a no-op (idempotent).
      final again = await service.runDueRecurrences(until: until);
      expect(again, 0);
      expect(service.activeTransactions.length, 4);
    });

    test('paused templates do not log', () async {
      final service = FinanceService.instance;
      await service.addRecurring(_template(
        id: 'auto-2',
        dayOfMonth: 1,
        startDate: DateTime(2026, 1, 1),
        active: false,
      ));

      final logged =
          await service.runDueRecurrences(until: DateTime(2026, 3, 1));

      expect(logged, 0);
      expect(service.activeTransactions, isEmpty);
    });
  });

  group('MoneyScreen recurring UI', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FinanceService.instance.clearCache();
    });

    testWidgets('recurring section shows hint and Add action', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MoneyScreen()));
      await tester.pumpAndSettle();

      // The Money tab builds its sections lazily (ListView), so bring the
      // Recurring header into view before asserting on it.
      await tester.scrollUntilVisible(
        find.text('Recurring'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Recurring'), findsOneWidget);
      expect(
        find.textContaining('auto-logged'),
        findsWidgets,
      );

      // Open the recurring form sheet via its stable key.
      await tester.tap(find.byKey(const Key('recurring-add')));
      await tester.pumpAndSettle();

      expect(find.text('New recurring transaction'), findsOneWidget);
      expect(find.text('Day of month'), findsOneWidget);
      expect(find.text('End date (optional)'), findsOneWidget);
    });

    testWidgets('Add Record sheet offers the Repeat monthly toggle',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: MoneyScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Record').first);
      await tester.pumpAndSettle();

      expect(find.text('Repeat monthly'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('Add Record sheet shows Linked document picker for expenses',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      FinanceService.instance.clearCache();

      await tester.pumpWidget(const MaterialApp(home: MoneyScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Record').first);
      await tester.pumpAndSettle();

      // Expense is the default kind — the linked-document picker shows.
      expect(find.text('Linked document (optional)'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);
    });
  });

  group('Renewal payment loop (tier glue)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FinanceService.instance.clearCache();
    });

    test('markAsRenewed with newExpiryDate renews in place', () async {
      final service = DocumentScannerService.instance;
      final original = await service.getItemById('glue-doc');
      expect(original, isNull); // cache empty in test env

      // Seed a document directly through the service.
      final item = ExpiryItem.create(
        id: 'glue-doc',
        displayName: 'Trade licence',
        docType: DocumentTypeRegistry.instance.byEnum(DocumentType.tradeLicence),
        expiresAt: DateTime(2026, 10, 1),
        collectionId: 'personal',
        renewalFee: 500,
      );
      await service.addItem(item);

      final newExpiry = DateTime(2027, 10, 1);
      await service.markAsRenewed('glue-doc', newExpiryDate: newExpiry);

      final renewed = await service.getItemById('glue-doc');
      expect(renewed, isNotNull, reason: 'renewed document stays active');
      expect(renewed!.expiresAt, newExpiry);
      expect(renewed.daysRemaining, greaterThan(0));
    });

    test('markAsRenewed without newExpiryDate archives (legacy behaviour)',
        () async {
      final service = DocumentScannerService.instance;
      final item = ExpiryItem.create(
        id: 'glue-doc-2',
        displayName: 'Old licence',
        docType: DocumentTypeRegistry.instance.byEnum(DocumentType.tradeLicence),
        expiresAt: DateTime(2026, 10, 1),
        collectionId: 'personal',
      );
      await service.addItem(item);

      await service.markAsRenewed('glue-doc-2');

      expect(await service.getItemById('glue-doc-2'), isNull,
          reason: 'archived documents leave the active cache');
    });
  });
}
