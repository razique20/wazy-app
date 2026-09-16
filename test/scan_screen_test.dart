import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wazy/models/document_type.dart';
import 'package:wazy/screens/document_scan_screen.dart';

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

    await tester.tap(find.text('Document Category'));
    await tester.pumpAndSettle();

    // Built-in types appear in the open menu (trade licence is the selected
    // value and its item is also rendered as the dropdown's selected child).
    expect(find.text('Trade Licence'), findsWidgets);
    // Select a different type and confirm the field updates.
    await tester.tap(find.text('Ejari').last);
    await tester.pumpAndSettle();
    expect(find.text('Ejari'), findsOneWidget);
  });
}
