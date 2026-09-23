import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_collection.dart';
import '../models/subscription_tier.dart';
import '../services/alert_preferences_service.dart';
import '../services/auth_service.dart';
import '../services/collection_service.dart';
import '../services/document_scanner_service.dart';
import '../services/finance_service.dart';
import '../services/custom_document_type_service.dart';
import '../services/gemini_api_service.dart';
import '../services/notification_service.dart';
import '../services/entitlement_service.dart';
import '../services/supabase_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// Profile tab — Settings, redesigned to the visual language of the Home and
/// Documents tabs: a navy hero header over a rounded content sheet.
///
/// It keeps the same anatomy family but a settings-specific identity — the
/// hero carries the user's identity (avatar, name, plan and sync badges)
/// instead of live dashboards, and the sheet holds grouped preference cards
/// rather than grids or document lists:
/// 1. Subscription card (plan, usage meters, upgrade/renew)
/// 2. Collections (document workspaces)
/// 3. Appearance (theme)
/// 4. Alerts & reminders (alert switches + reminder ladder)
/// 5. AI summary key
///
/// Sign out lives in the hero — the floating bottom nav pill covers the end
/// of the scroll content, so it can't live there. Every control saves
/// immediately — there is no Save button.
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
    // The active collection can be switched elsewhere (e.g. the Home page's
    // switcher); mirror those changes in the My Collections section.
    DocumentCollectionService.instance.addListener(_onCollectionsChanged);
  }

  @override
  void dispose() {
    DocumentCollectionService.instance.removeListener(_onCollectionsChanged);
    super.dispose();
  }

  void _onCollectionsChanged() {
    if (!mounted) return;
    // Schedule outside the notification in case the service notifies while
    // the widget tree is building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCollections();
    });
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
    // Same as the Home switcher: re-scope finance data so the Money tab
    // follows the newly active collection.
    await FinanceService.instance.refresh();
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      // Navy backdrop behind the hero; the content sheet covers the rest.
      // Same backdrop as Home/Documents.
      backgroundColor:
          isDark ? WazyColors.obsidian : WazyColors.navyPrimaryDark,
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                color: theme.colorScheme.secondary,
                onRefresh: _loadSettings,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeroHeader(theme)),
                    SliverToBoxAdapter(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(24),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            _buildAccountCard(theme),
                            const SizedBox(height: 16),
                            _buildSubscriptionSection(context, theme),
                            const SizedBox(height: 16),
                            _buildCollectionsSection(context, theme),
                            const SizedBox(height: 16),
                            _buildAppearanceSection(context, theme),
                            const SizedBox(height: 16),
                            _buildAlertsSection(context, theme),
                            const SizedBox(height: 16),
                            _buildAiSection(context, theme),
                            // Keep the last card scrollable clear of the
                            // floating nav pill (height + margins ≈ 80).
                            SizedBox(
                              height:
                                  8 +
                                  MediaQuery.of(context).padding.bottom +
                                  80,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // White filler: extends the sheet across the rest of the
                    // viewport when content is short, and into overscroll —
                    // the navy backdrop never peeks out below the content,
                    // behind the floating nav pill.
                    SliverFillRemaining(
                      hasScrollBody: false,
                      fillOverscroll: true,
                      child: ColoredBox(color: theme.colorScheme.surface),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Hero header — identity (avatar, name, badges, email)
  // ------------------------------------------------------------------

  Widget _buildHeroHeader(ThemeData theme) {
    final email = AuthService.instance.userEmail;
    final isCloudSynced =
        SupabaseService.hasCredentials && AuthService.instance.isSignedIn;
    final signedIn = AuthService.instance.isSignedIn;
    final entitlements = EntitlementService.instance;
    final tier = entitlements.tier;
    final tierInfo = TierInfo.all[tier]!;
    final daysLeft = entitlements.daysUntilPlanExpiry();

    final initials = _userName
        .trim()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .take(2)
        .join('')
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Settings',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (signedIn)
                _HeroIconButton(
                  icon: Icons.logout_rounded,
                  tooltip: 'Sign out',
                  onTap: _signOut,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Avatar: initials on the cyan accent — the only cyan-forward
              // element in the hero, echoing the filled "Budget" pill.
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [WazyColors.cyanSecondary, Color(0xFF00B8D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    initials.isEmpty ? 'U' : initials,
                    style: const TextStyle(
                      color: Color(0xFF0A0E1A),
                      fontSize: 18,
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
                    Text(
                      _userName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email ?? 'local@wazy.app',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.65),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Plan + sync status badges.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(
                icon: Icons.workspace_premium_rounded,
                label: tierInfo.name,
              ),
              _HeroPill(
                icon: isCloudSynced
                    ? Icons.cloud_done_rounded
                    : Icons.storage_rounded,
                label: isCloudSynced ? 'Cloud synced' : 'Local only',
              ),
              if (daysLeft != null && !entitlements.isPlanExpired)
                _HeroPill(
                  icon: Icons.hourglass_top_rounded,
                  label: '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // 1. Account card — role/phone summary + edit (identity lives in the
  //    hero; the card carries the editable details).
  // ------------------------------------------------------------------

  Widget _buildAccountCard(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: _tileBg(theme),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _SettingsTile(
              icon: Icons.badge_outlined,
              title: _userRole,
              subtitle: 'Role / designation',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.grey,
              ),
              onTap: () => _editProfile(context),
            ),
            if (_userPhone.trim().isNotEmpty)
              _SettingsTile(
                icon: Icons.phone_iphone_rounded,
                title: _userPhone,
                subtitle: 'Phone number',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Colors.grey,
                ),
                onTap: () => _editProfile(context),
              ),
            _SettingsTile(
              icon: Icons.folder_special_rounded,
              title: '$_activeCollectionName is active',
              subtitle: 'Current collection',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Colors.grey,
              ),
              onTap: () => context.go('/documents'),
            ),
          ],
        ),
      ),
    );
  }

  String get _activeCollectionName {
    for (final c in _collections) {
      if (c.id == _activeId) return c.name;
    }
    return 'Personal';
  }

  // ------------------------------------------------------------------
  // 2. Subscription — plan badge, expiry, usage meters, upgrade/renew.
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subscription',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _tileBg(theme),
              borderRadius: BorderRadius.circular(16),
            ),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Plan expiry countdown (fetched from user_tiers.plan_ends_at).
            if (isPaid && !isExpired && daysLeft != null) ...[
              const SizedBox(height: 10),
              _planNotice(
                theme,
                icon: daysLeft <= 7
                    ? Icons.notification_important_rounded
                    : Icons.event_available_rounded,
                color: daysLeft <= 7 ? WazyColors.warning : WazyColors.safe,
                text: daysLeft == 0
                    ? 'Your ${info.name} plan expires today'
                    : 'Your ${info.name} plan expires in $daysLeft '
                          'day${daysLeft == 1 ? '' : 's'} — '
                          '${_formatDate(planEndsAt)}',
              ),
            ],
            // Expired plan: warn + nudge to renew.
            if (isExpired) ...[
              const SizedBox(height: 10),
              _planNotice(
                theme,
                icon: Icons.error_outline_rounded,
                color: WazyColors.danger,
                text: 'Your ${info.name} plan expired on '
                    '${_formatDate(planEndsAt!)} — features are locked '
                    'again. Tap Renew Plan to resubscribe.',
              ),
            ],
            const SizedBox(height: 12),
            // Usage meters: documents + company workspaces, mirrored from
            // the free-tier limits.
            FutureBuilder<int>(
              future: _documentCount ??= _countDocuments(),
              builder: (context, snap) {
                final used = snap.data ?? 0;
                final max = limits.maxDocuments;
                final companyUsed = _collections
                    .where((c) => !c.isPersonal)
                    .length;
                final maxCompany = limits.maxCompanyCollections;
                // Hide the workspaces meter on Free (cap 0, none in use) —
                // a permanent empty bar is noise, not information.
                final showCompanyMeter =
                    companyUsed > 0 || (maxCompany != null && maxCompany > 0);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _UsageMeter(
                      label: 'Documents',
                      used: used,
                      max: max,
                    ),
                    if (showCompanyMeter) ...[
                      const SizedBox(height: 8),
                      _UsageMeter(
                        label: 'Company workspaces',
                        used: companyUsed,
                        max: maxCompany,
                      ),
                    ],
                  ],
                );
              },
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
        ],
      ),
    );
  }

  /// One-tick-later guard so the FutureBuilder doesn't re-fire the count on
  /// every rebuild (usage only changes when documents change).
  Future<int>? _documentCount;

  Future<int> _countDocuments() =>
      EntitlementService.instance.documentsInUse();

  Widget _planNotice(
    ThemeData theme, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
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
  // 3. Collections — group documents per company.
  // ------------------------------------------------------------------

  Widget _buildCollectionsSection(BuildContext context, ThemeData theme) {
    return _SettingsGroup(
      title: 'My Collections',
      action: IconButton(
        onPressed: _createCollection,
        icon: const Icon(Icons.add_circle_outline),
        tooltip: 'New collection',
        visualDensity: VisualDensity.compact,
      ),
      children: [
        for (final collection in _collections)
          _SettingsTile(
            icon: collection.icon,
            title: collection.name,
            subtitle: collection.isPersonal
                ? 'Your own documents — always here'
                : 'Company collection',
            highlighted: _activeId == collection.id,
            trailing: _activeId == collection.id
                ? const Tooltip(
                    message: 'Active collection',
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Personal collection cannot be renamed/deleted.
                      if (!collection.isPersonal) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Rename',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _renameCollection(collection),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _deleteCollection(collection),
                        ),
                      ],
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ],
                  ),
            onTap: _activeId == collection.id
                ? null
                : () => _switchTo(collection),
          ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // 4. Appearance — theme (segmented control).
  // ------------------------------------------------------------------

  Widget _buildAppearanceSection(BuildContext context, ThemeData theme) {
    return _SettingsGroup(
      title: 'Appearance',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: SizedBox(
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
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // 5. Alerts & reminders — switches + the reminder ladder.
  //    Every change is saved and re-applied immediately.
  // ------------------------------------------------------------------

  Widget _buildAlertsSection(BuildContext context, ThemeData theme) {
    return _SettingsGroup(
      title: 'Alerts & Reminders',
      children: [
        _SettingsSwitchTile(
          icon: Icons.notifications_rounded,
          title: 'Renewal notifications',
          subtitle: 'Remind me before documents expire',
          value: _notificationsEnabled,
          onChanged: (value) async {
            setState(() => _notificationsEnabled = value);
            await _applyReminderSettings();
          },
        ),
        _SettingsSwitchTile(
          icon: Icons.trending_up_rounded,
          title: 'Bill spike alerts',
          subtitle: 'Flag bills unusually higher than your average',
          value: _billSpikesEnabled,
          onChanged: (value) async {
            setState(() => _billSpikesEnabled = value);
            await AlertPreferencesService.instance.setBillSpikesEnabled(value);
          },
        ),
        _SettingsSwitchTile(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Budget alerts',
          subtitle: 'Warn when spending nears a category budget',
          value: _budgetAlertsEnabled,
          onChanged: (value) async {
            setState(() => _budgetAlertsEnabled = value);
            await AlertPreferencesService.instance
                .setBudgetAlertsEnabled(value);
          },
        ),
        _SettingsDropdownTile<int>(
          icon: Icons.notifications_active,
          iconColor: Colors.indigo,
          title: 'First reminder',
          subtitle: 'First notification when an expiry is this far away',
          value: _reminderCadence,
          items: [30, 60, 90, 120],
          onChanged: (v) async {
            if (v != null) {
              setState(() => _reminderCadence = v);
              await _applyReminderSettings();
            }
          },
        ),
        _SettingsDropdownTile<int>(
          icon: Icons.assignment_turned_in,
          iconColor: Colors.amber.shade700,
          title: 'Renewal task',
          subtitle: 'Assign the renewal task to a responsible person',
          value: _taskCadence,
          items: [30, 45, 60, 75, 90],
          onChanged: (v) async {
            if (v != null) {
              setState(() => _taskCadence = v);
              await _applyReminderSettings();
            }
          },
        ),
        _SettingsDropdownTile<int>(
          icon: Icons.priority_high_rounded,
          iconColor: Colors.orange,
          title: 'Escalation',
          subtitle: 'Escalate to management / stakeholders',
          value: _escalationCadence,
          items: [15, 21, 30, 45],
          onChanged: (v) async {
            if (v != null) {
              setState(() => _escalationCadence = v);
              await _applyReminderSettings();
            }
          },
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // 6. AI summary — Gemini key configuration. Key stays on-device and only
  //    gates the LLM polish pass; the summary works without it.
  // ------------------------------------------------------------------

  Widget _buildAiSection(BuildContext context, ThemeData theme) {
    return _SettingsGroup(
      title: 'AI Summary',
      children: [
        _SettingsTile(
          icon: Icons.auto_awesome_rounded,
          iconColor: Colors.deepPurple,
          title: 'AI Executive Summary',
          subtitle: _geminiKey.isEmpty
              ? 'Uses built-in templates — add a Gemini key for AI polish'
              : 'Gemini key configured — summaries are AI-polished',
          trailing: const Icon(
            Icons.edit_rounded,
            size: 20,
            color: Colors.grey,
          ),
          onTap: _editGeminiKey,
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Shared building blocks
  // ------------------------------------------------------------------

  Color _tileBg(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return isDark
        ? WazyColors.slate.withOpacity(0.55)
        : WazyColors.cloud;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings building blocks
// ─────────────────────────────────────────────────────────────────────────────

/// A grouped settings card: title row (like "Next renewals · N") over a
/// rounded tile-background column of rows, matching the sheet's tile style.
class _SettingsGroup extends StatelessWidget {
  final String title;
  final Widget? action;
  final List<Widget> children;

  const _SettingsGroup({
    required this.title,
    required this.children,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tileBg = isDark
        ? WazyColors.slate.withOpacity(0.55)
        : WazyColors.cloud;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: tileBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1)
                    Divider(
                      height: 1,
                      indent: 50,
                      endIndent: 16,
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.05),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One tappable settings row: tinted circular icon, title, optional subtitle,
/// and a trailing widget — the same row anatomy as the notification rows.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool highlighted;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.iconColor,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = iconColor ??
        (isDark ? WazyColors.textPrimary : WazyColors.navyPrimary);

    return Material(
      color: highlighted
          ? theme.colorScheme.primary.withOpacity(isDark ? 0.14 : 0.06)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withOpacity(isDark ? 0.14 : 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Switch row inside a [_SettingsGroup].
class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () => onChanged(!value),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

/// Dropdown row inside a [_SettingsGroup].
class _SettingsDropdownTile<T> extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;

  const _SettingsDropdownTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.items,
    required this.onChanged,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SettingsTile(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      onTap: () {
        // Hand-rolled menu: ListTile options in a bottom sheet, matching
        // the collection switcher on Home.
        showModalBottomSheet<T>(
          context: context,
          backgroundColor: theme.colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 1),
                for (final item in items)
                  ListTile(
                    leading: Text(
                      _labelFor(item),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: value == item
                        ? Icon(
                            Icons.check_rounded,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.pop(sheetContext, item),
                  ),
              ],
            ),
          ),
        ).then((selection) {
          if (selection != null) onChanged(selection);
        });
      },
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _labelFor(value),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Icon(Icons.expand_more_rounded, size: 18),
        ],
      ),
    );
  }

  String _labelFor(T value) {
    // Day counts render as "N days"; other types as raw strings.
    if (value is int) return '$value days';
    return '$value';
  }
}

/// Plan usage meter: label + "used / max" (or "used · unlimited"), with a
/// thin progress bar — documents/workspaces at a glance, like the money
/// breakdown under the Home hero.
class _UsageMeter extends StatelessWidget {
  final String label;
  final int used;
  final int? max;

  const _UsageMeter({
    required this.label,
    required this.used,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ratio = max == null || max == 0 ? 0.0 : (used / max!).clamp(0.0, 1.0);
    final barColor = max == null
        ? WazyColors.safe
        : ratio >= 1.0
            ? WazyColors.danger
            : ratio >= 0.8
                ? WazyColors.warning
                : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            Text(
              max == null
                  ? '$used · unlimited'
                  : '$used / $max',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: max == null ? null : ratio,
            minHeight: 5,
            backgroundColor: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

/// Frosted pill in the hero (plan / sync status) — a quieter variant of the
/// hero action pills on Home.
class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted glass icon button used in the hero header (sign out) — same style
/// as the dark-mode toggle on Home.
class _HeroIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeroIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
