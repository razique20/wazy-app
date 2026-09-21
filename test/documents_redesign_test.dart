import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wazy/screens/documents_screen.dart';
import 'package:wazy/services/document_scanner_service.dart';
import 'package:wazy/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // The scanner service caches documents in a singleton — clear it so
    // seeded prefs from one test don't leak into the next.
    DocumentScannerService.instance.clearCache();
  });

  Future<void> pumpDocuments(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: WazyTheme.light(), home: const DocumentsScreen()),
    );
    // _loadData: collection + items from the (empty) local cache.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('renders hero header and rounded content sheet', (tester) async {
    await pumpDocuments(tester);

    // Hero header content — compact: title, one status line, no greeting.
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('All on track · 0 tracked'), findsOneWidget);
    expect(find.textContaining('Good morning'), findsNothing);

    // Action pills (Filter/Sort/Add) in the hero.
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Sort'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);

    // Sheet content: search, status chips, insight tiles.
    expect(find.text('Search documents…'), findsOneWidget);
    expect(find.text('All (0)'), findsOneWidget);
    expect(find.text('Next due'), findsOneWidget);
    expect(find.text('Upcoming fees'), findsOneWidget);

    // The old layout's AppBar title is gone — the hero carries it now.
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('status chips filter the document list', (tester) async {
    final soon = DateTime.now().add(const Duration(days: 3));
    final far = DateTime.now().add(const Duration(days: 200));
    String docJson(String id, DateTime d) {
      final y = d.year;
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '{"collectionId":"personal","id":"$id",'
          '"displayName":"Doc $id","docType":"drivingLicence",'
          '"expiryDate":"$y-$m-$day","daysRemaining":${d.difference(DateTime.now()).inDays},'
          '"isActive":true,"urgencyPriority":0,"expiresAt":"${d.toIso8601String()}"}';
    }

    SharedPreferences.setMockInitialValues({
      'local_documents_v1': jsonEncode([
        jsonDecode(docJson('a', soon)),
        jsonDecode(docJson('b', far)),
      ]),
    });

    await pumpDocuments(tester);

    // Both documents are listed; the hero status line reflects the total.
    expect(find.text('Doc a'), findsOneWidget);
    expect(find.text('Doc b'), findsOneWidget);
    expect(find.textContaining('· 2 tracked'), findsOneWidget);

    // Tap the Critical chip → only the soon document remains.
    await tester.tap(find.textContaining('Critical'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Doc a'), findsOneWidget);
    expect(find.text('Doc b'), findsNothing);
  });

  testWidgets('sort bottom sheet reorders the list', (tester) async {
    final nameA = DateTime.now().add(const Duration(days: 10));
    final nameB = DateTime.now().add(const Duration(days: 5));
    String docJson(String id, String name, DateTime d) {
      final y = d.year;
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '{"collectionId":"personal","id":"$id",'
          '"displayName":"$name","docType":"drivingLicence",'
          '"expiryDate":"$y-$m-$day",'
          '"daysRemaining":${d.difference(DateTime.now()).inDays},'
          '"isActive":true,"urgencyPriority":0,"expiresAt":"${d.toIso8601String()}"}';
    }

    SharedPreferences.setMockInitialValues({
      'local_documents_v1': jsonEncode([
        jsonDecode(docJson('a', 'Alpha', nameA)),
        jsonDecode(docJson('b', 'Beta', nameB)),
      ]),
    });

    await pumpDocuments(tester);

    // Default sort is due date: Beta (5d) comes before Alpha (10d).
    expect(
      tester.getTopLeft(find.text('Alpha')).dy >
          tester.getTopLeft(find.text('Beta')).dy,
      isTrue,
    );

    // Open the sort sheet and pick Name.
    await tester.tap(find.text('Sort'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Name'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Alpha now precedes Beta.
    expect(
      tester.getTopLeft(find.text('Alpha')).dy <
          tester.getTopLeft(find.text('Beta')).dy,
      isTrue,
    );
  });
}
