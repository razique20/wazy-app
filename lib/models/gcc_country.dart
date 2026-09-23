import 'package:flutter/material.dart';

/// The 6 member states of the Gulf Cooperation Council (GCC).
enum GccCountry {
  uae('AE', 'United Arab Emirates', '🇦🇪', 'AED', '+971'),
  ksa('SA', 'Saudi Arabia', '🇸🇦', 'SAR', '+966'),
  kuwait('KW', 'Kuwait', '🇰🇼', 'KWD', '+965'),
  qatar('QA', 'Qatar', '🇶🇦', 'QAR', '+974'),
  bahrain('BH', 'Bahrain', '🇧🇭', 'BHD', '+973'),
  oman('OM', 'Oman', '🇴🇲', 'OMR', '+968');

  final String code;
  final String displayName;
  final String flagEmoji;
  final String currency;
  final String phoneCode;

  const GccCountry(
    this.code,
    this.displayName,
    this.flagEmoji,
    this.currency,
    this.phoneCode,
  );

  /// Resolve country from standard ISO 2-letter country code (case-insensitive).
  /// Defaults to UAE for unknown or missing codes.
  static GccCountry fromCode(String? code) {
    if (code == null || code.trim().isEmpty) return GccCountry.uae;
    final upper = code.trim().toUpperCase();
    for (final country in GccCountry.values) {
      if (country.code == upper) return country;
    }
    return GccCountry.uae;
  }

  /// National ID card document title for this country.
  String get nationalIdLabel {
    switch (this) {
      case GccCountry.uae:
        return 'Emirates ID';
      case GccCountry.ksa:
        return 'Iqama / National ID';
      case GccCountry.kuwait:
        return 'Civil ID';
      case GccCountry.qatar:
        return 'QID (Qatar ID)';
      case GccCountry.bahrain:
        return 'CPR (Central Population ID)';
      case GccCountry.oman:
        return 'Resident / National ID';
    }
  }

  /// Tenancy registration service name for this country.
  String get tenancyLabel {
    switch (this) {
      case GccCountry.uae:
        return 'Ejari / Tenancy Registration';
      case GccCountry.ksa:
        return 'Ejar Platform Registration';
      case GccCountry.kuwait:
        return 'Tenancy Agreement / Contract';
      case GccCountry.qatar:
        return 'Lease Registration';
      case GccCountry.bahrain:
        return 'Lease Contract Registration';
      case GccCountry.oman:
        return 'Municipality Lease Contract';
    }
  }

  /// Commercial registration / Business Licence title for this country.
  String get tradeLicenceLabel {
    switch (this) {
      case GccCountry.uae:
        return 'Trade Licence';
      case GccCountry.ksa:
        return 'Commercial Registration (CR)';
      case GccCountry.kuwait:
        return 'Commercial Licence / CR';
      case GccCountry.qatar:
        return 'Commercial Registration (CR)';
      case GccCountry.bahrain:
        return 'Commercial Registration (CR)';
      case GccCountry.oman:
        return 'Commercial Registration (CR)';
    }
  }

  /// Primary work permit body / document name.
  String get labourDocumentLabel {
    switch (this) {
      case GccCountry.uae:
        return 'MOHRE Labour Card';
      case GccCountry.ksa:
        return 'QIWA / GOSI Work Permit';
      case GccCountry.kuwait:
        return 'PAM Work Permit';
      case GccCountry.qatar:
        return 'Labour Department Work Permit';
      case GccCountry.bahrain:
        return 'LMRA Work Permit';
      case GccCountry.oman:
        return 'Ministry of Labour Permit';
    }
  }
}
