import 'package:flutter/material.dart';

import '../../models/document_type.dart';
import '../../models/expiry_item.dart';
import '../../theme/app_theme.dart';
import '../indicators/department_logo.dart';

class ExpiryCard extends StatelessWidget {
  final ExpiryItem item;
  final VoidCallback onTap;
  final VoidCallback? onAction;

  const ExpiryCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onAction,
  });

  Color _cardColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (!item.isActive) return Theme.of(context).colorScheme.surfaceContainerHighest;
    return FinavigColors.urgencyBg(item.daysRemaining, brightness: brightness);
  }

  Color _accentColor() {
    return FinavigColors.urgencyColor(item.daysRemaining, isActive: item.isActive);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentColor();
    final locationText = item.location != null && item.location!.isNotEmpty && item.location != 'UAE'
        ? item.location!
        : item.docType.displayName;

    return Material(
      color: _cardColor(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withOpacity(0.15),
            ),
          ),
          child: Row(
            children: [
              DepartmentLogo(item: item, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$locationText • Expires ${item.expiryDate}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.urgency.title,
                      style: TextStyle(
                        color: (accent == FinavigColors.caution || item.daysRemaining > 30 && item.daysRemaining <= 60)
                            ? const Color(0xFF0A0E1A)
                            : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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
