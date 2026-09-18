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

    group('effectiveRenewalWarning expiry-aware fallback', () {
      final farExpiry = DateTime.now().add(const Duration(days: 365));
      final nearExpiry = DateTime.now().add(const Duration(days: 14));
      final expired = DateTime.now().subtract(const Duration(days: 5));

      DocumentTypeMeta type(DocumentType t) =>
          DocumentTypeRegistry.instance.byEnum(t);

      /// Build via the RAW constructor — the path used by
      /// DocumentScanScreen — which leaves renewalWarning null, unlike
      /// ExpiryItem.create (pre-fills the type's generic blurb).
      ExpiryItem rawItem(
        String id,
        DocumentType t,
        DateTime expiresAt, {
        String? renewalWarning,
      }) {
        final days = expiresAt.difference(DateTime.now()).inDays;
        return ExpiryItem(
          collectionId: 'personal',
          id: id,
          displayName: 'Doc $id',
          docType: type(t),
          expiryDate: ExpiryItem.formatDate(expiresAt),
          daysRemaining: days,
          isExpired: days < 0,
          urgency: UrgencyLevel.fromDays(days),
          expiresAt: expiresAt,
          renewalWarning: renewalWarning,
        );
      }

      test('far from expiry: type blurb + expiry date, never blank', () {
        final item = rawItem('far-doc', DocumentType.visa, farExpiry);
        expect(item.renewalWarning, isNull);

        final text = item.effectiveRenewalWarning;
        expect(text.trim(), isNotEmpty);
        expect(text, contains('Visa expired'));
        expect(text, contains(ExpiryItem.formatDate(farExpiry)));
      });

      test('within 30 days: urgency message with days and date', () {
        final item = rawItem('near-doc', DocumentType.tradeLicence, nearExpiry);
        final text = item.effectiveRenewalWarning;
        // Whole days truncate (14 days away minus time-of-day → 13), so
        // assert against the item's own day count.
        expect(text, contains('${item.daysRemaining} days'));
        expect(item.daysRemaining, inInclusiveRange(13, 14));
        expect(text, contains(ExpiryItem.formatDate(nearExpiry)));
      });

      test('expired: days-ago message', () {
        final item = rawItem('expired-doc', DocumentType.ejari, expired);
        final text = item.effectiveRenewalWarning;
        expect(text, contains('Expired 5 days ago'));
        expect(text, contains(ExpiryItem.formatDate(expired)));
      });

      test('create() pre-filled type blurb is respected as stored text', () {
        final item = ExpiryItem.create(
          id: 'create-doc',
          displayName: 'Work Visa',
          docType: type(DocumentType.visa),
          expiresAt: farExpiry,
        );
        expect(item.effectiveRenewalWarning, equals(item.renewalWarning));
      });

      test('stored warning always wins over the fallback', () {
        final item = rawItem(
          'stored-doc',
          DocumentType.insurance,
          farExpiry,
          renewalWarning: 'Custom underwriter note',
        );
        expect(item.effectiveRenewalWarning, equals('Custom underwriter note'));
      });
    });
  });
}
