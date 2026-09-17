import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uuid/uuid.dart';

import '../models/expiry_item.dart';
import '../models/document_type.dart';
import '../models/document_collection.dart';
import '../models/renewal_record.dart';
import 'auth_service.dart';
import 'collection_service.dart';
import 'doc_sync.dart';
import 'expiry_report.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

/// Persistent store for [ExpiryItem] records backed by Supabase Postgres and
/// offline SharedPreferences local storage.
class DocumentScannerService extends ChangeNotifier {
  DocumentScannerService._();

  static final DocumentScannerService instance = DocumentScannerService._();

  factory DocumentScannerService() => instance;

  static const String _localDocsKey = 'local_documents_v1';
  static const String _outboxKey = 'local_documents_outbox_v1';

  /// Null in local-only mode (unconfigured, or Supabase not initialised —
  /// e.g. unit tests). clientOrNull never throws.
  final _client = SupabaseService.clientOrNull;

  final List<ExpiryItem> _cache = [];

  /// Offline mutation queue (see [DocSync]/[PendingOp]). Mutations made while
  /// offline (or when a write throws) land here and are replayed to Supabase
  /// on the next init/refresh.
  final List<PendingOp> _outbox = [];
  bool _initialized = false;

  /// Load documents from Supabase or local offline storage into the cache.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true; // set first so concurrent callers don't re-enter

    await _loadOutbox();

    // Always hydrate from local storage first so that documents added while
    // offline (or whose Supabase insert failed) survive a restart.  The
    // subsequent _mergeRemote() will reconcile local ↔ remote; without this
    // step the cache is empty and _mergeRemote() has nothing to reconcile.
    await _loadLocal();

    final client = _client;
    final userId = AuthService.instance.currentUserId;
    if (client == null || userId == null) {
      notifyListeners();
      return;
    }

    try {
      final response = await client
          .from('documents')
          .select()
          .eq('owner_id', userId)
          .eq('status', 'active')
          .order('expires_at', ascending: true);

      final remote = response
          .map(_documentRowToExpiryItem)
          .toList();
      await _mergeRemote(remote);
      await _flushOutbox();
      await _saveLocal();
    } catch (_) {
      // Supabase unreachable — stay on the local cache (already loaded above);
      // queued mutations will be flushed on a later refresh.
    }
    notifyListeners();
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_localDocsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        final loaded = list.map((e) {
          final item = ExpiryItem.fromJson(e as Map<String, dynamic>);
          final days = item.expiresAt.difference(DateTime.now()).inDays;
          return item.copyWith(
            daysRemaining: days,
            isExpired: days < 0,
            urgency: UrgencyLevel.fromDays(days),
          );
        }).toList();
        _cache
          ..clear()
          ..addAll(loaded);
      } else {
        _cache.clear();
        await _saveLocal();
      }
    } catch (_) {
      _cache.clear();
    }
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_cache.map((e) => e.toJson()).toList());
      await prefs.setString(_localDocsKey, jsonStr);
    } catch (_) {
      // Local save failed
    }
  }

  /// Documents in the active collection.
  List<ExpiryItem> get _activeItems => _cache
      .where((item) =>
          item.collectionId == DocumentCollectionService.instance.activeCollectionId)
      .toList();

  /// Re-fetch from Supabase (pull-to-refresh, after sign-in, etc.).
  Future<void> refresh() async {
    _initialized = false;
    await init();
  }

  /// Drop all cached data (used on sign-out).
  void clearCache() {
    _cache.clear();
    _initialized = false;
    SharedPreferences.getInstance().then((prefs) => prefs.remove(_localDocsKey));
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Reads
  // ------------------------------------------------------------------

  /// Find document by ID across all collections.
  Future<ExpiryItem?> getItemById(String id) async {
    await _ensureInitialized();
    return _cache.where((item) => item.id == id).firstOrNull;
  }

  /// Active documents in the active collection.
  ///
  /// Pass [includeExpired] to also receive documents that slipped past their
  /// expiry date (still tracked in the DB with status 'expired').
  Future<List<ExpiryItem>> getAllItems({bool includeExpired = false}) async {
    return getAllItemsIn(
      DocumentCollectionService.instance.activeCollectionId,
      includeExpired: includeExpired,
    );
  }

  /// Same as [getAllItems] for an arbitrary collection — lets the expiry
  /// list/search exports run over a collection chosen in the filter sheet
  /// without mutating the app-wide active-collection selection.
  Future<List<ExpiryItem>> getAllItemsIn(
    String collectionId, {
    bool includeExpired = false,
  }) async {
    await _ensureInitialized();
    return List.unmodifiable(
      _cache
          .where((item) =>
              item.collectionId == collectionId &&
              (item.isActive || (includeExpired && item.isExpired)))
          .toList(),
    );
  }

  Future<List<ExpiryItem>> getItemsByType(DocumentTypeMeta type) async {
    await _ensureInitialized();
    return _activeItems
        .where((item) => item.isActive && item.docType.key == type.key)
        .toList();
  }

  Future<List<ExpiryItem>> getItemsDueBefore(DateTime date) async {
    await _ensureInitialized();
    return _activeItems
        .where((item) => item.isActive && item.expiresAt.isBefore(date))
        .toList();
  }

  Future<List<ExpiryItem>> getItemsDueWithinDays(int days) async {
    await _ensureInitialized();
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: days));
    return _activeItems
        .where((item) => item.isActive && item.expiresAt.isBefore(cutoff))
        .toList();
  }

  /// Global text search across every collection: matches document name,
  /// record/document number fields (description, location/authority,
  /// assigned-to), file names, type names and free-form notes.
  /// Case-insensitive; empty query returns everything active.
  Future<List<ExpiryItem>> search(String query) async {
    await _ensureInitialized();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _activeItems.where((i) => i.isActive).toList();

    return _activeItems
        .where((i) => i.isActive && DocumentScannerSearch.matchesQuery(i, q))
        .toList();
  }

  // ------------------------------------------------------------------
  // Writes — remote first, then update local cache and notify
  // ------------------------------------------------------------------

  Future<void> addItem(ExpiryItem item) async {
    await _ensureInitialized();
    // Documents always land in the active collection.
    final scoped = item.copyWith(
      collectionId: DocumentCollectionService.instance.activeCollectionId,
      updatedAt: DateTime.now().toUtc(),
    );
    final row = _expiryItemToDocumentRow(scoped, ownerId: AuthService.instance.currentUserId);

    // Offline-first: cache immediately, then try the server; on failure the
    // mutation is queued and replayed on the next sync.
    _replaceInCache(scoped);
    _enqueueUpsert(scoped);
    final client = _client;
    if (client != null) {
      try {
        await client.from('documents').insert(row);
        _outbox.removeWhere((op) => op.id == scoped.id);
        await _saveOutbox();
      } catch (_) {
        // stays queued
      }
    }

    // Schedule OS-level reminders on the 90/60/30/7-day ladder.
    await NotificationService.instance.scheduleEscalationLadder(
      scoped.id,
      scoped.expiresAt,
      title: scoped.displayName,
    );
    await _saveLocal();
    notifyListeners();
  }

  Future<void> updateItem(ExpiryItem updatedItem) async {
    await _ensureInitialized();
    // Always re-stamp the mutation time: the caller passes a copy of a cached
    // item, and LWW conflict resolution (DocSync.merge) compares updatedAt —
    // an unstamped update would tie with (or lose to) its own remote copy.
    final stamped =
        updatedItem.copyWith(updatedAt: DateTime.now().toUtc());
    final row = _expiryItemToDocumentRow(stamped);

    _replaceInCache(stamped);
    _enqueueUpsert(stamped);
    final client = _client;
    if (client != null) {
      try {
        await client.from('documents').update(row).eq('id', stamped.id);
        _outbox.removeWhere((op) => op.id == stamped.id);
        await _saveOutbox();
      } catch (_) {
        // stays queued
      }
    }
    _replaceInCache(stamped);

    // Re-schedule: replaces the old reminders (stable notification ids)
    // with ones matching the new expiry date.
    await NotificationService.instance.cancelReminders(updatedItem.id);
    await NotificationService.instance.scheduleEscalationLadder(
      updatedItem.id,
      updatedItem.expiresAt,
      title: updatedItem.displayName,
    );
    await _saveLocal();
    notifyListeners();
  }

  Future<void> removeItem(String id) async {
    await _ensureInitialized();
    _enqueueDelete(id);
    final client = _client;
    if (client != null) {
      try {
        await client.from('documents').delete().eq('id', id);
        _outbox.removeWhere((op) => op.id == id);
        await _saveOutbox();
      } catch (_) {
        // stays queued
      }
    }
    await NotificationService.instance.cancelReminders(id);
    _cache.removeWhere((existing) => existing.id == id);
    await _saveLocal();
    notifyListeners();
  }

  /// Synchronous snapshot of the whole cache — for pickers/dropdowns where
  /// a Future would complicate build(). Filter/sort as needed by the caller.
  List<ExpiryItem> getAllItemsSync() => List.unmodifiable(_cache);

  /// Mark a document as renewed.
  ///
  /// When [newExpiryDate], [fee], [renewedBy] or [note] is given, the document is
  /// *renewed in place*: expiry moves forward, a [RenewalRecord] is logged to
  /// [renewalHistory], and OS reminders are rescheduled. When called with no
  /// arguments, the legacy archiving behaviour applies: status 'renewed' is set and
  /// the document leaves the active cache.
  Future<void> markAsRenewed(
    String id, {
    DateTime? newExpiryDate,
    double? fee,
    String? renewedBy,
    String? note,
  }) async {
    await _ensureInitialized();
    final client = _client;

    final index = _cache.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final oldItem = _cache[index];
    final bool renewInPlace = newExpiryDate != null || fee != null || renewedBy != null || note != null;

    if (!renewInPlace) {
      if (client != null) {
        try {
          await client
              .from('documents')
              .update({'status': 'renewed'}).eq('id', id);
        } catch (_) {
          _enqueueDelete(id);
        }
      }
      await NotificationService.instance.cancelReminders(id);
      _cache.removeWhere((existing) => existing.id == id);
      await _saveLocal();
      notifyListeners();
      return;
    }

    final targetExpiry = newExpiryDate ??
        DateTime(
          oldItem.expiresAt.year + 1,
          oldItem.expiresAt.month,
          oldItem.expiresAt.day,
        );
    final days = targetExpiry.difference(DateTime.now()).inDays;
    final record = RenewalRecord(
      id: const Uuid().v4(),
      renewedAt: DateTime.now(),
      previousExpiryDate: oldItem.expiresAt,
      newExpiryDate: targetExpiry,
      fee: fee ?? oldItem.renewalFee,
      renewedBy: renewedBy ?? oldItem.assignedTo ?? 'User',
      note: note ?? 'Document renewed',
    );
    final history = <RenewalRecord>[...(oldItem.renewalHistory ?? []), record];

    final updated = oldItem.copyWith(
      expiresAt: targetExpiry,
      expiryDate: ExpiryItem.formatDate(targetExpiry),
      daysRemaining: days,
      isExpired: days < 0,
      isActive: true,
      urgency: UrgencyLevel.fromDays(days),
      renewalHistory: history,
      updatedAt: DateTime.now().toUtc(),
    );

    _cache[index] = updated;
    _enqueueUpsert(updated);

    if (client != null) {
      try {
        await client.from('documents').update({
          'expires_at': _dateOnly(targetExpiry),
          'status': 'active',
        }).eq('id', id);
        _outbox.removeWhere((op) => op.id == id);
        await _saveOutbox();
      } catch (_) {}
    }

    await NotificationService.instance.cancelReminders(id, customReminderDays: updated.customReminderDays);
    if (!updated.isExpired) {
      await NotificationService.instance.scheduleEscalationLadder(
        id,
        targetExpiry,
        title: updated.displayName,
        customReminderDays: updated.customReminderDays,
      );
    }
    await _saveLocal();
    notifyListeners();
  }

  Future<void> assignTo(String id, String assignee) async {
    await _ensureInitialized();
    final index = _cache.indexWhere((item) => item.id == id);
    if (index != -1) {
      final updated = _cache[index].copyWith(
        assignedTo: assignee,
        updatedAt: DateTime.now().toUtc(),
      );
      _cache[index] = updated;
      _enqueueUpsert(updated);
      final client = _client;
      if (client != null) {
        try {
          await client.from('documents').update({'assigned_to': assignee}).eq('id', id);
          _outbox.removeWhere((op) => op.id == id);
          await _saveOutbox();
        } catch (_) {
          // stays queued
        }
      }
      await _saveLocal();
      notifyListeners();
    }
  }

  Future<void> updateExpiryDate(String id, DateTime newExpiryDate) async {
    await _ensureInitialized();
    final client = _client;

    final index = _cache.indexWhere((item) => item.id == id);
    if (index != -1) {
      final days = newExpiryDate.difference(DateTime.now()).inDays;
      final updated = _cache[index].copyWith(
        expiresAt: newExpiryDate,
        expiryDate: ExpiryItem.formatDate(newExpiryDate),
        daysRemaining: days,
        isExpired: days < 0,
        urgency: UrgencyLevel.fromDays(days),
        updatedAt: DateTime.now().toUtc(),
      );
      _cache[index] = updated;
      _enqueueUpsert(updated);
      if (client != null) {
        try {
          await client.from('documents').update({
            'expires_at': _dateOnly(newExpiryDate),
          }).eq('id', id);
          _outbox.removeWhere((op) => op.id == id);
          await _saveOutbox();
        } catch (_) {
          // stays queued
        }
      }
      await _saveLocal();
      notifyListeners();

      // Keep OS reminders in sync with the new expiry date.
      await NotificationService.instance.cancelReminders(id);
      if (!updated.isExpired) {
        await NotificationService.instance.scheduleEscalationLadder(
          id,
          newExpiryDate,
          title: updated.displayName,
        );
      }
    }
  }

  /// Toggle the reminder-status badge. Writes to the `reminders` table when
  /// Supabase is configured (one row per activation, channel 'push'); the
  /// cache is always updated so the UI works offline too.
  ///
  /// Status 0 cancels the OS-level reminders; any other status (re)schedules
  /// the 90/60/30/7-day ladder for this document.
  Future<void> setReminderStatus(String id, int status) async {
    await _ensureInitialized();
    final client = _client;
    if (client != null && status > 0) {
      final item = _cache.firstWhere(
        (i) => i.id == id,
        orElse: () => throw StateError('Unknown document $id'),
      );
      try {
        await client.from('reminders').insert({
          'document_id': id,
          'remind_at': _dateOnly(item.expiresAt),
          'channel': 'push',
        });
      } catch (_) {
        // Non-fatal: badge still toggles locally.
      }
    }
    final index = _cache.indexWhere((item) => item.id == id);
    if (index != -1) {
      _cache[index] = _cache[index].copyWith(reminderStatus: status);
      await _saveLocal();
      notifyListeners();

      // Keep OS-level reminders in sync with the badge.
      if (status == 0) {
        await NotificationService.instance.cancelReminders(id);
      } else {
        await NotificationService.instance.scheduleEscalationLadder(
          id,
          _cache[index].expiresAt,
          title: _cache[index].displayName,
        );
      }
    }
  }

  // ------------------------------------------------------------------
  // Offline-first sync — outbox + LWW merge (logic in doc_sync.dart)
  // ------------------------------------------------------------------

  /// Reconcile fetched remote rows into the local cache (pull phase).
  ///
  /// Remote rows are fetched WITHOUT a status filter downstream of this
  /// method's contract: a row deleted on another device simply won't appear
  /// here, and [DocSync.merge] turns that into a local drop unless the local
  /// record has unsynced edits.
  Future<void> _mergeRemote(List<ExpiryItem> remote) async {
    final remoteById = {for (final r in remote) r.id: r};

    // 1. Remote rows missing locally → add (pulled from another device),
    //    unless the local outbox has a pending delete for them.
    for (final r in remoteById.values) {
      final local = _cache.where((i) => i.id == r.id).firstOrNull;
      final pendingDelete = _outbox.any((op) => op.id == r.id && op.isDelete);
      if (local == null) {
        if (!pendingDelete) _cache.add(r);
        continue;
      }
      final action = DocSync.merge(
        localUpdatedAt: local.updatedAt,
        remoteUpdatedAt: r.updatedAt,
        localDirty: _outbox.any((op) => op.id == r.id && !op.isDelete),
      );
      switch (action) {
        case MergeAction.takeRemote:
          _cache[_cache.indexWhere((i) => i.id == r.id)] = r;
        case MergeAction.keepLocal:
          _outbox.add(PendingOp.upsert(r.id, _expiryItemToDocumentRow(local)));
        case MergeAction.dropDeleted:
          break; // unreachable here (remote exists); handled below
      }
    }

    // 2. Local rows missing remotely → deleted elsewhere (or this device is
    //    offline). Drop unless the local record has unsynced edits — those
    //    resurrect the row on the next push.
    final remoteIds = remoteById.keys.toSet();
    final staleLocal = _cache
        .where((i) => !remoteIds.contains(i.id) && !_outbox.any((op) => op.id == i.id))
        .map((i) => i.id)
        .toList();
    _cache.removeWhere((i) => staleLocal.contains(i.id));

    _cache.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
  }

  /// Replay queued mutations to Supabase, oldest first. Successful ops are
  /// removed from the outbox; failures keep it for the next flush.
  Future<void> _flushOutbox() async {
    final client = _client;
    if (client == null || _outbox.isEmpty) return;

    final remaining = <PendingOp>[];
    for (final op in _outbox) {
      try {
        if (op.isDelete) {
          await client.from('documents').delete().eq('id', op.id);
        } else {
          await client.from('documents').upsert({
            ...op.item!,
            'owner_id': AuthService.instance.currentUserId,
          });
        }
      } catch (_) {
        remaining.add(op); // network/permission failure — retry later
      }
    }
    _outbox
      ..clear()
      ..addAll(remaining);
    await _saveOutbox();
  }

  void _enqueueUpsert(ExpiryItem item) {
    _outbox.removeWhere((op) => op.id == item.id);
    _outbox.add(PendingOp.upsert(item.id, _expiryItemToDocumentRow(item)));
    _saveOutbox();
  }

  void _enqueueDelete(String id) {
    _outbox.removeWhere((op) => op.id == id);
    _outbox.add(PendingOp.delete(id));
    _saveOutbox();
  }

  Future<void> _loadOutbox() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_outboxKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = jsonDecode(jsonStr) as List<dynamic>;
        _outbox
          ..clear()
          ..addAll(list.map((e) => PendingOp.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {
      _outbox.clear();
    }
  }

  Future<void> _saveOutbox() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _outboxKey,
        jsonEncode(_outbox.map((op) => op.toJson()).toList()),
      );
    } catch (_) {
      // Local save failed — outbox stays in memory for this session.
    }
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  Future<void> _ensureInitialized() async {
    if (!_initialized) await init();
  }

  void _replaceInCache(ExpiryItem item) {
    final index = _cache.indexWhere((existing) => existing.id == item.id);
    if (index != -1) {
      _cache[index] = item;
    } else {
      _cache.add(item);
    }
    _cache.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    _saveLocal();
    notifyListeners();
  }

  static String _dateOnly(DateTime date) =>
      date.toIso8601String().split('T').first;

  // ------------------------------------------------------------------
  // DB row ↔ model conversion
  // ------------------------------------------------------------------

  /// Supabase row → ExpiryItem. Derived fields are recomputed here so callers
  /// always get a consistent object regardless of what's stored.
  ///
  /// Legacy rows with an unknown collection are mapped into the built-in
  /// personal collection so they stay visible.
  ///
  /// NOTE: reads the legacy `company_id` key as a fallback until every
  /// project has run the migration to `collection_id`.
  static ExpiryItem _documentRowToExpiryItem(Map<String, dynamic> row) {
    final docType =
        DocumentTypeRegistry.instance.byKey(row['doc_type'] as String?);

    final expiresAt =
        DateTime.tryParse(row['expires_at'] as String? ?? '') ?? DateTime.now();

    final assignedTo = row['assigned_to'] as String?;
    final renewalFee = (row['renewal_fee'] as num?)?.toDouble();
    final notes = row['notes'] as String?;
    final collectionId = (row['collection_id'] ?? row['company_id']) as String? ??
        DocumentCollection.personalId;

    final days = expiresAt.difference(DateTime.now()).inDays;
    final urgency = UrgencyLevel.fromDays(days);

    return ExpiryItem(
      collectionId: collectionId,
      id: row['id'] as String,
      displayName: row['display_name'] as String? ?? 'Untitled document',
      docType: docType,
      expiryDate: ExpiryItem.formatDate(expiresAt),
      daysRemaining: days,
      isExpired: days < 0,
      isActive: days >= 0 && (row['status'] as String? ?? 'active') == 'active',
      isNotified: false,
      notifiedDays: null,
      description: notes,
      location: 'UAE',
      reminderStatus: _calculateReminderStatusFromDays(days),
      urgency: urgency,
      assignedTo: assignedTo,
      documentDate: null,
      renewalFee: renewalFee,
      renewalSteps: null,
      renewalAuthorities: null,
      renewalWarning: notes ?? defaultWarningFor(docType),
      expiresAt: expiresAt,
      fileName: row['file_name'] as String?,
      filePath: row['file_path'] as String?,
      fileSize: row['file_size'] as int?,
      updatedAt: DateTime.tryParse(
        (row['updated_at_client'] ?? row['updated_at']) as String? ?? '',
      ),
    );
  }

  /// ExpiryItem → Supabase `documents` insert/update row.
  ///
  /// Only persists columns that exist in the schema (see supabase/schema.sql):
  ///   id, collection_id, doc_type, display_name, expires_at, reminder_days,
  ///   status, assigned_to, renewal_fee, notes, file_name, file_path, file_size
  ///
  /// `owner_id` is included on insert; the DB trigger plus RLS policies scope
  /// every row to the authenticated user.
  static Map<String, dynamic> _expiryItemToDocumentRow(
    ExpiryItem item, {
    String? ownerId,
  }) {
    final row = <String, dynamic>{
      'id': item.id,
      'collection_id': item.collectionId,
      'doc_type': item.docType.key,
      'display_name': item.displayName,
      'expires_at': _dateOnly(item.expiresAt),
      'reminder_days': _defaultReminderDays(item.docType),
      'status': item.isExpired ? 'expired' : 'active',
      'assigned_to': item.assignedTo,
      'renewal_fee': item.renewalFee,
      'notes': (item.description != null && item.description!.trim().isNotEmpty)
          ? item.description!.trim()
          : item.renewalWarning,
      'file_name': item.fileName,
      'file_path': item.filePath,
      'file_size': item.fileSize,
    };
    if (item.updatedAt != null) {
      row['updated_at_client'] = item.updatedAt!.toIso8601String();
    }
    if (ownerId != null) row['owner_id'] = ownerId;
    return row;
  }

  static int _calculateReminderStatusFromDays(int daysRemaining) {
    if (daysRemaining <= 7) return 4;
    if (daysRemaining <= 30) return 3;
    if (daysRemaining <= 60) return 2;
    if (daysRemaining <= 90) return 1;
    return 0;
  }

  static int _defaultReminderDays(DocumentTypeMeta type) {
    return type.key == DocumentType.softwareSubscriptions.name ? 14 : 30;
  }

  static String defaultWarningFor(DocumentTypeMeta type) => type.defaultWarning;
}
