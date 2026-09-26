import 'package:flutter/material.dart';

import '../../models/document_type.dart';
import '../../models/expiry_item.dart';
import '../../theme/app_theme.dart';
import '../indicators/department_logo.dart';

class DocumentListTile extends StatelessWidget {
  final ExpiryItem item;
  final VoidCallback onTap;
  final VoidCallback? onAction;

  const DocumentListTile({
    super.key,
    required this.item,
    required this.onTap,
    this.onAction,
  });

  Color _color() {
    return FinavigColors.urgencyColor(item.daysRemaining, isActive: item.isActive);
  }

  String _label() {
    final days = item.daysRemaining;
    if (!item.isActive) return 'Expired / Offboarded';
    if (days <= 7) return 'Due now';
    if (days <= 30) return 'Within month';
    if (days <= 60) return 'Within 60 days';
    return 'On track';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              DepartmentLogo(
                item: item,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (item.location != null && item.location!.isNotEmpty)
                          ? '${item.docType.displayName} • ${item.location}'
                          : item.docType.displayName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.daysRemaining}d',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _color(),
                        ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _color().withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _label(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _color(),
                      ),
                    ),
                  ),
                ],
              ),
              if (onAction != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: onAction,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
