import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_collection.dart';
import 'auth_service.dart';
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
class DocumentCollectionService {
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

  /// All collections owned by the user, personal first.
  List<DocumentCollection> get collections => List.unmodifiable(_collections);

  /// Id of the active collection. Synchronous access is safe before [init]
  /// runs — it falls back to the built-in personal collection.
  String get activeCollectionId {
    if (_activeId == DocumentCollection.personalId || !_collections.any((c) => c.id == _activeId)) {
      final personal = _collections.where((c) => c.isPersonal).firstOrNull;
      if (personal != null) return personal.id;
      if (_collections.isNotEmpty) return _collections.first.id;
    }
    return _activeId;
  }

  /// The active collection (defaults to Personal).
  Future<DocumentCollection> getActiveCollection() async {
    await _ensureInitialized();
    return _collections.firstWhere(
      (c) => c.id == _activeId,
      orElse: () => _collections.isEmpty
          ? const DocumentCollection.personal()
          : _collections.first,
    );
  }

  /// Load the user's collections, ensure the personal one exists, and
  /// restore the persisted active selection.
  Future<void> init() async {
    if (_initialized) return;

    final client = _client;
    final userId = AuthService.instance.currentUserId;

    if (client == null || userId == null) {
      _collections = [const DocumentCollection.personal()];
      _activeId = DocumentCollection.personalId;
      _initialized = true;
      await _restoreActiveSelection();
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
  }

  /// Make [id] the active collection and persist the choice.
  Future<void> setActive(String id) async {
    await _ensureInitialized();
    var targetId = id;
    if (targetId == DocumentCollection.personalId) {
      final personal = _collections.where((c) => c.isPersonal).firstOrNull;
      if (personal != null) targetId = personal.id;
    }
    if (!_collections.any((c) => c.id == targetId)) return;
    _activeId = targetId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeIdKey, targetId);
  }

  /// Create a new company collection named [name] and return it.
  /// Personal collections cannot be created — there is exactly one.
  Future<DocumentCollection> createCollection(String name) async {
    await _ensureInitialized();
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Collection name cannot be empty');
    }

    final client = _client;
    final userId = AuthService.instance.currentUserId;

    if (client != null && userId != null) {
      final inserted = await client
          .from('collections')
          .insert({
            'owner_id': userId,
            'name': trimmed,
            'is_personal': false,
          })
          .select()
          .single();
      final collection = _collectionRowToCollection(inserted);
      _collections = [..._collections, collection];
      return collection;
    }

    // Local-only mode: stable pseudo id.
    final collection = DocumentCollection(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
    );
    _collections = [..._collections, collection];
    return collection;
  }

  /// Rename a company collection. The personal collection keeps its name.
  Future<void> renameCollection(String id, String name) async {
    await _ensureInitialized();
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final index = _collections.indexWhere((c) => c.id == id);
    if (index == -1) return;
    if (_collections[index].isPersonal) return;

    final client = _client;
    if (client != null) {
      await client.from('collections').update({'name': trimmed}).eq('id', id);
    }
    final old = _collections[index];
    _collections[index] = DocumentCollection(
      id: old.id,
      name: trimmed,
      isPersonal: old.isPersonal,
    );
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
  }

  /// Force a re-fetch from Supabase (e.g. after auth state changes).
  Future<void> reset() async {
    _initialized = false;
    _collections = [];
    _activeId = DocumentCollection.personalId;
    await init();
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

    final client = _client;
    if (client != null) {
      try {
        final inserted = await client
            .from('collections')
            .insert({
              'owner_id': userId,
              'name': 'Personal',
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
    _collections = [const DocumentCollection.personal(), ..._collections];
  }

  /// Restore the persisted active selection, validating it still exists.
  Future<void> _restoreActiveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_activeIdKey);
    if (stored != null && _collections.any((c) => c.id == stored)) {
      _activeId = stored;
    } else {
      final personal = _collections.where((c) => c.isPersonal).firstOrNull;
      _activeId = personal?.id ?? _collections.firstOrNull?.id ?? DocumentCollection.personalId;
    }
  }

  /// Supabase row → [DocumentCollection].
  static DocumentCollection _collectionRowToCollection(
    Map<String, dynamic> row,
  ) {
    return DocumentCollection(
      id: row['id'] as String,
      name: row['name'] as String? ?? 'Collection',
      isPersonal: row['is_personal'] as bool? ?? false,
    );
  }
}
