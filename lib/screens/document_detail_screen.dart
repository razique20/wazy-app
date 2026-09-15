import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/document_type.dart';
import '../models/expiry_item.dart';
import '../services/document_scanner_service.dart';
import '../widgets/widgets.dart';

class DocumentDetailScreen extends StatefulWidget {
  final String documentId;

  const DocumentDetailScreen({super.key, required this.documentId});

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  ExpiryItem? _item;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  Future<void> _loadItem() async {
    // Find item by ID
    final allItems = await DocumentScannerService().getAllItems();
    final item = allItems.where((i) => i.id == widget.documentId).firstOrNull;
    if (mounted) {
      setState(() {
        _item = item;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
          title: const Text('Loading...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_item == null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Document not found',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'This document may have been removed or expired.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('Back to home'),
              ),
            ],
          ),
        ),
      );
    }

    final item = _item!;
    final urgency = item.urgency;
    final now = DateTime.now();
    final daysRemaining = item.daysRemaining;
    final expiresAt = item.expiresAt;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // App bar with document info
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit document (coming soon)')),
                  );
                },
                tooltip: 'Edit document',
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => _handleMenuAction(context, value, item),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'renew', child: Text('Mark as renewed')),
                  const PopupMenuItem(value: 'share', child: Text('Share details')),
                  const PopupMenuItem(value: 'export', child: Text('Export report')),
                  const PopupMenuItem(value: 'delete', child: Text('Remove document')),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      urgency.color.withOpacity(0.06),
                      theme.colorScheme.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Document type chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: urgency.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.docType.icon,
                                size: 14,
                                color: urgency.color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.docType.displayName,
                                style: TextStyle(
                                  color: urgency.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: daysRemaining <= 7
                                      ? Colors.red
                                      : daysRemaining <= 30
                                          ? Colors.amber
                                          : Colors.green,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$daysRemaining days',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Title
                        Text(
                          item.displayName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Expiry date
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Expires ${DateFormat('EEEE, dd MMMM yyyy').format(expiresAt)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Documented ${item.documentDate != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(item.documentDate!)) : 'Not recorded'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Urgency badge
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: urgency.color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                urgency.icon,
                                color: urgency.color,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                urgency.title,
                                style: TextStyle(
                                  color: urgency.color,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Warning box
                  if (!item.isExpired)
                    _buildWarningCard(theme, item),

                  const SizedBox(height: 16),

                  // Key info grid
                  _buildInfoGrid(theme, item),

                  const SizedBox(height: 20),

                  // Urgency path steps
                  _buildUrgencyPath(theme, item),

                  const SizedBox(height: 20),

                  // Renewal process
                  _buildRenewalProcess(theme, item),

                  const SizedBox(height: 20),

                  // Actions
                  _buildActions(theme, item),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard(ThemeData theme, ExpiryItem item) {
    final days = item.daysRemaining;
    final isCritical = days <= 7;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCritical
            ? theme.colorScheme.errorContainer
            : days <= 30
                ? Colors.amber.shade50
                : days <= 60
                    ? Colors.orange.shade50
                    : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCritical
              ? theme.colorScheme.error
              : days <= 30
                  ? Colors.amber
                  : days <= 60
                      ? Colors.orange
                      : theme.colorScheme.outline,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCritical ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            color: isCritical ? theme.colorScheme.error : theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCritical ? 'Urgent action required' : 'Renewal information',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isCritical ? theme.colorScheme.error : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.renewalWarning ?? '',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(ThemeData theme, ExpiryItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Document details',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.8,
          children: [
            _InfoTile(
              icon: Icons.folder_outlined,
              label: 'Document type',
              value: item.docType.displayName,
            ),
            _InfoTile(
              icon: Icons.calendar_today_rounded,
              label: 'Expiry date',
              value: DateFormat('dd MMM yyyy').format(item.expiresAt),
              valueColor: item.daysRemaining <= 7 ? Colors.red : null,
            ),
            _InfoTile(
              icon: Icons.timer_outlined,
              label: 'Days remaining',
              value: '${item.daysRemaining} days',
              valueColor: item.daysRemaining <= 7 ? Colors.red : item.daysRemaining <= 30 ? Colors.amber : null,
            ),
            _InfoTile(
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: item.location ?? 'UAE',
            ),
            _InfoTile(
              icon: Icons.attach_money,
              label: 'Renewal fee',
              value: item.renewalFee != null
                  ? 'AED ${item.renewalFee!.toStringAsFixed(0)}'
                  : 'Estimated',
            ),
            _InfoTile(
              icon: Icons.history_edu_rounded,
              label: 'Documented on',
              value: item.documentDate ?? 'Not recorded',
            ),
            _InfoTile(
              icon: Icons.person_outline,
              label: 'Assigned to',
              value: item.assignedTo ?? 'Unassigned',
            ),
            _InfoTile(
              icon: Icons.notifications_active,
              label: 'Reminder status',
              value: _reminderStatusLabel(item.reminderStatus),
            ),
          ],
        ),
      ],
    );
  }

  String _reminderStatusLabel(int status) {
    switch (status) {
      case 0:
        return 'No reminders set';
      case 1:
        return '90-day reminder active';
      case 2:
        return '60-day task active';
      case 3:
        return '30-day escalation active';
      case 4:
        return '7-day WhatsApp sent';
      default:
        return 'Unknown';
    }
  }

  Widget _buildUrgencyPath(ThemeData theme, ExpiryItem item) {
    final days = item.daysRemaining;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Urgency timeline',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        // Timeline
        Row(
          children: [
            // 90 days
            Expanded(
              child: _TimelineStep(
                days: 90,
                label: 'Reminder',
                description: '90-day reminder sent',
                isActive: days <= 90 && days > 60,
                isCompleted: days > 90,
                color: Colors.indigo,
                icon: Icons.notifications_active_rounded,
              ),
            ),
            // 60 days
            Expanded(
              child: _TimelineStep(
                days: 60,
                label: 'Task assigned',
                description: 'Renewal task created',
                isActive: days <= 60 && days > 30,
                isCompleted: days > 60,
                color: Colors.amber,
                icon: Icons.assignment_turned_in_rounded,
              ),
            ),
            // 30 days
            Expanded(
              child: _TimelineStep(
                days: 30,
                label: 'Escalation',
                description: 'Stakeholder escalation',
                isActive: days <= 30 && days > 7,
                isCompleted: days > 30,
                color: Colors.orange,
                icon: Icons.priority_high_rounded,
              ),
            ),
            // 7 days
            Expanded(
              child: _TimelineStep(
                days: 7,
                label: 'WhatsApp',
                description: 'Urgent WhatsApp alert',
                isActive: days <= 7,
                isCompleted: false,
                color: Colors.red,
                icon: Icons.whatshot_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Current step indicator
        _getCurrentStepIndicator(theme, days),
      ],
    );
  }

  Widget _getCurrentStepIndicator(ThemeData theme, int days) {
    String label;
    Color color;
    IconData icon;
    String description;

    if (days > 90) {
      label = 'On track';
      color = Colors.green;
      icon = Icons.check_circle_rounded;
      description = 'All renewal milestones on schedule';
    } else if (days > 60) {
      label = '90-day reminder due';
      color = Colors.indigo;
      icon = Icons.notifications_active_rounded;
      description = 'Remind the responsible person';
    } else if (days > 30) {
      label = '60-day task due';
      color = Colors.amber;
      icon = Icons.assignment_turned_in_rounded;
      description = 'Assign renewal task to team member';
    } else if (days > 7) {
      label = '30-day escalation triggered';
      color = Colors.orange;
      icon = Icons.priority_high_rounded;
      description = 'Escalating to management';
    } else {
      label = '7-day WhatsApp alert';
      color = Colors.red;
      icon = Icons.whatshot_rounded;
      description = 'Send urgent WhatsApp notification';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$days days left',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRenewalProcess(ThemeData theme, ExpiryItem item) {
    final steps = item.renewalSteps ?? [
      'Review current document status',
      'Gather required renewal documents',
      'Submit renewal application',
      'Pay applicable fees',
      'Receive renewed document',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Renewal process',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isLast = index == steps.length - 1;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step number circle
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isLast
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isLast ? Colors.white : theme.colorScheme.outline,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Step content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isLast) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Complete this step to renew ${item.displayName}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isLast)
                  Flexible(
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            height: 2,
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActions(ThemeData theme, ExpiryItem item) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _markAsRenewed(context, item),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Mark as renewed'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('WhatsApp reminder sent (demo)'),
                ),
              );
            },
            icon: const Icon(Icons.chat_rounded),
            label: const Text('Send WhatsApp reminder'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: Colors.green),
              iconColor: Colors.green,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Renewal reminder set (demo)'),
                ),
              );
            },
            icon: const Icon(Icons.notifications_active_rounded),
            label: const Text('Schedule reminders'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _markAsRenewed(BuildContext context, ExpiryItem item) async {
    try {
      await DocumentScannerService.instance.markAsRenewed(item.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.displayName} marked as renewed ✓'),
          backgroundColor: Colors.green,
        ),
      );
      context.go('/home');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeDocument(BuildContext context, ExpiryItem item) async {
    try {
      await DocumentScannerService.instance.removeItem(item.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.displayName} removed'),
          backgroundColor: Colors.red,
        ),
      );
      context.go('/home');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not remove: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleMenuAction(BuildContext context, String action, ExpiryItem item) {
    switch (action) {
      case 'renew':
        _markAsRenewed(context, item);
        break;
      case 'share':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Share link copied (demo)')),
        );
        break;
      case 'export':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report exported (demo)')),
        );
        break;
      case 'delete':
        _confirmDelete(context, item);
        break;
    }
  }

  void _confirmDelete(BuildContext context, ExpiryItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove document'),
        content: Text(
          'Are you sure you want to remove "${item.displayName}" from tracking? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _removeDocument(context, item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum TimelineDay { d90, d60, d30, d7 }

class _TimelineStep extends StatelessWidget {
  final int days;
  final String label;
  final String description;
  final bool isActive;
  final bool isCompleted;
  final Color color;
  final IconData icon;

  const _TimelineStep({
    required this.days,
    required this.label,
    required this.description,
    required this.isActive,
    required this.isCompleted,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top connector line
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: 2,
              color: isActive
                  ? color.withOpacity(0.6)
                  : isCompleted
                      ? color.withOpacity(0.3)
                      : Colors.transparent,
            ),
          ),
        ),
        // Content
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isActive
                      ? color
                      : isCompleted
                          ? color.withOpacity(0.2)
                          : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted
                        ? color.withOpacity(0.4)
                        : isActive
                            ? color
                            : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  isCompleted ? Icons.check : icon,
                  color: isCompleted
                      ? color
                      : isActive
                          ? Colors.white
                          : Colors.transparent,
                  size: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive
                          ? color
                          : isCompleted
                              ? Colors.grey
                              : Theme.of(context).colorScheme.outline,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isActive
                          ? color
                          : Theme.of(context).colorScheme.outline,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
