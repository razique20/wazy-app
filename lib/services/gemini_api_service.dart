import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal Gemini API client for on-demand LLM calls (executive summary
/// polish pass, future AI features).
///
/// The API key is stored in SharedPreferences (set at runtime from a debug
/// or settings screen) — it never ships in the binary, unlike Supabase's
/// publishable anon key which is fine to embed.
class GeminiApiService {
  GeminiApiService._();

  static final GeminiApiService instance = GeminiApiService._();

  static const String _keyPrefsKey = 'gemini.apiKey.v1';
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Default model — Flash tier is fast and cheap for short summaries.
  static const String defaultModel = 'gemini-2.0-flash';

  String? _apiKey;
  bool _loaded = false;

  /// True when an API key is configured — gates the LLM polish pass.
  bool get isConfigured => (_apiKey ?? '').isNotEmpty;

  /// Load a persisted key (call once at app start; safe to call again).
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _apiKey = prefs.getString(_keyPrefsKey);
    } catch (_) {
      _apiKey = null;
    }
  }

  /// Configure with a key and persist it.
  Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPrefsKey, _apiKey!);
  }

  /// Remove the stored key.
  Future<void> clearApiKey() async {
    _apiKey = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPrefsKey);
  }

  /// Simple text generation. Throws on HTTP/network errors; returns the
  /// generated text (may be empty).
  Future<String> generateContent(
    String prompt, {
    String model = defaultModel,
  }) async {
    final key = _apiKey;
    if (key == null || key.isEmpty) {
      throw StateError('Gemini API key not configured');
    }

    final uri = Uri.parse('$_endpoint/$model:generateContent?key=$key');
    final body = jsonEncode({
      'contents': [
        {
          'parts': [{'text': prompt}]
        }
      ],
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': 300,
      },
    });

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('Gemini API error ${response.statusCode}: ${response.body}');
        throw HttpException('Gemini API returned ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return '';
      final content = (candidates.first as Map<String, dynamic>)['content'];
      if (content is! Map<String, dynamic>) return '';
      final parts = content['parts'] as List?;
      if (parts == null || parts.isEmpty) return '';
      final text = parts
          .whereType<Map<String, dynamic>>()
          .map((p) => p['text'])
          .whereType<String>()
          .join();
      return text.trim();
    } on FormatException catch (e) {
      throw HttpException('Gemini API response parse error: $e');
    }
  }
}

/// Simple HTTP exception carrying a short user-presentable message.
class HttpException implements Exception {
  final String message;
  const HttpException(this.message);

  @override
  String toString() => message;
}
