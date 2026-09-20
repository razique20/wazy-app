import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wazy/models/document_collection.dart';
import 'package:wazy/models/document_type.dart';
import 'package:wazy/models/expiry_item.dart';
import 'package:wazy/screens/expiry_list_screen.dart';
import 'package:wazy/screens/global_search_screen.dart';
import 'package:wazy/services/document_scanner_service.dart';
import 'package:wazy/services/entitlement_service.dart';
import 'package:wazy/services/expiry_report.dart';

ExpiryItem _item({
  required String id,
  required String name,
  DateTime? expires,
  String? notes,
  String? assignee,
  String? fileName,
  String? collectionId,
  DocumentType type = DocumentType.insurance,
  double? fee,
}) {
  return ExpiryItem.create(
    id: id,
    displayName: name,
    docType: DocumentTypeRegistry.instance.byEnum(type),
    expiresAt: expires ?? DateTime.now().add(const Duration(days: 30)),
    description: notes,
    fileName: fileName,
    collectionId: collectionId,
    renewalFee: fee,
  ).copyWith(assignedTo: assignee);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DocumentScannerSearch.matchesQuery (global search rules)', () {
    final doc = _item(
      id: '1',
      name: 'Al Mansoori Trade Licence',
      notes: 'Licence no. 773001 — DED Dubai',
      assignee: 'Sarah Khan',
      fileName: 'licence-2026.pdf',
      type: DocumentType.tradeLicence,
    );

    test('matches display name, case-insensitively', () {
      expect(DocumentScannerSearch.matchesQuery(doc, 'mansoori'), isTrue);
    });

    test('matches record numbers inside notes', () {
      expect(DocumentScannerSearch.matchesQuery(doc, '773001'), isTrue);
    });

    test('matches notes text', () {
      expect(DocumentScannerSearch.matchesQuery(doc, 'ded dubai'), isTrue);
    });

    test('matches assignee and file name', () {
      expect(DocumentScannerSearch.matchesQuery(doc, 'sarah'), isTrue);
      expect(DocumentScannerSearch.matchesQuery(doc, 'licence-2026'), isTrue);
    });

    test('matches type display name', () {
      expect(DocumentScannerSearch.matchesQuery(doc, 'trade licence'), isTrue);
    });

    test('no match on unrelated needle', () {
      expect(DocumentScannerSearch.matchesQuery(doc, 'ejari'), isFalse);
    });

    test('empty query matches everything', () {
      expect(DocumentScannerSearch.matchesQuery(doc, ''), isTrue);
      expect(DocumentScannerSearch.matchesQuery(doc, '   '), isTrue);
    });
  });

  group('ExpiryFilterSpec.apply', () {
    final docs = [
      _item(id: 'a', name: 'Licence A', type: DocumentType.tradeLicence,
          expires: DateTime.now().add(const Duration(days: 5)), collectionId: 'co'),
      _item(id: 'b', name: 'Visa B', type: DocumentType.visa,
          expires: DateTime.now().add(const Duration(days: 45)), fee: 900),
      _item(id: 'c', name: 'Insurance C', type: DocumentType.insurance,
          expires: DateTime.now().add(const Duration(days: 200)), fee: 5000),
      _item(id: 'd', name: 'Old Permit', type: DocumentType.permits,
          expires: DateTime.now().subtract(const Duration(days: 10))),
    ];

    test('default shows only active docs sorted by due date', () {
      final out = ExpiryFilterSpec.apply(docs, ExpiryFilterSpec.all);
      expect(out.map((i) => i.id), equals(['a', 'b', 'c'])); // d is expired
    });

    test('type filter', () {
      final out = ExpiryFilterSpec.apply(
        docs,
        ExpiryFilterSpec.all.copyWith(
          docType: DocumentTypeRegistry.instance.byEnum(DocumentType.visa),
        ),
      );
      expect(out.map((i) => i.id), equals(['b']));
    });

    test('urgency filter matches by tier priority', () {
      final out = ExpiryFilterSpec.apply(
        docs,
        ExpiryFilterSpec.all.copyWith(urgency: UrgencyLevel.critical),
      );
      expect(out.map((i) => i.id), equals(['a'])); // 5 days → critical
    });

    test('collection filter', () {
      final out = ExpiryFilterSpec.apply(
        docs,
        ExpiryFilterSpec.all.copyWith(collectionId: 'co'),
      );
      expect(out.map((i) => i.id), equals(['a']));
    });

    test('days-remaining window', () {
      final out = ExpiryFilterSpec.apply(
        docs,
        ExpiryFilterSpec.all.copyWith(daysMin: 8, daysMax: 60),
      );
      expect(out.map((i) => i.id), equals(['b']));
    });

    test('status=expired shows only expired docs, exempt from days window', () {
      final out = ExpiryFilterSpec.apply(
        docs,
        ExpiryFilterSpec.all.copyWith(status: ExpiryStatusFilter.expired),
      );
      expect(out.map((i) => i.id), equals(['d'])); // -10 days, outside 0..730
    });

    test('status=all shows active and expired, sorted by due date', () {
      final out = ExpiryFilterSpec.apply(
        docs,
        ExpiryFilterSpec.all.copyWith(status: ExpiryStatusFilter.all),
      );
      expect(out.map((i) => i.id), equals(['d', 'a', 'b', 'c']));
    });

    test('status=expired still honours type and collection filters', () {
      final out = ExpiryFilterSpec.apply(
        docs,
        ExpiryFilterSpec.all.copyWith(
          status: ExpiryStatusFilter.expired,
          docType: DocumentTypeRegistry.instance.byEnum(DocumentType.insurance),
        ),
      );
      expect(out, isEmpty);
    });

    test('query filter reuses global search rules', () {
      final out = ExpiryFilterSpec.apply(
        docs,
        ExpiryFilterSpec.all.copyWith(query: 'insurance'),
      );
      expect(out.map((i) => i.id), equals(['c']));
    });

    test('sorting: name asc', () {
      final out = ExpiryFilterSpec.apply(
        docs,
        ExpiryFilterSpec.all.copyWith(
          sortMode: ExpirySortMode.name,
          status: ExpiryStatusFilter.all,
        ),
      );
      expect(
        out.map((i) => i.displayName).toList(),
        equals(['Insurance C', 'Licence A', 'Old Permit', 'Visa B']),
      );
    });

    test('sorting: fee high → low, then due date tiebreak', () {
      final out = ExpiryFilterSpec.apply(
        docs,
        ExpiryFilterSpec.all.copyWith(sortMode: ExpirySortMode.fee),
      );
      expect(out.map((i) => i.id), equals(['c', 'b', 'a']));
    });

    test('sorting: due date latest first', () {
      final out = ExpiryFilterSpec.apply(
        docs,
        ExpiryFilterSpec.all.copyWith(sortMode: ExpirySortMode.dueDateDesc),
      );
      expect(out.map((i) => i.id), equals(['c', 'b', 'a']));
    });

    test('filters compose (AND)', () {
      final out = ExpiryFilterSpec.apply(
        docs,
        ExpiryFilterSpec.all.copyWith(
          collectionId: DocumentCollection.personalId,
          daysMin: 8,
        ),
      );
      // a is in 'co'; b (45d) and c (200d) are personal; both fit the window.
      expect(out.map((i) => i.id), equals(['b', 'c']));
    });

    test('hasRestrictions reflects every dimension', () {
      expect(ExpiryFilterSpec.all.hasRestrictions, isFalse);
      expect(ExpiryFilterSpec.all.copyWith(query: 'x').hasRestrictions, isTrue);
      expect(
        ExpiryFilterSpec.all.copyWith(status: ExpiryStatusFilter.all)
            .hasRestrictions,
        isTrue,
      );
    });

    test('copyWith can clear a dimension with an explicit null', () {
      final withType = ExpiryFilterSpec.all.copyWith(
        docType: DocumentTypeRegistry.instance.byEnum(DocumentType.visa),
      );
      expect(withType.docType, isNotNull);
      expect(withType.copyWith(docType: null).docType, isNull);
      // Omitted dimension is preserved.
      expect(withType.copyWith(daysMin: 3).docType, isNotNull);
    });
  });

  group('ExpiryListScreen (offline local cache)', () {
    const cacheKey = 'local_documents_v1';

    Future<void> seedCache(List<ExpiryItem> items) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        cacheKey,
        jsonEncode(items.map((i) => i.toJson()).toList()),
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      DocumentScannerService.instance.clearCache();
    });

    testWidgets('renders active documents from the local cache', (tester) async {
      await seedCache([
        _item(id: 'x1', name: 'Fresh Visa', type: DocumentType.visa),
      ]);

      await tester.pumpWidget(const MaterialApp(home: ExpiryListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Fresh Visa'), findsOneWidget);
    });

    testWidgets('status filter: expired documents appear via the filter sheet',
        (tester) async {
      await seedCache([
        _item(id: 'x1', name: 'Fresh Visa', type: DocumentType.visa),
        _item(
          id: 'x2',
          name: 'Old Licence',
          type: DocumentType.tradeLicence,
          expires: DateTime.now().subtract(const Duration(days: 10)),
        ),
      ]);

      await tester.pumpWidget(const MaterialApp(home: ExpiryListScreen()));
      await tester.pumpAndSettle();

      // Default (active only): expired doc hidden.
      expect(find.text('Fresh Visa'), findsOneWidget);
      expect(find.text('Old Licence'), findsNothing);

      // Open the filter sheet and pick "Expired".
      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Expired'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Expired'));
      await tester.pumpAndSettle();

      // Now only the expired document is listed (active one hidden), even
      // though its days-remaining is outside the default 0–730 window.
      expect(find.text('Old Licence'), findsOneWidget);
      expect(find.text('Fresh Visa'), findsNothing);
    });

    testWidgets('export entry point is reachable', (tester) async {
      // Report export is Plus-gated (Track 1): run this test on the Plus
      // override tier so the export sheet opens instead of the paywall.
      SharedPreferences.setMockInitialValues({
        EntitlementService.tierOverrideKey: 'plus',
      });
      EntitlementService.instance.reset();
      await EntitlementService.instance.refresh();

      await seedCache([
        _item(id: 'x1', name: 'Fresh Visa', type: DocumentType.visa),
      ]);

      await tester.pumpWidget(const MaterialApp(home: ExpiryListScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.ios_share));
      await tester.pumpAndSettle();

      expect(find.text('Export as CSV'), findsOneWidget);
      expect(find.text('Export as PDF'), findsOneWidget);
    });
  });

  group('GlobalSearchScreen (offline local cache)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      DocumentScannerService.instance.clearCache();
      // Isolate from tier overrides left by other groups.
      EntitlementService.instance.reset();
    });

    testWidgets('finds documents by record number in notes', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final doc = _item(
        id: 's1',
        name: 'Company Visa File',
        notes: 'File no. 1994-5566',
        type: DocumentType.visa,
        expires: DateTime.now().add(const Duration(days: 120)),
      );
      await prefs.setString(
        'local_documents_v1',
        jsonEncode([doc.toJson()]),
      );

      await tester.pumpWidget(const MaterialApp(home: GlobalSearchScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Company Visa File'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1994-5566');
      // Advance past the 250ms search debounce, then let the async search run.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Company Visa File'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'no-such-thing');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Nothing found'), findsOneWidget);
    });
  });
}
