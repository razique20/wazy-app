import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/expiry_item.dart';
import '../models/document_type.dart';
import '../models/document_collection.dart';
import 'auth_service.dart';
import 'collection_service.dart';
import 'supabase_service.dart';

/// Persistent store for [ExpiryItem] records backed by Supabase Postgres and
/// offline SharedPreferences local storage.
class DocumentScannerService extends ChangeNotifier {
  DocumentScannerService._();

  static final DocumentScannerService instance = DocumentScannerService._();

  factory DocumentScannerService() => instance;

  static const String _localDocsKey = 'local_documents_v1';

  final _client = SupabaseService.hasCredentials ? SupabaseService.client : null;

  final List<ExpiryItem> _cache = [];
  bool _initialized = false;

  /// Load documents from Supabase or local offline storage into the cache.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true; // set first so concurrent callers don't re-enter

    final client = _client;
    final userId = AuthService.instance.currentUserId;
    if (client == null || userId == null) {
      await _loadLocal();
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

      _cache
        ..clear()
        ..addAll(response.map(_documentRowToExpiryItem).toList());
      await _saveLocal();
    } catch (_) {
      // Supabase unreachable or table missing — fall back to local offline storage
      await _loadLocal();
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
    await _ensureInitialized();
    return List.unmodifiable(
      _activeItems
          .where((item) =>
              item.isActive || (includeExpired && item.isExpired))
          .toList(),
    );
  }

  Future<List<ExpiryItem>> getItemsByType(DocumentType type) async {
    await _ensureInitialized();
    return _activeItems
        .where((item) => item.isActive && item.docType == type)
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

  // ------------------------------------------------------------------
  // Writes — remote first, then update local cache and notify
  // ------------------------------------------------------------------

  Future<void> addItem(ExpiryItem item) async {
    await _ensureInitialized();
    final client = _client;
    // Documents always land in the active collection.
    final scoped = item.copyWith(
      collectionId: DocumentCollectionService.instance.activeCollectionId,
    );
    final row = _expiryItemToDocumentRow(scoped, ownerId: AuthService.instance.currentUserId);

    if (client != null) {
      await client.from('documents').insert(row);
    }
    _replaceInCache(scoped);
  }

  Future<void> updateItem(ExpiryItem updatedItem) async {
    await _ensureInitialized();
    final client = _client;
    final row = _expiryItemToDocumentRow(updatedItem);

    if (client != null) {
      await client.from('documents').update(row).eq('id', updatedItem.id);
    }
    _replaceInCache(updatedItem);
  }

  Future<void> removeItem(String id) async {
    await _ensureInitialized();
    final client = _client;
    if (client != null) {
      await client.from('documents').delete().eq('id', id);
    }
    _cache.removeWhere((existing) => existing.id == id);
    await _saveLocal();
    notifyListeners();
  }

  Future<void> markAsRenewed(String id) async {
    await _ensureInitialized();
    final client = _client;
    if (client != null) {
      await client.from('documents').update({'status': 'renewed'}).eq('id', id);
    }
    _cache.removeWhere((existing) => existing.id == id);
    await _saveLocal();
    notifyListeners();
  }

  Future<void> assignTo(String id, String assignee) async {
    await _ensureInitialized();
    final client = _client;
    if (client != null) {
      await client.from('documents').update({'assigned_to': assignee}).eq('id', id);
    }
    final index = _cache.indexWhere((item) => item.id == id);
    if (index != -1) {
      _cache[index] = _cache[index].copyWith(assignedTo: assignee);
      await _saveLocal();
      notifyListeners();
    }
  }

  Future<void> updateExpiryDate(String id, DateTime newExpiryDate) async {
    await _ensureInitialized();
    final client = _client;
    if (client != null) {
      await client.from('documents').update({
        'expires_at': _dateOnly(newExpiryDate),
      }).eq('id', id);
    }

    final index = _cache.indexWhere((item) => item.id == id);
    if (index != -1) {
      final days = DateTime.now().difference(newExpiryDate).inDays;
      _cache[index] = _cache[index].copyWith(
        expiresAt: newExpiryDate,
        expiryDate: ExpiryItem.formatDate(newExpiryDate),
        daysRemaining: -days, // positive days remaining
        isExpired: newExpiryDate.isBefore(DateTime.now()),
        urgency: UrgencyLevel.fromDays(
          newExpiryDate.difference(DateTime.now()).inDays,
        ),
      );
      await _saveLocal();
      notifyListeners();
    }
  }

  /// Toggle the reminder-status badge. Writes to the `reminders` table when
  /// Supabase is configured (one row per activation, channel 'push'); the
  /// cache is always updated so the UI works offline too.
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
    final docType = DocumentType.values.firstWhere(
      (e) => e.name == row['doc_type'] as String?,
      orElse: () => DocumentType.tradeLicence,
    );

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
      'doc_type': item.docType.name,
      'display_name': item.displayName,
      'expires_at': _dateOnly(item.expiresAt),
      'reminder_days': _defaultReminderDays(item.docType),
      'status': item.isExpired ? 'expired' : 'active',
      'assigned_to': item.assignedTo,
      'renewal_fee': item.renewalFee,
      'notes': item.renewalWarning,
      'file_name': item.fileName,
      'file_path': item.filePath,
      'file_size': item.fileSize,
    };
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

  static int _defaultReminderDays(DocumentType type) {
    return type == DocumentType.softwareSubscriptions ? 14 : 30;
  }

  static String defaultWarningFor(DocumentType type) {
    switch (type) {
      case DocumentType.tradeLicence:
        return 'Licence expired → Activity suspended. Renewal required within 30 days or activity stops.';
      case DocumentType.ejari:
        return 'Ejari expired → Contract invalid. Cannot renew without valid Ejari.';
      case DocumentType.visa:
        return 'Visa expired → Employee must leave UAE or apply for renewal. Grace period: 6 months.';
      case DocumentType.insurance:
        return 'Insurance lapsed → No coverage. Claims denied.';
      case DocumentType.contracts:
        return 'Contract expired → Legal terms may revert to month-to-month.';
      case DocumentType.domainNames:
        return 'Domain expired → Website and email down. Redemption period: 30 days.';
      case DocumentType.softwareSubscriptions:
        return 'Subscription expired → Service suspended. Access lost until renewal.';
      case DocumentType.emiratesId:
        return 'Emirates ID expired → Cannot travel or access services.';
      case DocumentType.labourDocuments:
        return 'Labour card expired → Work permit invalid. Employee cannot work.';
      case DocumentType.vehicleRegistration:
        return 'Registration expired → Fine AED 500+. Vehicle may be impounded.';
      case DocumentType.permits:
        return 'Permit expired → Business activity not authorized.';
      case DocumentType.certificates:
        return 'Certificate expired → Professional status may be invalidated.';
      case DocumentType.supplierAgreements:
        return 'Agreement expired → Supplier terms may change. Review before expiry.';
    }
  }
}
