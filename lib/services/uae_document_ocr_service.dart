import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/document_type.dart';
import '../screens/document_scan_screen.dart';

/// Result of OCR processing and UAE field extraction.
class UaeOcrResult {
  final String rawText;
  final String? title;
  final String? documentNumber;
  final DocumentTypeMeta? documentType;
  final DateTime? expiryDate;
  final UaeEmirate? emirate;
  final String? authority;
  final Map<String, bool> fieldConfidence; // field name -> isHighConfidence

  const UaeOcrResult({
    required this.rawText,
    this.title,
    this.documentNumber,
    this.documentType,
    this.expiryDate,
    this.emirate,
    this.authority,
    this.fieldConfidence = const {},
  });

  bool get hasAnyExtractedField =>
      title != null ||
      documentNumber != null ||
      documentType != null ||
      expiryDate != null ||
      emirate != null;

  @override
  String toString() {
    return 'UaeOcrResult(title: $title, docNo: $documentNumber, type: ${documentType?.displayName}, expiry: $expiryDate, emirate: ${emirate?.displayName})';
  }
}

/// Specialized OCR parsing service for UAE business & identity documents.
class UaeDocumentOcrService {
  static final UaeDocumentOcrService instance = UaeDocumentOcrService._();
  UaeDocumentOcrService._();

  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Processes an image file path and returns extracted UAE fields.
  Future<UaeOcrResult> processImageFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return const UaeOcrResult(rawText: '');
    }

    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      final String rawText = recognizedText.text;
      if (rawText.trim().isEmpty) {
        return const UaeOcrResult(rawText: '');
      }

      return parseText(rawText);
    } catch (e, stack) {
      debugPrint('Error running ML Kit OCR: $e\n$stack');
      return const UaeOcrResult(rawText: '');
    }
  }

  /// Parses raw text extracted from a UAE document.
  UaeOcrResult parseText(String rawText) {
    final Map<String, bool> confidence = {};
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. Detect Document Type
    final docType = _extractDocumentType(rawText);
    if (docType != null) confidence['documentType'] = true;

    // 2. Detect Expiry Date
    final expiryDate = _extractExpiryDate(rawText, lines);
    if (expiryDate != null) confidence['expiryDate'] = true;

    // 3. Detect Emirate & Authority
    final emirateMatch = _extractEmirateAndAuthority(rawText);
    final emirate = emirateMatch?.$1;
    final authority = emirateMatch?.$2;
    if (emirate != null) confidence['emirate'] = true;

    // 4. Extract Document Number
    final docNo = _extractDocumentNumber(rawText, lines, docType);
    if (docNo != null) confidence['documentNumber'] = true;

    // 5. Extract Title / Name
    final title = _extractTitle(rawText, lines, docType);
    if (title != null) confidence['title'] = true;

    return UaeOcrResult(
      rawText: rawText,
      title: title,
      documentNumber: docNo,
      documentType: docType,
      expiryDate: expiryDate,
      emirate: emirate,
      authority: authority,
      fieldConfidence: confidence,
    );
  }

  DocumentTypeMeta? _extractDocumentType(String text) {
    final upper = text.toUpperCase();
    final registry = DocumentTypeRegistry.instance;

    if (upper.contains('EJARI') ||
        upper.contains('TENANCY CONTRACT') ||
        upper.contains('LEASE CONTRACT') ||
        upper.contains('إيجاري') ||
        upper.contains('عقد إيجار')) {
      return registry.byEnum(DocumentType.ejari);
    }

    if (upper.contains('PASSPORT') ||
        upper.contains('جواز سفر')) {
      return registry.byEnum(DocumentType.passport);
    }

    if (upper.contains('DRIVING LICENCE') ||
        upper.contains('DRIVING LICENSE') ||
        upper.contains('DRIVER PERMIT') ||
        upper.contains('رخصة قيادة')) {
      return registry.byEnum(DocumentType.drivingLicence);
    }

    if (upper.contains('RESIDENCE PERMIT') ||
        upper.contains('RESIDENCY PERMIT') ||
        upper.contains('EMPLOYMENT VISA') ||
        upper.contains('ENTRY PERMIT') ||
        upper.contains('VISA') ||
        upper.contains('إقامة') ||
        upper.contains('تأشيرة')) {
      return registry.byEnum(DocumentType.visa);
    }

    if (upper.contains('MULKIYA') ||
        upper.contains('VEHICLE REGISTRATION') ||
        upper.contains('REGISTRATION CARD') ||
        upper.contains('ملكية') ||
        upper.contains('مركبة')) {
      return registry.byEnum(DocumentType.vehicleRegistration);
    }

    if (upper.contains('TRADE LICENSE') ||
        upper.contains('TRADE LICENCE') ||
        upper.contains('COMMERCIAL LICENSE') ||
        upper.contains('COMMERCIAL REGISTRATION') ||
        upper.contains('رخصة تجارية')) {
      return registry.byEnum(DocumentType.tradeLicence);
    }

    if (upper.contains('EMIRATES ID') ||
        upper.contains('IDENTITY CARD') ||
        upper.contains('بطاقة الهوية')) {
      return registry.byEnum(DocumentType.emiratesId);
    }

    if (upper.contains('ESTABLISHMENT CARD') ||
        upper.contains('COMPANY CARD') ||
        upper.contains('بطاقة منشأة')) {
      return registry.byEnum(DocumentType.labourDocuments);
    }

    if (upper.contains('HEALTH INSURANCE') ||
        upper.contains('MEDICAL INSURANCE') ||
        upper.contains('INSURANCE POLICY') ||
        upper.contains('تأمين صحي')) {
      return registry.byEnum(DocumentType.insurance);
    }

    if (upper.contains('CIVIL DEFENCE') ||
        upper.contains('CIVIL DEFENSE') ||
        upper.contains('SAFETY CERTIFICATE') ||
        upper.contains('الدفاع المدني')) {
      return registry.byEnum(DocumentType.certificates);
    }

    return null;
  }

  /// Parses dates from OCR text with specialized UAE format rules.
  DateTime? _extractExpiryDate(String fullText, List<String> lines) {
    final expiryKeywords = [
      'EXPIRY',
      'EXP',
      'VALID UNTIL',
      'EXPIRATION',
      'END DATE',
      'UNTIL',
      'تاريخ الانتهاء',
      'تاريخ انتهاء',
      'الانتهاء',
    ];

    List<DateTime> candidateDates = [];

    for (int i = 0; i < lines.length; i++) {
      final lineUpper = lines[i].toUpperCase();

      bool isExpiryLine = expiryKeywords.any((kw) => lineUpper.contains(kw));

      final searchChunk = isExpiryLine
          ? '$lineUpper ${i + 1 < lines.length ? lines[i + 1].toUpperCase() : ''}'
          : lineUpper;

      final dates = _findDatesInText(searchChunk);
      if (isExpiryLine && dates.isNotEmpty) {
        return dates.first;
      }
      candidateDates.addAll(dates);
    }

    final now = DateTime.now();
    final futureDates = candidateDates.where((d) => d.isAfter(now)).toList();
    if (futureDates.isNotEmpty) {
      futureDates.sort((a, b) => a.compareTo(b));
      return futureDates.first;
    }

    if (candidateDates.isNotEmpty) {
      candidateDates.sort((a, b) => b.compareTo(a));
      return candidateDates.first;
    }

    return null;
  }

  List<DateTime> _findDatesInText(String text) {
    final List<DateTime> results = [];

    // Pattern 1: DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY
    final dmyRegex = RegExp(
        r'\b(0?[1-9]|[12][0-9]|3[01])[\/\.\-](0?[1-9]|1[012])[\/\.\-](20\d{2})\b');
    for (final match in dmyRegex.allMatches(text)) {
      final d = int.tryParse(match.group(1) ?? '');
      final m = int.tryParse(match.group(2) ?? '');
      final y = int.tryParse(match.group(3) ?? '');
      if (d != null && m != null && y != null) {
        try {
          results.add(DateTime(y, m, d));
        } catch (_) {}
      }
    }

    // Pattern 2: YYYY/MM/DD or YYYY-MM-DD
    final ymdRegex = RegExp(
        r'\b(20\d{2})[\/\.\-](0?[1-9]|1[012])[\/\.\-](0?[1-9]|[12][0-9]|3[01])\b');
    for (final match in ymdRegex.allMatches(text)) {
      final y = int.tryParse(match.group(1) ?? '');
      final m = int.tryParse(match.group(2) ?? '');
      final d = int.tryParse(match.group(3) ?? '');
      if (d != null && m != null && y != null) {
        try {
          results.add(DateTime(y, m, d));
        } catch (_) {}
      }
    }

    // Pattern 3: DD MMM YYYY (e.g. 15 OCT 2026, 01-JAN-2025)
    final textDateRegex = RegExp(
        r'\b(0?[1-9]|[12][0-9]|3[01])[\s\/\.\-](JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[a-zA-Z]*[\s\/\.\-](20\d{2})\b',
        caseSensitive: false);
    final monthMap = {
      'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
      'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12
    };

    for (final match in textDateRegex.allMatches(text)) {
      final d = int.tryParse(match.group(1) ?? '');
      final mStr = match.group(2)?.toUpperCase().substring(0, 3);
      final y = int.tryParse(match.group(3) ?? '');
      final m = monthMap[mStr];

      if (d != null && m != null && y != null) {
        try {
          results.add(DateTime(y, m, d));
        } catch (_) {}
      }
    }

    return results;
  }

  (UaeEmirate, String)? _extractEmirateAndAuthority(String text) {
    final upper = text.toUpperCase();

    // Check Abu Dhabi first to avoid 'DHA' substring match inside 'ABU DHABI'
    if (upper.contains('ABU DHABI') || upper.contains('ADDED') || upper.contains('TAMM') || upper.contains('ADGM') || upper.contains('أبوظبي')) {
      if (upper.contains('ADDED') || upper.contains('ECONOMIC DEVELOPMENT')) {
        return (UaeEmirate.abuDhabi, 'ADDED (Abu Dhabi Dept of Economic Development)');
      }
      return (UaeEmirate.abuDhabi, 'TAMM / Municipality of Abu Dhabi');
    }

    if (upper.contains('DUBAI') || upper.contains('DET') || upper.contains('RERA') || upper.contains('GDRFA') || RegExp(r'\bDHA\b').hasMatch(upper) || upper.contains('DIFC') || upper.contains('دبي')) {
      if (upper.contains('RERA') || upper.contains('EJARI') || upper.contains('LAND DEPARTMENT')) {
        return (UaeEmirate.dubai, 'RERA / Dubai Land Department (Ejari)');
      }
      if (upper.contains('GDRFA')) {
        return (UaeEmirate.dubai, 'GDRFA Dubai (General Directorate of Residency)');
      }
      return (UaeEmirate.dubai, 'Dubai DET / DED (Department of Economy & Tourism)');
    }

    if (upper.contains('SHARJAH') || upper.contains('SEDD') || upper.contains('الشارقة')) {
      return (UaeEmirate.sharjah, 'Sharjah SEDD (Economic Development Dept)');
    }

    if (upper.contains('AJMAN') || upper.contains('عجمان')) {
      return (UaeEmirate.ajman, 'Ajman DED (Department of Economic Development)');
    }

    if (upper.contains('RAS AL KHAIMAH') || upper.contains('RAK') || upper.contains('رأس الخيمة')) {
      return (UaeEmirate.rak, 'RAK DED (Department of Economic Development)');
    }

    if (upper.contains('FUJAIRAH') || upper.contains('الفجيرة')) {
      return (UaeEmirate.fujairah, 'Fujairah Municipality');
    }

    if (upper.contains('UMM AL QUWAIN') || upper.contains('UAQ') || upper.contains('أم القيوين')) {
      return (UaeEmirate.uaq, 'UAQ DED (Department of Economic Development)');
    }

    if (upper.contains('MOHRE') || upper.contains('ICP') || upper.contains('FEDERAL TAX') || upper.contains('FTA')) {
      return (UaeEmirate.federal, 'ICP (Federal Identity, Citizenship & Customs)');
    }

    return null;
  }

  String? _extractDocumentNumber(
      String fullText, List<String> lines, DocumentTypeMeta? docType) {
    final visaMatch = RegExp(r'\b(201|301|101)\/\d{4}\/\d{1,2}\/\d{5,8}\b')
        .firstMatch(fullText);
    if (visaMatch != null) {
      return visaMatch.group(0);
    }

    final eidMatch =
        RegExp(r'\b784[-\s]?\d{4}[-\s]?\d{7}[-\s]?\d\b').firstMatch(fullText);
    if (eidMatch != null) {
      return eidMatch.group(0);
    }

    for (final line in lines) {
      final lUpper = line.toUpperCase();
      if (lUpper.contains('LICENCE NO') ||
          lUpper.contains('LICENSE NO') ||
          lUpper.contains('PASSPORT NO') ||
          lUpper.contains('REGISTRATION NO') ||
          lUpper.contains('CONTRACT NO') ||
          lUpper.contains('FILE NO') ||
          lUpper.contains('PERMIT NO') ||
          lUpper.contains('NUMBER:')) {
        // Document number must contain at least 1 digit
        final numRegex = RegExp(r'\b[A-Za-z0-9\-\/]*\d+[A-Za-z0-9\-\/]*\b');
        final matches = numRegex.allMatches(line).where((m) {
          final val = m.group(0)!;
          return !val.toUpperCase().contains('LICENCE') &&
              !val.toUpperCase().contains('LICENSE') &&
              !val.toUpperCase().contains('NUMBER') &&
              !val.toUpperCase().contains('DATE');
        }).toList();

        if (matches.isNotEmpty) {
          return matches.first.group(0);
        }
      }
    }

    return null;
  }

  String? _extractTitle(
      String fullText, List<String> lines, DocumentTypeMeta? docType) {
    final keywords = [
      'TRADE NAME',
      'COMPANY NAME',
      'LICENSEE',
      'TENANT NAME',
      'FULL NAME',
      'NAME / الاسم',
      'NAME',
      'EMPLOYER',
    ];

    for (int i = 0; i < lines.length; i++) {
      final lineUpper = lines[i].toUpperCase();
      for (final kw in keywords) {
        if (lineUpper.contains(kw)) {
          final parts = lines[i].split(RegExp(r'[:\-–]'));
          if (parts.length > 1 && parts[1].trim().length > 3) {
            return parts[1].trim();
          }
          if (i + 1 < lines.length && lines[i + 1].length > 3) {
            return lines[i + 1].trim();
          }
        }
      }
    }

    if (docType != null) {
      for (final line in lines) {
        final clean = line.trim();
        if (clean.length > 5 &&
            !clean.toUpperCase().contains('GOVERNMENT') &&
            !clean.toUpperCase().contains('UNITED ARAB EMIRATES') &&
            !clean.toUpperCase().contains('LICENSE') &&
            !clean.toUpperCase().contains('CERTIFICATE')) {
          return clean;
        }
      }
    }

    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
