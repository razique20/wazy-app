import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finavig/models/document_type.dart';
import 'package:finavig/models/expiry_item.dart';
import 'package:finavig/services/document_scanner_service.dart';
import 'package:finavig/widgets/dialogs/renew_document_dialog.dart';

ExpiryItem _item({
  String id = 'renew-1',
  int inDays = 10,
  String collectionId = 'personal',
}) {
  return ExpiryItem.create(
    id: id,
    displayName: 'Trade Licence',
    docType: DocumentTypeRegistry.instance
        .byEnum(DocumentType.tradeLicence),
    expiresAt: DateTime.now().add(Duration(days: inDays)),
    collectionId: collectionId,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DocumentScannerService.instance.clearCache();
  });

  group('RenewDocumentDialog', () {
    testWidgets('returns the chosen new expiry and defaults to +1 year',
        (tester) async {
      final item = _item();
      RenewDocumentResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showRenewDocumentDialog(context, item);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Dialog shows the current expiry and the +1y default.
      expect(find.text('Renew ${item.displayName}'), findsOneWidget);
      // No file attached yet → the button offers attaching one.
      expect(find.text('Attach document file'), findsOneWidget);

      await tester.tap(find.text('Confirm Renewal'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.newExpiry.year, item.expiresAt.year + 1);
      expect(result!.replacementFile, isNull);
    });

    testWidgets('cancel returns null', (tester) async {
      final item = _item();
      RenewDocumentResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showRenewDocumentDialog(context, item);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // The placeholder was replaced by the dialog's null result.
      expect(result, isNull);
    });
  });

  group('Renewal keeps the document tracked (no archive)', () {
    test('markAsRenewed with a dialog-style result keeps the item active',
        () async {
      final service = DocumentScannerService.instance;
      await service.init();
      final item = _item(id: 'docs-renew');
      await service.addItem(item);

      // What the dialog returns on Confirm (+1y default, no re-upload).
      final result = RenewDocumentResult(
        newExpiry: DateTime(
          item.expiresAt.year + 1,
          item.expiresAt.month,
          item.expiresAt.day,
        ),
        fee: 1500,
        renewedBy: 'Ops',
        note: 'Annual renewal',
      );

      await service.markAsRenewed(
        item.id,
        newExpiryDate: result.newExpiry,
        fee: result.fee,
        renewedBy: result.renewedBy,
        note: result.note,
      );

      final renewed = await service.getItemById(item.id);
      expect(renewed, isNotNull);
      expect(renewed!.isActive, isTrue);
      expect(renewed.expiresAt.year, item.expiresAt.year + 1);
      expect(renewed.renewalHistory, isNotEmpty);
      expect(renewed.renewalHistory!.last.fee, 1500);
    });

    test('legacy no-arg markAsRenewed still archives (kept for money flow)',
        () async {
      final service = DocumentScannerService.instance;
      await service.init();
      await service.addItem(_item(id: 'legacy-1'));

      await service.markAsRenewed('legacy-1');

      expect(await service.getItemById('legacy-1'), isNull);
    });
  });
}
