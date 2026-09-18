/// Central configuration for public-facing links used across the app
/// (Terms, Privacy, Support, Website, WhatsApp, email).
///
/// Placeholder values point to the intended production destinations — update
/// the constants here when the pages go live and every screen follows.
class AppLinks {
  AppLinks._();

  // ── Web pages ────────────────────────────────────────────────────────────
  static const String website = 'https://wazy.app';
  static const String terms = 'https://wazy.app/terms';
  static const String privacy = 'https://wazy.app/privacy';
  static const String support = 'https://wazy.app/support';

  // ── Direct contact ───────────────────────────────────────────────────────
  static const String supportEmail = 'support@wazy.app';
  static const String salesEmail = 'hello@wazy.app';
  static const String whatsappNumber = '971500000000';

  // ── Composed URLs ────────────────────────────────────────────────────────
  static String get mailtoSupport => 'mailto:$supportEmail';
  static String get mailtoSales => 'mailto:$salesEmail';
  static String get whatsappUrl => 'https://wa.me/$whatsappNumber';
}
