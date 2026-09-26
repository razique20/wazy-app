import 'package:flutter/material.dart';

import '../../models/subscription_tier.dart';
import '../../services/entitlement_service.dart';
import '../../services/upgrade_request_service.dart';
import '../../theme/app_theme.dart';

/// The Track 1 paywall.
///
/// Shown whenever a user hits a tier gate. Displays the locked feature, the
/// current tier and the tier that unlocks it, then offers exactly one
/// primary action: **Request Upgrade** — which opens the mail client with a
/// pre-filled request (user id, account email, current tier, requested tier,
/// feature, device, timestamp) addressed to
/// [UpgradeRequestService.supportEmail]. If no mail client is available the
/// message is copied to the clipboard instead.
///
/// Usage:
/// ```dart
/// if (!EntitlementService.instance.allows(EntitlementFeature.reportExport)) {
///   await showUpgradeDialog(context, EntitlementFeature.reportExport);
///   return;
/// }
/// ```
Future<void> showUpgradeDialog(
  BuildContext context,
  EntitlementFeature feature, {
  SubscriptionTier? requestedTier,
}) {
  return showDialog(
    context: context,
    useRootNavigator: true,
    builder: (ctx) =>
        UpgradeDialog(feature: feature, requestedTier: requestedTier),
  );
}

/// Convenience for the document-count gate: returns true when adding a
/// document is allowed; otherwise shows the paywall and returns false.
Future<bool> enforceDocumentLimit(
  BuildContext context, {
  int additional = 1,
}) async {
  final entitlements = EntitlementService.instance;
  final used = await entitlements.documentsInUse();
  if (entitlements.canAddDocuments(used, additional: additional)) return true;

  if (context.mounted) {
    await showUpgradeDialog(context, EntitlementFeature.moreDocuments);
  }
  return false;
}

/// Convenience for the company-collection gate: returns true when adding a
/// company collection is allowed; otherwise shows the paywall and returns false.
Future<bool> enforceCompanyCollectionLimit(
  BuildContext context, {
  int additional = 1,
}) async {
  final entitlements = EntitlementService.instance;
  final used = await entitlements.companyCollectionsInUse();
  if (entitlements.canAddCompanyCollections(used, additional: additional)) {
    return true;
  }

  if (context.mounted) {
    final feature = (entitlements.limits.maxCompanyCollections ?? 0) == 0
        ? EntitlementFeature.companyCollection
        : EntitlementFeature.multipleCompanyCollections;
    await showUpgradeDialog(context, feature);
  }
  return false;
}

/// General tier-upgrade sheet for the profile's subscription section: pick
/// Plus or Business, pick a billing period (1 / 3 / 12 months), then send the
/// pre-filled request email. The admin replies with a payment link; after
/// payment the tier + expiry are set in `user_tiers` and the app picks the
/// new plan up on the next Profile visit.
Future<void> showTierRequestSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _TierRequestSheet(),
  );
}

class _TierRequestSheet extends StatefulWidget {
  const _TierRequestSheet();

  @override
  State<_TierRequestSheet> createState() => _TierRequestSheetState();
}

class _TierRequestSheetState extends State<_TierRequestSheet> {
  PlanDuration _duration = PlanDuration.oneMonth;

  Future<void> _request(BuildContext context, SubscriptionTier tier) async {
    UpgradeRequestService.instance.logAttempt(null, tier);
    final launched = await UpgradeRequestService.instance.send(
      feature: null,
      requestedTier: tier,
      duration: _duration,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: launched ? Colors.green : FinavigColors.navyPrimary,
        content: Text(
          launched
              ? 'Upgrade request opened in your mail app — just press send. '
                    'You will receive a payment link for the ${_duration.label} plan.'
              : 'No mail app found — request copied to clipboard, paste it '
                    'into an email to ${UpgradeRequestService.supportEmail}',
        ),
      ),
    );
    if (launched && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final currentTier = EntitlementService.instance.tier;
    final planEndsAt = EntitlementService.instance.planEndsAt;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose your plan',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'You are on ${TierInfo.all[currentTier]!.name}'
              '${planEndsAt != null && currentTier != SubscriptionTier.free ? ' — ends ${_formatDate(planEndsAt)}' : ''}. '
              'Pick a billing period, tap a plan, and send the drafted email to '
              '${UpgradeRequestService.supportEmail} — we reply with a payment '
              'link and activate your plan after payment.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Billing period',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final d in PlanDuration.values)
                  ChoiceChip(
                    label: Text(d.label),
                    selected: _duration == d,
                    onSelected: (_) => setState(() => _duration = d),
                    selectedColor: FinavigColors.navyPrimary.withAlpha(46),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _duration == d
                          ? FinavigColors.navyPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    side: BorderSide(
                      color: _duration == d
                          ? FinavigColors.navyPrimary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            for (final target in [
              SubscriptionTier.plus,
              SubscriptionTier.business,
            ])
              if (target > currentTier) ...[
                _TierOptionCard(
                  info: TierInfo.all[target]!,
                  duration: _duration,
                  onTap: () => _request(context, target),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = date.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

class _TierOptionCard extends StatelessWidget {
  const _TierOptionCard({
    required this.info,
    required this.onTap,
    this.duration,
  });

  final TierInfo info;
  final VoidCallback onTap;

  /// When set, the card shows the price estimate for this billing period.
  final PlanDuration? duration;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: FinavigColors.navyPrimary.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                info.tier == SubscriptionTier.business
                    ? Icons.business_center_rounded
                    : Icons.workspace_premium_rounded,
                color: FinavigColors.navyPrimary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${info.name} — ${info.priceLabel}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    info.benefits.take(3).join(' • '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class UpgradeDialog extends StatelessWidget {
  const UpgradeDialog({super.key, required this.feature, this.requestedTier});

  final EntitlementFeature feature;

  /// Override the advertised tier (defaults to the tier that unlocks
  /// [feature]).
  final SubscriptionTier? requestedTier;

  Future<void> _sendRequest(BuildContext context) async {
    final target = requestedTier ?? feature.requiredTier;
    UpgradeRequestService.instance.logAttempt(feature, target);
    final launched = await UpgradeRequestService.instance.send(
      feature: feature,
      requestedTier: target,
      duration: PlanDuration.oneMonth,
    );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: launched ? Colors.green : FinavigColors.navyPrimary,
        content: Text(
          launched
              ? 'Upgrade request opened in your mail app — just press send. '
                    'You will receive a payment link for the 1 Month plan.'
              : 'No mail app found — request copied to clipboard, paste it '
                    'into an email to ${UpgradeRequestService.supportEmail}',
        ),
      ),
    );
    if (launched && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entitlements = EntitlementService.instance;
    final currentTier = entitlements.tier;
    final target = requestedTier ?? feature.requiredTier;
    final info = TierInfo.all[target]!;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FinavigColors.navyPrimary.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: FinavigColors.navyPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Upgrade required')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${feature.label}" is part of the ${info.name} plan. '
              'You are currently on the ${TierInfo.all[currentTier]!.name} plan.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [FinavigColors.navyPrimary, FinavigColors.navyPrimaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        info.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: FinavigColors.cyanSecondary.withAlpha(46),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          info.priceLabel,
                          style: const TextStyle(
                            color: FinavigColors.cyanSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...info.benefits.map(
                    (b) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: FinavigColors.cyanSecondary,
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              b,
                              style: TextStyle(
                                color: Colors.white.withAlpha(230),
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Manual upgrade for early access: tap the button below and '
              'send the pre-filled email to ${UpgradeRequestService.supportEmail}. '
              'Our team activates your tier in the admin panel and you get a '
              'confirmation email.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe later'),
        ),
        // The one-button upgrade flow.
        FilledButton.icon(
          onPressed: () => _sendRequest(context),
          icon: const Icon(Icons.upgrade_rounded, size: 18),
          label: const Text('Request Upgrade'),
          style: FilledButton.styleFrom(
            backgroundColor: FinavigColors.navyPrimary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Compact tier badge for headers (e.g. the profile card).
class TierBadge extends StatelessWidget {
  const TierBadge({super.key, this.tier, this.compact = false});

  final SubscriptionTier? tier;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final resolved = tier ?? EntitlementService.instance.tier;
    final info = TierInfo.all[resolved]!;
    final color = switch (resolved) {
      SubscriptionTier.free => Colors.white.withAlpha(230),
      SubscriptionTier.plus => FinavigColors.cyanSecondary,
      SubscriptionTier.business => FinavigColors.emerald,
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(120), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (resolved) {
              SubscriptionTier.free => Icons.person_rounded,
              SubscriptionTier.plus => Icons.workspace_premium_rounded,
              SubscriptionTier.business => Icons.business_center_rounded,
            },
            size: compact ? 11 : 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            info.name,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
