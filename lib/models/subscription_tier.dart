/// Finavig Track 1 monetization tiers (see MONETIZATION.md — Freemium SaaS).
///
/// The tier is granted server-side by the admin (via the `user_tiers` table
/// managed with the service-role key in the Admin Console). The app only
/// reads it and resolves feature entitlements from [limits].
library;

/// The three commercial tiers. Ordered by ascending capability.
enum SubscriptionTier {
  free,
  plus,
  business;

  /// Stable id used in the `user_tiers.tier` column.
  String get id => name;

  static SubscriptionTier fromId(String? id) {
    switch (id) {
      case 'plus':
        return SubscriptionTier.plus;
      case 'business':
        return SubscriptionTier.business;
      default:
        return SubscriptionTier.free;
    }
  }

  static SubscriptionTier? tryFromId(String? id) {
    switch (id) {
      case 'free':
        return SubscriptionTier.free;
      case 'plus':
        return SubscriptionTier.plus;
      case 'business':
        return SubscriptionTier.business;
      default:
        return null;
    }
  }

  bool operator >(SubscriptionTier other) => index > other.index;
  bool operator >=(SubscriptionTier other) => index >= other.index;
  bool operator <(SubscriptionTier other) => index < other.index;
  bool operator <=(SubscriptionTier other) => index <= other.index;

  /// Static limits and entitlements granted by this tier.
  TierLimits get limits => switch (this) {
    SubscriptionTier.free => TierLimits.free,
    SubscriptionTier.plus => TierLimits.plus,
    SubscriptionTier.business => TierLimits.business,
  };
}

/// Static limits and feature entitlements for one tier.
class TierLimits {
  /// Max total active documents across all collections.
  /// Null = unlimited.
  final int? maxDocuments;

  /// Max company (non-personal) collections.
  /// Null = unlimited.
  final int? maxCompanyCollections;

  /// 90-day cash-flow forecast + dip detection.
  final bool cashFlowForecast;

  /// PDF/CSV report export (expiry list + finance ledger).
  final bool reportExport;

  /// Per-document custom alert-day offsets (beyond the 90/60/30/7 ladder).
  final bool customReminderDays;

  /// AI monthly executive summary card (LLM-polished narrative).
  final bool aiMonthlySummary;

  /// Assigning documents to team members / responsible persons.
  final bool documentAssignment;

  /// Renewal audit history (who renewed what, when, for how much).
  final bool renewalAuditHistory;

  /// Company/team data export (multi-collection bulk reports).
  final bool teamExport;

  /// Monthly quota for Groq AI Executive Summaries.
  final int groqAiSummaryMonthlyQuota;

  /// Monthly quota for Groq AI Budget Planner generations.
  final int aiBudgetPlanMonthlyQuota;

  const TierLimits({
    required this.maxDocuments,
    required this.maxCompanyCollections,
    required this.cashFlowForecast,
    required this.reportExport,
    required this.customReminderDays,
    required this.aiMonthlySummary,
    required this.documentAssignment,
    required this.renewalAuditHistory,
    required this.teamExport,
    required this.groqAiSummaryMonthlyQuota,
    required this.aiBudgetPlanMonthlyQuota,
  });

  static const free = TierLimits(
    maxDocuments: 10,
    maxCompanyCollections: 0,
    cashFlowForecast: false,
    reportExport: false,
    customReminderDays: false,
    aiMonthlySummary: false,
    documentAssignment: false,
    renewalAuditHistory: false,
    teamExport: false,
    groqAiSummaryMonthlyQuota: 3,
    aiBudgetPlanMonthlyQuota: 2,
  );

  static const plus = TierLimits(
    maxDocuments: null,
    maxCompanyCollections: 1,
    cashFlowForecast: true,
    reportExport: true,
    customReminderDays: true,
    aiMonthlySummary: true,
    documentAssignment: false,
    renewalAuditHistory: false,
    teamExport: false,
    groqAiSummaryMonthlyQuota: 15,
    aiBudgetPlanMonthlyQuota: 10,
  );

  static const business = TierLimits(
    maxDocuments: null,
    maxCompanyCollections: null,
    cashFlowForecast: true,
    reportExport: true,
    customReminderDays: true,
    aiMonthlySummary: true,
    documentAssignment: true,
    renewalAuditHistory: true,
    teamExport: true,
    groqAiSummaryMonthlyQuota: 40,
    aiBudgetPlanMonthlyQuota: 25,
  );
}

/// Display metadata for a tier (pricing, tagline, benefits).
class TierInfo {
  final SubscriptionTier tier;
  final String name;
  final String priceLabel;
  final String tagline;
  final List<String> benefits;

  const TierInfo({
    required this.tier,
    required this.name,
    required this.priceLabel,
    required this.tagline,
    required this.benefits,
  });

  TierLimits get limits => tier.limits;

  static const Map<SubscriptionTier, TierInfo> all = {
    SubscriptionTier.free: TierInfo(
      tier: SubscriptionTier.free,
      name: 'Free',
      priceLabel: 'Free',
      tagline: 'Track what matters — free forever',
      benefits: [
        '1 personal collection',
        'Up to 10 documents',
        '30/60/90-day renewal reminders',
        'Basic budgets & finance tracking',
      ],
    ),
    SubscriptionTier.plus: TierInfo(
      tier: SubscriptionTier.plus,
      name: 'Plus',
      priceLabel: 'AED 25 / month  (~\$6.99)',
      tagline: 'For power users who never miss a renewal',
      benefits: [
        'Unlimited documents',
        '1 company collection',
        '90-day cash-flow forecast',
        'PDF / CSV report export',
        'Custom alert days per document',
        'AI monthly executive summary',
        'AI budget planning & goal simulator',
      ],
    ),
    SubscriptionTier.business: TierInfo(
      tier: SubscriptionTier.business,
      name: 'Business',
      priceLabel: 'AED 99 / month  (~\$26.99)',
      tagline: 'Multiple workspaces for PROs & SMEs',
      benefits: [
        'Everything in Plus',
        'Unlimited company workspaces',
        'Document assignment to team members',
        'Renewal audit history',
        'Team data exports',
      ],
    ),
  };

  /// The tier one step above, or null when already at the top tier.
  static SubscriptionTier? nextTierUp(SubscriptionTier tier) => switch (tier) {
    SubscriptionTier.free => SubscriptionTier.plus,
    SubscriptionTier.plus => SubscriptionTier.business,
    SubscriptionTier.business => null,
  };
}

/// Feature identifiers used to label upgrade requests and look up gates in
/// one place. Each entry names the shipped capability being gated.
enum EntitlementFeature {
  moreDocuments('moreDocuments', 'More than 10 tracked documents'),
  companyCollection('companyCollection', 'Company collections'),
  multipleCompanyCollections(
    'multipleCompanyCollections',
    'Multiple company workspaces',
  ),
  cashFlowForecast('cashFlowForecast', '90-day cash-flow forecast'),
  reportExport('reportExport', 'PDF / CSV report export'),
  customReminderDays('customReminderDays', 'Custom alert days'),
  aiMonthlySummary('aiMonthlySummary', 'AI monthly executive summary'),
  documentAssignment('documentAssignment', 'Document assignment'),
  renewalAuditHistory('renewalAuditHistory', 'Renewal audit history'),
  teamExport('teamExport', 'Team data export'),
  groqAiSummary('groqAiSummary', 'Groq AI Executive Summary'),
  aiBudgetPlanning('aiBudgetPlanning', 'AI Budget Planning');

  const EntitlementFeature(this.id, this.label);

  /// Stable id sent in upgrade-request emails.
  final String id;

  /// Human-readable label shown on the paywall and in the email body.
  final String label;

  /// The tier that unlocks this feature.
  SubscriptionTier get requiredTier => switch (this) {
    EntitlementFeature.multipleCompanyCollections ||
    EntitlementFeature.documentAssignment ||
    EntitlementFeature.renewalAuditHistory ||
    EntitlementFeature.teamExport => SubscriptionTier.business,
    _ => SubscriptionTier.plus,
  };
}
