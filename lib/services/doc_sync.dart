/// Pure (UI-free, I/O-free) offline-first sync logic for documents.
///
/// The local cache is the source of truth for the UI; Supabase is synced to
/// in the background. Three pieces live here:
///
/// 1. [PendingOp] — a queued mutation that couldn't reach the server yet
///    (upsert / delete), persisted as JSON by the scanner service.
/// 2. [merge] — last-writer-wins merge of a remote row against the local
///    cache, using `updated_at` as the tiebreaker. Ties go to remote (the
///    server is authoritative for identical timestamps); unsynced local
///    edits always win so offline work is never silently discarded.
/// 3. [planPush] — diff local ids vs the server id set to decide which
///    records must be pushed.
///
/// Keeping this pure makes the conflict rules unit-testable without a
/// Supabase instance.
library;

/// A queued offline mutation.
///
/// Stored as `{"kind": "upsert"|"delete", "id": ..., "item": {...}}`.
/// Upserts collapse: queueing two edits for the same document keeps only
/// the latest snapshot. A delete removes the whole entry (including an
/// offline insert — the record never existed server-side).
class PendingOp {
  final String kind; // 'upsert' | 'delete'
  final String id;
  final Map<String, dynamic>? item; // non-null for upserts

  const PendingOp.upsert(this.id, Map<String, dynamic> this.item)
      : kind = 'upsert';

  const PendingOp.delete(this.id)
      : kind = 'delete',
        item = null;

  bool get isDelete => kind == 'delete';

  factory PendingOp.fromJson(Map<String, dynamic> json) =>
      json['kind'] == 'delete'
          ? PendingOp.delete(json['id'] as String)
          : PendingOp.upsert(
              json['id'] as String,
              (json['item'] as Map<String, dynamic>).cast<String, dynamic>(),
            );

  Map<String, dynamic> toJson() => kind == 'delete'
      ? {'kind': 'delete', 'id': id}
      : {'kind': 'upsert', 'id': id, 'item': item};

  @override
  String toString() => 'PendingOp($kind $id)';
}

/// Outcome of merging one remote row into the local cache.
enum MergeAction { keepLocal, takeRemote, dropDeleted }

/// The push/pull plan for a sync round.
class SyncPlan {
  final List<String> pushIds;
  final List<String> pullIds;
  const SyncPlan({required this.pushIds, required this.pullIds});
}

class DocSync {
  DocSync._();

  /// Merge decision for a remote row against the local record.
  ///
  /// Rules (last-writer-wins on `updated_at`):
  /// * local is dirty (unsynced edit) → keep local, caller queues a push
  /// * remote newer → take remote
  /// * local newer → keep local
  /// * equal / missing timestamps → remote wins (server authoritative)
  ///
  /// [remoteDeleted] means the row no longer exists server-side. Then the
  /// local record is dropped unless it has unsynced local edits (keep and
  /// push — the delete from another device raced with an edit here; the
  /// edit resurrects the row server-side on the next push).
  static MergeAction merge({
    required DateTime? localUpdatedAt,
    required DateTime? remoteUpdatedAt,
    bool localDirty = false,
    bool remoteDeleted = false,
  }) {
    if (localDirty) {
      return remoteDeleted ? MergeAction.keepLocal : MergeAction.keepLocal;
    }
    if (remoteDeleted) return MergeAction.dropDeleted;
    if (remoteUpdatedAt == null) return MergeAction.takeRemote;
    if (localUpdatedAt == null) return MergeAction.takeRemote;
    if (remoteUpdatedAt.isAfter(localUpdatedAt)) return MergeAction.takeRemote;
    if (localUpdatedAt.isAfter(remoteUpdatedAt)) return MergeAction.keepLocal;
    return MergeAction.takeRemote; // tie → remote
  }

  /// Diff local ids (with dirty flags) against the server id set.
  ///
  /// * dirty local ids → push (offline edits)
  /// * local ids missing server-side → push (created offline, or deleted
  ///   remotely — callers should double-check with a pull before pushing
  ///   creations to avoid resurrecting remotely deleted rows; see [merge])
  /// * server ids missing locally → pull (added from another device)
  static SyncPlan planPush({
    required Map<String, bool> localDirty, // id → isDirty
    required Set<String> remoteIds,
  }) {
    final push = <String>[];
    final pull = <String>[];
    for (final entry in localDirty.entries) {
      if (entry.value || !remoteIds.contains(entry.key)) push.add(entry.key);
    }
    final localIds = localDirty.keys.toSet();
    for (final id in remoteIds) {
      if (!localIds.contains(id)) pull.add(id);
    }
    return SyncPlan(pushIds: push, pullIds: pull);
  }
}
