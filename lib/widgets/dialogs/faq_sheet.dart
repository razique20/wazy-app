import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Item model for FAQ entry.
class FaqItem {
  final String question;
  final String answer;
  final String category;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const FaqItem({
    required this.question,
    required this.answer,
    required this.category,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });
}

/// Opens an interactive, searchable FAQ bottom sheet with categorized questions,
/// expandable accordions, and a direct link to submit support requests.
Future<void> showFaqSheet(
  BuildContext context, {
  VoidCallback? onOpenSupportTicket,
}) async {
  final theme = Theme.of(context);

  await showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: theme.colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _FaqSheetContent(onOpenSupportTicket: onOpenSupportTicket),
  );
}

class _FaqSheetContent extends StatefulWidget {
  final VoidCallback? onOpenSupportTicket;

  const _FaqSheetContent({this.onOpenSupportTicket});

  @override
  State<_FaqSheetContent> createState() => _FaqSheetContentState();
}

class _FaqSheetContentState extends State<_FaqSheetContent> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Documents',
    'Money',
    'AI & Voice',
    'Account & Tiers',
    'Support',
  ];

  late final List<FaqItem> _allFaqs;

  @override
  void initState() {
    super.initState();
    _allFaqs = [
      FaqItem(
        category: 'Documents',
        icon: Icons.description_rounded,
        question: 'How does Finavig track document expiries?',
        answer:
            'Finavig monitors all your added documents (Emirates ID, Passports, Visas, Trade Licences, Mulkiya, Insurance) and notifies you at key lead times (90, 60, 30, 14, 7, and 1 day before expiration). You can also customize reminder lead times in Settings.',
      ),
      FaqItem(
        category: 'Documents',
        icon: Icons.autorenew_rounded,
        question: 'How do I mark a document as renewed?',
        answer:
            'Tap on any document card, then tap "Renew Document". You can set the new expiry date, attach a renewal fee receipt, and optionally auto-log the renewal cost into your Money expense tracker.',
      ),
      FaqItem(
        category: 'Documents',
        icon: Icons.folder_copy_rounded,
        question: 'What are Document Collections?',
        answer:
            'Collections organize your documents into distinct workspaces (e.g. Personal vs. Company). You can easily switch active collections from the top app header or from Profile settings.',
      ),
      FaqItem(
        category: 'Documents',
        icon: Icons.sd_storage_rounded,
        question: 'How are uploaded document files and attachments stored?',
        answer:
            'Uploaded document files (photos, scans, PDF receipts) are saved 100% locally on your device in the app\'s secure storage folder (/finavig/documents/). They remain strictly on your phone and are never uploaded to external cloud file servers.',
      ),
      FaqItem(
        category: 'Documents',
        icon: Icons.security_rounded,
        question: 'How are document details and metadata stored?',
        answer:
            'Document details (title, expiry date, authority, type, fees, and notes) are synchronized to your secure account cloud database (Supabase) for cross-device access, while also cached locally on your device for instant offline access.',
      ),
      FaqItem(
        category: 'Money',
        icon: Icons.payments_rounded,
        question: 'How does Smart Category matching work?',
        answer:
            'When logging an expense (e.g., "Paid 450 AED for DEWA"), Finavig automatically identifies UAE merchants and categories (like Utilities, Transport, Food, Govt Fees) using fuzzy matching and a UAE keyword dictionary.',
      ),
      FaqItem(
        category: 'Money',
        icon: Icons.repeat_rounded,
        question: 'How do Recurring Transactions and Cash Flow work?',
        answer:
            'Mark any expense or income as "Repeat Monthly/Yearly". Finavig auto-logs them when due and calculates a 90-Day Cash Flow forecast combining bank balance, upcoming recurring bills, and document renewal fees.',
      ),
      FaqItem(
        category: 'Money',
        icon: Icons.show_chart_rounded,
        question: 'What is a Bill Spike anomaly alert?',
        answer:
            'Finavig automatically detects sudden price increases in recurring expenses (e.g., a utility bill jumping 35%+ higher than your average) and alerts you so you can review potential overcharges.',
      ),
      FaqItem(
        category: 'AI & Voice',
        icon: Icons.graphic_eq_rounded,
        question: 'How do I log records using Voice or Text?',
        answer:
            'Tap the Voice / Sparkle button on the Home or Money screen and speak or type naturally (e.g., "Spent 85 AED on Uber today"). Finavig extracts the amount, vendor, category, and date automatically.',
      ),
      FaqItem(
        category: 'AI & Voice',
        icon: Icons.auto_awesome_rounded,
        question: 'Do I need a Gemini API key for AI features?',
        answer:
            'No! Finavig includes built-in smart templates out of the box. Adding your free Gemini API key in Settings is optional and enables deeper executive summaries generated by Google Gemini.',
      ),
      FaqItem(
        category: 'Account & Tiers',
        icon: Icons.wifi_off_rounded,
        question: 'Does Finavig work offline without internet?',
        answer:
            'Yes! Finavig uses local-first caching. All your data is saved locally on your device for fast offline access and automatically syncs with cloud database when reconnected.',
      ),
      FaqItem(
        category: 'Account & Tiers',
        icon: Icons.workspace_premium_rounded,
        question: 'What are the differences between Free, Plus, and Business tiers?',
        answer:
            '• Free: 1 Personal collection & up to 10 active documents.\n• Plus: 1 Company collection & up to 100 documents.\n• Business: Unlimited Company collections, team features & unlimited AI summaries.',
      ),
      FaqItem(
        category: 'Account & Tiers',
        icon: Icons.lock_outline_rounded,
        question: 'What happens to my data if my plan changes?',
        answer:
            'Your data is completely safe and is never deleted. If your plan downgrades, surplus company collections are safely locked in read-only mode until you upgrade your plan.',
      ),
      FaqItem(
        category: 'Support',
        icon: Icons.support_agent_rounded,
        question: 'How can I submit a support request or report a bug?',
        answer:
            'Tap "Submit a Request" in Profile → Help & Support, or tap the button below to send a message to our support team. You can track all your submissions in "My Requests".',
        actionLabel: 'Submit Support Ticket',
        onAction: () {
          Navigator.pop(context);
          widget.onOpenSupportTicket?.call();
        },
      ),
      FaqItem(
        category: 'Support',
        icon: Icons.contact_support_rounded,
        question: 'Where can I track the status of my support ticket?',
        answer:
            'Go to Profile → Help & Support → "My Requests". There you will see all your active and resolved tickets along with admin status updates.',
      ),
    ];
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FaqItem> get _filteredFaqs {
    return _allFaqs.where((faq) {
      final matchesCategory =
          _selectedCategory == 'All' || faq.category == _selectedCategory;
      final q = _searchQuery.toLowerCase().trim();
      final matchesQuery = q.isEmpty ||
          faq.question.toLowerCase().contains(q) ||
          faq.answer.toLowerCase().contains(q) ||
          faq.category.toLowerCase().contains(q);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filteredFaqs;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.quiz_rounded,
                      color: Color(0xFFD97706),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Frequently Asked Questions',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Everything you need to know about Finavig',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search questions, features, or keywords...',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline.withOpacity(0.7),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Category Filter Chips
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final cat = _categories[idx];
                  final selected = cat == _selectedCategory;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedCategory = cat);
                    },
                    selectedColor: const Color(0xFFD97706).withOpacity(0.2),
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.04),
                    labelStyle: TextStyle(
                      color: selected
                          ? (isDark ? const Color(0xFFD97706) : FinavigColors.ink)
                          : theme.colorScheme.onSurface.withOpacity(0.7),
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: selected
                            ? const Color(0xFFD97706).withOpacity(0.5)
                            : Colors.transparent,
                      ),
                    ),
                    showCheckmark: false,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),

            // FAQ Accordion List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: theme.colorScheme.outline.withOpacity(0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No matching questions found',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try searching for another keyword or category',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, idx) {
                        return _FaqAccordionCard(
                          item: filtered[idx],
                          isDark: isDark,
                        );
                      },
                    ),
            ),

            // Bottom CTA Card: Still Need Help?
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? FinavigColors.obsidian
                    : FinavigColors.navyPrimary.withOpacity(0.04),
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.12),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Still have questions?',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Contact our team for quick support',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onOpenSupportTicket?.call();
                    },
                    icon: const Icon(Icons.support_agent_rounded, size: 18),
                    label: const Text('Contact Support'),
                    style: FilledButton.styleFrom(
                      backgroundColor: FinavigColors.navyPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqAccordionCard extends StatefulWidget {
  final FaqItem item;
  final bool isDark;

  const _FaqAccordionCard({
    required this.item,
    required this.isDark,
  });

  @override
  State<_FaqAccordionCard> createState() => _FaqAccordionCardState();
}

class _FaqAccordionCardState extends State<_FaqAccordionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.grey.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.icon,
                        size: 20,
                        color: widget.isDark
                            ? const Color(0xFFD97706)
                            : FinavigColors.ink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.question,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.category,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: const Color(0xFFD97706),
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.outline,
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      SelectableText(
                        item.answer,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.45,
                          color: theme.colorScheme.onSurface.withOpacity(0.85),
                          fontSize: 13.5,
                        ),
                      ),
                      if (item.actionLabel != null && item.onAction != null) ...[
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: item.onAction,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                          ),
                          label: Text(item.actionLabel!),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD97706),
                            side: BorderSide(
                              color: const Color(0xFFD97706).withOpacity(0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  crossFadeState: _expanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
