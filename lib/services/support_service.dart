import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'supabase_service.dart';

/// Represents a user support ticket or feature/tracking option request.
class SupportRequestItem {
  final String id;
  final String? userId;
  final String? userEmail;
  final String requestType; // 'tracking_option_request', 'support_request', 'feature_request', 'bug_report'
  final String title;
  final String description;
  final String status; // 'open', 'in_progress', 'resolved'
  final String? adminNotes;
  final DateTime createdAt;

  const SupportRequestItem({
    required this.id,
    this.userId,
    this.userEmail,
    required this.requestType,
    required this.title,
    required this.description,
    required this.status,
    this.adminNotes,
    required this.createdAt,
  });

  String get typeLabel {
    switch (requestType) {
      case 'tracking_option_request':
        return 'Tracking Option';
      case 'feature_request':
        return 'Feature Request';
      case 'bug_report':
        return 'Bug Report';
      case 'support_request':
      default:
        return 'Support Ticket';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'user_email': userEmail,
        'request_type': requestType,
        'title': title,
        'description': description,
        'status': status,
        'admin_notes': adminNotes,
        'created_at': createdAt.toIso8601String(),
      };

  factory SupportRequestItem.fromJson(Map<String, dynamic> json) {
    return SupportRequestItem(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String?,
      userEmail: json['user_email'] as String?,
      requestType: json['request_type'] as String? ?? 'tracking_option_request',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      adminNotes: json['admin_notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Service that handles creating and tracking user support & tracking requests.
/// Syncs with Supabase `support_requests` table with local device caching.
class SupportService {
  SupportService._();

  static final SupportService instance = SupportService._();

  static const String _localPrefsKey = 'wazy.support_requests.v1';

  List<SupportRequestItem> _cachedRequests = const [];
  List<SupportRequestItem> get cachedRequests => _cachedRequests;

  /// Submit a new support / tracking option request.
  Future<({bool success, String? message})> submitRequest({
    required String title,
    required String description,
    required String requestType,
  }) async {
    final userId = AuthService.instance.currentUserId;
    final userEmail = AuthService.instance.userEmail ?? 'guest@wazy.app';
    final now = DateTime.now();

    final newItem = SupportRequestItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      userEmail: userEmail,
      requestType: requestType,
      title: title.trim(),
      description: description.trim(),
      status: 'open',
      createdAt: now,
    );

    var syncedToSupabase = false;

    // 1. Save to Supabase if connected
    final client = SupabaseService.clientOrNull;
    if (client != null) {
      try {
        final inserted = await client.from('support_requests').insert({
          'user_id': userId,
          'user_email': userEmail,
          'request_type': requestType,
          'title': title.trim(),
          'description': description.trim(),
          'status': 'open',
        }).select().maybeSingle();

        if (inserted != null) {
          syncedToSupabase = true;
        }
      } catch (e) {
        debugPrint('Supabase support request insert failed (using local save): $e');
      }
    }

    // 2. Save to local SharedPreferences cache
    try {
      final list = await fetchUserRequests();
      final updatedList = [newItem, ...list];
      _cachedRequests = updatedList;

      final prefs = await SharedPreferences.getInstance();
      final jsonList = updatedList.map((e) => e.toJson()).toList();
      await prefs.setString(_localPrefsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Local SharedPreferences save support request failed: $e');
    }

    return (
      success: true,
      message: syncedToSupabase
          ? 'Your request has been submitted to support team.'
          : 'Your request has been saved locally and queued.',
    );
  }

  /// Fetch user support requests (queries Supabase if available, falls back to local cache).
  Future<List<SupportRequestItem>> fetchUserRequests() async {
    final userId = AuthService.instance.currentUserId;
    final client = SupabaseService.clientOrNull;

    // 1. Try Supabase
    if (client != null && userId != null && userId.isNotEmpty) {
      try {
        final rows = await client
            .from('support_requests')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false);

        if (rows is List) {
          final items = rows
              .map((r) => SupportRequestItem.fromJson(r as Map<String, dynamic>))
              .toList();
          _cachedRequests = items;

          // Sync to SharedPreferences for offline reading
          try {
            final prefs = await SharedPreferences.getInstance();
            final jsonList = items.map((e) => e.toJson()).toList();
            await prefs.setString(_localPrefsKey, jsonEncode(jsonList));
          } catch (_) {}

          return items;
        }
      } catch (e) {
        debugPrint('Supabase fetchUserRequests failed (using local fallback): $e');
      }
    }

    // 2. Fallback to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_localPrefsKey);
      if (stored != null && stored.trim().isNotEmpty) {
        final decoded = jsonDecode(stored) as List<dynamic>;
        final items = decoded
            .map((e) => SupportRequestItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _cachedRequests = items;
        return items;
      }
    } catch (e) {
      debugPrint('SharedPreferences fetchUserRequests failed: $e');
    }

    return _cachedRequests;
  }
}
