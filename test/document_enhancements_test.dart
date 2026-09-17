import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wazy/models/document_type.dart';
import 'package:wazy/models/expiry_item.dart';
import 'package:wazy/models/renewal_record.dart';
import 'package:wazy/services/document_scanner_service.dart';
import 'package:wazy/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Document Enhancements: Renewal History & Reminder Overrides', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await DocumentScannerService.instance.init();
    });

    test('RenewalRecord JSON round-trip serialization', () {
      final now = DateTime.now();
      final prev = DateTime(2026, 3, 12);
      final next = DateTime(2027, 3, 12);

      final record = RenewalRecord(
        id: 'rec-1',
        renewedAt: now,
        previousExpiryDate: prev,
        newExpiryDate: next,
        fee: 1500.0,
        renewedBy: 'Razique',
        note: 'Annual trade licence renewal',
      );

      final json = record.toJson();
      final restored = RenewalRecord.fromJson(json);

      expect(restored.id, equals('rec-1'));
      expect(restored.fee, equals(1500.0));
      expect(restored.renewedBy, equals('Razique'));
      expect(restored.note, equals('Annual trade licence renewal'));
      expect(restored.formattedPreviousExpiry, contains('2026'));
      expect(restored.formattedNewExpiry, contains('2027'));
    });

    test('markAsRenewed appends a RenewalRecord entry to renewalHistory', () async {
      final service = DocumentScannerService.instance;
      final docId = 'doc-history-test-1';
      final initialExpiry = DateTime(2026, 5, 20);

      final item = ExpiryItem.create(
        id: docId,
        displayName: 'Dubai Ejari',
        docType: DocumentTypeRegistry.instance.byEnum(DocumentType.ejari),
        expiresAt: initialExpiry,
        renewalFee: 2200.0,
      );

      await service.addItem(item);

      final nextExpiry = DateTime(2027, 5, 20);
      await service.markAsRenewed(
        docId,
        newExpiryDate: nextExpiry,
        fee: 2500.0,
        renewedBy: 'Facilities Manager',
        note: 'Ejari renewed with ejari.ae',
      );

      final updated = await service.getItemById(docId);
      expect(updated, isNotNull);
      expect(updated!.renewalHistory, isNotNull);
      expect(updated.renewalHistory!.length, equals(1));

      final firstRecord = updated.renewalHistory!.first;
      expect(firstRecord.fee, equals(2500.0));
      expect(firstRecord.renewedBy, equals('Facilities Manager'));
      expect(firstRecord.note, equals('Ejari renewed with ejari.ae'));
      expect(firstRecord.previousExpiryDate, equals(initialExpiry));
      expect(firstRecord.newExpiryDate, equals(nextExpiry));
    });

    test('ExpiryItem customReminderDays schedules custom notification offsets', () {
      final customDays = [45, 15, 3];
      final expires = DateTime.now().add(const Duration(days: 100));
      final item = ExpiryItem.create(
        id: 'custom-reminders-doc',
        displayName: 'Vehicle Mulkiya',
        docType: DocumentTypeRegistry.instance.byEnum(DocumentType.vehicleRegistration),
        expiresAt: expires,
      ).copyWith(customReminderDays: customDays);

      expect(item.customReminderDays, equals([45, 15, 3]));

      final fireDate45 = NotificationService.fireDateFor(expires, 45);
      final expectedDate = expires.subtract(const Duration(days: 45));
      expect(fireDate45.day, equals(expectedDate.day));
      expect(fireDate45.month, equals(expectedDate.month));
    });
  });
}
