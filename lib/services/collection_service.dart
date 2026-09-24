import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_collection.dart';
import '../models/gcc_country.dart';
import 'auth_service.dart';
import 'entitlement_service.dart';
import 'supabase_service.dart';

/// Store for the signed-in user's document collections.
///
/// Every user has exactly one built-in "Personal" collection (their own
/// documents) and may create any number of company collections. One
/// collection is active at a time; the selection is persisted in
/// SharedPreferences and DocumentScannerService scopes reads/writes to it.
///
/// Backed by Supabase (see supabase/schema.sql). Local-only mode: when
/// Supabase isn't configured the service keeps an in-memory list starting
/// with the built-in personal collection, so the app remains fully usable
/// offline.
///
/// A [ChangeNotifier]: fires whenever the collection list or the active
/// selection changes, so screens that mirror the selection (e.g. the
/// Settings tab's "My Collections" section) can stay in sync with switches
/// made elsewhere (e.g. the Home page's collection switcher).
class DocumentCollectionService extends ChangeNotifier {
  DocumentCollectionService._();

  static final DocumentCollectionService instance =
      DocumentCollectionService._();

  factory DocumentCollectionService() => instance;

  static const String _activeIdKey = 'activeCollectionId';

  /// Null in local-only mode (unconfigured, or Supabase not initialised —
  /// e.g. unit tests). clientOrNull never throws.
  final _client = SupabaseService.clientOrNull;

  List<DocumentCollection> _collections = [];
  String _activeId = DocumentCollection.personalId;
  bool _initialized = false;
  bool _entitlementListenerAttached = false;

  /// All collections owned by the user, personal first.
  List<DocumentCollection> get collections => List.unmodifiable(_collections);

  /// Id of the active collection. Synchronous access is safe before [init]
  /// runs — it falls back to the built-in personal collection.
  /// If the active collection is locked due to plan expiry/downgrade, automatically
  /// falls back to the personal collection or first unlocked collection.
  String get activeCollectionId {
    final isLocked = EntitlementService.instance.isCollectionIdLocked(_activeId);
    if (_activeId == DocumentCollection.personalId || !_collections.any((c) => c.id == _activeId) || isLocked) {
      final personal = _collections.where((c) => c.isPersonal).firstOrNull;
      if (personal != null) return personal.id;
      final firstUnlocked = _collections.where((c) => !EntitlementService.instance.isCollectionLocked(c)).firstOrNull;
      if (firstUnlocked != null) return firstUnlocked.id;
      if (_collections.isNotEmpty) return _collections.first.id;
    }
    return _activeId;
  }

  /// Active GCC country based on active collection.
  GccCountry get activeCountry {
    final activeId = activeCollectionId;
    final active = _collections.firstWhere(
      (c) => c.id == activeId,
      orElse: () => const DocumentCollection.personal(),
    );
    return active.country;
  }

  /// Active currency string (e.g. 'AED', 'SAR', 'KWD', 'QAR', 'BHD', 'OMR').
  String get activeCurrency => activeCountry.currency;

  /// The active collection (defaults to Personal).
  Future<DocumentCollection> getActiveCollection() async {
    await _ensureInitialized();
    final currentActiveId = activeCollectionId;
    return _collections.firstWhere(
      (c) => c.id == currentActiveId,
      orElse: () => _collections.isEmpty
          ? const DocumentCollection.personal()
          : _collections.first,
    );
  }

  /// Load the user's collections, ensure the personal one exists, and
  /// restore the persisted active selection.
  Future<void> init() async {
    if (!_entitlementListenerAttached) {
      _entitlementListenerAttached = true;
      EntitlementService.instance.addListener(_onEntitlementsChanged);
    }

    if (_initialized) return;

    final client = _client;
    final userId = AuthService.instance.currentUserId;

    if (client == null || userId == null) {
      _collections = [const DocumentCollection.personal()];
      _activeId = DocumentCollection.personalId;
      _initialized = true;
      await _restoreActiveSelection();
      notifyListeners();
      return;
    }

    try {
      final rows = await client
          .from('collections')
          .select()
          .eq('owner_id', userId)
          .order('created_at', ascending: true);
      _collections = rows.map(_collectionRowToCollection).toList();
    } catch (_) {
      // Supabase unreachable or table missing — fall back to defaults so the
      // app doesn't crash on cold start. Writes will surface errors later.
      _collections = [const DocumentCollection.personal()];
    }

    await _ensurePersonal(userId);
    _initialized = true;
    await _restoreActiveSelection();
    notifyListeners();
  }

  void _onEntitlementsChanged() {
    if (EntitlementService.instance.isCollectionIdLocked(_activeId)) {
      final personal = _collections.where((c) => c.isPersonal).firstOrNull;
      final fallbackId = personal?.id ?? _collections.where((c) => !EntitlementService.instance.isCollectionLocked(c)).firstOrNull?.id ?? DocumentCollection.personalId;
      if (_activeId != fallbackId) {
        _activeId = fallbackId;
        SharedPreferences.getInstance().then((p) => p.setString(_activeIdKey, fallbackId));
        notifyListeners();
      }
    } else {
      notifyListeners();
    }
  }

  /// Make [id] the active collection and persist the choice.
  /// Returns false if the collection cannot be set active or is locked.
  Future<bool> setActive(String id) async {
    await _ensureInitialized();
    var targetId = id;
    if (targetId == DocumentCollection.personalId) {
      final personal = _collections.where((c) => c.isPersonal).firstOrNull;
      if (personal != null) targetId = personal.id;
    }
    if (!_collections.any((c) => c.id == targetId)) return false;
    if (EntitlementService.instance.isCollectionIdLocked(targetId)) return false;
    final changed = _activeId != targetId;
    _activeId = targetId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeIdKey, targetId);
    if (changed) notifyListeners();
    return true;
  }

  /// Create a new company collection named [name] in [countryCode] and return it.
  /// Personal collections cannot be created — there is exactly one.
  Future<DocumentCollection> createCollection(
    String name, {
    String countryCode = 'AE',
  }) async {
    await _ensureInitialized();
    final companyCount = _collections.where((c) => !c.isPersonal).length;
    if (!EntitlementService.instance.canAddCompanyCollections(companyCount)) {
      throw StateError('Plan limit reached for company collections');
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Collection name cannot be empty');
    }
    final code = countryCode.toUpperCase();

    final client = _client;
    final userId = AuthService.instance.currentUserId;

    if (client != null && userId != null) {
      final inserted = await client
          .from('collections')
          .insert({
            'owner_id': userId,
            'name': trimmed,
            'country_code': code,
            'is_personal': false,
          })
          .select()
          .single();
      final collection = _collectionRowToCollection(inserted);
      _collections = [..._collections, collection];
      notifyListeners();
      return collection;
    }

    // Local-only mode: stable pseudo id.
    final collection = DocumentCollection(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      countryCode: code,
    );
    _collections = [..._collections, collection];
    notifyListeners();
    return collection;
  }

  /// Rename a company collection or update its country. The personal collection keeps its name.
  Future<void> renameCollection(
    String id,
    String name, {
    String? countryCode,
  }) async {
    await _ensureInitialized();
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final index = _collections.indexWhere((c) => c.id == id);
    if (index == -1) return;
    if (_collections[index].isPersonal) return;

    final old = _collections[index];
    final newCountry = countryCode?.toUpperCase() ?? old.countryCode;

    final client = _client;
    if (client != null) {
      await client
          .from('collections')
          .update({
            'name': trimmed,
            'country_code': newCountry,
          })
          .eq('id', id);
    }
    _collections[index] = DocumentCollection(
      id: old.id,
      name: trimmed,
      countryCode: newCountry,
      isPersonal: old.isPersonal,
    );
    notifyListeners();
  }

  /// Delete a company collection and all documents inside it (the DB foreign
  /// key cascades). The built-in personal collection can never be deleted;
  /// if the active collection is deleted, fall back to Personal.
  Future<void> deleteCollection(String id) async {
    await _ensureInitialized();
    final target = _collections.where((c) => c.id == id).firstOrNull;
    if (target == null || target.isPersonal) return;

    final client = _client;
    if (client != null) {
      await client.from('collections').delete().eq('id', id);
    }
    _collections = _collections.where((c) => c.id != id).toList();

    if (_activeId == id) {
      await setActive(DocumentCollection.personalId);
    }
    notifyListeners();
  }

  /// Force a re-fetch from Supabase (e.g. after auth state changes).
  Future<void> reset() async {
    _initialized = false;
    _collections = [];
    _activeId = DocumentCollection.personalId;
    await init();
  }

  /// Update the personal collection's country code. Called after signup when
  /// the DB trigger created the row with the default 'AE' but the user chose
  /// a different GCC country.
  Future<void> updatePersonalCountry(String countryCode) async {
    await _ensureInitialized();
    final code = countryCode.toUpperCase();
    final idx = _collections.indexWhere((c) => c.isPersonal);
    if (idx == -1) return;
    final old = _collections[idx];
    if (old.countryCode == code) return; // already correct

    final client = _client;
    if (client != null) {
      await client
          .from('collections')
          .update({'country_code': code})
          .eq('id', old.id);
    }
    _collections[idx] = DocumentCollection(
      id: old.id,
      name: old.name,
      countryCode: code,
      isPersonal: true,
    );
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  Future<void> _ensureInitialized() async {
    if (!_initialized) await init();
  }

  /// Guarantee a personal collection exists. The DB trigger creates one for
  /// new users; this covers accounts created before the schema change and
  /// DB failures during init.
  Future<void> _ensurePersonal(String userId) async {
    if (_collections.any((c) => c.isPersonal)) return;

    // Read the country the user chose during signup (falls back to 'AE'
    // for users who signed up before GCC support was added).
    final prefs = await SharedPreferences.getInstance();
    final userCountry = prefs.getString('userCountry') ?? 'AE';

    final client = _client;
    if (client != null) {
      try {
        final inserted = await client
            .from('collections')
            .insert({
              'owner_id': userId,
              'name': 'Personal',
              'country_code': userCountry,
              'is_personal': true,
            })
            .select()
            .single();
        _collections = [_collectionRowToCollection(inserted), ..._collections];
        return;
      } catch (_) {
        // Fall through to the local default below.
      }
    }
    _collections = [
      DocumentCollection(
        id: DocumentCollection.personalId,
        name: 'Personal',
        countryCode: userCountry,
        isPersonal: true,
      ),
      ..._collections,
    ];
  }

  /// Restore the persisted active selection, validating it still exists and is not locked.
  Future<void> _restoreActiveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_activeIdKey);
    if (stored != null &&
        _collections.any((c) => c.id == stored) &&
        !EntitlementService.instance.isCollectionIdLocked(stored)) {
      _activeId = stored;
    } else {
      final personal = _collections.where((c) => c.isPersonal).firstOrNull;
      final firstUnlocked = _collections.where((c) => !EntitlementService.instance.isCollectionLocked(c)).firstOrNull;
      _activeId = personal?.id ?? firstUnlocked?.id ?? DocumentCollection.personalId;
    }
  }

  /// Supabase row → [DocumentCollection].
  static DocumentCollection _collectionRowToCollection(
    Map<String, dynamic> row,
  ) {
    return DocumentCollection(
      id: row['id'] as String,
      name: row['name'] as String? ?? 'Collection',
      countryCode: (row['country_code'] ?? row['countryCode']) as String? ?? 'AE',
      isPersonal: row['is_personal'] as bool? ?? false,
    );
  }
}
