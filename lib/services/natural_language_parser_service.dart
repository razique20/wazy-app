import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/document_type.dart';
import '../screens/document_scan_screen.dart';

/// Parsed natural language output item.
class ParsedNaturalLanguageItem {
  final String rawInput;
  final String title;
  final DocumentTypeMeta docType;
  final DateTime expiryDate;
  final UaeEmirate emirate;
  final String authority;
  final double? renewalFee;
  final bool hasExtractedDate;
  final bool hasExtractedFee;
  final bool hasExtractedEmirate;

  const ParsedNaturalLanguageItem({
    required this.rawInput,
    required this.title,
    required this.docType,
    required this.expiryDate,
    required this.emirate,
    required this.authority,
    this.renewalFee,
    this.hasExtractedDate = false,
    this.hasExtractedFee = false,
    this.hasExtractedEmirate = false,
  });

  @override
  String toString() {
    return 'ParsedNaturalLanguageItem(title: "$title", type: ${docType.displayName}, expiry: ${DateFormat("dd MMM yyyy").format(expiryDate)}, fee: $renewalFee, emirate: ${emirate.displayName})';
  }
}

/// Service that converts unstructured natural language text into structured Wazy document parameters.
class NaturalLanguageParserService {
  static final NaturalLanguageParserService instance =
      NaturalLanguageParserService._();
  NaturalLanguageParserService._();

  static const Map<String, int> _monthMap = {
    'JAN': 1, 'JANUARY': 1,
    'FEB': 2, 'FEBRUARY': 2,
    'MAR': 3, 'MARCH': 3,
    'APR': 4, 'APRIL': 4,
    'MAY': 5,
    'JUN': 6, 'JUNE': 6,
    'JUL': 7, 'JULY': 7,
    'AUG': 8, 'AUGUST': 8,
    'SEP': 9, 'SEPT': 9, 'SEPTEMBER': 9,
    'OCT': 10, 'OCTOBER': 10,
    'NOV': 11, 'NOVEMBER': 11,
    'DEC': 12, 'DECEMBER': 12,
  };

  /// Parses input string like:
  /// "Driving License Will Expire In October 12 2027 By Dubai Rta"
  ParsedNaturalLanguageItem parse(String text) {
    final rawText = text.trim();
    if (rawText.isEmpty) {
      return _defaultItem(rawText);
    }

    final lower = rawText.toLowerCase();

    // 1. Extract Expiry Date
    final dateMatch = _extractExpiryDate(rawText);
    final expiryDate = dateMatch?.$1 ?? DateTime.now().add(const Duration(days: 365));
    final hasExtractedDate = dateMatch != null;

    // 2. Extract Document Category Type
    final docType = _extractDocumentType(lower);

    // 3. Extract Renewal Fee
    final feeMatch = _extractFee(rawText);
    final renewalFee = feeMatch?.$1;
    final hasExtractedFee = feeMatch != null;

    // 4. Extract Emirate & Issuing Authority
    final emirateMatch = _extractEmirateAndAuthority(rawText);
    final emirate = emirateMatch?.$1 ?? UaeEmirate.dubai;
    final authority = emirateMatch?.$2 ?? 'Dubai DET / DED (Department of Economy & Tourism)';
    final hasExtractedEmirate = emirateMatch != null;

    // 5. Clean & Extract Title
    final title = _extractTitle(
      rawText: rawText,
      docType: docType,
      dateSnippet: dateMatch?.$2,
      feeSnippet: feeMatch?.$2,
      emirateSnippet: emirateMatch?.$3,
    );

    return ParsedNaturalLanguageItem(
      rawInput: rawText,
      title: title,
      docType: docType,
      expiryDate: expiryDate,
      emirate: emirate,
      authority: authority,
      renewalFee: renewalFee,
      hasExtractedDate: hasExtractedDate,
      hasExtractedFee: hasExtractedFee,
      hasExtractedEmirate: hasExtractedEmirate,
    );
  }

  ParsedNaturalLanguageItem _defaultItem(String raw) {
    return ParsedNaturalLanguageItem(
      rawInput: raw,
      title: 'New Document',
      docType: DocumentTypeRegistry.instance.byEnum(DocumentType.tradeLicence),
      expiryDate: DateTime.now().add(const Duration(days: 365)),
      emirate: UaeEmirate.dubai,
      authority: 'Dubai DET / DED (Department of Economy & Tourism)',
    );
  }

  (DateTime, String)? _extractExpiryDate(String text) {
    final now = DateTime.now();

    // 1. Relative dates: "in X days", "in X weeks", "in X months", "in X years", "tomorrow", "next month"
    final inDaysMatch = RegExp(r'\bin\s+(\d+)\s+days?\b', caseSensitive: false).firstMatch(text);
    if (inDaysMatch != null) {
      final days = int.parse(inDaysMatch.group(1)!);
      return (now.add(Duration(days: days)), inDaysMatch.group(0)!);
    }

    final inWeeksMatch = RegExp(r'\bin\s+(\d+)\s+weeks?\b', caseSensitive: false).firstMatch(text);
    if (inWeeksMatch != null) {
      final weeks = int.parse(inWeeksMatch.group(1)!);
      return (now.add(Duration(days: weeks * 7)), inWeeksMatch.group(0)!);
    }

    final inMonthsMatch = RegExp(r'\bin\s+(\d+)\s+months?\b', caseSensitive: false).firstMatch(text);
    if (inMonthsMatch != null) {
      final months = int.parse(inMonthsMatch.group(1)!);
      return (now.add(Duration(days: months * 30)), inMonthsMatch.group(0)!);
    }

    final inYearsMatch = RegExp(r'\bin\s+(\d+)\s+years?\b', caseSensitive: false).firstMatch(text);
    if (inYearsMatch != null) {
      final years = int.parse(inYearsMatch.group(1)!);
      return (now.add(Duration(days: years * 365)), inYearsMatch.group(0)!);
    }

    if (RegExp(r'\btomorrow\b', caseSensitive: false).hasMatch(text)) {
      final match = RegExp(r'\btomorrow\b', caseSensitive: false).firstMatch(text)!;
      return (now.add(const Duration(days: 1)), match.group(0)!);
    }

    if (RegExp(r'\bnext month\b', caseSensitive: false).hasMatch(text)) {
      final match = RegExp(r'\bnext month\b', caseSensitive: false).firstMatch(text)!;
      return (now.add(const Duration(days: 30)), match.group(0)!);
    }

    if (RegExp(r'\bnext year\b', caseSensitive: false).hasMatch(text)) {
      final match = RegExp(r'\bnext year\b', caseSensitive: false).firstMatch(text)!;
      return (now.add(const Duration(days: 365)), match.group(0)!);
    }

    // 2. Month-First Text Date: e.g. "October 12 2027", "Oct 12th 2027", "October 12, 2027", "in October 12 2027"
    final monthFirstRegex = RegExp(
      r'\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[a-zA-Z]*[\s\/\.\-]+(0?[1-9]|[12][0-9]|3[01])(?:st|nd|rd|th)?(?:[\s,\/\.\-]+(20\d{2}))?\b',
      caseSensitive: false,
    );
    final matchMonthFirst = monthFirstRegex.firstMatch(text);
    if (matchMonthFirst != null) {
      final mStr = matchMonthFirst.group(1)!.toUpperCase().substring(0, 3);
      final d = int.parse(matchMonthFirst.group(2)!);
      final yStr = matchMonthFirst.group(3);
      final y = yStr != null ? int.parse(yStr) : (now.month > (_monthMap[mStr] ?? 1) ? now.year + 1 : now.year);
      final m = _monthMap[mStr] ?? 1;
      try {
        return (DateTime(y, m, d), matchMonthFirst.group(0)!);
      } catch (_) {}
    }

    // 3. Day-First Text Date: e.g. "12 October 2027", "12th Oct 2027", "12/Oct/2027"
    final dayFirstRegex = RegExp(
      r'\b(0?[1-9]|[12][0-9]|3[01])(?:st|nd|rd|th)?[\s\/\.\-]+(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[a-zA-Z]*(?:[\s,\/\.\-]+(20\d{2}))?\b',
      caseSensitive: false,
    );
    final matchDayFirst = dayFirstRegex.firstMatch(text);
    if (matchDayFirst != null) {
      final d = int.parse(matchDayFirst.group(1)!);
      final mStr = matchDayFirst.group(2)!.toUpperCase().substring(0, 3);
      final yStr = matchDayFirst.group(3);
      final y = yStr != null ? int.parse(yStr) : (now.month > (_monthMap[mStr] ?? 1) ? now.year + 1 : now.year);
      final m = _monthMap[mStr] ?? 1;
      try {
        return (DateTime(y, m, d), matchDayFirst.group(0)!);
      } catch (_) {}
    }

    // 4. Month & Year only: e.g. "October 2027"
    final monthYearRegex = RegExp(
      r'\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[a-zA-Z]*[\s,\/\.\-]+(20\d{2})\b',
      caseSensitive: false,
    );
    final matchMonthYear = monthYearRegex.firstMatch(text);
    if (matchMonthYear != null) {
      final mStr = matchMonthYear.group(1)!.toUpperCase().substring(0, 3);
      final y = int.parse(matchMonthYear.group(2)!);
      final m = _monthMap[mStr] ?? 1;
      try {
        return (DateTime(y, m, 1), matchMonthYear.group(0)!);
      } catch (_) {}
    }

    // 5. ISO format: YYYY-MM-DD or YYYY/MM/DD
    final isoRegex = RegExp(r'\b(20\d{2})[\/\.\-](0?[1-9]|1[012])[\/\.\-](0?[1-9]|[12][0-9]|3[01])\b');
    final matchIso = isoRegex.firstMatch(text);
    if (matchIso != null) {
      final y = int.parse(matchIso.group(1)!);
      final m = int.parse(matchIso.group(2)!);
      final d = int.parse(matchIso.group(3)!);
      try {
        return (DateTime(y, m, d), matchIso.group(0)!);
      } catch (_) {}
    }

    // 6. Standard format: DD/MM/YYYY or DD-MM-YYYY
    final dmyRegex = RegExp(r'\b(0?[1-9]|[12][0-9]|3[01])[\/\.\-](0?[1-9]|1[012])[\/\.\-](20\d{2})\b');
    final matchDmy = dmyRegex.firstMatch(text);
    if (matchDmy != null) {
      final d = int.parse(matchDmy.group(1)!);
      final m = int.parse(matchDmy.group(2)!);
      final y = int.parse(matchDmy.group(3)!);
      try {
        return (DateTime(y, m, d), matchDmy.group(0)!);
      } catch (_) {}
    }

    return null;
  }

  DocumentTypeMeta _extractDocumentType(String lower) {
    final registry = DocumentTypeRegistry.instance;

    // Driving License & Vehicle / Mulkiya / RTA Card
    if (lower.contains('driving license') ||
        lower.contains('driving licence') ||
        lower.contains('driver license') ||
        lower.contains('driver\'s license') ||
        lower.contains('mulkiya') ||
        lower.contains('vehicle registration') ||
        lower.contains('vehicle') ||
        lower.contains('car registration')) {
      return registry.byEnum(DocumentType.vehicleRegistration);
    }

    // Ejari & Tenancy / Rental / Lease
    if (lower.contains('ejari') ||
        lower.contains('tenancy') ||
        lower.contains('lease') ||
        lower.contains('rent') ||
        lower.contains('apartment contract')) {
      return registry.byEnum(DocumentType.ejari);
    }

    // Visa & Residence / Residency
    if (lower.contains('visa') ||
        lower.contains('residency') ||
        lower.contains('residence') ||
        lower.contains('entry permit') ||
        lower.contains('passport')) {
      return registry.byEnum(DocumentType.visa);
    }

    // Emirates ID
    if (lower.contains('emirates id') ||
        lower.contains('eid') ||
        lower.contains('national id') ||
        lower.contains('identity card')) {
      return registry.byEnum(DocumentType.emiratesId);
    }

    // Trade License & Commercial License / Business License / DED
    if (lower.contains('trade licence') ||
        lower.contains('trade license') ||
        lower.contains('commercial license') ||
        lower.contains('commercial licence') ||
        lower.contains('business license') ||
        lower.contains('ded license') ||
        lower.contains('licence') ||
        lower.contains('license')) {
      return registry.byEnum(DocumentType.tradeLicence);
    }

    // Insurance
    if (lower.contains('insurance') ||
        lower.contains('health insurance') ||
        lower.contains('medical insurance') ||
        lower.contains('policy')) {
      return registry.byEnum(DocumentType.insurance);
    }

    // Labour / Establishment Card
    if (lower.contains('labour') ||
        lower.contains('labor') ||
        lower.contains('establishment card') ||
        lower.contains('company card') ||
        lower.contains('mohre')) {
      return registry.byEnum(DocumentType.labourDocuments);
    }

    // Civil Defense / Safety / Certificates
    if (lower.contains('civil defense') ||
        lower.contains('civil defence') ||
        lower.contains('safety certificate') ||
        lower.contains('certificate')) {
      return registry.byEnum(DocumentType.certificates);
    }

    return registry.byEnum(DocumentType.tradeLicence);
  }

  (double, String)? _extractFee(String text) {
    final aedRegex = RegExp(
      r'\b(?:aed|dirhams|dhs)\s*(\d+(?:\.\d{1,2})?)\b|\b(\d+(?:\.\d{1,2})?)\s*(?:aed|dirhams|dhs)\b',
      caseSensitive: false,
    );
    final aedMatch = aedRegex.firstMatch(text);
    if (aedMatch != null) {
      final valStr = aedMatch.group(1) ?? aedMatch.group(2);
      if (valStr != null) {
        final val = double.tryParse(valStr);
        if (val != null) {
          return (val, aedMatch.group(0)!);
        }
      }
    }

    final costRegex = RegExp(
      r'\b(?:cost|fee|price|amount)\s*:?\s*(\d+(?:\.\d{1,2})?)\b',
      caseSensitive: false,
    );
    final costMatch = costRegex.firstMatch(text);
    if (costMatch != null) {
      final valStr = costMatch.group(1);
      if (valStr != null) {
        final val = double.tryParse(valStr);
        if (val != null) {
          return (val, costMatch.group(0)!);
        }
      }
    }

    return null;
  }

  (UaeEmirate, String, String)? _extractEmirateAndAuthority(String text) {
    final upper = text.toUpperCase();

    // RTA (Roads & Transport Authority)
    if (upper.contains('RTA') || upper.contains('ROADS & TRANSPORT')) {
      return (UaeEmirate.dubai, 'RTA Dubai (Roads & Transport Authority)', 'RTA');
    }

    // GDRFA (Residency & Foreign Affairs)
    if (upper.contains('GDRFA') || upper.contains('IMMIGRATION')) {
      return (UaeEmirate.dubai, 'GDRFA Dubai (General Directorate of Residency)', 'GDRFA');
    }

    // Dubai / DET / DED / RERA
    if (upper.contains('DUBAI') || upper.contains('DET') || upper.contains('DED') || upper.contains('RERA')) {
      if (upper.contains('RERA') || upper.contains('EJARI')) {
        return (UaeEmirate.dubai, 'RERA / Dubai Land Department (Ejari)', 'Dubai');
      }
      return (UaeEmirate.dubai, 'Dubai DET / DED (Department of Economy & Tourism)', 'Dubai');
    }

    // Abu Dhabi / ITC / ADDED / TAMM
    if (upper.contains('ABU DHABI') || upper.contains('ADDED') || upper.contains('TAMM') || upper.contains('ITC')) {
      if (upper.contains('ITC') || upper.contains('TRANSPORT')) {
        return (UaeEmirate.abuDhabi, 'Integrated Transport Centre (ITC / DoT)', 'Abu Dhabi');
      }
      return (UaeEmirate.abuDhabi, 'ADDED (Abu Dhabi Dept of Economic Development)', 'Abu Dhabi');
    }

    if (upper.contains('SHARJAH') || upper.contains('SEDD')) {
      return (UaeEmirate.sharjah, 'Sharjah SEDD (Economic Development Dept)', 'Sharjah');
    }
    if (upper.contains('AJMAN')) {
      return (UaeEmirate.ajman, 'Ajman DED (Department of Economic Development)', 'Ajman');
    }
    if (upper.contains('RAS AL KHAIMAH') || upper.contains('RAK')) {
      return (UaeEmirate.rak, 'RAK DED (Department of Economic Development)', 'RAK');
    }
    if (upper.contains('FUJAIRAH')) {
      return (UaeEmirate.fujairah, 'Fujairah Municipality', 'Fujairah');
    }
    if (upper.contains('UMM AL QUWAIN') || upper.contains('UAQ')) {
      return (UaeEmirate.uaq, 'UAQ DED (Department of Economic Development)', 'UAQ');
    }

    return null;
  }

  String _extractTitle({
    required String rawText,
    required DocumentTypeMeta docType,
    String? dateSnippet,
    String? feeSnippet,
    String? emirateSnippet,
  }) {
    String clean = rawText;

    // 1. Strip action verbs at start
    clean = clean.replaceFirst(
      RegExp(r'^(?:add|remind\s+me\s+about|create|track|new)\s+(?:my\s+)?', caseSensitive: false),
      '',
    );
    clean = clean.replaceFirst(RegExp(r'^my\s+', caseSensitive: false), '');

    // 2. Strip date snippet
    if (dateSnippet != null && dateSnippet.isNotEmpty) {
      clean = clean.replaceAll(dateSnippet, '');
    }

    // 3. Strip fee snippet
    if (feeSnippet != null && feeSnippet.isNotEmpty) {
      clean = clean.replaceAll(feeSnippet, '');
    }

    // 4. Strip date prefix clauses: "will expire in", "will expire on", "expires in", "expires on", "expiring on", "due in", "due on", "expires"
    clean = clean.replaceAll(
      RegExp(r'\b(?:will\s+expire|expires|expiring|expiry|exp|valid\s+until|due)\b\s*(?:in|on|at|by)?', caseSensitive: false),
      '',
    );

    // 5. Strip authority prefix clauses: "by dubai rta", "by rta", "from rta", "issued by"
    clean = clean.replaceAll(
      RegExp(r'\b(?:by|from|issued\s+by|at)\b\s*(?:dubai|abu\s+dhabi|rta|ded|det|gdrfa|tamm|rera)?', caseSensitive: false),
      '',
    );

    // 6. Strip emirates / authority names if matched
    if (emirateSnippet != null && emirateSnippet.isNotEmpty) {
      clean = clean.replaceAll(RegExp(RegExp.escape(emirateSnippet), caseSensitive: false), '');
    }
    clean = clean.replaceAll(RegExp(r'\b(?:dubai|abu\s+dhabi|sharjah|ajman|rak|fujairah|uaq|rta|ded|det|gdrfa|mohre)\b', caseSensitive: false), '');

    // 7. Strip isolated prepositions and punctuation
    clean = clean.replaceAll(RegExp(r'\b(?:in|on|at|by|for|of|the|a|an)\b', caseSensitive: false), '');
    clean = clean.replaceAll(RegExp(r'[,:;\.\-–]'), ' ');

    final tokens = clean
        .split(RegExp(r'\s+'))
        .where((t) => t.trim().isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      return docType.displayName;
    }

    // Capitalize words
    final result = tokens.map((t) {
      if (t.length == 1) return t.toUpperCase();
      return t[0].toUpperCase() + t.substring(1).toLowerCase();
    }).join(' ');

    return result.trim().isEmpty ? docType.displayName : result.trim();
  }
}
