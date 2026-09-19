import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? WazyColors.charcoal : Colors.white;
    final subColor =
        isDark ? WazyColors.textSecondary : WazyColors.textSecondaryLight;
    final ctaColor = isDark ? WazyColors.cyanAccent : WazyColors.navyPrimary;
    final ctaTextColor = isDark ? WazyColors.obsidian : Colors.white;

    return Scaffold(
      backgroundColor: WazyColors.navyPrimary,
      body: Column(
        children: [
          // ── Brand hero (navy header) ────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 26),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _HeaderDecor(),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wazy',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Financial & document intelligence\nfor UAE businesses.',
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color: Colors.white.withOpacity(0.72),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: const [
                          _HeroPill(
                            icon: Icons.auto_awesome_rounded,
                            label: 'AI extraction',
                          ),
                          _HeroPill(
                            icon: Icons.query_stats_rounded,
                            label: 'Budgets & forecasts',
                          ),
                          _HeroPill(
                            icon: Icons.notifications_active_rounded,
                            label: 'Renewal alerts',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Form sheet (rounded top, theme surface) ─────────────────────
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Drag-handle for the sheet look
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.15)
                                : Colors.black.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // ── Sign in / Sign up pill toggle ──────────────────
                      _ModeToggle(
                        isSignUp: _isSignUp,
                        enabled: !_busy,
                        activeColor: ctaColor,
                        activeTextColor: ctaTextColor,
                        onChanged: (v) => setState(() => _isSignUp = v),
                      ),
                      const SizedBox(height: 22),

                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        style: TextStyle(color: _fieldTextColor(isDark)),
                        decoration: _fieldDecoration(
                          isDark,
                          label: 'Email',
                          icon: Icons.email_outlined,
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
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        style: TextStyle(color: _fieldTextColor(isDark)),
                        decoration: _fieldDecoration(
                          isDark,
                          label: 'Password',
                          icon: Icons.lock_outline,
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
                                color: isDark
                                    ? WazyColors.cyanAccent
                                    : WazyColors.navyPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_isSignUp) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [
                            AutofillHints.telephoneNumber
                          ],
                          style: TextStyle(color: _fieldTextColor(isDark)),
                          decoration: _fieldDecoration(
                            isDark,
                            label: 'Phone Number (Optional)',
                            icon: Icons.phone_outlined,
                            helperText: 'For renewal & cash alerts',
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? WazyColors.dangerBg
                                : WazyColors.dangerBgLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: WazyColors.danger.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: WazyColors.danger,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: WazyColors.danger,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 54,
                        child: FilledButton(
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: ctaColor,
                            foregroundColor: ctaTextColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _busy
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      ctaTextColor,
                                    ),
                                  ),
                                )
                              : Text(
                                  _isSignUp ? 'Create account' : 'Sign in',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Legal consent line ──────────────────────────────
                      // Opens the in-app legal sheets — the external
                      // wazy.app pages are placeholders until they go live.
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: [
                          Text(
                            'By continuing you agree to our',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: subColor,
                              height: 1.5,
                            ),
                          ),
                          _LegalLink(
                            label: 'Terms & Conditions',
                            color: isDark
                                ? WazyColors.cyanAccent
                                : WazyColors.navyPrimary,
                            onTap: () => showTermsDialog(context),
                          ),
                          Text(
                            'and',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: subColor,
                              height: 1.5,
                            ),
                          ),
                          _LegalLink(
                            label: 'Privacy Policy',
                            color: isDark
                                ? WazyColors.cyanAccent
                                : WazyColors.navyPrimary,
                            onTap: () => showPrivacyDialog(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ── Info links row ─────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _TextLink(
                            label: 'About',
                            color: subColor,
                            onTap: () => showAboutSheet(context),
                          ),
                          _DotSeparator(color: subColor),
                          _TextLink(
                            label: 'Terms',
                            color: subColor,
                            onTap: () => showTermsDialog(context),
                          ),
                          _DotSeparator(color: subColor),
                          _TextLink(
                            label: 'Privacy',
                            color: subColor,
                            onTap: () => showPrivacyDialog(context),
                          ),
                          _DotSeparator(color: subColor),
                          _TextLink(
                            label: 'Support',
                            color: subColor,
                            onTap: () => showSupportSheet(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
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
        ],
      ),
    );
  }

  Color _fieldTextColor(bool isDark) =>
      isDark ? WazyColors.textPrimary : WazyColors.textPrimaryLight;

  InputDecoration _fieldDecoration(
    bool isDark, {
    required String label,
    required IconData icon,
    String? helperText,
  }) {
    final accent = isDark ? WazyColors.cyanAccent : WazyColors.navyPrimary;
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      prefixIcon: Icon(icon, size: 20, color: accent),
      filled: true,
      fillColor: isDark
          ? Colors.white.withOpacity(0.06)
          : const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Header decorative shapes (poster-style sparkle + soft ring)
// ──────────────────────────────────────────────────────────────────────────────

class _HeaderDecor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 70,
      child: Stack(
        children: [
          Positioned(
            right: 0,
            top: 6,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            top: 0,
            child: _Sparkle(size: 13, color: WazyColors.cyanAccent),
          ),
          Positioned(
            right: 34,
            bottom: 2,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF9AF2C6),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  final double size;
  final Color color;

  const _Sparkle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SparklePainter(color: color)),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color color;

  _SparklePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.color != color;
}

// ──────────────────────────────────────────────────────────────────────────────
// Hero capability pill
// ──────────────────────────────────────────────────────────────────────────────

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: WazyColors.cyanAccent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Sign in / Sign up segmented pill toggle
// ──────────────────────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final bool isSignUp;
  final bool enabled;
  final Color activeColor;
  final Color activeTextColor;
  final ValueChanged<bool> onChanged;

  const _ModeToggle({
    required this.isSignUp,
    required this.enabled,
    required this.activeColor,
    required this.activeTextColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark
        ? Colors.white.withOpacity(0.06)
        : const Color(0xFFF1F5F9);
    final inactiveColor =
        isDark ? WazyColors.textSecondary : WazyColors.textSecondaryLight;

    Widget segment(String label, bool value, IconData icon) {
      final selected = isSignUp == value;
      return Expanded(
        child: GestureDetector(
          onTap: enabled ? () => onChanged(value) : null,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? activeTextColor : inactiveColor,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? activeTextColor : inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          segment('Sign in', false, Icons.login_rounded),
          segment('Sign up', true, Icons.person_add_alt_rounded),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Footer text links
// ──────────────────────────────────────────────────────────────────────────────

class _TextLink extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TextLink({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _DotSeparator extends StatelessWidget {
  final Color color;

  const _DotSeparator({required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      '·',
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Legal consent link — opens the matching in-app sheet
// ──────────────────────────────────────────────────────────────────────────────

class _LegalLink extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _LegalLink({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: color,
            decoration: TextDecoration.underline,
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
