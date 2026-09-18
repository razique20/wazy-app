import 'dart:convert';

import 'package:flutter/material.dart' show IconData, Color;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_type.dart';
import 'auth_service.dart';
import 'supabase_service.dart';

/// Persistence for user-defined document types.
///
/// Supabase-backed when configured (table `custom_document_types`), with a
/// SharedPreferences fallback so the feature works in local-only mode. The
/// in-memory [DocumentTypeRegistry] is kept in sync — call [init] after sign-in
/// and [reset] on sign-out.
class CustomDocumentTypeService {
  CustomDocumentTypeService._();

  static final CustomDocumentTypeService instance =
      CustomDocumentTypeService._();

  factory CustomDocumentTypeService() => instance;

  static const String _localKey = 'custom_document_types_v1';

  /// Null in local-only mode (unconfigured, or Supabase not initialised —
  /// e.g. unit tests). clientOrNull never throws.
  final _client = SupabaseService.clientOrNull;

  bool _initialized = false;

  /// Load persisted custom types into the registry (Supabase first, local
  /// fallback on error or when unconfigured).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final client = _client;
    final userId = AuthService.instance.currentUserId;
    if (client != null && userId != null) {
      try {
        final rows = await client
            .from('custom_document_types')
            .select()
            .eq('owner_id', userId)
            .order('created_at', ascending: true);
        for (final row in rows) {
          _registerFromRow(Map<String, dynamic>.from(row as Map));
        }
        return;
      } catch (_) {
        // Table missing or unreachable — fall back to local storage.
      }
    }
    await _loadLocal();
  }

  /// Force a re-fetch (auth state changed).
  Future<void> reset() async {
    _initialized = false;
    DocumentTypeRegistry.instance.reset();
    await init();
  }

  /// Create a custom type, persist it, and return the stored metadata.
  Future<DocumentTypeMeta> create({
    required String name,
    IconData? icon,
    Color? color,
    String? renewalAuthority,
    int typicalRenewalDays = 365,
  }) async {
    await _ensureInitialized();

    final meta = DocumentTypeRegistry.instance.register(
      name: name,
      icon: icon,
      color: color,
      renewalAuthority: renewalAuthority,
      typicalRenewalDays: typicalRenewalDays,
    );

    final client = _client;
    final userId = AuthService.instance.currentUserId;
    if (client != null && userId != null) {
      try {
        // Persist with the generated uuid so the registry key stays stable
        // across sessions (`custom-<uuid>`). Keys are 'custom-<uuid>'.
        await client.from('custom_document_types').insert({
          'id': meta.key.substring('custom-'.length),
          'owner_id': userId,
          'name': meta.displayName,
          'renewal_authority': meta.renewalAuthority,
          'renewal_days': meta.typicalRenewalDays,
        });
      } catch (_) {
        // Non-fatal: registry already holds it; local copy below still works.
      }
    }

    await _saveLocal();
    return meta;
  }

  /// Delete a custom type and its persisted row.
  Future<void> delete(String key) async {
    await _ensureInitialized();
    DocumentTypeRegistry.instance.removeCustom(key);

    final client = _client;
    if (client != null && key.startsWith('custom-')) {
      try {
        await client
            .from('custom_document_types')
            .delete()
            .eq('id', key.replaceFirst('custom-', ''));
      } catch (_) {
        // Non-fatal.
      }
    }
    await _saveLocal();
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  Future<void> _ensureInitialized() async {
    if (!_initialized) await init();
  }

  void _registerFromRow(Map<String, dynamic> row) {
    try {
      // Re-register with the row's stable DB id so the registry key stays
      // 'custom-<uuid>' across sign-out → sign-in. Without this a fresh key
      // would be generated and documents whose doc_type references the old
      // key would silently resolve to the trade-licence fallback.
      DocumentTypeRegistry.instance.register(
        name: row['name'] as String? ?? '',
        key: row['id'] == null
            ? null
            : '${DocumentTypeRegistry.customKeyPrefix}${row['id']}',
        renewalAuthority: row['renewal_authority'] as String?,
        typicalRenewalDays: (row['renewal_days'] as num?)?.toInt() ?? 365,
      );
    } on ArgumentError {
      // Duplicate of an already-registered name (e.g. re-login) — skip.
    }
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey);
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List<dynamic>;
      for (final entry in list) {
        final map = Map<String, dynamic>.from(entry as Map);
        try {
          // Restore the stored key so documents referencing 'custom-<uuid>'
          // still resolve after a restart (same rationale as _registerFromRow).
          final storedKey = map['key'] as String?;
          DocumentTypeRegistry.instance.register(
            name: map['name'] as String? ?? '',
            key: storedKey,
            renewalAuthority: map['renewalAuthority'] as String?,
            typicalRenewalDays:
                (map['typicalRenewalDays'] as num?)?.toInt() ?? 365,
          );
        } on ArgumentError {
          // Duplicate — skip.
        }
      }
    } catch (_) {
      // Corrupt local data — start empty.
    }
  }

  Future<void> _saveLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customs = DocumentTypeRegistry.instance.all
          .where((t) => t.isCustom)
          .map((t) => {
                'key': t.key,
                'name': t.displayName,
                'renewalAuthority': t.renewalAuthority,
                'typicalRenewalDays': t.typicalRenewalDays,
              })
          .toList();
      await prefs.setString(_localKey, jsonEncode(customs));
    } catch (_) {
      // Local save failed — non-fatal.
    }
  }
}
