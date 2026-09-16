import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_credentials.dart';

/// Singleton Supabase client initialised once at app startup.
///
/// Credentials live in [AppCredentials] (lib/config/app_credentials.dart).
/// Edit the constants there and rebuild — no env file or --dart-define
/// needed.
///
/// The anon (publishable) key is safe to bundle in the app binary. Never use
/// the service_role key in the client.
class SupabaseService {
  static Supabase? _instance;

  /// True when real credentials have been filled in [AppCredentials].
  ///
  /// When false the app still runs, but auth and DB calls fail gracefully
  /// (services fall back to in-memory defaults) instead of throwing against
  /// the placeholder URL.
  static bool get hasCredentials {
    const url = AppCredentials.supabaseUrl;
    const key = AppCredentials.supabaseAnonKey;
    return url.isNotEmpty &&
        key.isNotEmpty &&
        !url.contains('YOUR-PROJECT') &&
        !key.contains('your-anon');
  }

  /// Must be called once before any other services, ideally in [main].
  static Future<void> initialize() async {
    if (!hasCredentials) return;

    _instance ??= await Supabase.initialize(
      url: AppCredentials.supabaseUrl,
      publishableKey: AppCredentials.supabaseAnonKey,
    );
  }

  /// The shared Supabase client. Throws if credentials are missing or
  /// [initialize] hasn't been called — callers should check
  /// [hasCredentials] first when they intend to degrade gracefully.
  static SupabaseClient get client {
    final instance = _instance;
    if (instance == null) {
      throw StateError(
        'Supabase is not configured. Fill in supabaseUrl and supabaseAnonKey '
        'in lib/config/app_credentials.dart.',
      );
    }
    return instance.client;
  }

  /// The shared Supabase client, or null when Supabase isn't configured or
  /// [initialize] hasn't run yet. Use this where services should degrade
  /// gracefully to local-only mode (unit tests, offline mode); use [client]
  /// where absence is a programming error.
  static SupabaseClient? get clientOrNull => _instance?.client;

  static bool get isInitialized => _instance != null;

  /// Clear the cached instance — useful in tests only.
  static void reset() {
    _instance = null;
  }
}
