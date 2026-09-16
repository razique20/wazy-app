import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum DocumentType {
  tradeLicence,
  ejari,
  visa,
  emiratesId,
  labourDocuments,
  insurance,
  vehicleRegistration,
  contracts,
  certificates,
  permits,
  domainNames,
  softwareSubscriptions,
  supplierAgreements,
}

extension DocumentTypeExtension on DocumentType {
  String get displayName {
    switch (this) {
      case DocumentType.tradeLicence:
        return 'Trade Licence';
      case DocumentType.ejari:
        return 'Ejari';
      case DocumentType.visa:
        return 'Work Visa';
      case DocumentType.emiratesId:
        return 'Emirates ID';
      case DocumentType.labourDocuments:
        return 'Labour Documents';
      case DocumentType.insurance:
        return 'Insurance';
      case DocumentType.vehicleRegistration:
        return 'Vehicle Registration';
      case DocumentType.contracts:
        return 'Contracts';
      case DocumentType.certificates:
        return 'Certificates';
      case DocumentType.permits:
        return 'Permits';
      case DocumentType.domainNames:
        return 'Domain Names';
      case DocumentType.softwareSubscriptions:
        return 'Software Subscriptions';
      case DocumentType.supplierAgreements:
        return 'Supplier Agreements';
    }
  }

  IconData get icon {
    switch (this) {
      case DocumentType.tradeLicence:
        return Icons.business_rounded;
      case DocumentType.ejari:
        return Icons.home_rounded;
      case DocumentType.visa:
        return Icons.badge_rounded;
      case DocumentType.emiratesId:
        return Icons.credit_card_rounded;
      case DocumentType.labourDocuments:
        return Icons.work_rounded;
      case DocumentType.insurance:
        return Icons.health_and_safety_rounded;
      case DocumentType.vehicleRegistration:
        return Icons.directions_car_rounded;
      case DocumentType.contracts:
        return Icons.description_rounded;
      case DocumentType.certificates:
        return Icons.verified_user_rounded;
      case DocumentType.permits:
        return Icons.check_circle_rounded;
      case DocumentType.domainNames:
        return Icons.public_rounded;
      case DocumentType.softwareSubscriptions:
        return Icons.computer_rounded;
      case DocumentType.supplierAgreements:
        return Icons.handshake_rounded;
    }
  }

  Color get primaryColor {
    switch (this) {
      case DocumentType.tradeLicence:
        return const Color(0xFF5C6BC0); // Indigo 400
      case DocumentType.ejari:
        return const Color(0xFF26A69A); // Teal 400
      case DocumentType.visa:
        return const Color(0xFF42A5F5); // Blue 400
      case DocumentType.emiratesId:
        return const Color(0xFFAB47BC); // Purple 400
      case DocumentType.labourDocuments:
        return const Color(0xFF8D6E63); // Brown 400
      case DocumentType.insurance:
        return const Color(0xFF66BB6A); // Green 400
      case DocumentType.vehicleRegistration:
        return const Color(0xFFFFA726); // Orange 400
      case DocumentType.contracts:
        return const Color(0xFF78909C); // BlueGrey 400
      case DocumentType.certificates:
        return const Color(0xFFEC407A); // Pink 400
      case DocumentType.permits:
        return const Color(0xFFFFCA28); // Amber 400
      case DocumentType.domainNames:
        return const Color(0xFF26C6DA); // Cyan 400
      case DocumentType.softwareSubscriptions:
        return const Color(0xFF7C4DFF); // Deep Purple A200
      case DocumentType.supplierAgreements:
        return const Color(0xFFEF6C00); // Orange 800
    }
  }

  String get renewalAuthority {
    switch (this) {
      case DocumentType.tradeLicence:
        return 'Dubai DED / Department of Economic Development';
      case DocumentType.ejari:
        return 'RERA / Dubai Land Department';
      case DocumentType.visa:
        return 'GDRFA / ICP / MOHRE';
      case DocumentType.emiratesId:
        return 'ICP / GDRFA';
      case DocumentType.labourDocuments:
        return 'MOHRE / GDRFA';
      case DocumentType.insurance:
        return 'UAE Insurance Authority';
      case DocumentType.vehicleRegistration:
        return 'RTA / Dubai Police';
      case DocumentType.contracts:
        return 'Dubai Courts / DIFC';
      case DocumentType.certificates:
        return 'Relevant Authority';
      case DocumentType.permits:
        return 'Dubai Municipality / Civil Defence';
      case DocumentType.domainNames:
        return 'TRA / ICANN';
      case DocumentType.softwareSubscriptions:
        return 'Service Provider';
      case DocumentType.supplierAgreements:
        return 'Supplier / Vendor';
    }
  }

  int get typicalRenewalDays {
    switch (this) {
      case DocumentType.tradeLicence:
        return 365;
      case DocumentType.ejari:
        return 365;
      case DocumentType.visa:
        return 365;
      case DocumentType.emiratesId:
        return 365;
      case DocumentType.labourDocuments:
        return 365;
      case DocumentType.insurance:
        return 365;
      case DocumentType.vehicleRegistration:
        return 365;
      case DocumentType.contracts:
        return 365;
      case DocumentType.certificates:
        return 365;
      case DocumentType.permits:
        return 365;
      case DocumentType.domainNames:
        return 365;
      case DocumentType.softwareSubscriptions:
        return 30;
      case DocumentType.supplierAgreements:
        return 365;
    }
  }
}

// ---------------------------------------------------------------------------
// Document type metadata + registry (built-ins + user-defined custom types)
// ---------------------------------------------------------------------------

/// Immutable description of a document type, used everywhere a type is
/// displayed. Built-in types resolve from the [DocumentType] enum; custom
/// types carry their own name/icon/color and a renewal interval.
class DocumentTypeMeta {
  /// Stable storage key. Built-ins use the enum `.name`; customs use a
  /// generated `custom-…` id, so the two never collide.
  final String key;

  final String displayName;
  final IconData icon;
  final Color primaryColor;
  final String renewalAuthority;
  final int typicalRenewalDays;

  /// True when the user created this type (not one of the 13 built-ins).
  final bool isCustom;

  const DocumentTypeMeta({
    required this.key,
    required this.displayName,
    required this.icon,
    required this.primaryColor,
    required this.renewalAuthority,
    this.typicalRenewalDays = 365,
    this.isCustom = false,
  });

  /// Built-in type backing this meta, or null for custom types.
  DocumentType? get builtinEnum {
    for (final t in DocumentType.values) {
      if (t.name == key) return t;
    }
    return null;
  }

  /// Fallback warning text for documents of this type.
  String get defaultWarning {
    final builtin = builtinEnum;
    if (builtin == null) {
      return '$displayName expired — renew to stay compliant.';
    }
    return defaultWarningFor(builtin);
  }

  DocumentTypeMeta copyWith({
    String? displayName,
    IconData? icon,
    Color? primaryColor,
    String? renewalAuthority,
    int? typicalRenewalDays,
  }) {
    return DocumentTypeMeta(
      key: key,
      displayName: displayName ?? this.displayName,
      icon: icon ?? this.icon,
      primaryColor: primaryColor ?? this.primaryColor,
      renewalAuthority: renewalAuthority ?? this.renewalAuthority,
      typicalRenewalDays: typicalRenewalDays ?? this.typicalRenewalDays,
      isCustom: isCustom,
    );
  }

  /// Identity is the stable storage [key]: registry lookups and pickers build
  /// fresh instances per call, so value equality must not rely on object
  /// identity (e.g. DropdownButtonFormField matching initialValue to items).
  @override
  bool operator ==(Object other) => other is DocumentTypeMeta && other.key == key;

  @override
  int get hashCode => key.hashCode;

  static String defaultWarningFor(DocumentType type) {
    switch (type) {
      case DocumentType.tradeLicence:
        return 'Licence expired → Activity suspended. Renewal required within 30 days or activity stops.';
      case DocumentType.ejari:
        return 'Ejari expired → Contract invalid. Cannot renew without valid Ejari.';
      case DocumentType.visa:
        return 'Visa expired → Employee must leave UAE or apply for renewal. Grace period: 6 months.';
      case DocumentType.insurance:
        return 'Insurance lapsed → No coverage. Claims denied.';
      case DocumentType.contracts:
        return 'Contract expired → Legal terms may revert to month-to-month.';
      case DocumentType.domainNames:
        return 'Domain expired → Website and email down. Redemption period: 30 days.';
      case DocumentType.softwareSubscriptions:
        return 'Subscription expired → Service suspended. Access lost until renewal.';
      case DocumentType.emiratesId:
        return 'Emirates ID expired → Cannot travel or access services.';
      case DocumentType.labourDocuments:
        return 'Labour card expired → Work permit invalid. Employee cannot work.';
      case DocumentType.vehicleRegistration:
        return 'Registration expired → Fine AED 500+. Vehicle may be impounded.';
      case DocumentType.permits:
        return 'Permit expired → Business activity not authorized.';
      case DocumentType.certificates:
        return 'Certificate expired → Professional status may be invalidated.';
      case DocumentType.supplierAgreements:
        return 'Agreement expired → Supplier terms may change. Review before expiry.';
    }
  }
}

/// Registry of every document type available in the app: the 13 built-ins
/// plus any user-defined custom types loaded from Supabase/local storage.
///
/// Resolution is key-based ([byKey]) so DB rows and JSON with unknown or
/// custom `doc_type` values still resolve to displayable metadata.
class DocumentTypeRegistry {
  DocumentTypeRegistry._();

  static final DocumentTypeRegistry instance = DocumentTypeRegistry._();

  static const _customKeyPrefix = 'custom-';

  static const _customPalette = <Color>[
    Color(0xFF7E57C2),
    Color(0xFF29B6F6),
    Color(0xFFEF5350),
    Color(0xFF66BB6A),
    Color(0xFFFF7043),
    Color(0xFF26C6DA),
    Color(0xFFEC407A),
    Color(0xFF8D6E63),
    Color(0xFF5C6BC0),
    Color(0xFF9CCC65),
  ];

  static const _customIcons = <IconData>[
    Icons.description_rounded,
    Icons.folder_rounded,
    Icons.badge_rounded,
    Icons.gavel_rounded,
    Icons.receipt_long_rounded,
    Icons.workspace_premium_rounded,
    Icons.local_shipping_rounded,
    Icons.account_balance_rounded,
    Icons.medical_services_rounded,
    Icons.school_rounded,
  ];

  final List<DocumentTypeMeta> _custom = [];

  /// Built-in types, in enum order.
  static List<DocumentTypeMeta> get builtIns => DocumentType.values
      .map(
        (t) => DocumentTypeMeta(
          key: t.name,
          displayName: t.displayName,
          icon: t.icon,
          primaryColor: t.primaryColor,
          renewalAuthority: t.renewalAuthority,
          typicalRenewalDays: t.typicalRenewalDays,
        ),
      )
      .toList(growable: false);

  /// All types (built-ins first, customs after).
  List<DocumentTypeMeta> get all => [...builtIns, ..._custom];

  /// Types offered in pickers (built-ins + user-defined customs).
  List<DocumentTypeMeta> get typesForPicker => all;

  /// Resolve a storage key to metadata. Falls back to the trade-licence
  /// built-in for unknown legacy values, so old rows always render.
  DocumentTypeMeta byKey(String? key) {
    if (key != null) {
      for (final t in builtIns) {
        if (t.key == key) return t;
      }
      for (final t in _custom) {
        if (t.key == key) return t;
      }
    }
    return byEnum(DocumentType.tradeLicence);
  }

  /// Metadata for a built-in enum value.
  DocumentTypeMeta byEnum(DocumentType type) => DocumentTypeMeta(
        key: type.name,
        displayName: type.displayName,
        icon: type.icon,
        primaryColor: type.primaryColor,
        renewalAuthority: type.renewalAuthority,
        typicalRenewalDays: type.typicalRenewalDays,
      );

  /// Register a user-defined type and return the stored metadata.
  ///
  /// Pass [key] to re-register an existing custom type with a stable id
  /// (used when reloading from Supabase/local storage); omit it to generate
  /// a fresh key. Throws [ArgumentError] on empty names, built-in name
  /// collisions, or a different custom type with the same name.
  DocumentTypeMeta register({
    required String name,
    String? key,
    IconData? icon,
    Color? color,
    String? renewalAuthority,
    int typicalRenewalDays = 365,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Document type name cannot be empty');
    }

    // Idempotent reload: same key → replace in place.
    if (key != null) {
      final existingIndex = _custom.indexWhere((t) => t.key == key);
      final meta = DocumentTypeMeta(
        key: key,
        displayName: trimmed,
        icon: icon ?? Icons.description_rounded,
        primaryColor: color ?? _customPalette[_custom.length % _customPalette.length],
        renewalAuthority:
            (renewalAuthority?.trim().isNotEmpty ?? false)
                ? renewalAuthority!.trim()
                : 'Per document terms',
        typicalRenewalDays: typicalRenewalDays <= 0 ? 365 : typicalRenewalDays,
        isCustom: true,
      );
      if (existingIndex != -1) {
        _custom[existingIndex] = meta;
      } else {
        _custom.add(meta);
      }
      return meta;
    }

    final duplicateName = all.any(
      (t) => t.displayName.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicateName) {
      throw ArgumentError('A document type named "$trimmed" already exists');
    }

    final index = _custom.length;
    final meta = DocumentTypeMeta(
      key: '$_customKeyPrefix${const Uuid().v4()}',
      displayName: trimmed,
      icon: icon ?? _customIcons[index % _customIcons.length],
      primaryColor: color ?? _customPalette[index % _customPalette.length],
      renewalAuthority:
          (renewalAuthority?.trim().isNotEmpty ?? false)
              ? renewalAuthority!.trim()
              : 'Per document terms',
      typicalRenewalDays: typicalRenewalDays <= 0 ? 365 : typicalRenewalDays,
      isCustom: true,
    );
    _custom.add(meta);
    return meta;
  }

  /// Remove a custom type. Built-ins cannot be removed.
  void removeCustom(String key) {
    _custom.removeWhere((t) => t.key == key);
  }

  bool get hasCustom => _custom.isNotEmpty;

  /// Drop all custom types (sign-out).
  void reset() => _custom.clear();

  static String get customKeyPrefix => _customKeyPrefix;
}
