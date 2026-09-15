import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/document_collection.dart';
import '../services/auth_service.dart';
import '../services/collection_service.dart';
import '../services/document_scanner_service.dart';
import '../services/finance_service.dart';
import '../services/supabase_service.dart';
import '../widgets/widgets.dart';

/// Personal settings: account, notification preferences, and management of
/// the user's document collections (built-in Personal + company collections).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<DocumentCollection> _collections = [];
  String _activeId = DocumentCollection.personalId;
  bool _loading = true;
  bool _saving = false;
  bool _notificationsEnabled = true;
  bool _whatsappAlertsEnabled = true;
  bool _emailAlertsEnabled = true;
  int _reminderCadence = 90;
  int _taskCadence = 60;
  int _escalationCadence = 30;
  int _whatsappCadence = 7;

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
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _whatsappAlertsEnabled = prefs.getBool('whatsappAlertsEnabled') ?? true;
      _emailAlertsEnabled = prefs.getBool('emailAlertsEnabled') ?? true;
      _reminderCadence = prefs.getInt('reminderCadence') ?? 90;
      _taskCadence = prefs.getInt('taskCadence') ?? 60;
      _escalationCadence = prefs.getInt('escalationCadence') ?? 30;
      _whatsappCadence = prefs.getInt('whatsappCadence') ?? 7;
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setBool('whatsappAlertsEnabled', _whatsappAlertsEnabled);
    await prefs.setBool('emailAlertsEnabled', _emailAlertsEnabled);
    await prefs.setInt('reminderCadence', _reminderCadence);
    await prefs.setInt('taskCadence', _taskCadence);
    await prefs.setInt('escalationCadence', _escalationCadence);
    await prefs.setInt('whatsappCadence', _whatsappCadence);

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content:
            const Text('You will need to sign in again to see your documents.'),
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

    if (mounted) context.go('/login');
  }

  // ------------------------------------------------------------------
  // Collection management
  // ------------------------------------------------------------------

  Future<void> _createCollection() async {
    final name = await showCreateCollectionDialog(context);
    if (name == null || !mounted) return;

    try {
      final created = await DocumentCollectionService.instance
          .createCollection(name);
      await DocumentCollectionService.instance.setActive(created.id);
      await _loadCollections();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Collection "$name" created')),
        );
      }
    } catch (e) {
      if (mounted) _showError('Could not create collection: $e');
    }
  }

  Future<void> _renameCollection(DocumentCollection collection) async {
    final name = await showRenameCollectionDialog(context, collection);
    if (name == null || !mounted) return;

    try {
      await DocumentCollectionService.instance
          .renameCollection(collection.id, name);
      await _loadCollections();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Renamed to "$name"')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${collection.name}" deleted')),
        );
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
                  // Collections manager
                  _buildCollectionsSection(context, theme),

                  const SizedBox(height: 20),

                  // Account section — always visible so sign-in state and
                  // sign-out stay discoverable. In local-only mode (no
                  // Supabase credentials) it explains how to enable auth.
                  if (SupabaseService.hasCredentials)
                    _buildAccountSection(theme, signedInEmail)
                  else
                    _buildLocalModeSection(theme),
                  const SizedBox(height: 20),

                  // Notification settings
                  _buildSection(
                    context,
                    'Notifications & Alerts',
                    Icons.notifications_active_rounded,
                    theme,
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Enable notifications'),
                          subtitle: const Text('Receive renewal alerts'),
                          value: _notificationsEnabled,
                          onChanged: (value) {
                            setState(() => _notificationsEnabled = value);
                            _markDirty();
                          },
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('WhatsApp alerts'),
                          subtitle: const Text('Send urgent alerts via WhatsApp'),
                          value: _whatsappAlertsEnabled,
                          onChanged: (value) {
                            setState(() => _whatsappAlertsEnabled = value);
                            _markDirty();
                          },
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Email alerts'),
                          subtitle:
                              const Text('Send renewal reminders via email'),
                          value: _emailAlertsEnabled,
                          onChanged: (value) {
                            setState(() => _emailAlertsEnabled = value);
                            _markDirty();
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Alert cadence settings
                  _buildSection(
                    context,
                    'Alert Timing',
                    Icons.timer_outlined,
                    theme,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.indigo,
                            child: Icon(Icons.notifications_active,
                                color: Colors.white, size: 18),
                          ),
                          title: const Text('90-day reminder'),
                          subtitle: const Text(
                              'First notification when expiry is 90 days away'),
                          trailing: DropdownButton<int>(
                            value: _reminderCadence,
                            underline: const SizedBox(),
                            items: [30, 60, 90, 120].map((d) {
                              return DropdownMenuItem(
                                value: d,
                                child: Text('$d days'),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _reminderCadence = v);
                                _markDirty();
                              }
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.amber,
                            child: Icon(Icons.assignment_turned_in,
                                color: Colors.white, size: 18),
                          ),
                          title: const Text('60-day task'),
                          subtitle: const Text(
                              'Assign renewal task to responsible person'),
                          trailing: DropdownButton<int>(
                            value: _taskCadence,
                            underline: const SizedBox(),
                            items: [30, 45, 60, 75, 90].map((d) {
                              return DropdownMenuItem(
                                value: d,
                                child: Text('$d days'),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _taskCadence = v);
                                _markDirty();
                              }
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Icon(Icons.priority_high_rounded,
                                color: Colors.white, size: 18),
                          ),
                          title: const Text('30-day escalation'),
                          subtitle:
                              const Text('Escalate to management / stakeholders'),
                          trailing: DropdownButton<int>(
                            value: _escalationCadence,
                            underline: const SizedBox(),
                            items: [15, 21, 30, 45].map((d) {
                              return DropdownMenuItem(
                                value: d,
                                child: Text('$d days'),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _escalationCadence = v);
                                _markDirty();
                              }
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.red,
                            child: Icon(Icons.whatshot_rounded,
                                color: Colors.white, size: 18),
                          ),
                          title: const Text('7-day WhatsApp'),
                          subtitle: const Text('Final urgent alert via WhatsApp'),
                          trailing: DropdownButton<int>(
                            value: _whatsappCadence,
                            underline: const SizedBox(),
                            items: [3, 5, 7, 10].map((d) {
                              return DropdownMenuItem(
                                value: d,
                                child: Text('$d days'),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _whatsappCadence = v);
                                _markDirty();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Danger zone
                  _buildSection(
                    context,
                    'Danger Zone',
                    Icons.warning_amber_rounded,
                    theme,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.delete_forever,
                              color: Colors.red),
                          title: const Text('Clear all documents'),
                          subtitle: const Text(
                              'Remove every tracked document in the active collection'),
                          onTap: () => _confirmClearAll(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save Settings'),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ------------------------------------------------------------------
  // Collections section
  // ------------------------------------------------------------------

  Widget _buildCollectionsSection(
    BuildContext context,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.folder_copy_outlined,
                size: 20, color: theme.colorScheme.outline),
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
                          child: Icon(Icons.check_circle,
                              color: Colors.green),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Personal collection cannot be renamed/deleted.
                            if (!collection.isPersonal) ...[
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 20),
                                tooltip: 'Rename',
                                onPressed: () => _renameCollection(collection),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 20, color: Colors.red),
                                tooltip: 'Delete',
                                onPressed: () =>
                                    _deleteCollection(collection),
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

  Widget _buildAccountSection(ThemeData theme, String? email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_circle_outlined,
                size: 20, color: theme.colorScheme.outline),
            const SizedBox(width: 8),
            Text(
              'Account',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.alternate_email),
            title: Text(email ?? 'Signed in'),
            subtitle: const Text('Signed in with Supabase Auth'),
            trailing: TextButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign out'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocalModeSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_circle_outlined,
                size: 20, color: theme.colorScheme.outline),
            const SizedBox(width: 8),
            Text(
              'Account',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.cloud_off_outlined),
            title: const Text('Local-only mode'),
            subtitle: const Text(
              'Supabase isn\'t configured in this build, so there\'s no '
              'account to sign out of. Run with '
              '--dart-define-from-file=.env.local to enable sign-in.',
            ),
            isThreeLine: true,
          ),
        ),
      ],
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
        Card(
          child: Column(
            children: [
              const Divider(height: 1),
              child,
            ],
          ),
        ),
      ],
    );
  }

  void _markDirty() {
    // Mark as dirty - settings need saving
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all documents'),
        content: const Text(
          'This will remove all documents from the active collection. '
          'This action cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All documents cleared (demo)'),
                  backgroundColor: Colors.red,
                ),
              );
              context.go('/home');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
  }
}
