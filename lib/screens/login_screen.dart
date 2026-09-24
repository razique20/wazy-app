import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gcc_country.dart';
import '../services/auth_service.dart';
import '../services/collection_service.dart';
import '../services/custom_document_type_service.dart';
import '../services/document_scanner_service.dart';
import '../services/entitlement_service.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogs/legal_info_dialogs.dart';
import '../widgets/widgets.dart';

/// Redesigned Login & Sign-up screen adhering to Wazy's Bento Design System.
///
/// Features a dark navy hero header with logo & GCC capabilities, over a smooth
/// rounded surface sheet containing the sign-in / sign-up mode switcher,
/// styled form inputs with password visibility toggle, GCC country picker,
/// legal consent links, and app version badge.
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
  GccCountry _selectedCountry = GccCountry.uae;

  bool _isSignUp = false;
  bool _busy = false;
  bool _obscurePassword = true;
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userCountry', _selectedCountry.code);
        final phone = _phoneController.text.trim();
        if (phone.isNotEmpty) {
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
      // On signup the DB trigger creates the personal collection with default
      // country 'AE'. Patch it to the country the user actually selected.
      if (_isSignUp) {
        await DocumentCollectionService.instance
            .updatePersonalCountry(_selectedCountry.code);
      }
      await CustomDocumentTypeService.instance.reset();
      await DocumentScannerService.instance.refresh();
      await FinanceService.instance.refresh();
      // Load the tier granted to this user (Track 1 entitlements).
      await EntitlementService.instance.refresh();

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WazyRadius.dialog),
        ),
        backgroundColor: isDark ? WazyColors.charcoal : Colors.white,
        title: Text(
          'Reset Password',
          style: TextStyle(
            color: isDark ? WazyColors.textPrimary : WazyColors.textPrimaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your email address and we\'ll send you a link to reset your password.',
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? WazyColors.textSecondary : WazyColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(
                color: isDark ? WazyColors.textPrimary : WazyColors.textPrimaryLight,
              ),
              decoration: _fieldDecoration(
                isDark,
                label: 'Email',
                icon: Icons.alternate_email_rounded,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? WazyColors.textSecondary : WazyColors.textSecondaryLight,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: isDark ? WazyColors.slate : WazyColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(WazyRadius.button),
              ),
            ),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );

    final email = resetEmailController.text.trim();

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? WazyColors.charcoal : Colors.white;
    final subColor =
        isDark ? WazyColors.textSecondary : WazyColors.textSecondaryLight;
    final ctaColor = isDark ? WazyColors.slate : WazyColors.ink;
    final primaryAccent = isDark ? WazyColors.textPrimary : WazyColors.ink;

    return Scaffold(
      backgroundColor: isDark ? WazyColors.obsidian : WazyColors.navyPrimaryDark,
      body: Column(
        children: [
          // ── Brand hero header ──────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                      Row(
                        children: [
                          const WazyLogo(size: 42, showShadow: false),
                          const SizedBox(width: 12),
                          const Text(
                            'Wazy',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: WazyColors.accentBright.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(WazyRadius.tile),
                              border: Border.all(
                                color: WazyColors.accentBright.withOpacity(0.35),
                              ),
                            ),
                            child: const Text(
                              'GCC Edition',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: WazyColors.accentBright,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Financial & document intelligence for GCC businesses.',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.92),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Track document expiries, manage cash flow, and stay compliant across UAE, KSA, Kuwait, Qatar, Bahrain & Oman.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: Colors.white.withOpacity(0.72),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Feature highlight pills
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: const [
                            _HeroPill(
                              icon: Icons.notifications_active_rounded,
                              label: 'Expiry Alerts',
                            ),
                            SizedBox(width: 8),
                            _HeroPill(
                              icon: Icons.account_balance_wallet_rounded,
                              label: 'Cash Flow',
                            ),
                            SizedBox(width: 8),
                            _HeroPill(
                              icon: Icons.verified_rounded,
                              label: 'GCC Compliance',
                            ),
                            SizedBox(width: 8),
                            _HeroPill(
                              icon: Icons.auto_awesome_rounded,
                              label: 'Groq AI',
                            ),
                          ],
                        ),
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
                  top: Radius.circular(WazyRadius.sheet),
                ),
                boxShadow: WazyShadows.adaptive(isDark),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Sheet drag-handle bar
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.18)
                                : Colors.black.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // ── Sign in / Sign up mode toggle ──────────────────
                      _ModeToggle(
                        isSignUp: _isSignUp,
                        enabled: !_busy,
                        activeColor: ctaColor,
                        activeTextColor: Colors.white,
                        onChanged: (v) => setState(() => _isSignUp = v),
                      ),
                      const SizedBox(height: 22),

                      // Email input
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        style: TextStyle(color: _fieldTextColor(isDark)),
                        decoration: _fieldDecoration(
                          isDark,
                          label: 'Email Address',
                          icon: Icons.alternate_email_rounded,
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

                      // Password input with visibility toggle
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        style: TextStyle(color: _fieldTextColor(isDark)),
                        decoration: _fieldDecoration(
                          isDark,
                          label: 'Password',
                          icon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 20,
                              color: isDark
                                  ? WazyColors.textSecondary
                                  : WazyColors.textSecondaryLight,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
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
                                color: primaryAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],

                      if (_isSignUp) ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<GccCountry>(
                          initialValue: _selectedCountry,
                          isExpanded: true,
                          dropdownColor:
                              isDark ? WazyColors.slate : Colors.white,
                          style: TextStyle(color: _fieldTextColor(isDark)),
                          decoration: _fieldDecoration(
                            isDark,
                            label: 'Residence / Base GCC Country',
                            icon: Icons.public_rounded,
                            helperText:
                                'Sets your primary personal document defaults',
                          ),
                          items: GccCountry.values.map((c) {
                            return DropdownMenuItem<GccCountry>(
                              value: c,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryAccent.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      c.code,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: primaryAccent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${c.displayName} (${c.currency})',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _fieldTextColor(isDark),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedCountry = val);
                            }
                          },
                        ),
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
                            icon: Icons.phone_iphone_rounded,
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
                            borderRadius: BorderRadius.circular(WazyRadius.tile),
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

                      // Form Submit CTA Button
                      SizedBox(
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(WazyRadius.button),
                            boxShadow: WazyShadows.adaptive(isDark),
                          ),
                          child: FilledButton(
                            onPressed: _busy ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: ctaColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(WazyRadius.button),
                              ),
                            ),
                            child: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    _isSignUp ? 'Create account' : 'Sign in',
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Legal consent line ──────────────────────────────
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
                            color: primaryAccent,
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
                            color: primaryAccent,
                            onTap: () => showPrivacyDialog(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

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
                        '${AppVersionBadge.version} · Made for the GCC',
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
    Widget? suffixIcon,
  }) {
    final accent = isDark ? WazyColors.textPrimary : WazyColors.ink;
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      prefixIcon: Icon(icon, size: 20, color: accent),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark
          ? Colors.white.withOpacity(0.06)
          : WazyColors.cloud,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WazyRadius.field),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WazyRadius.field),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(WazyRadius.field),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Header decorative shapes
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
            child: _Sparkle(size: 13, color: WazyColors.accentBright),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(WazyRadius.tile),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: WazyColors.accentBright),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.88),
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
        : WazyColors.cloud;
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
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(WazyRadius.tile),
              boxShadow: selected ? WazyShadows.soft : null,
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
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(WazyRadius.tile + 2),
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
// Legal consent link
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
// Version badge
// ──────────────────────────────────────────────────────────────────────────────

class AppVersionBadge {
  AppVersionBadge._();
  static const String version = 'v1.0.0';
}
