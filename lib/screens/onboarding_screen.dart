import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;

  List<_OnboardingPage> _buildPages(BuildContext context) => [
        _OnboardingPage(
          icon: Icons.upload_file_rounded,
          title: 'Upload your documents',
          body:
              'Drop a folder or zip of all your company documents. We\'ll sort them out — trade licences, Ejari, visas, insurance, contracts, domains, subscriptions.',
          color: FinavigColors.cyanAccent,
        ),
        _OnboardingPage(
          icon: Icons.auto_awesome_rounded,
          title: 'AI identifies every expiry',
          body:
              'No manual entry. Our layered AI reads each document, finds the expiry date, and tells you: what expires, when, and what happens if you miss it.',
          color: FinavigColors.violetAccent,
        ),
        _OnboardingPage(
          icon: Icons.notifications_active_rounded,
          title: 'We remind you before it\'s too late',
          body:
              '90 days out → reminder. 60 days → task assigned. 30 days → escalation. 7 days → WhatsApp alert. You set the cadence; we enforce it.',
          color: FinavigColors.warning,
        ),
        _OnboardingPage(
          icon: Icons.folder_special_rounded,
          title: 'One system for the whole company',
          body:
              'Trade licence, ejari, visas, Emirates IDs, labour documents, insurance, vehicles, contracts, domains, subscriptions, supplier agreements — in one place.',
          color: FinavigColors.emeraldAccent,
        ),
        _OnboardingPage(
          icon: Icons.check_circle_rounded,
          title: 'You\'re ready',
          body:
              'Nothing to install. Nothing to sync. Just upload and we\'ll take it from there. Welcome to Finavig.',
          color: FinavigColors.safe,
          actionLabel: 'Get started',
          action: () {
            SharedPreferences.getInstance().then((prefs) {
              prefs.setBool('hasOnboarded', true);
              if (context.mounted) context.go('/home');
            });
          },
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = _buildPages(context);
    final page = pages[_page];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? FinavigGradients.darkHeader
              : const LinearGradient(
                  colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: FinavigGlass(
                      borderRadius: BorderRadius.circular(24),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: KeyedSubtree(
                              key: ValueKey(_page),
                              child: Column(
                                children: [
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      color: page.color.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: page.color.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: page.color.withOpacity(0.2),
                                          blurRadius: 20,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      page.icon,
                                      size: 52,
                                      color: page.color,
                                    ),
                                  ),
                                  const SizedBox(height: 28),
                                  Text(
                                    page.title,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? FinavigColors.textPrimaryDark : FinavigColors.textPrimaryLight,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    page.body,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.55,
                                      color: isDark ? FinavigColors.textSecondary : FinavigColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom navigation row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dots
                    Row(
                      children: List.generate(
                        pages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: i == _page ? 24 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: i == _page
                                ? FinavigColors.cyanAccent
                                : (isDark ? FinavigColors.textMuted.withOpacity(0.3) : Colors.black12),
                          ),
                        ),
                      ),
                    ),
                    // Action button / next button
                    if (_page < pages.length - 1)
                      TextButton(
                        onPressed: () => setState(() => _page++),
                        style: TextButton.styleFrom(
                          foregroundColor: FinavigColors.cyanAccent,
                        ),
                        child: Text(
                          _page == pages.length - 2 ? 'Next' : 'Skip',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: page.action,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('Get started'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FinavigColors.cyanAccent,
                          foregroundColor: const Color(0xFF0A0E1A),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final VoidCallback? action;
  final String? actionLabel;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    this.action,
    this.actionLabel,
  });
}
