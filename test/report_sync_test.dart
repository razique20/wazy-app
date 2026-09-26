import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/models/document_type.dart';
import 'package:finavig/models/expiry_item.dart';
import 'package:finavig/services/doc_sync.dart';
import 'package:finavig/services/expiry_report.dart';

ExpiryItem _item({
  required String id,
  required String name,
  DateTime? expires,
  DateTime? updatedAt,
  double? fee,
  String? notes,
}) {
  final now = DateTime.now();
  final expiry = expires ?? now.add(const Duration(days: 30));
  return ExpiryItem.create(
    id: id,
    displayName: name,
    docType: DocumentTypeRegistry.instance.byEnum(DocumentType.insurance),
    expiresAt: expiry,
    renewalFee: fee,
    renewalWarning: notes,
  ).copyWith(updatedAt: updatedAt);
}

void main() {
  group('ExpiryReport', () {
    test('toCsv emits header and sorted rows with escaping', () {
      final items = [
        _item(id: 'a', name: 'Plain name', fee: 1500, expires: DateTime(2027, 1, 15)),
        _item(
          id: 'b',
          name: 'Comma, "quoted"',
          notes: 'line1\nline2',
          expires: DateTime(2026, 12, 1),
        ),
      ];

      final csv = ExpiryReport.toCsv(items);
      final lines = csv.trim().split('\n');

      expect(lines.first, equals(ExpiryReport.header.join(',')));
      // The notes cell of the first row contains a quoted newline
      // (RFC-4180-legal, Excel/Sheets parse it back), so the CSV carries 4
      // physical lines for header + 2 logical rows.
      expect(lines.length, equals(4));
      expect(csv, contains('"Comma, ""quoted"""'));
      expect(csv, contains('"line1\nline2"'));
      expect(csv, contains('Plain name'));
      expect(csv, contains('1500.00'));
    });

    test('rows sanitise non-Latin-1 characters for the PDF fonts', () {
      final items = [
        _item(id: 'x', name: 'Licence — Dubai ‘VIP’', expires: DateTime(2027, 3, 1)),
      ];
      final row = ExpiryReport.rows(items).single;
      expect(row.first, equals('Licence - Dubai \'VIP\''));
    });

    test('rows compute status buckets', () {
      final now = DateTime.now();
      final items = [
        _item(id: '1', name: 'soon', expires: now.add(const Duration(days: 3))),
        _item(id: '2', name: 'month', expires: now.add(const Duration(days: 20))),
        _item(id: '3', name: 'later', expires: now.add(const Duration(days: 100))),
      ];
      final rows = ExpiryReport.rows(items);
      expect(rows[0][4], equals('Critical'));
      expect(rows[1][4], equals('Due soon'));
      expect(rows[2][4], equals('On track'));
    });
  });

  group('DocSync.merge (LWW conflict resolution)', () {
    final t1 = DateTime(2026, 9, 1, 10);
    final t2 = DateTime(2026, 9, 1, 11);

    test('remote newer wins', () {
      expect(
        DocSync.merge(localUpdatedAt: t1, remoteUpdatedAt: t2),
        equals(MergeAction.takeRemote),
      );
    });

    test('local newer keeps local', () {
      expect(
        DocSync.merge(localUpdatedAt: t2, remoteUpdatedAt: t1),
        equals(MergeAction.keepLocal),
      );
    });

    test('equal timestamps → remote wins (server authoritative)', () {
      expect(
        DocSync.merge(localUpdatedAt: t1, remoteUpdatedAt: t1),
        equals(MergeAction.takeRemote),
      );
    });

    test('missing timestamps → remote wins', () {
      expect(
        DocSync.merge(localUpdatedAt: null, remoteUpdatedAt: t1),
        equals(MergeAction.takeRemote),
      );
      expect(
        DocSync.merge(localUpdatedAt: t1, remoteUpdatedAt: null),
        equals(MergeAction.takeRemote),
      );
    });

    test('dirty local never loses to remote (offline edits preserved)', () {
      expect(
        DocSync.merge(
          localUpdatedAt: t1,
          remoteUpdatedAt: t2,
          localDirty: true,
        ),
        equals(MergeAction.keepLocal),
      );
    });

    test('remote deletion drops clean local rows', () {
      expect(
        DocSync.merge(localUpdatedAt: t1, remoteUpdatedAt: t1, remoteDeleted: true),
        equals(MergeAction.dropDeleted),
      );
    });

    test('remote deletion does NOT drop dirty local rows (edit resurrects)', () {
      expect(
        DocSync.merge(
          localUpdatedAt: t1,
          remoteUpdatedAt: t1,
          localDirty: true,
          remoteDeleted: true,
        ),
        equals(MergeAction.keepLocal),
      );
    });
  });

  group('DocSync.planPush', () {
    test('dirty and offline-created ids are pushed; clean and remote-only ids are not', () {
      final plan = DocSync.planPush(
        localDirty: {'a': false, 'b': true, 'c': false, 'e': false},
        remoteIds: {'a', 'c', 'd'},
      );
      // b is dirty → push (offline edit); e is missing server-side → push
      // (offline creation); a and c are clean and present remotely → nothing
      // to push; d exists only remotely → pull.
      expect(plan.pushIds, containsAll(['b', 'e']));
      expect(plan.pushIds, isNot(contains('a')));
      expect(plan.pushIds, isNot(contains('c')));
      expect(plan.pullIds, equals(['d']));
    });
  });

  group('PendingOp serialization', () {
    test('upsert round-trips and collapses by id in the outbox contract', () {
      final op = PendingOp.upsert('id1', {'display_name': 'Test'});
      final restored = PendingOp.fromJson(op.toJson() as Map<String, dynamic>);
      expect(restored.kind, equals('upsert'));
      expect(restored.id, equals('id1'));
      expect(restored.item, equals({'display_name': 'Test'}));
    });

    test('delete round-trips', () {
      final op = PendingOp.delete('id2');
      final restored = PendingOp.fromJson(op.toJson() as Map<String, dynamic>);
      expect(restored.isDelete, isTrue);
      expect(restored.id, equals('id2'));
    });
  });
}
