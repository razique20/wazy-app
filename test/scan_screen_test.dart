import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/models/document_type.dart';
import 'package:finavig/models/expiry_item.dart';
import 'package:finavig/screens/document_scan_screen.dart';

void main() {
  testWidgets('DocumentScanScreen renders its form without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DocumentScanScreen()));
    await tester.pump();

    expect(
      find.text(
        'Upload your document file and enter expiry details to start tracking.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tap to select & attach document file'), findsOneWidget);
    expect(find.text('Document Title *'), findsOneWidget);
  });

  testWidgets('Document category dropdown opens and lists built-in types', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DocumentScanScreen()));
    await tester.pump();

    await tester.tap(find.text('Document Category'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Built-in types appear in the open menu (trade licence is the selected
    // value and its item is also rendered as the dropdown's selected child).
    // Aliased types render as "Official Name (everyday name)".
    expect(find.text('Trade Licence (Business / Commercial Licence)'),
        findsWidgets);
    // Select a different type and confirm the field updates.
    await tester.tap(find.text('Ejari (Tenancy Contract)').last);
    await tester.pumpAndSettle();
    expect(find.text('Ejari (Tenancy Contract)'), findsOneWidget);
  });

  testWidgets('Category dropdown shows everyday aliases like Mulkiya', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DocumentScanScreen()));
    await tester.pump();

    await tester.tap(find.text('Document Category'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // Vehicle Registration is listed with its everyday name.
    expect(find.text('Vehicle Registration (Mulkiya)'), findsWidgets);
    expect(find.text('Labour Documents (Labour / Establishment Card)'),
        findsWidgets);
    // Types whose display name is already the everyday name have no alias.
    expect(find.text('Passport'), findsWidgets);
  });

  testWidgets('DocumentScanScreen in edit mode pre-populates fields and shows update button', (
    tester,
  ) async {
    final existingItem = ExpiryItem(
      id: 'doc-edit-123',
      collectionId: 'personal-1',
      displayName: 'My Dubai Trade Licence',
      docType: DocumentTypeRegistry.instance.byEnum(DocumentType.tradeLicence),
      expiryDate: '15 Oct 2027',
      daysRemaining: 365,
      isExpired: false,
      location: 'DET (Dubai Economy & Tourism)',
      renewalFee: 1500.0,
      urgency: UrgencyLevel.low,
      description: 'License #12345',
      expiresAt: DateTime.now().add(const Duration(days: 365)),
    );

    await tester.pumpWidget(MaterialApp(
      home: DocumentScanScreen(initialItem: existingItem),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Edit document'), findsOneWidget);
    expect(find.text('My Dubai Trade Licence'), findsOneWidget);
    expect(find.text('Update document'), findsOneWidget);
  });
}
