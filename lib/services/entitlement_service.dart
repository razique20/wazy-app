import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_collection.dart';
import '../models/subscription_tier.dart';
import 'auth_service.dart';
import 'collection_service.dart';
import 'document_scanner_service.dart';
import 'supabase_service.dart';
import 'ai_executive_summary_service.dart';
import 'ai_budget_plan_service.dart';

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
  /// an end date). Read from `user_tiers.plan_ends_at`, falling back to
  /// `user_tiers.expires_at` (the Admin Console's column).
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
    final prefs = await SharedPreferences.getInstance();
    var resolved = SubscriptionTier.tryFromId(prefs.getString(tierOverrideKey)) ??
        SubscriptionTier.free;

    final client = SupabaseService.clientOrNull;
    final userId = AuthService.instance.currentUserId;
    if (client != null && userId != null) {
      try {
        Map<String, dynamic>? row;
        try {
          row = await client
              .from('user_tiers')
              .select('tier, plan_duration, plan_ends_at, expires_at')
              .eq('user_id', userId)
              .maybeSingle();
        } catch (_) {
          // Deployment without the Admin Console's expires_at column —
          // retry with the original Flutter-schema columns only.
          row = await client
              .from('user_tiers')
              .select('tier, plan_duration, plan_ends_at')
              .eq('user_id', userId)
              .maybeSingle();
        }
        final serverTier = SubscriptionTier.tryFromId(row?['tier'] as String?);
        if (serverTier != null) resolved = serverTier;
        _planDuration = row?['plan_duration'] as String?;
        // The paid plan ends at `plan_ends_at` (Flutter schema) or
        // `expires_at` (Admin Console schema) — whichever is set. Without
        // this fallback an admin-granted expiry is invisible to the app and
        // an expired plan would keep its paid features forever.
        final endsAt = (row?['plan_ends_at'] ?? row?['expires_at']) as String?;
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
      // Tier changed (upgrade or downgrade) — reset current month AI usage to zero
      await AiExecutiveSummaryService.instance.resetCurrentMonthUsage();
      await AiBudgetPlanService.instance.resetCurrentMonthUsage();
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

  /// Whether a specific collection is locked under the current subscription tier.
  /// The personal collection is never locked.
  /// Company collections are unlocked up to [TierLimits.maxCompanyCollections].
  /// Any company collection exceeding the active plan's allowance is locked.
  bool isCollectionLocked(DocumentCollection collection) {
    if (collection.isPersonal) return false;
    final max = limits.maxCompanyCollections;
    if (max == null) return false; // unlimited (Business tier)
    if (max <= 0) return true; // Free tier allows 0 company collections
    final companyCollections = DocumentCollectionService.instance.collections
        .where((c) => !c.isPersonal)
        .toList();
    final index = companyCollections.indexWhere((c) => c.id == collection.id);
    if (index == -1) {
      return companyCollections.length >= max;
    }
    return index >= max;
  }

  /// Whether a collection by [id] is locked.
  bool isCollectionIdLocked(String id) {
    final collection = DocumentCollectionService.instance.collections
        .where((c) => c.id == id)
        .firstOrNull;
    if (collection == null) return false;
    return isCollectionLocked(collection);
  }

  /// The minimum subscription tier required to unlock [collection].
  SubscriptionTier requiredTierForCollection(DocumentCollection collection) {
    if (collection.isPersonal) return SubscriptionTier.free;
    final companyCollections = DocumentCollectionService.instance.collections
        .where((c) => !c.isPersonal)
        .toList();
    final index = companyCollections.indexWhere((c) => c.id == collection.id);
    if (index <= 0) return SubscriptionTier.plus; // 1st company collection is Plus
    return SubscriptionTier.business; // 2nd+ company collections are Business
  }

  /// The entitlement feature needed to unlock [collection].
  EntitlementFeature requiredFeatureForCollection(DocumentCollection collection) {
    if (collection.isPersonal) return EntitlementFeature.companyCollection;
    final companyCollections = DocumentCollectionService.instance.collections
        .where((c) => !c.isPersonal)
        .toList();
    final index = companyCollections.indexWhere((c) => c.id == collection.id);
    if (index <= 0) return EntitlementFeature.companyCollection;
    return EntitlementFeature.multipleCompanyCollections;
  }

  /// How many company collections are currently locked for the user.
  int get lockedCollectionsCount {
    final companyCollections = DocumentCollectionService.instance.collections
        .where((c) => !c.isPersonal);
    return companyCollections.where(isCollectionLocked).length;
  }

  /// Whether the user has at least one locked collection.
  bool get hasAnyLockedCollections => lockedCollectionsCount > 0;

  /// Clear cached state on sign-out so the next user starts from Free.
  void reset() {
    _tier = SubscriptionTier.free;
    _initialized = false;
    _planEndsAt = null;
    _planDuration = null;
    notifyListeners();
  }
}
