import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_links.dart';
import '../services/auth_service.dart';
import '../services/collection_service.dart';
import '../services/custom_document_type_service.dart';
import '../services/document_scanner_service.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/legal_info_dialogs.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isSignUp = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final auth = AuthService.instance;
      if (_isSignUp) {
        final phone = _phoneController.text.trim();
        if (phone.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userPhone', phone);
        }
        await auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (!auth.isSignedIn) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Account created! Check your email to confirm, then sign in.',
                ),
              ),
            );
            setState(() {
              _isSignUp = false;
              _busy = false;
            });
          }
          return;
        }
      } else {
        await auth.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      // Reload everything that is scoped per-user. Order matters:
      // collections first (DocumentScannerService maps legacy collection
      // ids against this list), then custom doc types (rows decode into
      // ExpiryItems via the registry), then documents and finance.
      await DocumentCollectionService.instance.reset();
      await CustomDocumentTypeService.instance.reset();
      await DocumentScannerService.instance.refresh();
      await FinanceService.instance.refresh();

      if (mounted) context.go('/home');
    } catch (e) {
      setState(() {
        _error = _friendlyError(e.toString());
        _busy = false;
      });
    }
  }

  String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Wrong email or password.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please confirm your email first (check your inbox).';
    }
    if (lower.contains('already registered')) {
      return 'An account with this email already exists — sign in instead.';
    }
    if (lower.contains('password') && lower.contains('at least')) {
      return 'Password is too weak — use at least 6 characters.';
    }
    if (lower.contains('rate limit')) {
      return 'Too many attempts — wait a minute and try again.';
    }
    if (lower.contains('not configured')) {
      return 'Supabase is not configured in this build (see lib/config/app_credentials.dart).';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _showForgotPassword() async {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );

    final email = resetEmailController.text.trim();

    // Dispose after the dialog animation finishes to avoid
    // "used after being disposed" errors during the exit transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      resetEmailController.dispose();
    });

    if (confirmed != true) return;

    if (email.isEmpty || !email.contains('@')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid email address.')),
        );
      }
      return;
    }

    try {
      await AuthService.instance.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset link sent! Check your inbox.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e.toString())),
            backgroundColor: WazyColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _launchExternal(String raw) async {
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Placeholder URLs may not resolve yet — ignore.
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor =
        isDark ? WazyColors.textPrimaryDark : WazyColors.textPrimaryLight;
    final subColor =
        isDark ? WazyColors.textSecondary : WazyColors.textSecondaryLight;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? WazyGradients.darkHeader
              : const LinearGradient(
                  colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Brand hero ──────────────────────────────────────────
                  Text(
                    'Wazy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Financial & document intelligence\nfor UAE businesses.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 14, color: subColor, height: 1.4),
                  ),
                  const SizedBox(height: 22),

                  // ── Capability highlights ───────────────────────────────
                  _FeatureRow(
                    icon: Icons.auto_awesome_rounded,
                    color: WazyColors.cyanAccent,
                    title: 'AI reads your documents',
                    subtitle:
                        'Scans, invoices & licences — dates and amounts extracted automatically.',
                  ),
                  const SizedBox(height: 10),
                  _FeatureRow(
                    icon: Icons.query_stats_rounded,
                    color: WazyColors.warning,
                    title: 'See your money clearly',
                    subtitle:
                        'Budgets, spend trends, anomalies & 90-day cash forecasts.',
                  ),
                  const SizedBox(height: 10),
                  _FeatureRow(
                    icon: Icons.notifications_active_rounded,
                    color: WazyColors.emeraldAccent,
                    title: 'Never miss a deadline',
                    subtitle:
                        'Renewal alerts escalate 90 → 60 → 30 → 7 days out.',
                  ),
                  const SizedBox(height: 10),
                  _FeatureRow(
                    icon: Icons.mic_rounded,
                    color: WazyColors.cyanAccent,
                    title: 'Talk to your books',
                    subtitle:
                        '“Paid 450 AED for DEWA yesterday” — voice entries, done.',
                  ),
                  const SizedBox(height: 24),

                  // ── Auth form ───────────────────────────────────────────
                  WazyGlass(
                    borderRadius: BorderRadius.circular(24),
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                icon: Icon(Icons.login_rounded, size: 18),
                                label: Text('Sign in'),
                              ),
                              ButtonSegment(
                                value: true,
                                icon: Icon(Icons.person_add_alt_rounded,
                                    size: 18),
                                label: Text('Sign up'),
                              ),
                            ],
                            selected: {_isSignUp},
                            onSelectionChanged: _busy
                                ? null
                                : (selection) => setState(
                                    () => _isSignUp = selection.first),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) return 'Enter your email';
                              if (!value.contains('@') || !value.contains('.')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (v) {
                              final value = v ?? '';
                              if (value.isEmpty) return 'Enter your password';
                              if (value.length < 6) {
                                return 'At least 6 characters';
                              }
                              return null;
                            },
                          ),
                          if (!_isSignUp) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _busy ? null : _showForgotPassword,
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: WazyColors.cyanAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (_isSignUp) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              autofillHints: const [
                                AutofillHints.telephoneNumber
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Phone Number (Optional)',
                                hintText: '+971 50 000 0000',
                                prefixIcon: Icon(Icons.phone_outlined),
                                helperText: 'For renewal & cash alerts',
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: WazyColors.dangerBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: WazyColors.danger.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: WazyColors.danger,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              Colors.white),
                                    ),
                                  )
                                : Text(
                                    _isSignUp ? 'Create account' : 'Sign in',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Legal consent line ──────────────────────────────────
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 12.5,
                        color: subColor,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: _legalPrefix),
                        TextSpan(
                          text: 'Terms & Conditions',
                          style: TextStyle(
                            color: WazyColors.cyanAccent,
                            fontWeight: FontWeight.w600,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _launchExternal(AppLinks.terms),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: TextStyle(
                            color: WazyColors.cyanAccent,
                            fontWeight: FontWeight.w600,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _launchExternal(AppLinks.privacy),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // ── Info link chips ─────────────────────────────────────
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.info_outline_rounded,
                        label: 'About',
                        onTap: () => showAboutSheet(context),
                      ),
                      _InfoChip(
                        icon: Icons.description_outlined,
                        label: 'Terms',
                        onTap: () => showTermsDialog(context),
                      ),
                      _InfoChip(
                        icon: Icons.shield_outlined,
                        label: 'Privacy',
                        onTap: () => showPrivacyDialog(context),
                      ),
                      _InfoChip(
                        icon: Icons.support_agent_rounded,
                        label: 'Support',
                        onTap: () => showSupportSheet(context),
                      ),
                      _InfoChip(
                        icon: Icons.language_rounded,
                        label: 'wazy.app',
                        onTap: () => _launchExternal(AppLinks.website),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '${AppVersionBadge.version} · Made in the UAE 🇦🇪',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark
                          ? WazyColors.textMuted
                          : WazyColors.textMutedLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const String _legalPrefix = 'By continuing you agree to our\n';

// ──────────────────────────────────────────────────────────────────────────────
// Capability highlight row
// ──────────────────────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? WazyColors.textPrimary
                      : WazyColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark
                      ? WazyColors.textSecondary
                      : WazyColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Info link chip
// ──────────────────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark
          ? Colors.white.withOpacity(0.06)
          : Colors.black.withOpacity(0.04),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isDark
                    ? WazyColors.textSecondary
                    : WazyColors.textSecondaryLight,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? WazyColors.textSecondary
                      : WazyColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Version badge — single source for the version string shown here.
// ──────────────────────────────────────────────────────────────────────────────

class AppVersionBadge {
  AppVersionBadge._();
  static const String version = 'v1.0.0';
}
