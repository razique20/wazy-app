import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';

/// Show the comprehensive Wazy App Guide modal.
Future<void> showAppGuideDialog(
  BuildContext context, {
  int initialPage = 0,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    builder: (ctx) => AppGuideDialog(initialPage: initialPage),
  );
}

/// The comprehensive, interactive user guide introducing everything in Wazy:
/// 1. Overview & Vision (Financial & Document Command Center)
/// 2. Document & Expiry Intelligence (OCR, Authority catalogs, 90/60/30/7 reminder ladders)
/// 3. Money, Budgets & Cash Flow (GCC currencies, categories, 90-day forecast, bill spikes)
/// 4. Workspaces & Collections (Personal vs Company workspaces, multi-GCC countries)
/// 5. AI Intelligence & Reports (Groq AI Executive Summaries, AI Budget Planner, PDF/CSV export)
class AppGuideDialog extends StatefulWidget {
  final int initialPage;

  const AppGuideDialog({super.key, this.initialPage = 0});

  @override
  State<AppGuideDialog> createState() => _AppGuideDialogState();
}

class _AppGuideDialogState extends State<AppGuideDialog> {
  late final PageController _pageController;
  late int _currentPage;

  static const _totalChapters = 5;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(0, _totalChapters - 1);
    _pageController = PageController(initialPage: _currentPage);
    _markGuideAsSeen();
  }

  Future<void> _markGuideAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenAppGuide', true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 380 || size.height < 650;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: isCompact ? size.height * 0.95 : 680,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? WazyColors.slate : WazyColors.cloud,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.6 : 0.2),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // ── Header Bar ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B).withOpacity(0.5)
                      : WazyColors.cloud.withOpacity(0.6),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? WazyColors.slate.withOpacity(0.5)
                          : WazyColors.mist,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: WazyColors.navyPrimary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.explore_rounded,
                            color: WazyColors.navyPrimary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Wazy App Guide',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                'Chapter ${_currentPage + 1} of $_totalChapters',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          tooltip: 'Close guide',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Quick Chapter Selector Pills
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _chapterPill(0, 'Overview', Icons.auto_awesome_rounded),
                          const SizedBox(width: 6),
                          _chapterPill(1, 'Documents', Icons.description_rounded),
                          const SizedBox(width: 6),
                          _chapterPill(2, 'Money', Icons.account_balance_wallet_rounded),
                          const SizedBox(width: 6),
                          _chapterPill(3, 'Workspaces', Icons.business_center_rounded),
                          const SizedBox(width: 6),
                          _chapterPill(4, 'AI Power', Icons.psychology_rounded),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Page View Content ────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  children: [
                    _buildOverviewSlide(context, isDark, theme),
                    _buildDocumentsSlide(context, isDark, theme),
                    _buildMoneySlide(context, isDark, theme),
                    _buildWorkspacesSlide(context, isDark, theme),
                    _buildAiSlide(context, isDark, theme),
                  ],
                ),
              ),

              // ── Bottom Navigation Controls ───────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? WazyColors.slate.withOpacity(0.4)
                          : WazyColors.mist,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Dot indicators
                    Row(
                      children: List.generate(
                        _totalChapters,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: index == _currentPage ? 22 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: index == _currentPage
                                ? WazyColors.navyPrimary
                                : (isDark
                                    ? WazyColors.slateLight
                                    : WazyColors.fog),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_currentPage > 0) ...[
                      TextButton(
                        onPressed: () => _goToPage(_currentPage - 1),
                        child: const Text('Back'),
                      ),
                      const SizedBox(width: 6),
                    ],
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: WazyColors.navyPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (_currentPage < _totalChapters - 1) {
                          _goToPage(_currentPage + 1);
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Text(
                        _currentPage < _totalChapters - 1
                            ? 'Next →'
                            : 'Start Exploring',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _chapterPill(int index, String label, IconData icon) {
    final active = _currentPage == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _goToPage(index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? WazyColors.navyPrimary
              : (isDark
                  ? WazyColors.slate.withOpacity(0.6)
                  : WazyColors.cloud),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: active
                  ? Colors.white
                  : (isDark ? WazyColors.textSecondary : WazyColors.textMuted),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                color: active
                    ? Colors.white
                    : (isDark
                        ? WazyColors.textSecondary
                        : WazyColors.textSecondaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 1. Overview Slide
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildOverviewSlide(
    BuildContext context,
    bool isDark,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner visual
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [WazyColors.navyPrimary, WazyColors.navyPrimaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: WazyColors.cyanSecondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        color: WazyColors.cyanSecondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Welcome to Wazy',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Your unified command center for expiry tracking, financial budgets, multi-company workspaces, and AI intelligence.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'The Four Pillars of Wazy',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _featureRow(
            icon: Icons.description_rounded,
            color: WazyColors.cyanSecondary,
            title: '1. Document & Expiry Tracking',
            desc: 'OCR scan IDs, Passports, Visas, Trade Licenses, Ejari & get 90/60/30/7-day alerts.',
            isDark: isDark,
          ),
          _featureRow(
            icon: Icons.account_balance_wallet_rounded,
            color: WazyColors.emerald,
            title: '2. Money, Budgets & Cash Flow',
            desc: 'Track income/expenses in GCC currencies, set category limits & forecast 90-day cash flow.',
            isDark: isDark,
          ),
          _featureRow(
            icon: Icons.business_center_rounded,
            color: Colors.purpleAccent,
            title: '3. Workspaces & Collections',
            desc: 'Keep personal files completely separate from multiple company or client workspaces.',
            isDark: isDark,
          ),
          _featureRow(
            icon: Icons.psychology_rounded,
            color: Colors.amber,
            title: '4. AI Executive Summaries',
            desc: 'Groq & Gemini AI analyze your financial health and build realistic savings plans.',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 2. Documents Slide
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildDocumentsSlide(
    BuildContext context,
    bool isDark,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.document_scanner_rounded, color: WazyColors.navyPrimary, size: 22),
              const SizedBox(width: 8),
              Text(
                'Document & Expiry Intelligence',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Never get caught by surprise fines or lapsed licenses in the UAE & GCC.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          // Interactive Mock Document Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? WazyColors.slate.withOpacity(0.5) : WazyColors.cloud,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? WazyColors.slateLight : WazyColors.mist,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: WazyColors.navyPrimary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.badge_outlined, color: WazyColors.navyPrimary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Emirates ID — Mohammed R.',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Authority: ICP UAE • Fee: 370 AED',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: WazyColors.warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '18 Days Left',
                        style: TextStyle(
                          color: WazyColors.warning,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _featureBullet('Smart OCR Scan', 'Upload images or PDFs — AI extracts expiry date, document number, and issuing authority automatically.'),
          _featureBullet('GCC Authority Catalog', 'Auto-matches DED, GDRFA, MoHRE, ICP, RTA, DHA, and municipal agencies.'),
          _featureBullet('Escalation Reminders', 'Automated reminders 90, 60, 30, and 7 days prior to expiry so you renew on time.'),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.push('/scan');
              },
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
              label: const Text('Try Adding or Scanning a Document'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: WazyColors.navyPrimary),
                foregroundColor: WazyColors.navyPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 3. Money Slide
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMoneySlide(
    BuildContext context,
    bool isDark,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: WazyColors.emerald, size: 22),
              const SizedBox(width: 8),
              Text(
                'Money, Budgets & Cash Flow',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Keep your personal & business cash flow healthy and predictable.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          // Mock Budget Gauge
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? WazyColors.slate.withOpacity(0.5) : WazyColors.cloud,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? WazyColors.slateLight : WazyColors.mist,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Office & Rent Budget', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('65% used', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? WazyColors.cyanSecondary : WazyColors.navyPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.65,
                    minHeight: 8,
                    backgroundColor: isDark ? Colors.black26 : Colors.black12,
                    valueColor: const AlwaysStoppedAnimation<Color>(WazyColors.emerald),
                  ),
                ),
                const SizedBox(height: 6),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Spent: 6,500 AED', style: TextStyle(fontSize: 11)),
                    Text('Budget: 10,000 AED', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _featureBullet('GCC Multi-Currency', 'Native support for AED, SAR, KWD, QAR, BHD, and OMR across all reports.'),
          _featureBullet('90-Day Cash Flow Forecast', 'Combines recurring expenses and document renewal fees to detect financial dips in advance.'),
          _featureBullet('Smart Bill Spike Alerts', 'Automatically detects anomalous utility or service bills compared to your 3-month history.'),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.go('/money');
              },
              icon: const Icon(Icons.arrow_outward_rounded, size: 16),
              label: const Text('Go to Money & Budgets Tab'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: WazyColors.emerald),
                foregroundColor: isDark ? WazyColors.emerald : const Color(0xFF065F46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 4. Workspaces & Collections Slide
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildWorkspacesSlide(
    BuildContext context,
    bool isDark,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business_center_rounded, color: Colors.purpleAccent, size: 22),
              const SizedBox(width: 8),
              Text(
                'Workspaces & Collections',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Keep personal documents separate from your business or client entities.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? WazyColors.slate.withOpacity(0.5) : WazyColors.cloud,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? WazyColors.slateLight : WazyColors.mist,
              ),
            ),
            child: Column(
              children: [
                _workspaceItem(
                  icon: Icons.person_rounded,
                  title: 'Personal Workspace',
                  subtitle: 'Your family passports, visas & driving licenses',
                  country: 'UAE (AED)',
                  isDark: isDark,
                ),
                const Divider(height: 16),
                _workspaceItem(
                  icon: Icons.business_rounded,
                  title: 'Al Mansoori Trading LLC',
                  subtitle: 'Trade license, Ejari, corporate tax & PRO docs',
                  country: 'UAE (AED)',
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _featureBullet('One-Tap Switching', 'Switch workspaces from the top-left header anytime to instantly re-scope documents and finances.'),
          _featureBullet('Plan Tier Mapping', 'Free includes 1 personal collection; Plus unlocks 1 company workspace; Business unlocks unlimited company workspaces.'),
          _featureBullet('Auto-Protection', 'If a plan expires, your data is never deleted — surplus company workspaces are securely locked until renewed.'),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.go('/profile');
              },
              icon: const Icon(Icons.folder_shared_rounded, size: 16),
              label: const Text('Manage Collections in Settings'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.purpleAccent),
                foregroundColor: Colors.purpleAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 5. AI Power Slide
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildAiSlide(
    BuildContext context,
    bool isDark,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded, color: Colors.amber, size: 22),
              const SizedBox(width: 8),
              Text(
                'AI Intelligence & Reports',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Harness the speed of Groq LLMs and Gemini to understand your finances.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2D2305), const Color(0xFF1E1700)]
                    : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'AI Executive Summary & Budget Simulator',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '“Your cash flow is stable with 12,400 AED net income. 2 renewals totaling 1,850 AED are due in 3 weeks. Recommended: reallocate 400 AED from dining out.”',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _featureBullet('Monthly Financial Health Score', 'Calculates an objective 0–100 financial health score based on savings rate, budget discipline, and renewal readiness.'),
          _featureBullet('Goal-Driven AI Budget Planner', 'State any financial goal (e.g. "Save 15,000 AED for vacation in 6 months") and AI produces tailored category caps.'),
          _featureBullet('PDF & CSV Export', 'Export official audit lists and finance reports with a single tap for accountants and team records.'),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.push('/ai-summary');
              },
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('Try AI Executive Summary'),
              style: FilledButton.styleFrom(
                backgroundColor: WazyColors.navyPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helper Widgets
  // ──────────────────────────────────────────────────────────────────────────

  Widget _featureRow({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: isDark ? WazyColors.textSecondary : WazyColors.textMutedLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureBullet(String title, String desc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: WazyColors.emerald,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: isDark ? WazyColors.textPrimary : WazyColors.textPrimaryLight,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text: desc,
                    style: TextStyle(
                      color: isDark ? WazyColors.textSecondary : WazyColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspaceItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String country,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: WazyColors.navyPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: WazyColors.navyPrimary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? WazyColors.slate : WazyColors.mist,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(country, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
