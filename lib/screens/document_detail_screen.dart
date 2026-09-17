import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/expiry_item.dart';
import '../models/finance.dart';
import '../services/finance_service.dart';
import '../services/document_scanner_service.dart';
import '../services/notification_service.dart';
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
    // Find item by ID directly across all cached documents
    final item = await DocumentScannerService.instance.getItemById(widget.documentId);
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
      appBar: AppBar(
        title: Text(
          item.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Card with Department Logo
            _buildHeaderCard(theme, item, urgency, expiresAt, daysRemaining),

            const SizedBox(height: 16),

            // Warning box
            if (!item.isExpired)
              _buildWarningCard(theme, item),

            if (item.fileName != null || item.filePath != null) ...[
              const SizedBox(height: 16),
              _buildAttachedFileCard(theme, item),
            ],

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
    );
  }

  Widget _buildHeaderCard(
    ThemeData theme,
    ExpiryItem item,
    UrgencyLevel urgency,
    DateTime expiresAt,
    int daysRemaining,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: urgency.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgency.color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DepartmentLogo(item: item, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (item.location != null && item.location!.isNotEmpty)
                          ? '${item.docType.displayName} • ${item.location}'
                          : item.docType.displayName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Expires ${DateFormat('EEEE, dd MMMM yyyy').format(expiresAt)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: daysRemaining <= 7
                      ? Colors.red
                      : daysRemaining <= 30
                          ? Colors.orange
                          : Colors.green,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  daysRemaining < 0 ? '${-daysRemaining}d overdue' : '$daysRemaining days left',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(urgency.icon, size: 15, color: urgency.color),
              const SizedBox(width: 6),
              Text(
                urgency.title,
                style: TextStyle(
                  color: urgency.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              if (item.documentDate != null && item.documentDate!.isNotEmpty)
                Text(
                  'Documented: ${item.documentDate}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttachedFileCard(ThemeData theme, ExpiryItem item) {
    final fileName = item.fileName ?? 'Attached Document';
    final fileSizeKb = item.fileSize != null ? (item.fileSize! / 1024).toStringAsFixed(0) : null;
    final ext = fileName.contains('.') ? fileName.split('.').last.toUpperCase() : 'FILE';

    final path = item.filePath;
    final isNetwork = path != null && (path.startsWith('http://') || path.startsWith('https://'));
    final file = path != null && path.isNotEmpty && !isNetwork ? File(path) : null;
    final exists = isNetwork || (file != null && file.existsSync());

    if (!exists) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.devices_other_rounded,
                    color: Colors.amber.shade900,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File saved on another device',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fileName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.amber.shade900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'This document attachment was stored locally on a different device. You can re-upload the file on this device to view it here in the future.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.amber.shade900,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _reuploadAttachment(context, item),
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: const Text('Re-upload File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showFilePreview(context, item),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber.shade900,
                    side: BorderSide(color: Colors.amber.shade400),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.attach_file_rounded,
              color: theme.colorScheme.onPrimaryContainer,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ext,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  fileSizeKb != null ? 'Attachment file size: $fileSizeKb KB' : 'Document attachment file',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _showFilePreview(context, item),
            icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
            label: const Text('View'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilePreview(BuildContext context, ExpiryItem item) {
    final path = item.filePath;
    final name = item.fileName ?? 'Attached Document';
    final isNetwork = path != null && (path.startsWith('http://') || path.startsWith('https://'));
    final file = path != null && path.isNotEmpty && !isNetwork ? File(path) : null;
    final exists = isNetwork || (file != null && file.existsSync());

    final lowerPath = (path ?? '').toLowerCase();
    final isImage = exists && (
      lowerPath.contains('.png') ||
      lowerPath.contains('.jpg') ||
      lowerPath.contains('.jpeg') ||
      lowerPath.contains('.webp') ||
      lowerPath.contains('.gif') ||
      lowerPath.contains('.heic')
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  const Icon(Icons.attach_file, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: isImage
                    ? InteractiveViewer(
                        clipBehavior: Clip.none,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: isNetwork
                              ? Image.network(
                                  path!,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (_, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(child: CircularProgressIndicator());
                                  },
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Text('Error loading cloud image.'),
                                  ),
                                )
                              : Image.file(
                                  file!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Text('Error loading local image file.'),
                                  ),
                                ),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            exists ? Icons.insert_drive_file_outlined : Icons.find_in_page_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          if (item.fileSize != null)
                            Text(
                              'Size: ${(item.fileSize! / 1024).toStringAsFixed(1)} KB',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            exists
                                ? 'File path: $path'
                                : path != null && path.isNotEmpty
                                    ? 'File was uploaded on another device ($path).'
                                    : 'No file path stored for this document.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reuploadAttachment(BuildContext context, ExpiryItem item) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'heic'],
      );

      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;

      if (file.path == null || !File(file.path!).existsSync()) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access the selected file.')),
        );
        return;
      }

      final appDocDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory('${appDocDir.path}/wazy/documents/${item.id}');
      if (!targetDir.existsSync()) {
        targetDir.createSync(recursive: true);
      }
      final targetPath = '${targetDir.path}/${file.name}';
      final savedFile = await File(file.path!).copy(targetPath);

      final updatedItem = item.copyWith(
        fileName: file.name,
        filePath: savedFile.path,
        fileSize: file.size,
      );

      await DocumentScannerService.instance.updateItem(updatedItem);

      if (!context.mounted) return;
      setState(() {
        _item = updatedItem;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attachment "${file.name}" saved to this device'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error re-uploading file: $e')),
      );
    }
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
        // WhatsApp alerts are not active yet (need a server-side provider).
        // The button is shown disabled so users see it's coming.
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.chat_rounded),
            label: const Text('WhatsApp reminder — coming soon'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _scheduleReminders(context, item),
            icon: const Icon(Icons.notifications_active_rounded),
            label: Text(
              item.reminderStatus > 0
                  ? 'Reminders active — tap to reschedule'
                  : 'Schedule reminders',
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  /// Schedules OS-level local notifications on the 90/60/30/7-day ladder
  /// for this document (only tiers still in the future fire).
  Future<void> _scheduleReminders(
    BuildContext context,
    ExpiryItem item,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await NotificationService.instance.scheduleEscalationLadder(
        item.id,
        item.expiresAt,
        title: item.displayName,
      );
      if (item.reminderStatus == 0) {
        await DocumentScannerService.instance.setReminderStatus(item.id, 1);
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Reminders scheduled for ${item.displayName} (90/60/30/7 days)',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not schedule reminders: $e')),
      );
    }
  }

  Future<void> _markAsRenewed(BuildContext context, ExpiryItem item) async {
    try {
      // Tier glue: renewing in place also offers to log the renewal payment
      // against the Money tier, closing the loop from either direction.
      final newExpiry = DateTime(
        item.expiresAt.year + 1,
        item.expiresAt.month,
        item.expiresAt.day,
      );
      await DocumentScannerService.instance
          .markAsRenewed(item.id, newExpiryDate: newExpiry);

      if ((item.renewalFee ?? 0) > 0) {
        await FinanceService.instance.addTransaction(
          FinanceTransaction(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            collectionId: item.collectionId,
            kind: FinanceKind.expense,
            category: FinanceCategory.renewals,
            title: '${item.displayName} renewal',
            amount: item.renewalFee!,
            occurredAt: DateTime.now(),
            note: 'Logged from document renewal',
            documentId: item.id,
          ),
        );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (item.renewalFee ?? 0) > 0
                ? '${item.displayName} renewed — payment of '
                    '${MoneyFormat.aed(item.renewalFee ?? 0)} logged ✓'
                : '${item.displayName} renewed — now expires '
                    '${ExpiryItem.formatDate(newExpiry)} ✓',
          ),
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
        Container(
          height: 3,
          width: double.infinity,
          color: isActive
              ? color
              : isCompleted
                  ? color.withOpacity(0.4)
                  : Theme.of(context).colorScheme.outline.withOpacity(0.2),
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
