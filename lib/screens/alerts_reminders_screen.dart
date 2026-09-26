import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/alert_preferences_service.dart';
import '../services/document_scanner_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

/// Full-screen settings page dedicated to managing Alert toggles and
/// Document Expiry Reminder lead times.
class AlertsRemindersScreen extends StatefulWidget {
  const AlertsRemindersScreen({super.key});

  @override
  State<AlertsRemindersScreen> createState() => _AlertsRemindersScreenState();
}

class _AlertsRemindersScreenState extends State<AlertsRemindersScreen> {
  bool _loading = true;
  bool _notificationsEnabled = true;
  bool _billSpikesEnabled = true;
  bool _budgetAlertsEnabled = true;

  int _reminderCadence = 90;
  int _taskCadence = 60;
  int _escalationCadence = 30;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final alertsService = AlertPreferencesService.instance;
    await alertsService.load();

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _reminderCadence = prefs.getInt('reminderCadence') ?? 90;
      _taskCadence = prefs.getInt('taskCadence') ?? 60;
      _escalationCadence = prefs.getInt('escalationCadence') ?? 30;

      _billSpikesEnabled = alertsService.billSpikesEnabled;
      _budgetAlertsEnabled = alertsService.budgetAlertsEnabled;
      _loading = false;
    });
  }

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
      // Scheduling may be unavailable in some environments (e.g. tests)
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts & Reminders'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Informational banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: FinavigColors.indigo.withOpacity(isDark ? 0.18 : 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: FinavigColors.indigo.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: FinavigColors.indigo.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: FinavigColors.indigo,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Configure proactive alerts for document expiries, budget caps, and unusual monthly bill spikes.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Group 1: Notification Toggles
                _buildGroupTitle(theme, 'Alert Notifications'),
                const SizedBox(height: 10),
                _buildCardContainer(
                  isDark: isDark,
                  children: [
                    _buildSwitchTile(
                      theme: theme,
                      icon: Icons.notifications_rounded,
                      iconColor: FinavigColors.indigo,
                      title: 'Renewal notifications',
                      subtitle: 'Remind me before documents expire',
                      value: _notificationsEnabled,
                      onChanged: (val) async {
                        setState(() => _notificationsEnabled = val);
                        await _applyReminderSettings();
                      },
                    ),
                    _buildDivider(isDark),
                    _buildSwitchTile(
                      theme: theme,
                      icon: Icons.trending_up_rounded,
                      iconColor: Colors.orange,
                      title: 'Bill spike alerts',
                      subtitle: 'Flag bills unusually higher than average',
                      value: _billSpikesEnabled,
                      onChanged: (val) async {
                        setState(() => _billSpikesEnabled = val);
                        await AlertPreferencesService.instance
                            .setBillSpikesEnabled(val);
                      },
                    ),
                    _buildDivider(isDark),
                    _buildSwitchTile(
                      theme: theme,
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: FinavigColors.emerald,
                      title: 'Budget alerts',
                      subtitle: 'Warn when spending nears a category budget',
                      value: _budgetAlertsEnabled,
                      onChanged: (val) async {
                        setState(() => _budgetAlertsEnabled = val);
                        await AlertPreferencesService.instance
                            .setBudgetAlertsEnabled(val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Group 2: Reminder Lead Times
                _buildGroupTitle(theme, 'Reminder Lead Times & Schedule'),
                const SizedBox(height: 10),
                _buildCardContainer(
                  isDark: isDark,
                  children: [
                    _buildDropdownTile<int>(
                      theme: theme,
                      icon: Icons.notifications_active_rounded,
                      iconColor: Colors.indigo,
                      title: 'First reminder',
                      subtitle: 'Initial alert before document expiration',
                      value: _reminderCadence,
                      items: const [30, 60, 90, 120],
                      itemLabel: (v) => '$v days before expiry',
                      onChanged: (v) async {
                        if (v != null) {
                          setState(() => _reminderCadence = v);
                          await _applyReminderSettings();
                        }
                      },
                    ),
                    _buildDivider(isDark),
                    _buildDropdownTile<int>(
                      theme: theme,
                      icon: Icons.assignment_turned_in_rounded,
                      iconColor: Colors.amber.shade700,
                      title: 'Renewal task',
                      subtitle: 'Assign task & prepare renewal papers',
                      value: _taskCadence,
                      items: const [30, 45, 60, 75, 90],
                      itemLabel: (v) => '$v days before expiry',
                      onChanged: (v) async {
                        if (v != null) {
                          setState(() => _taskCadence = v);
                          await _applyReminderSettings();
                        }
                      },
                    ),
                    _buildDivider(isDark),
                    _buildDropdownTile<int>(
                      theme: theme,
                      icon: Icons.priority_high_rounded,
                      iconColor: Colors.redAccent,
                      title: 'Escalation',
                      subtitle: 'Final escalation to stakeholders',
                      value: _escalationCadence,
                      items: const [15, 21, 30, 45],
                      itemLabel: (v) => '$v days before expiry',
                      onChanged: (v) async {
                        if (v != null) {
                          setState(() => _escalationCadence = v);
                          await _applyReminderSettings();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildGroupTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildCardContainer({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Material(
      color: isDark ? FinavigColors.slate.withOpacity(0.5) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 52,
      endIndent: 16,
      color: isDark
          ? Colors.white.withOpacity(0.06)
          : Colors.black.withOpacity(0.05),
    );
  }

  Widget _buildSwitchTile({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: BentoIconTile(
        icon: icon,
        color: iconColor,
        size: 38,
        iconSize: 18,
        radius: 12,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
      onTap: () => onChanged(!value),
    );
  }

  Widget _buildDropdownTile<T>({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: BentoIconTile(
        icon: icon,
        color: iconColor,
        size: 38,
        iconSize: 18,
        radius: 12,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          itemLabel(value),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: iconColor,
          ),
        ),
      ),
      onTap: () {
        showModalBottomSheet<T>(
          context: context,
          backgroundColor: theme.colorScheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                for (final item in items)
                  ListTile(
                    title: Text(itemLabel(item)),
                    trailing: item == value
                        ? Icon(Icons.check_circle_rounded, color: iconColor)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onChanged(item);
                    },
                  ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
