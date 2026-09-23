import '../models/document_type.dart';
import '../models/gcc_country.dart';
import 'uae_authority_catalog.dart';

/// Central catalog for issuing authorities and document types across all 6 GCC countries.
class GccAuthorityCatalog {
  GccAuthorityCatalog._();

  static final GccAuthorityCatalog instance = GccAuthorityCatalog._();

  /// Sentinel option for custom/other issuing authority.
  static const String otherAuthorityLabel = 'Other / Custom Authority';

  /// Issuing authorities per GCC country.
  static final Map<GccCountry, List<String>> authoritiesByCountry = {
    GccCountry.uae: [
      'Dubai DET / DED (Department of Economy & Tourism)',
      'RERA / Dubai Land Department (Ejari)',
      'GDRFA Dubai (General Directorate of Residency)',
      'RTA Dubai (Roads & Transport Authority)',
      'DHA (Dubai Health Authority)',
      'Dubai Municipality',
      'DIFC (Dubai International Financial Centre)',
      'DDA (Dubai Development Authority / Free Zones)',
      'ADDED (Abu Dhabi Dept of Economic Development)',
      'TAMM / Municipality of Abu Dhabi',
      'ICP (Identity, Citizenship, Customs & Port Security)',
      'MOHRE (Ministry of Human Resources & Emiratisation)',
      'Ministry of Economy UAE',
      'FTA (Federal Tax Authority - TRN/VAT)',
    ],
    GccCountry.ksa: [
      'MOCI / Ministry of Commerce (Commercial Registration)',
      'ZATCA (Zakat, Tax and Customs Authority)',
      'QIWA / Ministry of Human Resources & Social Dev',
      'GOSI (General Organization for Social Insurance)',
      'Balady / Ministry of Municipal & Rural Affairs',
      'Ejar Network (Tenancy Registration)',
      'General Directorate of Passports (Jawazat)',
      'General Directorate of Traffic (Muroor)',
      'Saudi Food and Drug Authority (SFDA)',
      'Saudi Central Bank (SAMA)',
      'MISA (Ministry of Investment)',
    ],
    GccCountry.kuwait: [
      'MOCI (Ministry of Commerce & Industry)',
      'PAM (Public Authority of Manpower)',
      'PACI (Public Authority for Civil Information)',
      'Ministry of Interior (Residency & Passports)',
      'Kuwait Municipality',
      'Kuwait Chamber of Commerce & Industry (KCCI)',
      'General Administration of Customs',
      'Central Bank of Kuwait (CBK)',
      'Ministry of Health (MOH)',
    ],
    GccCountry.qatar: [
      'MOCI (Ministry of Commerce and Industry)',
      'Ministry of Interior (General Directorate of Passports / QID)',
      'Ministry of Labour',
      'Ministry of Municipality',
      'Qatar Chamber of Commerce & Industry',
      'General Tax Authority (GTA)',
      'Qatar Financial Centre (QFC)',
      'Kahramaa (Qatar General Electricity & Water)',
    ],
    GccCountry.bahrain: [
      'MOIC / Sijilat (Ministry of Industry & Commerce)',
      'LMRA (Labour Market Regulatory Authority)',
      'iGA (Information & eGovernment Authority - CPR)',
      'Ministry of Interior (General Directorate of Traffic / Nationality)',
      'Tamkeen (Labour Fund)',
      'National Bureau for Revenue (NBR - VAT)',
      'Bahrain Electricity & Water Authority (EWA)',
      'Central Bank of Bahrain (CBB)',
    ],
    GccCountry.oman: [
      'MOCIIP / Invest Easy (Ministry of Commerce, Industry & Investment)',
      'Ministry of Labour (Manpower Clearance)',
      'Royal Oman Police (ROP - Passports & Civil Status / Resident ID)',
      'Oman Chamber of Commerce and Industry (OCCI)',
      'Tax Authority Oman (VAT & Corporate Tax)',
      'Muscat Municipality / Local Municipalities',
      'Central Bank of Oman (CBO)',
      'Public Authority for Special Economic Zones (OPAZ)',
    ],
  };

  /// Country specific overrides for suggested issuing authority.
  static final Map<DocumentType, Map<GccCountry, String>> _countryAuthorityDefaults = {
    DocumentType.tradeLicence: {
      GccCountry.uae: 'Dubai DET / DED (Department of Economy & Tourism)',
      GccCountry.ksa: 'MOCI / Ministry of Commerce (Commercial Registration)',
      GccCountry.kuwait: 'MOCI (Ministry of Commerce & Industry)',
      GccCountry.qatar: 'MOCI (Ministry of Commerce and Industry)',
      GccCountry.bahrain: 'MOIC / Sijilat (Ministry of Industry & Commerce)',
      GccCountry.oman: 'MOCIIP / Invest Easy (Ministry of Commerce, Industry & Investment)',
    },
    DocumentType.ejari: {
      GccCountry.uae: 'RERA / Dubai Land Department (Ejari)',
      GccCountry.ksa: 'Ejar Network (Tenancy Registration)',
      GccCountry.kuwait: 'Kuwait Municipality',
      GccCountry.qatar: 'Ministry of Municipality',
      GccCountry.bahrain: 'Bahrain Electricity & Water Authority (EWA)',
      GccCountry.oman: 'Muscat Municipality / Local Municipalities',
    },
    DocumentType.visa: {
      GccCountry.uae: 'GDRFA Dubai / ICP UAE',
      GccCountry.ksa: 'General Directorate of Passports (Jawazat)',
      GccCountry.kuwait: 'Ministry of Interior (Residency & Passports)',
      GccCountry.qatar: 'Ministry of Interior (General Directorate of Passports / QID)',
      GccCountry.bahrain: 'iGA (Information & eGovernment Authority - CPR)',
      GccCountry.oman: 'Royal Oman Police (ROP - Passports & Civil Status)',
    },
    DocumentType.emiratesId: {
      GccCountry.uae: 'ICP (Identity, Citizenship, Customs & Port Security)',
      GccCountry.ksa: 'General Directorate of Passports (Jawazat / Iqama)',
      GccCountry.kuwait: 'PACI (Public Authority for Civil Information)',
      GccCountry.qatar: 'Ministry of Interior (QID Division)',
      GccCountry.bahrain: 'iGA (Information & eGovernment Authority - CPR)',
      GccCountry.oman: 'Royal Oman Police (Civil Status Division)',
    },
    DocumentType.labourDocuments: {
      GccCountry.uae: 'MOHRE (Ministry of Human Resources & Emiratisation)',
      GccCountry.ksa: 'QIWA / Ministry of Human Resources & Social Dev',
      GccCountry.kuwait: 'PAM (Public Authority of Manpower)',
      GccCountry.qatar: 'Ministry of Labour',
      GccCountry.bahrain: 'LMRA (Labour Market Regulatory Authority)',
      GccCountry.oman: 'Ministry of Labour (Manpower Clearance)',
    },
    DocumentType.drivingLicence: {
      GccCountry.uae: 'RTA Dubai / Transport Authorities',
      GccCountry.ksa: 'General Directorate of Traffic (Muroor)',
      GccCountry.kuwait: 'Ministry of Interior (General Directorate of Traffic)',
      GccCountry.qatar: 'General Directorate of Traffic (MOI Qatar)',
      GccCountry.bahrain: 'General Directorate of Traffic (MOI Bahrain)',
      GccCountry.oman: 'Royal Oman Police (Traffic Department)',
    },
    DocumentType.vehicleRegistration: {
      GccCountry.uae: 'RTA Dubai / Traffic Departments',
      GccCountry.ksa: 'General Directorate of Traffic (Muroor / Istimara)',
      GccCountry.kuwait: 'Ministry of Interior (General Directorate of Traffic)',
      GccCountry.qatar: 'General Directorate of Traffic (MOI Qatar)',
      GccCountry.bahrain: 'General Directorate of Traffic (MOI Bahrain)',
      GccCountry.oman: 'Royal Oman Police (Traffic Department)',
    },
  };

  /// Suggested authority for a document type in a given GCC country.
  String? suggestedAuthorityFor(DocumentTypeMeta meta, GccCountry country) {
    final builtin = meta.builtinEnum;
    if (builtin == null) return null;

    // For UAE, defer to UAE authority catalog for emirate specificity if needed
    if (country == GccCountry.uae) {
      final uaeResult = UaeAuthorityCatalog.instance.suggestedAuthorityFor(meta, UaeEmirate.dubai);
      if (uaeResult != null) return uaeResult;
    }

    return _countryAuthorityDefaults[builtin]?[country];
  }

  /// Ordered dropdown options for a type/country pair.
  List<String> authorityOptionsFor(DocumentTypeMeta meta, GccCountry country) {
    final options = <String>[];
    final suggested = suggestedAuthorityFor(meta, country);
    if (suggested != null) options.add(suggested);

    final countryList = authoritiesByCountry[country] ?? const <String>[];
    for (final a in countryList) {
      if (!options.contains(a)) options.add(a);
    }

    return options;
  }

  /// Get localized display name / alias for a document type based on the active country.
  static String getLocalizedDisplayName(DocumentType type, GccCountry country) {
    if (country == GccCountry.uae) {
      return type.displayName;
    }
    switch (type) {
      case DocumentType.tradeLicence:
        return country.tradeLicenceLabel;
      case DocumentType.emiratesId:
        return country.nationalIdLabel;
      case DocumentType.ejari:
        return country.tenancyLabel;
      case DocumentType.labourDocuments:
        return country.labourDocumentLabel;
      default:
        return type.displayName;
    }
  }

  /// Get localized picker alias for a document type.
  static String? getLocalizedPickerAlias(DocumentType type, GccCountry country) {
    if (country == GccCountry.uae) {
      return type.pickerAlias;
    }
    switch (type) {
      case DocumentType.tradeLicence:
        return 'Commercial Registration (CR)';
      case DocumentType.ejari:
        return 'Lease / Tenancy Registration';
      case DocumentType.emiratesId:
        return country.nationalIdLabel;
      case DocumentType.visa:
        return 'Residence Visa / Work Permit';
      case DocumentType.vehicleRegistration:
        return 'Vehicle Registration (Istimara)';
      case DocumentType.labourDocuments:
        return country.labourDocumentLabel;
      default:
        return type.pickerAlias;
    }
  }
}
