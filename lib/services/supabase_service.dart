import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton Supabase client initialised once at app startup.
///
/// Credentials are injected at build time via `--dart-define`:
/// ```bash
/// flutter run --dart-define-from-file=.env.local
/// ```
/// (copy `.env.example` → `.env.local` and fill in your project values —
/// `.env.local` is gitignored).
///
/// The anon (publishable) key is safe to bundle in the app binary. Never use
/// the service_role key in the client.
class SupabaseService {
  static Supabase? _instance;

  /// True when real credentials were supplied via --dart-define.
  ///
  /// When false the app still runs, but auth and DB calls fail gracefully
  /// (services fall back to in-memory defaults) instead of throwing against
  /// the placeholder URL.
  static bool get hasCredentials {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_ANON_KEY');
    return url.isNotEmpty &&
        key.isNotEmpty &&
        !url.contains('YOUR-PROJECT') &&
        !key.contains('your-anon');
  }

  /// Must be called once before any other services, ideally in [main].
  static Future<void> initialize() async {
    if (!hasCredentials) return;

    _instance ??= await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL'),
      publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
  }

  /// The shared Supabase client. Throws if credentials are missing or
  /// [initialize] hasn't been called — callers should check
  /// [hasCredentials] first when they intend to degrade gracefully.
  static SupabaseClient get client {
    final instance = _instance;
    if (instance == null) {
      throw StateError(
        'Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY '
        'via --dart-define (see .env.example).',
      );
    }
    return instance.client;
  }

  static bool get isInitialized => _instance != null;

  /// Clear the cached instance — useful in tests only.
  static void reset() {
    _instance = null;
  }
}
