import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          color: Colors.indigo.shade600,
        ),
        _OnboardingPage(
          icon: Icons.auto_awesome_rounded,
          title: 'AI identifies every expiry',
          body:
              'No manual entry. Our layered AI reads each document, finds the expiry date, and tells you: what expires, when, and what happens if you miss it.',
          color: Colors.teal.shade600,
        ),
        _OnboardingPage(
          icon: Icons.notifications_active_rounded,
          title: 'We remind you before it\'s too late',
          body:
              '90 days out → reminder. 60 days → task assigned. 30 days → escalation. 7 days → WhatsApp alert. You set the cadence; we enforce it.',
          color: Colors.orange.shade600,
        ),
        _OnboardingPage(
          icon: Icons.folder_special_rounded,
          title: 'One system for the whole company',
          body:
              'Trade licence, ejari, visas, Emirates IDs, labour documents, insurance, vehicles, contracts, domains, subscriptions, supplier agreements — in one place.',
          color: Colors.purple.shade600,
        ),
        _OnboardingPage(
          icon: Icons.check_circle_rounded,
          title: 'You\'re ready',
          body:
              'Nothing to install. Nothing to sync. Just upload and we\'ll take it from there. Welcome to Wazy.',
          color: Colors.green.shade600,
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
    final theme = Theme.of(context);
    final pages = _buildPages(context);
    final page = pages[_page];

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 48),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SizeTransition(
                            sizeFactor: animation,
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(_page),
                        child: Column(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: page.color.withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                page.icon,
                                size: 56,
                                color: page.color,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Text(
                              page.title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              page.body,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.outline,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
            // Bottom nav
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dots
                    Row(
                      children: List.generate(
                        pages.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _page
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withAlpha(75),
                          ),
                        ),
                      ),
                    ),
                    // Skip / next buttons
                    Row(
                      children: [
                        if (_page < pages.length - 1)
                          TextButton(
                            onPressed: () => setState(() => _page++),
                            child: Text(
                              _page == pages.length - 2 ? 'Next' : 'Skip',
                              style: TextStyle(
                                color: theme.colorScheme.outline,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        if (_page == pages.length - 1)
                          ElevatedButton.icon(
                            onPressed: page.action,
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: const Text('Get started'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
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
