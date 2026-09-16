/// Central credentials file — the single source of truth for all API
/// credentials used by the app.
///
/// Replaces the previous `--dart-define-from-file=.env.local` build-time
/// injection: edit the values below and rebuild, no env file needed.
///
/// NOTE: values here are compiled into the app binary. That is fine for the
/// anon (publishable) Supabase key, but never put a service_role key or any
/// other server-only secret in this file.
class AppCredentials {
  AppCredentials._();

  // ── Supabase ────────────────────────────────────────────────────────────
  /// Your Supabase project URL, e.g. 'https://YOUR-PROJECT-ref.supabase.co'.
  static const String supabaseUrl = 'https://jxyzmnaqukxvrcwolkil.supabase.co';

  /// Your Supabase anon (publishable) key.
  static const String supabaseAnonKey =
      'sb_publishable_GgyDJs0On_xdoFr4QLxlWA_wyRlktjf';

  // ── Future credentials go here ──────────────────────────────────────────
  // Add new credentials below following the same pattern.
}
