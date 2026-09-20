import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription_tier.dart';
import 'auth_service.dart';
import 'collection_service.dart';
import 'document_scanner_service.dart';
import 'supabase_service.dart';

/// Track 1 monetization gatekeeper.
///
/// Resolves the signed-in user's [SubscriptionTier] and answers every
/// "may this user use X?" question against [TierLimits]. The tier itself is
/// granted by the admin (Admin Console writes `public.user_tiers` with the
/// service-role key); this service only reads it. When Supabase isn't
/// configured — or the row/table is missing — the tier falls back to the
/// local SharedPreferences override, then to [SubscriptionTier.free], so the
/// app stays fully usable in local-only mode and tests.
///
/// Usage:
/// ```dart
/// await EntitlementService.instance.init();          // cold start / sign-in
/// EntitlementService.instance.allows(EntitlementFeature.reportExport);
/// EntitlementService.instance.canAddDocument(await usedCount);
/// ```
class EntitlementService extends ChangeNotifier {
  EntitlementService._();

  static final EntitlementService instance = EntitlementService._();

  /// Local override key — used by the admin/dev build to preview tiers and
  /// as the fallback tier in local-only mode (no Supabase session).
  /// Seed it (e.g. `SharedPreferences.setMockInitialValues({tierOverrideKey: 'plus'})`)
  /// and call [reset] + [refresh] to run tests/screens as a non-Free tier.
  static const String tierOverrideKey = 'subscription.tierOverride';

  SubscriptionTier _tier = SubscriptionTier.free;
  bool _initialized = false;
  DateTime? _planEndsAt;
  String? _planDuration;

  /// The resolved tier for the current user (Free until upgraded).
  SubscriptionTier get tier => _tier;

  TierLimits get limits => _tier.limits;

  bool get isInitialized => _initialized;

  /// When the paid plan expires (null on Free or when the admin hasn't set
  /// an end date). Read from `user_tiers.plan_ends_at`.
  DateTime? get planEndsAt => _planEndsAt;

  /// Plan duration id chosen at purchase: `1_month`, `3_months`, `1_year`.
  String? get planDuration => _planDuration;

  /// Days left until the plan expires (rounded up; 0 = expires today).
  /// Null on Free. Negative when already expired.
  int? daysUntilPlanExpiry() {
    final end = _planEndsAt;
    if (end == null || _tier == SubscriptionTier.free) return null;
    final now = DateTime.now().toUtc();
    return end.difference(now).inDays;
  }

  /// True when the user is on a paid tier whose plan end date has passed.
  /// The UI shows a warning and refresh() downgrades the tier locally.
  bool get isPlanExpired {
    final end = _planEndsAt;
    return _tier != SubscriptionTier.free && end != null && end.isBefore(DateTime.now().toUtc());
  }

  /// Load the tier once. Safe to call multiple times.
  Future<void> init() async {
    if (_initialized) return;
    await refresh();
  }

  /// Re-read the tier (cold start, sign-in, or returning from an upgrade
  /// that the admin has just processed).
  Future<void> refresh() async {
    final prefs = await SharedPreferences.getInstance();    var resolved = SubscriptionTier.tryFromId(prefs.getString(tierOverrideKey)) ??
        SubscriptionTier.free;

    final client = SupabaseService.clientOrNull;
    final userId = AuthService.instance.currentUserId;
    if (client != null && userId != null) {
      try {
        final row = await client
            .from('user_tiers')
            .select('tier, plan_duration, plan_ends_at')
            .eq('user_id', userId)
            .maybeSingle();
        final serverTier = SubscriptionTier.tryFromId(row?['tier'] as String?);
        if (serverTier != null) resolved = serverTier;
        _planDuration = row?['plan_duration'] as String?;
        final endsAt = row?['plan_ends_at'];
        _planEndsAt = endsAt is String ? DateTime.tryParse(endsAt)?.toUtc() : null;
      } catch (_) {
        // Table missing or unreachable — keep the local/default tier so the
        // app never blocks the user on an infrastructure error.
      }
    } else {
      _planDuration = null;
      _planEndsAt = null;
    }

    // A paid tier past its end date behaves as Free until the admin renews
    // (the DB trigger snaps the row back on the next write).
    if (resolved != SubscriptionTier.free &&
        _planEndsAt != null &&
        _planEndsAt!.isBefore(DateTime.now().toUtc())) {
      resolved = SubscriptionTier.free;
    }

    if (_tier != resolved) {
      _tier = resolved;
      // Tier changed (e.g. admin granted an upgrade) — release the gates.
      notifyListeners();
    }
    _initialized = true;
  }

  /// Dev/admin preview override. Pass null to clear.
  Future<void> setLocalOverride(SubscriptionTier? tier) async {
    final prefs = await SharedPreferences.getInstance();
    if (tier == null) {
      await prefs.remove(tierOverrideKey);
    } else {
      await prefs.setString(tierOverrideKey, tier.id);
    }
    await refresh();
  }

  /// Feature-gate lookup: true when the current tier unlocks [feature].
  bool allows(EntitlementFeature feature) => _tier >= feature.requiredTier;

  /// Minimum tier required to unlock [feature] — used by the paywall to
  /// advertise the right upgrade.
  SubscriptionTier requiredTierFor(EntitlementFeature feature) =>
      feature.requiredTier;

  /// Whether adding [currentCount + additional] documents stays within the
  /// document limit. Unlimited tiers always return true.
  bool canAddDocuments(int currentCount, {int additional = 1}) {
    final max = limits.maxDocuments;
    if (max == null) return true;
    return currentCount + additional <= max;
  }

  /// How many more documents the user may add (null = unlimited).
  int? remainingDocuments(int currentCount) {
    final max = limits.maxDocuments;
    if (max == null) return null;
    return (max - currentCount).clamp(0, max);
  }

  /// Whether creating [currentCount + additional] company collections stays
  /// within the company-collection limit. Unlimited tiers return true.
  bool canAddCompanyCollections(int currentCount, {int additional = 1}) {
    final max = limits.maxCompanyCollections;
    if (max == null) return true;
    return currentCount + additional <= max;
  }

  /// How many more company collections the user may create (null = unlimited).
  int? remainingCompanyCollections(int currentCount) {
    final max = limits.maxCompanyCollections;
    if (max == null) return null;
    return (max - currentCount).clamp(0, max);
  }

  /// Number of active documents the user currently tracks across all
  /// collections. Local-only mode returns the cached count.
  Future<int> documentsInUse() async {
    try {
      final items = await DocumentScannerService.instance.getAllItems();
      return items.where((i) => i.isActive).length;
    } catch (_) {
      return 0;
    }
  }

  /// Number of company (non-personal) collections the user owns.
  Future<int> companyCollectionsInUse() async {
    try {
      final collections = DocumentCollectionService.instance.collections;
      return collections.where((c) => !c.isPersonal).length;
    } catch (_) {
      return 0;
    }
  }

  /// Clear cached state on sign-out so the next user starts from Free.
  void reset() {
    _tier = SubscriptionTier.free;
    _initialized = false;
    _planEndsAt = null;
    _planDuration = null;
    notifyListeners();
  }
}
