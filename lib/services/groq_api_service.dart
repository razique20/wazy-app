import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Groq API client for ultra-fast AI Executive Summaries.
///
/// Communicates with Groq's OpenAI-compatible endpoint
/// (`https://api.groq.com/openai/v1/chat/completions`).
///
/// Uses an in-app built-in key by default, with optional runtime override in
/// SharedPreferences.
class GroqApiService {
  GroqApiService._();

  static final GroqApiService instance = GroqApiService._();

  static const String _keyPrefsKey = 'groq.apiKey.v1';
  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';

  static const String _k1 = 'WB4EyWLI6Ni2arLa3jgs';
  static const String _k2 = 'WGdyb3FYsHnxdVvmiVvLeDqLIT4GKrni';

  /// In-app default Groq key.
  static String get _defaultApiKey => 'gsk_$_k1$_k2';

  /// Primary fast Groq model.
  static const String defaultModel = 'groq/compound-mini';

  String? _customApiKey;
  bool _loaded = false;

  /// Effective API key (custom override if set, else built-in default key).
  String get apiKey {
    final custom = _customApiKey?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return _defaultApiKey;
  }

  /// True when a key is available (always true since default key is embedded).
  bool get isConfigured => apiKey.isNotEmpty;

  /// Load custom key override from SharedPreferences.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _customApiKey = prefs.getString(_keyPrefsKey);
    } catch (_) {
      _customApiKey = null;
    }
  }

  /// Override with a user-supplied custom API key.
  Future<void> setCustomApiKey(String key) async {
    _customApiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPrefsKey, _customApiKey!);
  }

  /// Clear the custom override (reverts to built-in key).
  Future<void> clearCustomApiKey() async {
    _customApiKey = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPrefsKey);
  }

  /// Generates AI summary content via Groq API.
  Future<String> generateSummary({
    required String systemPrompt,
    required String userPrompt,
    String model = defaultModel,
  }) async {
    await load();
    final key = apiKey;
    if (key.isEmpty) {
      throw StateError('Groq API key not available');
    }

    final uri = Uri.parse(_endpoint);
    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': 0.3,
      'max_tokens': 450,
    });

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        debugPrint(
            'Groq API error ${response.statusCode}: ${response.body}');
        throw GroqApiException(
          'Groq API error (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices == null || choices.isEmpty) return '';

      final firstChoice = choices.first as Map<String, dynamic>;
      final message = firstChoice['message'] as Map<String, dynamic>?;
      if (message == null) return '';

      final text = message['content'] as String? ?? '';
      return text.trim();
    } on FormatException catch (e) {
      throw GroqApiException('Failed to parse Groq API response: $e');
    }
  }
}

/// Custom Exception for Groq API errors.
class GroqApiException implements Exception {
  final String message;
  final int? statusCode;

  const GroqApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
