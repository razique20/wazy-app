import 'package:uuid/uuid.dart';

import '../models/expiry_item.dart';
import '../models/document_type.dart';
import 'companion_suggestion_service.dart';

/// Builds an [ExpiryItem] for a companion type picked from the suggestion
/// sheet, so every add flow creates documents consistently.
///
/// The expiry defaults to [CompanionSuggestionService]-typical renewal from
/// today (e.g. Emirates ID → +1 year). The user can edit it later from the
/// document detail screen or the renew dialog.
ExpiryItem buildCompanionItem({
  required DocumentType type,
  required String collectionId,
  String? anchoredToName,
}) {
  final now = DateTime.now();
  final meta = DocumentTypeRegistry.instance.byEnum(type);
  final expiresAt = now.add(Duration(days: meta.typicalRenewalDays));
  final daysOffset = expiresAt.difference(now).inDays;

  return ExpiryItem(
    id: const Uuid().v4(),
    collectionId: collectionId,
    displayName: meta.displayName,
    docType: meta,
    expiryDate: ExpiryItem.formatDate(expiresAt),
    daysRemaining: daysOffset,
    isExpired: false,
    isNotified: false,
    notifiedDays: null,
    description: anchoredToName == null
        ? 'Added from related-document suggestion'
        : 'Added from related-document suggestion after adding $anchoredToName',
    location: meta.renewalAuthority,
    reminderStatus: daysOffset <= 7
        ? 4
        : daysOffset <= 30
            ? 3
            : daysOffset <= 60
                ? 2
                : daysOffset <= 90
                    ? 1
                    : 0,
    urgency: daysOffset <= 7
        ? UrgencyLevel.critical
        : daysOffset <= 30
            ? UrgencyLevel.high
            : daysOffset <= 60
                ? UrgencyLevel.medium
                : UrgencyLevel.low,
    assignedTo: null,
    documentDate: ExpiryItem.formatDate(now),
    renewalSteps: [
      'Gather required documentation',
      'Prepare renewal application',
      'Submit to relevant authority',
      'Pay renewal fees',
      'Receive renewed document',
    ],
    renewalAuthorities: [meta.renewalAuthority],
    renewalWarning:
        daysOffset <= 30 ? 'Expires soon — renew to avoid penalties' : null,
    expiresAt: expiresAt,
  );
}
