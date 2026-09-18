import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'document_collection.dart';
import 'document_type.dart';
import 'renewal_record.dart';

class UrgencyLevel {
  final String title;
  final IconData icon;
  final Color color;
  final int priority;

  const UrgencyLevel({
    required this.title,
    required this.icon,
    required this.color,
    required this.priority,
  });

  static const low = UrgencyLevel(
    title: 'Low',
    icon: Icons.check_circle_rounded,
    color: WazyColors.safe,
    priority: 0,
  );
  static const medium = UrgencyLevel(
    title: 'Medium',
    icon: Icons.schedule_rounded,
    color: WazyColors.caution,
    priority: 1,
  );
  static const high = UrgencyLevel(
    title: 'High',
    icon: Icons.priority_high_rounded,
    color: WazyColors.warning,
    priority: 2,
  );
  static const critical = UrgencyLevel(
    title: 'Critical',
    icon: Icons.warning_amber_rounded,
    color: WazyColors.danger,
    priority: 3,
  );

  static UrgencyLevel fromDays(int days) {
    if (days <= 0) return critical;
    if (days <= 7) return critical;
    if (days <= 30) return high;
    if (days <= 60) return medium;
    return low;
  }

  static UrgencyLevel fromStatus(int status) {
    switch (status) {
      case 0:
        return low;
      case 1:
        return UrgencyLevel(
          title: 'Reminder active',
          icon: Icons.notifications_active_rounded,
          color: WazyColors.violet,
          priority: 0,
        );
      case 2:
        return UrgencyLevel(
          title: 'Task active',
          icon: Icons.assignment_turned_in_rounded,
          color: WazyColors.caution,
          priority: 1,
        );
      case 3:
        return UrgencyLevel(
          title: 'Escalation active',
          icon: Icons.priority_high_rounded,
          color: WazyColors.warning,
          priority: 2,
        );
      case 4:
        return UrgencyLevel(
          title: 'WhatsApp sent',
          icon: Icons.whatshot_rounded,
          color: WazyColors.danger,
          priority: 3,
        );
      default:
        return low;
    }
  }

  bool operator <(UrgencyLevel other) => priority < other.priority;
  bool operator >(UrgencyLevel other) => priority > other.priority;

  static List<UrgencyLevel> get values => [low, medium, high, critical];
}

class ExpiryItem {
  /// Id of the [DocumentCollection] this document belongs to. Documents in
  /// the built-in personal collection use [DocumentCollection.personalId].
  final String collectionId;

  final String id;
  final String displayName;

  /// Resolved type metadata. Built-ins map to the [DocumentType] enum via
  /// [DocumentTypeMeta.builtinEnum]; custom types carry their own definition.
  final DocumentTypeMeta docType;
  final String expiryDate;
  final int daysRemaining;
  final bool isExpired;
  final bool isActive;
  final bool isNotified;
  final int? notifiedDays;
  final String? description;
  final String? location;
  final int reminderStatus;
  final UrgencyLevel urgency;
  final String? assignedTo;
  final String? documentDate;
  final double? renewalFee;
  final List<String>? renewalSteps;
  final List<String>? renewalAuthorities;
  final String? renewalWarning;
  final DateTime expiresAt;
  final String? fileName;
  final String? filePath;
  final int? fileSize;
  final List<RenewalRecord>? renewalHistory;
  final List<int>? customReminderDays;

  /// Last local/remote mutation timestamp. Used by the offline-first sync
  /// (see DocumentScannerService) for last-writer-wins conflict resolution.
  /// Null on records created before this field existed.
  final DateTime? updatedAt;

  String get label => '$displayName (${docType.displayName})';

  /// Guidance shown in "Renewal information" cards and urgency dialogs.
  ///
  /// [renewalWarning] is only populated by some creation paths (and only when
  /// the document is near expiry), so it is blank for most documents. This
  /// getter always yields meaningful text:
  ///
  /// 1. an explicitly stored warning, if any;
  /// 2. otherwise an expiry-aware explanation: what changed when the
  ///    document expired, or what happens as expiry approaches;
  /// 3. otherwise the document type's generic compliance blurb.
  String get effectiveRenewalWarning {
    final stored = renewalWarning?.trim();
    if (stored != null && stored.isNotEmpty) return stored;

    final days = daysRemaining;
    if (days < 0) {
      return 'Expired ${-days} day${-days == 1 ? '' : 's'} ago on '
          '${ExpiryItem.formatDate(expiresAt)} — renew as soon as possible '
          'to avoid penalties or service interruptions.';
    }
    if (days == 0) {
      return 'Expires today (${ExpiryItem.formatDate(expiresAt)}). '
          'Renew now — many UAE authorities require valid documents at all times.';
    }
    if (days <= 30) {
      return 'Expires in $days days (${ExpiryItem.formatDate(expiresAt)}). '
          'Start the renewal now to avoid fines or a coverage gap.';
    }
    return '${docType.defaultWarning} Expires '
        '${ExpiryItem.formatDate(expiresAt)}.';
  }

  const ExpiryItem({
    required this.collectionId,
    required this.id,
    required this.displayName,
    required this.docType,
    required this.expiryDate,
    required this.daysRemaining,
    this.isExpired = false,
    this.isActive = true,
    this.isNotified = false,
    this.notifiedDays,
    this.description,
    this.location,
    this.reminderStatus = 0,
    required this.urgency,
    this.assignedTo,
    this.documentDate,
    this.renewalFee,
    this.renewalSteps,
    this.renewalAuthorities,
    this.renewalWarning,
    required this.expiresAt,
    this.fileName,
    this.filePath,
    this.fileSize,
    this.renewalHistory,
    this.customReminderDays,
    this.updatedAt,
  });

  factory ExpiryItem.fromJson(Map<String, dynamic> json) {
    final docType =
        DocumentTypeRegistry.instance.byKey(json['docType'] as String?);

    final urgencyPriority = json['urgencyPriority'] as int? ?? 0;
    final urgency = UrgencyLevel.values[urgencyPriority.clamp(0, 3)];

    return ExpiryItem(
      collectionId: json['collectionId'] as String? ?? DocumentCollection.personalId,
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      docType: docType,
      expiryDate: json['expiryDate'] as String,
      daysRemaining: json['daysRemaining'] as int,
      isExpired: json['isExpired'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      isNotified: json['isNotified'] as bool? ?? false,
      notifiedDays: json['notifiedDays'] as int?,
      description: json['description'] as String?,
      location: json['location'] as String?,
      reminderStatus: json['reminderStatus'] as int? ?? 0,
      urgency: urgency,
      assignedTo: json['assignedTo'] as String?,
      documentDate: json['documentDate'] as String?,
      renewalFee: (json['renewalFee'] as num?)?.toDouble(),
      renewalSteps: (json['renewalSteps'] as List<dynamic>?)?.cast<String>(),
      renewalAuthorities: (json['renewalAuthorities'] as List<dynamic>?)?.cast<String>(),
      renewalWarning: json['renewalWarning'] as String?,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      fileName: json['fileName'] as String?,
      filePath: json['filePath'] as String?,
      fileSize: json['fileSize'] as int?,
      renewalHistory: (json['renewalHistory'] as List<dynamic>?)
          ?.map((e) => RenewalRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      customReminderDays: (json['customReminderDays'] as List<dynamic>?)
          ?.cast<int>(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'collectionId': collectionId,
      'id': id,
      'displayName': displayName,
      'docType': docType.key,
      'expiryDate': expiryDate,
      'daysRemaining': daysRemaining,
      'isExpired': isExpired,
      'isActive': isActive,
      'isNotified': isNotified,
      'notifiedDays': notifiedDays,
      'description': description,
      'location': location,
      'reminderStatus': reminderStatus,
      'urgencyPriority': urgency.priority,
      'assignedTo': assignedTo,
      'documentDate': documentDate,
      'renewalFee': renewalFee,
      'renewalSteps': renewalSteps,
      'renewalAuthorities': renewalAuthorities,
      'renewalWarning': renewalWarning,
      'expiresAt': expiresAt.toIso8601String(),
      'fileName': fileName,
      'filePath': filePath,
      'fileSize': fileSize,
      'renewalHistory': renewalHistory?.map((e) => e.toJson()).toList(),
      'customReminderDays': customReminderDays,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory ExpiryItem.create({
    required String id,
    required String displayName,
    required DocumentTypeMeta docType,
    required DateTime expiresAt,
    String? collectionId,
    String? description,
    String? location,
    bool isExpired = false,
    bool isActive = true,
    bool isNotified = false,
    int? notifiedDays,
    String? documentDate,
    double? renewalFee,
    List<String>? renewalSteps,
    List<String>? renewalAuthorities,
    String? renewalWarning,
    int? reminderStatus,
    String? fileName,
    String? filePath,
    int? fileSize,
    List<RenewalRecord>? renewalHistory,
    List<int>? customReminderDays,
  }) {
    final daysRemaining = expiresAt.difference(DateTime.now()).inDays;
    final urgency = UrgencyLevel.fromDays(daysRemaining);
    return ExpiryItem(
      collectionId: collectionId ?? DocumentCollection.personalId,
      id: id,
      displayName: displayName,
      docType: docType,
      expiryDate: formatDate(expiresAt),
      daysRemaining: daysRemaining,
      isExpired: daysRemaining < 0,
      isActive: isActive && daysRemaining >= 0,
      isNotified: isNotified,
      notifiedDays: notifiedDays,
      description: description,
      location: location ?? 'UAE',
      urgency: urgency,
      documentDate: documentDate,
      renewalFee: renewalFee,
      renewalSteps: renewalSteps,
      renewalAuthorities: renewalAuthorities,
      renewalWarning: renewalWarning ?? docType.defaultWarning,
      expiresAt: expiresAt,
      reminderStatus: reminderStatus ?? _calculateReminderStatus(daysRemaining),
      fileName: fileName,
      filePath: filePath,
      fileSize: fileSize,
      renewalHistory: renewalHistory,
      customReminderDays: customReminderDays,
    );
  }

  static int _calculateReminderStatus(int daysRemaining) {
    if (daysRemaining <= 7) return 4;
    if (daysRemaining <= 30) return 3;
    if (daysRemaining <= 60) return 2;
    if (daysRemaining <= 90) return 1;
    return 0;
  }


  static String formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  ExpiryItem copyWith({
    String? collectionId,
    String? id,
    String? displayName,
    DocumentTypeMeta? docType,
    String? expiryDate,
    int? daysRemaining,
    bool? isExpired,
    bool? isActive,
    bool? isNotified,
    int? notifiedDays,
    String? description,
    String? location,
    int? reminderStatus,
    UrgencyLevel? urgency,
    String? assignedTo,
    String? documentDate,
    double? renewalFee,
    List<String>? renewalSteps,
    List<String>? renewalAuthorities,
    String? renewalWarning,
    DateTime? expiresAt,
    String? fileName,
    String? filePath,
    int? fileSize,
    List<RenewalRecord>? renewalHistory,
    List<int>? customReminderDays,
    DateTime? updatedAt,
  }) {
    return ExpiryItem(
      collectionId: collectionId ?? this.collectionId,
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      docType: docType ?? this.docType,
      expiryDate: expiryDate ?? this.expiryDate,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      isExpired: isExpired ?? this.isExpired,
      isActive: isActive ?? this.isActive,
      isNotified: isNotified ?? this.isNotified,
      notifiedDays: notifiedDays ?? this.notifiedDays,
      description: description ?? this.description,
      location: location ?? this.location,
      reminderStatus: reminderStatus ?? this.reminderStatus,
      urgency: urgency ?? this.urgency,
      assignedTo: assignedTo ?? this.assignedTo,
      documentDate: documentDate ?? this.documentDate,
      renewalFee: renewalFee ?? this.renewalFee,
      renewalSteps: renewalSteps ?? this.renewalSteps,
      renewalAuthorities: renewalAuthorities ?? this.renewalAuthorities,
      renewalWarning: renewalWarning ?? this.renewalWarning,
      expiresAt: expiresAt ?? this.expiresAt,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      renewalHistory: renewalHistory ?? this.renewalHistory,
      customReminderDays: customReminderDays ?? this.customReminderDays,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
