import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_links.dart';
import '../indicators/wazy_logo.dart';

/// In-app Terms & Conditions, Privacy Policy, About, and Support sheets.
///
/// Every sheet is fully self-contained, so the information is always visible
/// even if the external pages aren't live yet. External links open outside
/// the app when tapped.

Future<void> _openLink(String raw) async {
  final uri = Uri.tryParse(raw);
  if (uri == null) return;
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    // Placeholder URLs won't resolve yet — ignore until production pages ship.
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Legal sheet scaffolding
// ──────────────────────────────────────────────────────────────────────────────

class _LegalSection {
  final String title;
  final String body;
  const _LegalSection(this.title, this.body);
}

class _LegalBody extends StatelessWidget {
  final String intro;
  final List<_LegalSection> sections;

  const _LegalBody({required this.intro, required this.sections});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(intro, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        for (final s in sections) ...[
          Text(
            s.title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(s.body, style: theme.textTheme.bodySmall?.copyWith(height: 1.5)),
          const SizedBox(height: 16),
        ],
        Text(
          'Last updated: September 2026 · Questions? ${AppLinks.supportEmail}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

void _showLegalSheet(
  BuildContext context, {
  required String title,
  required _LegalBody body,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (sheetCtx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: body,
            ),
          ),
        ],
      ),
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Terms & Conditions content
// ──────────────────────────────────────────────────────────────────────────────

void _showTermsSheet(BuildContext context) {
  _showLegalSheet(
    context,
    title: 'Terms & Conditions',
    body: const _LegalBody(
      intro: 'These terms govern your use of Wazy — the financial and '
          'document intelligence platform for GCC businesses. By creating an '
          'account you agree to them.',
      sections: [
        _LegalSection(
          '1. The service',
          'Wazy lets you upload company documents (trade licences, visas, '
          'invoices, receipts, tenancy agreements and more), automatically '
          'extracts dates, amounts and vendors with AI, tracks spending, '
          'budgets and cash-flow forecasts, and sends renewal reminders.',
        ),
        _LegalSection(
          '2. Your account',
          'You are responsible for the accuracy of the email you register and '
          'for keeping your password secure. One account per person; company '
          'data belongs to the registering organisation.',
        ),
        _LegalSection(
          '3. Your documents & data',
          'You keep full ownership of everything you upload. We process your '
          'documents only to provide the service — expiry extraction, '
          'reminders, renewal tracking — and never sell your data.',
        ),
        _LegalSection(
          '4. Acceptable use',
          'Do not upload documents you are not authorised to handle, attempt '
          'to access other users\u2019 data, or use the service to store '
          'unlawful content.',
        ),
        _LegalSection(
          '5. Insights are assistance, not professional advice',
          'Wazy highlights upcoming deadlines, spending patterns and cash '
          'projections, but it does not replace professional legal, PRO, '
          'accounting, tax or compliance advice. Always confirm deadlines '
          'with the issuing authority and figures with your accountant.',
        ),
        _LegalSection(
          '6. Availability & changes',
          'We aim for high availability but the service is provided "as is". '
          'We may add, change, or discontinue features; material changes to '
          'these terms will be communicated in-app.',
        ),
        _LegalSection(
          '7. Termination',
          'You can delete your account at any time from the profile screen. '
          'We may suspend accounts that violate these terms.',
        ),
      ],
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Privacy Policy content
// ──────────────────────────────────────────────────────────────────────────────

void _showPrivacySheet(BuildContext context) {
  _showLegalSheet(
    context,
    title: 'Privacy Policy',
    body: const _LegalBody(
      intro: 'Your documents and financial data are sensitive. This policy '
          'explains, in plain language, what Wazy collects, why, and how it '
          'stays protected.',
      sections: [
        _LegalSection(
          '1. What we collect',
          '• Account details: email address (and optional phone number for '
          'renewal and cash alerts).\n'
          '• Documents you upload: scans, photos, and PDFs of company '
          'documents, invoices and receipts.\n'
          '• Extracted data: dates, amounts, vendors and document types '
          'derived from your uploads.\n'
          '• Financial records: transactions, budgets and categories you '
          'create or import.\n'
          '• Technical data: app version and platform, used to keep your '
          'installation up to date.',
        ),
        _LegalSection(
          '2. What we do NOT do',
          '• We never sell your data.\n'
          '• We never share your documents with third parties for marketing.\n'
          '• We do not use your documents to train public AI models.\n'
          '• No advertising trackers, no data brokers.',
        ),
        _LegalSection(
          '3. Why we process data',
          'To provide the service you signed up for: storing your documents, '
          'extracting expiry information, and delivering reminders you '
          'configured. Your documents belong to you; we process them on your '
          'instruction only.',
        ),
        _LegalSection(
          '4. Where data lives',
          'Documents, financial records and account data are stored in '
          'Supabase (cloud infrastructure) with encryption in transit and at '
          'rest. AI extraction runs on document content solely to locate '
          'dates, amounts and document attributes.',
        ),
        _LegalSection(
          '5. Retention & deletion',
          'Your data is kept while your account is active. Deleting a '
          'document removes it from your workspace. Deleting your account '
          'initiates removal of your personal data.',
        ),
        _LegalSection(
          '6. Your rights',
          'You can access, correct, export, or delete your data at any time '
          'from the app. For anything else, contact us and we will respond '
          'promptly.',
        ),
        _LegalSection(
          '7. Children',
          'Wazy is a business tool and is not directed at children under 16.',
        ),
      ],
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Public API
// ──────────────────────────────────────────────────────────────────────────────

/// Terms & Conditions sheet.
void showTermsDialog(BuildContext context) => _showTermsSheet(context);

/// Privacy Policy sheet.
void showPrivacyDialog(BuildContext context) => _showPrivacySheet(context);

/// About Wazy — what the app does, version, and links to everything else.
void showAboutSheet(BuildContext context) {
  final theme = Theme.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const WazyLogo(size: 56, showShadow: false),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Wazy',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Finance & Docs · v1.0.0',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(sheetCtx),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Financial & document intelligence for GCC businesses.',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Wazy turns your paperwork into clarity. Upload documents and '
              'receipts — AI extracts the dates, amounts and vendors. Track '
              'spending, budgets and 90-day cash forecasts in one place, and '
              'get renewal alerts before deadlines hit.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 20),
            _AboutLink(
              icon: Icons.language_rounded,
              label: 'wazy.app — website',
              onTap: () => _openLink(AppLinks.website),
            ),
            _AboutLink(
              icon: Icons.description_outlined,
              label: 'Terms & Conditions',
              onTap: () {
                Navigator.pop(sheetCtx);
                showTermsDialog(context);
              },
            ),
            _AboutLink(
              icon: Icons.shield_outlined,
              label: 'Privacy Policy',
              onTap: () {
                Navigator.pop(sheetCtx);
                showPrivacyDialog(context);
              },
            ),
            _AboutLink(
              icon: Icons.support_agent_rounded,
              label: 'Contact support',
              onTap: () {
                Navigator.pop(sheetCtx);
                showSupportSheet(context);
              },
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Made for the GCC 🇦🇪 🇸🇦 🇰🇼 🇶🇦 🇧🇭 🇴🇲 · © 2026 Wazy',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Support / Contact — email, WhatsApp, website.
void showSupportSheet(BuildContext context) {
  final theme = Theme.of(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need help?',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Questions about your account, documents, or renewals — we '
              'usually reply within a day.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _AboutLink(
              icon: Icons.mail_outline_rounded,
              label: AppLinks.supportEmail,
              sub: 'Support & account help',
              onTap: () => _openLink(AppLinks.mailtoSupport),
            ),
            _AboutLink(
              icon: Icons.handshake_outlined,
              label: AppLinks.salesEmail,
              sub: 'Sales & partnerships',
              onTap: () => _openLink(AppLinks.mailtoSales),
            ),
            _AboutLink(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'WhatsApp ${AppLinks.whatsappNumber}',
              sub: 'Fastest response',
              onTap: () => _openLink(AppLinks.whatsappUrl),
            ),
            _AboutLink(
              icon: Icons.language_rounded,
              label: 'wazy.app',
              sub: 'Guides & FAQ',
              onTap: () => _openLink(AppLinks.website),
            ),
          ],
        ),
      ),
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Shared tappable link row
// ──────────────────────────────────────────────────────────────────────────────

class _AboutLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback onTap;

  const _AboutLink({
    required this.icon,
    required this.label,
    this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (sub != null)
                        Text(
                          sub!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
