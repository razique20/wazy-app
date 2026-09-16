import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Thin wrapper around Supabase Auth.
///
/// Supabase persists the session automatically (secure platform storage via
/// supabase_flutter), so [currentUserId] is available on cold start without
/// any extra work. All data access in this app is scoped by `auth.uid()`
/// through Row Level Security — see supabase/schema.sql.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  bool get isAvailable => SupabaseService.isInitialized;

  Session? get _session => SupabaseService.clientOrNull?.auth.currentSession;

  /// Whether a signed-in session exists (restored automatically on cold
  /// start by supabase_flutter).
  bool get isSignedIn => _session != null;

  /// The authenticated user's id — the value RLS policies compare against
  /// `auth.uid()`. Null when not signed in or Supabase isn't configured.
  String? get currentUserId => _session?.user.id;

  String? get userEmail => _session?.user.email;

  /// Sign in with email + password. Throws [AuthException] on failure with a
  /// user-presentable message.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await SupabaseService.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Create a new account. Email confirmation is controlled by the Supabase
  /// Auth provider settings; if enabled the user must click the link in the
  /// email before signing in (the login screen surfaces that error).
  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await SupabaseService.client.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Send a password-reset email.
  Future<void> sendPasswordReset(String email) async {
    await SupabaseService.client.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    if (!isAvailable) return;
    await SupabaseService.client.auth.signOut();
  }

  /// Listen to auth changes (sign-in, sign-out, token refresh). Used by the
  /// splash screen and router to react to session changes.
  Stream<AuthState> get onAuthStateChange =>
      isAvailable ? SupabaseService.client.auth.onAuthStateChange : const Stream.empty();
}
