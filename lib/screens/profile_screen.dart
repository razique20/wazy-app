import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_collection.dart';
import '../services/alert_preferences_service.dart';
import '../services/auth_service.dart';
import '../services/collection_service.dart';
import '../services/document_scanner_service.dart';
import '../services/finance_service.dart';
import '../services/custom_document_type_service.dart';
import '../services/gemini_api_service.dart';
import '../services/notification_service.dart';
import '../models/subscription_tier.dart';
import '../services/entitlement_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// Personal settings: profile, subscription, collections, and preferences.
///
/// Organized top-to-bottom in the order a user needs it:
/// 1. Profile header (identity, edit profile)
/// 2. Subscription (current plan, upgrade/renew)
/// 3. My Collections (document workspaces)
/// 4. Preferences (theme, alert switches, AI summary key)
/// 5. Reminder Schedule (when renewal alerts fire)
/// 6. Sign out
///
/// Every control saves immediately — there is no Save button.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<DocumentCollection> _collections = [];
  String _activeId = DocumentCollection.personalId;
  bool _loading = true;
  String _userName = 'Unknown User';
  String _userRole = 'Document Admin';
  String _userPhone = '';
  bool _notificationsEnabled = true;
  bool _billSpikesEnabled = true;
  bool _budgetAlertsEnabled = true;
  int _reminderCadence = 90;
  int _taskCadence = 60;
  int _escalationCadence = 30;
  String _geminiKey = '';

  @override
  void initState() {
    super.initState();
    _loadCollections();
    _loadSettings();
  }

  Future<void> _loadCollections() async {
    final service = DocumentCollectionService.instance;
    await service.getActiveCollection();
    if (mounted) {
      setState(() {
        _collections = service.collections;
        _activeId = service.activeCollectionId;
        _loading = false;
      });
    }
  }

  Future<void> _loadSettings() async {
    // Re-read the user's tier so the subscription card is current (the admin
    // may have processed an upgrade since this session started).
    await EntitlementService.instance.refresh();

    final prefs = await SharedPreferences.getInstance();
    final email = AuthService.instance.userEmail;
    final derivedName = email != null && email.contains('@')
        ? email
              .split('@')
              .first
              .replaceAll('.', ' ')
              .replaceAll('_', ' ')
              .toUpperCase()
        : 'Unknown User';

    setState(() {
      _userName = derivedName;
      _userRole = prefs.getString('userRole') ?? 'Document Admin';
      _userPhone = prefs.getString('userPhone') ?? '';
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _billSpikesEnabled = AlertPreferencesService.instance.billSpikesEnabled;
      _budgetAlertsEnabled =
          AlertPreferencesService.instance.budgetAlertsEnabled;
      _reminderCadence = prefs.getInt('reminderCadence') ?? 90;
      _taskCadence = prefs.getInt('taskCadence') ?? 60;
      _escalationCadence = prefs.getInt('escalationCadence') ?? 30;
      _geminiKey = prefs.getString('gemini.apiKey.v1') ?? '';
    });
  }

  /// Prompt for / clear the Gemini API key used by the AI executive summary.
  Future<void> _editGeminiKey() async {
    final controller = TextEditingController(text: _geminiKey);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gemini API key'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'AIza…',
            helperText:
                'Stored only on this device. Get a free key at aistudio.google.com',
          ),
        ),
        actions: [
          if (_geminiKey.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _geminiKey = result);
    if (result.isEmpty) {
      await GeminiApiService.instance.clearApiKey();
    } else {
      await GeminiApiService.instance.setApiKey(result);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isEmpty
              ? 'Gemini key removed — summaries use built-in templates'
              : 'Gemini key saved — summaries will be AI-polished',
        ),
      ),
    );
  }

  /// Persists the profile details edited in the bottom sheet.
  Future<void> _saveProfileDetails() async {
    final prefs = await SharedPreferences.getInstance();
    // userName is always derived from the sign-in email — not saved locally.
    await prefs.setString('userRole', _userRole);
    await prefs.setString('userPhone', _userPhone);
  }

  /// Persists reminder prefs and re-applies the OS reminder schedule so
  /// changes take effect immediately — there is no Save button on this page.
  Future<void> _applyReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setInt('reminderCadence', _reminderCadence);
    await prefs.setInt('taskCadence', _taskCadence);
    await prefs.setInt('escalationCadence', _escalationCadence);
    try {
      final items = await DocumentScannerService.instance.getAllItems();
      for (final item in items) {
        if (_notificationsEnabled) {
          await NotificationService.instance.scheduleEscalationLadder(
            item.id,
            item.expiresAt,
            title: item.displayName,
          );
        } else {
          await NotificationService.instance.cancelReminders(item.id);
        }
      }
    } catch (_) {
      // Non-fatal: scheduling may be unavailable (e.g. plugin not ready).
    }
  }

  Future<void> _editProfile(BuildContext context) async {
    final roleCtrl = TextEditingController(text: _userRole);
    final phoneCtrl = TextEditingController(text: _userPhone);

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Edit Profile',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: roleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Role / Designation',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    hintText: '+971 50 000 0000',
                    prefixIcon: Icon(Icons.phone_iphone_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _userRole = roleCtrl.text.trim().isEmpty
                            ? _userRole
                            : roleCtrl.text.trim();
                        _userPhone = phoneCtrl.text.trim();
                      });
                      Navigator.pop(ctx);
                      _saveProfileDetails();
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to see your documents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await AuthService.instance.signOut();
    DocumentScannerService.instance.clearCache();
    FinanceService.instance.clearCache();
    CustomDocumentTypeService.instance.reset();
    EntitlementService.instance.reset();

    if (mounted) context.go('/login');
  }

  // ------------------------------------------------------------------
  // Collection management
  // ------------------------------------------------------------------

  Future<void> _createCollection() async {
    // Track 1 gate: company workspaces are tiered — Free has none, Plus one,
    // Business unlimited.
    final entitlements = EntitlementService.instance;
    final companyCount = await entitlements.companyCollectionsInUse();
    if (!entitlements.canAddCompanyCollections(companyCount)) {
      final feature = entitlements.limits.maxCompanyCollections == 0
          ? EntitlementFeature.companyCollection
          : EntitlementFeature.multipleCompanyCollections;
      await showUpgradeDialog(context, feature);
      return;
    }

    final name = await showCreateCollectionDialog(context);
    if (name == null || !mounted) return;

    try {
      final created = await DocumentCollectionService.instance.createCollection(
        name,
      );
      await DocumentCollectionService.instance.setActive(created.id);
      await _loadCollections();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Collection "$name" created')));
      }
    } catch (e) {
      if (mounted) _showError('Could not create collection: $e');
    }
  }

  Future<void> _renameCollection(DocumentCollection collection) async {
    final name = await showRenameCollectionDialog(context, collection);
    if (name == null || !mounted) return;

    try {
      await DocumentCollectionService.instance.renameCollection(
        collection.id,
        name,
      );
      await _loadCollections();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Renamed to "$name"')));
      }
    } catch (e) {
      if (mounted) _showError('Could not rename collection: $e');
    }
  }

  Future<void> _deleteCollection(DocumentCollection collection) async {
    final confirmed = await showDeleteCollectionDialog(context, collection);
    if (!confirmed || !mounted) return;

    try {
      await DocumentCollectionService.instance.deleteCollection(collection.id);
      await _loadCollections();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('"${collection.name}" deleted')));
      }
    } catch (e) {
      if (mounted) _showError('Could not delete collection: $e');
    }
  }

  Future<void> _switchTo(DocumentCollection collection) async {
    await DocumentCollectionService.instance.setActive(collection.id);
    await DocumentScannerService.instance.refresh();
    await _loadCollections();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to "${collection.name}"')),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signedInEmail = AuthService.instance.userEmail;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Profile header — identity, sync state, edit profile.
                  _buildProfileHeaderCard(theme, signedInEmail),

                  const SizedBox(height: 20),

                  // 2. Subscription — current plan, expiry, upgrade/renew.
                  _buildSubscriptionSection(context, theme),

                  const SizedBox(height: 20),

                  // 3. Collections — group documents per company.
                  _buildCollectionsSection(context, theme),

                  const SizedBox(height: 20),

                  // 4. Preferences — theme, alert switches, AI summary key.
                  _buildPreferencesSection(context, theme),

                  const SizedBox(height: 20),

                  // 5. Reminder schedule — when renewal alerts fire.
                  _buildReminderTimingSection(context, theme),

                  const SizedBox(height: 24),

                  // 6. Account — sign out (sign-in lives on the profile card).
                  if (SupabaseService.hasCredentials &&
                      AuthService.instance.isSignedIn)
                    _buildSignOutButton(theme),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ------------------------------------------------------------------
  // 1. User Profile Header Card
  // ------------------------------------------------------------------

  Widget _buildProfileHeaderCard(ThemeData theme, String? email) {
    final initials = _userName
        .trim()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .take(2)
        .join('')
        .toUpperCase();
    final isCloudSynced =
        SupabaseService.hasCredentials && AuthService.instance.isSignedIn;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [WazyColors.navyPrimary, WazyColors.navyPrimaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WazyColors.cyanSecondary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: WazyColors.navyPrimary.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar with Cyan Accent Gradient
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [WazyColors.cyanSecondary, Color(0xFF00B8D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: WazyColors.cyanSecondary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials.isEmpty ? 'U' : initials,
                    style: const TextStyle(
                      color: Color(0xFF0A0E1A),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Cloud Synced / Local Workspace Pill Badge (Navy & Cyan)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: WazyColors.cyanSecondary.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: WazyColors.cyanSecondary.withOpacity(0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isCloudSynced
                                    ? Icons.cloud_done_rounded
                                    : Icons.storage_rounded,
                                size: 12,
                                color: WazyColors.cyanSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isCloudSynced
                                    ? 'Cloud Synced'
                                    : 'Local Workspace',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: WazyColors.cyanSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: WazyColors.cyanSecondary.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _userRole,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: WazyColors.cyanSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const TierBadge(compact: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 13,
                          color: WazyColors.cyanSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            email ?? 'local@wazy.app',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_userPhone.trim().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.phone_iphone_rounded,
                            size: 13,
                            color: WazyColors.cyanSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _userPhone,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.white.withOpacity(0.15)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editProfile(context),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: WazyColors.cyanSecondary,
                  ),
                  label: const Text(
                    'Edit Profile',
                    style: TextStyle(
                      color: WazyColors.cyanSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(
                      color: WazyColors.cyanSecondary.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (!AuthService.instance.isSignedIn)
                FilledButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.login, size: 16),
                  label: const Text('Sign in'),
                  style: FilledButton.styleFrom(
                    backgroundColor: WazyColors.cyanSecondary,
                    foregroundColor: const Color(0xFF0A0E1A),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // 2. Subscription section (Track 1)
  // ------------------------------------------------------------------

  Widget _buildSubscriptionSection(BuildContext context, ThemeData theme) {
    final entitlements = EntitlementService.instance;
    final tier = entitlements.tier;
    final info = TierInfo.all[tier]!;
    final limits = entitlements.limits;
    final isTopTier = TierInfo.nextTierUp(tier) == null;
    final planEndsAt = entitlements.planEndsAt;
    final daysLeft = entitlements.daysUntilPlanExpiry();
    final isExpired = entitlements.isPlanExpired;
    final isPaid = tier != SubscriptionTier.free && planEndsAt != null;

    return _buildSection(
      context,
      'Subscription',
      Icons.workspace_premium_rounded,
      theme,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TierBadge(tier: tier),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    info.tagline,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
            // Plan expiry countdown (fetched from user_tiers.plan_ends_at).
            if (isPaid && !isExpired && daysLeft != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (daysLeft <= 7 ? WazyColors.warning : WazyColors.safe)
                      .withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (daysLeft <= 7 ? WazyColors.warning : WazyColors.safe)
                        .withAlpha(70),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      daysLeft <= 7
                          ? Icons.notification_important_rounded
                          : Icons.event_available_rounded,
                      size: 18,
                      color: daysLeft <= 7 ? WazyColors.warning : WazyColors.safe,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        daysLeft == 0
                            ? 'Your ${info.name} plan expires today'
                            : 'Your ${info.name} plan expires in $daysLeft '
                                  'day${daysLeft == 1 ? '' : 's'} — '
                                  '${_formatDate(planEndsAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color:
                              daysLeft <= 7 ? WazyColors.warning : WazyColors.safe,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Expired plan: warn + nudge to renew.
            if (isExpired) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: WazyColors.danger.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: WazyColors.danger.withAlpha(70)),
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
                        'Your ${info.name} plan expired on '
                        '${_formatDate(planEndsAt!)} — features are locked '
                        'again. Tap Renew Plan to resubscribe.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: WazyColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              limits.maxDocuments == null
                  ? 'Unlimited documents • '
                        '${limits.maxCompanyCollections ?? 'unlimited'} '
                        'company workspace(s)'
                  : '${limits.maxDocuments} documents • '
                        '${limits.maxCompanyCollections == 0 ? 'no' : limits.maxCompanyCollections} '
                        'company workspace(s)',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (!isTopTier)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => showTierRequestSheet(context),
                  icon: const Icon(Icons.upgrade_rounded, size: 18),
                  label: Text(isExpired
                      ? 'Renew Plan'
                      : isPaid
                          ? 'Extend Plan'
                          : 'Upgrade Plan'),
                  style: FilledButton.styleFrom(
                    backgroundColor: WazyColors.navyPrimary,
                    foregroundColor: Colors.white,
                  ),
                ),
              )
            else
              Text(
                'You are on the highest plan — thanks for supporting Wazy!',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: WazyColors.safe,
                ),
              ),
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

  // ------------------------------------------------------------------
  // 3. Collections section
  // ------------------------------------------------------------------

  Widget _buildCollectionsSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.folder_shared_outlined,
              size: 20,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Text(
              'My Collections',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _createCollection,
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'New collection',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'One collection per company — or keep everything in Personal. '
          'Documents are grouped inside the collection you choose.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final collection in _collections) ...[
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: collection.isPersonal
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      collection.icon,
                      color: collection.isPersonal
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    collection.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    collection.isPersonal
                        ? 'Your own documents — always here'
                        : 'Company collection',
                  ),
                  trailing: _activeId == collection.id
                      ? const Tooltip(
                          message: 'Active collection',
                          child: Icon(Icons.check_circle, color: Colors.green),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Personal collection cannot be renamed/deleted.
                            if (!collection.isPersonal) ...[
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Rename',
                                onPressed: () => _renameCollection(collection),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                tooltip: 'Delete',
                                onPressed: () => _deleteCollection(collection),
                              ),
                            ],
                          ],
                        ),
                  onTap: _activeId == collection.id
                      ? null
                      : () => _switchTo(collection),
                ),
                if (collection != _collections.last)
                  const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // 4. Preferences — theme, alert switches, AI summary key.
  //    Every control saves immediately.
  // ------------------------------------------------------------------

  Widget _buildPreferencesSection(BuildContext context, ThemeData theme) {
    return _buildSection(
      context,
      'Preferences',
      Icons.tune_rounded,
      theme,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto, size: 18),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode, size: 18),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode, size: 18),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {ThemeService.instance.mode},
                    onSelectionChanged: (selected) {
                      ThemeService.instance.setMode(selected.first);
                      setState(() {}); // update selected highlight
                    },
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Renewal notifications'),
            subtitle: const Text('Remind me before documents expire'),
            value: _notificationsEnabled,
            onChanged: (value) async {
              setState(() => _notificationsEnabled = value);
              await _applyReminderSettings();
            },
          ),
          const Divider(height: 1),
          // Saved immediately; silences the spike snackbar.
          SwitchListTile(
            title: const Text('Bill spike alerts'),
            subtitle: const Text(
              'Flag bills unusually higher than your average',
            ),
            value: _billSpikesEnabled,
            onChanged: (value) async {
              setState(() => _billSpikesEnabled = value);
              await AlertPreferencesService.instance.setBillSpikesEnabled(value);
            },
          ),
          const Divider(height: 1),
          // Saved immediately: silences the snackbar, the OS budget
          // notification and the Money tab badge.
          SwitchListTile(
            title: const Text('Budget alerts'),
            subtitle: const Text(
              'Warn when spending nears a category budget',
            ),
            value: _budgetAlertsEnabled,
            onChanged: (value) async {
              setState(() => _budgetAlertsEnabled = value);
              await AlertPreferencesService.instance.setBudgetAlertsEnabled(value);
            },
          ),
          const Divider(height: 1),
          // AI Executive Summary — Gemini API key configuration. Key stays
          // on-device and only gates the LLM polish pass; the summary works
          // without it.
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.deepPurple,
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            title: const Text('AI Executive Summary'),
            subtitle: Text(
              _geminiKey.isEmpty
                  ? 'Uses built-in templates — add a Gemini key for AI polish'
                  : 'Gemini key configured — summaries are AI-polished',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.edit_rounded, size: 20),
              onPressed: _editGeminiKey,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // 5. Reminder Schedule — when the renewal alert ladder fires.
  //    Each change is saved and re-applied to scheduled OS reminders
  //    immediately.
  // ------------------------------------------------------------------

  Widget _buildReminderTimingSection(BuildContext context, ThemeData theme) {
    return _buildSection(
      context,
      'Reminder Schedule',
      Icons.event_repeat_rounded,
      theme,
      child: Column(
        children: [
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.indigo,
              child: Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: 18,
              ),
            ),
            title: const Text('First reminder'),
            subtitle: const Text(
              'First notification when an expiry is this far away',
            ),
            trailing: DropdownButton<int>(
              value: _reminderCadence,
              underline: const SizedBox(),
              items: [30, 60, 90, 120].map((d) {
                return DropdownMenuItem(
                  value: d,
                  child: Text('$d days'),
                );
              }).toList(),
              onChanged: (v) async {
                if (v != null) {
                  setState(() => _reminderCadence = v);
                  await _applyReminderSettings();
                }
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.amber,
              child: Icon(
                Icons.assignment_turned_in,
                color: Colors.white,
                size: 18,
              ),
            ),
            title: const Text('Renewal task'),
            subtitle: const Text(
              'Assign the renewal task to a responsible person',
            ),
            trailing: DropdownButton<int>(
              value: _taskCadence,
              underline: const SizedBox(),
              items: [30, 45, 60, 75, 90].map((d) {
                return DropdownMenuItem(
                  value: d,
                  child: Text('$d days'),
                );
              }).toList(),
              onChanged: (v) async {
                if (v != null) {
                  setState(() => _taskCadence = v);
                  await _applyReminderSettings();
                }
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(
                Icons.priority_high_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            title: const Text('Escalation'),
            subtitle: const Text(
              'Escalate to management / stakeholders',
            ),
            trailing: DropdownButton<int>(
              value: _escalationCadence,
              underline: const SizedBox(),
              items: [15, 21, 30, 45].map((d) {
                return DropdownMenuItem(
                  value: d,
                  child: Text('$d days'),
                );
              }).toList(),
              onChanged: (v) async {
                if (v != null) {
                  setState(() => _escalationCadence = v);
                  await _applyReminderSettings();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // 6. Sign out
  // ------------------------------------------------------------------

  Widget _buildSignOutButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _signOut,
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Sign out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.error,
          side: BorderSide(color: theme.colorScheme.error.withAlpha(100)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    ThemeData theme, {
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.outline),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 8),
        Card(child: Column(children: [const Divider(height: 1), child])),
      ],
    );
  }
}
