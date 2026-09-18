import '../models/document_type.dart';

/// The seven emirates plus the federal (UAE-wide) jurisdiction.
enum UaeEmirate {
  dubai('Dubai'),
  abuDhabi('Abu Dhabi'),
  sharjah('Sharjah'),
  ajman('Ajman'),
  rak('Ras Al Khaimah'),
  fujairah('Fujairah'),
  uaq('Umm Al Quwain'),
  federal('Federal / UAE-Wide');

  final String displayName;
  const UaeEmirate(this.displayName);
}

/// Central catalog relating emirate, issuing authority and document type.
///
/// Single source of truth for:
/// - the authority list per emirate (used by the upload form dropdown),
/// - the *suggested* issuing authority for a document type in an emirate
///   (used by the form, the OCR pre-fill and the NL quick add), and
/// - the ordered option list shown for a type/emirate pair.
///
/// When no confident mapping exists the caller falls back to
/// [otherAuthorityLabel] — the form's "Other / Custom Authority..." option —
/// which is the honest default for private issuers (insurers, registrars,
/// SaaS vendors) that no government list can enumerate.
class UaeAuthorityCatalog {
  UaeAuthorityCatalog._();

  static final UaeAuthorityCatalog instance = UaeAuthorityCatalog._();

  /// Sentinel option meaning "not listed here" — the user then types the
  /// authority name. Also the NL fallback when nothing is matched.
  static const String otherAuthorityLabel = 'Other / Custom Authority';

  /// Issuing authorities by emirate, as shown in the upload form.
  static final Map<UaeEmirate, List<String>> authoritiesByEmirate = {
    UaeEmirate.dubai: [
      'Dubai DET / DED (Department of Economy & Tourism)',
      'RERA / Dubai Land Department (Ejari)',
      'GDRFA Dubai (General Directorate of Residency)',
      'RTA Dubai (Roads & Transport Authority)',
      'DHA (Dubai Health Authority)',
      'Dubai Municipality',
      'DIFC (Dubai International Financial Centre)',
      'DDA (Dubai Development Authority / Free Zones)',
      'Dubai Courts',
    ],
    UaeEmirate.abuDhabi: [
      'ADDED (Abu Dhabi Dept of Economic Development)',
      'TAMM / Municipality of Abu Dhabi',
      'ICP Abu Dhabi (Identity & Citizenship)',
      'Integrated Transport Centre (ITC / DoT)',
      'DOH (Department of Health Abu Dhabi)',
      'ADGM (Abu Dhabi Global Market)',
    ],
    UaeEmirate.sharjah: [
      'Sharjah SEDD (Economic Development Dept)',
      'Sharjah City Municipality',
      'Sharjah SRTA (Roads & Transport Authority)',
      'Sharjah Police',
    ],
    UaeEmirate.ajman: [
      'Ajman DED (Department of Economic Development)',
      'Ajman Municipality & Planning Department',
      'Ajman Transport Authority',
    ],
    UaeEmirate.rak: [
      'RAK DED (Department of Economic Development)',
      'RAK Municipality',
      'RAK Public Services / RTA',
    ],
    UaeEmirate.fujairah: [
      'Fujairah Municipality',
      'Fujairah Free Zone Authority',
    ],
    UaeEmirate.uaq: [
      'UAQ DED (Department of Economic Development)',
      'UAQ Municipality',
    ],
    UaeEmirate.federal: [
      'ICP (Federal Identity, Citizenship & Customs)',
      'MOHRE (Ministry of Human Resources & Emiratisation)',
      'Ministry of Economy UAE',
      'FTA (Federal Tax Authority - TRN/VAT)',
      'Central Bank of the UAE',
      'TDRA (Telecommunications & Digital Regulatory Authority)',
    ],
  };

  /// Per-emirate overrides: documents whose authority genuinely depends on
  /// where they were issued.
  static const Map<DocumentType, Map<UaeEmirate, String>> _emirateOverrides = {
    // Licence: every emirate runs its own economic department.
    DocumentType.tradeLicence: {
      UaeEmirate.dubai: 'Dubai DET / DED (Department of Economy & Tourism)',
      UaeEmirate.abuDhabi: 'ADDED (Abu Dhabi Dept of Economic Development)',
      UaeEmirate.sharjah: 'Sharjah SEDD (Economic Development Dept)',
      UaeEmirate.ajman: 'Ajman DED (Department of Economic Development)',
      UaeEmirate.rak: 'RAK DED (Department of Economic Development)',
      UaeEmirate.uaq: 'UAQ DED (Department of Economic Development)',
      UaeEmirate.federal: 'Ministry of Economy UAE',
      // Fujairah mainland licences issue via the Municipality.
      UaeEmirate.fujairah: 'Fujairah Municipality',
    },
    // Ejari is Dubai-specific; other emirates register tenancy municipally.
    DocumentType.ejari: {
      UaeEmirate.dubai: 'RERA / Dubai Land Department (Ejari)',
      UaeEmirate.abuDhabi: 'TAMM / Municipality of Abu Dhabi',
      UaeEmirate.sharjah: 'Sharjah City Municipality',
      UaeEmirate.ajman: 'Ajman Municipality & Planning Department',
      UaeEmirate.rak: 'RAK Municipality',
      UaeEmirate.fujairah: 'Fujairah Municipality',
      UaeEmirate.uaq: 'UAQ Municipality',
    },
    // Residence visas: GDRFA in Dubai, ICP elsewhere.
    DocumentType.visa: {
      UaeEmirate.dubai: 'GDRFA Dubai (General Directorate of Residency)',
      UaeEmirate.abuDhabi: 'ICP Abu Dhabi (Identity & Citizenship)',
    },
    // Emirates ID: federal ICP, Abu Dhabi has its own office.
    DocumentType.emiratesId: {
      UaeEmirate.abuDhabi: 'ICP Abu Dhabi (Identity & Citizenship)',
    },
    // Traffic documents are emirate-run.
    DocumentType.drivingLicence: {
      UaeEmirate.dubai: 'RTA Dubai (Roads & Transport Authority)',
      UaeEmirate.abuDhabi: 'Integrated Transport Centre (ITC / DoT)',
      UaeEmirate.sharjah: 'Sharjah SRTA (Roads & Transport Authority)',
      UaeEmirate.ajman: 'Ajman Transport Authority',
      UaeEmirate.rak: 'RAK Public Services / RTA',
    },
    DocumentType.vehicleRegistration: {
      UaeEmirate.dubai: 'RTA Dubai (Roads & Transport Authority)',
      UaeEmirate.abuDhabi: 'Integrated Transport Centre (ITC / DoT)',
      UaeEmirate.sharjah: 'Sharjah SRTA (Roads & Transport Authority)',
      UaeEmirate.ajman: 'Ajman Transport Authority',
      UaeEmirate.rak: 'RAK Public Services / RTA',
    },
    DocumentType.permits: {
      UaeEmirate.dubai: 'Dubai Municipality',
      UaeEmirate.abuDhabi: 'TAMM / Municipality of Abu Dhabi',
      UaeEmirate.sharjah: 'Sharjah City Municipality',
      UaeEmirate.ajman: 'Ajman Municipality & Planning Department',
      UaeEmirate.rak: 'RAK Municipality',
      UaeEmirate.fujairah: 'Fujairah Municipality',
      UaeEmirate.uaq: 'UAQ Municipality',
    },
    DocumentType.contracts: {
      UaeEmirate.dubai: 'Dubai Courts',
    },
  };

  /// National defaults: documents issued by a federal body regardless of
  /// emirate. Null means "no confident default" → Other / Custom.
  static const Map<DocumentType, String?> _nationalDefaults = {
    DocumentType.tradeLicence: null, // always emirate-specific (overrides)
    DocumentType.ejari: null,
    DocumentType.visa: 'ICP (Federal Identity, Citizenship & Customs)',
    DocumentType.passport: 'ICP (Federal Identity, Citizenship & Customs)',
    DocumentType.emiratesId: 'ICP (Federal Identity, Citizenship & Customs)',
    DocumentType.labourDocuments:
        'MOHRE (Ministry of Human Resources & Emiratisation)',
    // Private insurers — cannot be enumerated.
    DocumentType.insurance: null,
    // Traffic documents are emirate-specific (overrides).
    DocumentType.drivingLicence: null,
    DocumentType.vehicleRegistration: null,
    DocumentType.contracts: null,
    // Attestations vary wildly (MOFA, ministries, chambers).
    DocumentType.certificates: null,
    // Municipality/Civil Defence — emirate-specific (overrides).
    DocumentType.permits: null,
    // Registrars and vendors are private.
    DocumentType.domainNames: null,
    DocumentType.softwareSubscriptions: null,
    DocumentType.supplierAgreements: null,
  };

  /// The suggested issuing authority for [meta] issued in [emirate], or null
  /// when there is no confident mapping (caller should default to Other).
  String? suggestedAuthorityFor(DocumentTypeMeta meta, UaeEmirate emirate) {
    final builtin = meta.builtinEnum;
    if (builtin == null) return null; // user-defined types → Other
    return _emirateOverrides[builtin]?[emirate] ?? _nationalDefaults[builtin];
  }

  /// Ordered dropdown options for a type/emirate pair: the suggested
  /// authority first, then the emirate's list, then federal authorities
  /// (valid UAE-wide), de-duplicated. 'Other / Custom Authority...' is added
  /// by the widget as the trailing sentinel.
  List<String> authorityOptionsFor(
    DocumentTypeMeta meta,
    UaeEmirate emirate,
  ) {
    final options = <String>[];
    final suggested = suggestedAuthorityFor(meta, emirate);
    if (suggested != null) options.add(suggested);
    for (final a in authoritiesByEmirate[emirate] ?? const <String>[]) {
      if (!options.contains(a)) options.add(a);
    }
    for (final a in authoritiesByEmirate[UaeEmirate.federal]!) {
      if (!options.contains(a)) options.add(a);
    }
    return options;
  }
}
