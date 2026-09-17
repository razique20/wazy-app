import 'package:flutter_test/flutter_test.dart';
import 'package:wazy/models/document_type.dart';
import 'package:wazy/screens/document_scan_screen.dart';
import 'package:wazy/services/uae_document_ocr_service.dart';

void main() {
  group('UaeDocumentOcrService Text Parsing Tests', () {
    final parser = UaeDocumentOcrService.instance;

    test('Parses Dubai Trade License sample text correctly', () {
      const rawText = '''
GOVERNMENT OF DUBAI
DEPARTMENT OF ECONOMY & TOURISM
COMMERCIAL LICENSE
License No: 785412
Trade Name: AL WASL TRADING LLC
Issue Date: 15/01/2024
Expiry Date: 14/01/2026
Emirate: DUBAI
      ''';

      final res = parser.parseText(rawText);

      expect(res.title, equals('AL WASL TRADING LLC'));
      expect(res.documentNumber, equals('785412'));
      expect(res.documentType?.displayName, equals(DocumentType.tradeLicence.displayName));
      expect(res.emirate, equals(UaeEmirate.dubai));
      expect(res.expiryDate, equals(DateTime(2026, 1, 14)));
      expect(res.hasAnyExtractedField, isTrue);
    });

    test('Parses UAE Residence Visa Sticker sample text', () {
      const rawText = '''
UNITED ARAB EMIRATES
RESIDENCE PERMIT / VISA
File No: 201/2023/3/9876543
Name: JOHN PETER DOE
Issue Date: 2023-05-10
Valid Until: 2026-05-09
GDRFA DUBAI
      ''';

      final res = parser.parseText(rawText);

      expect(res.documentNumber, equals('201/2023/3/9876543'));
      expect(res.documentType?.displayName, equals(DocumentType.visa.displayName));
      expect(res.emirate, equals(UaeEmirate.dubai));
      expect(res.authority, contains('GDRFA'));
      expect(res.expiryDate, equals(DateTime(2026, 5, 9)));
    });

    test('Parses Ejari Tenancy Contract sample text', () {
      const rawText = '''
DUBAI LAND DEPARTMENT
EJARI REGISTRATION CERTIFICATE
Contract No: 100458923
Tenant Name: SMART SOLUTION FZ LLC
Property Location: BUSINESS BAY DUBAI
Start Date: 01 OCT 2024
End Date: 30 SEP 2026
      ''';

      final res = parser.parseText(rawText);

      expect(res.documentNumber, equals('100458923'));
      expect(res.documentType?.displayName, equals(DocumentType.ejari.displayName));
      expect(res.emirate, equals(UaeEmirate.dubai));
      expect(res.expiryDate, equals(DateTime(2026, 9, 30)));
    });

    test('Parses Abu Dhabi Vehicle Mulkiya card text', () {
      const rawText = '''
ABU DHABI POLICE
VEHICLE REGISTRATION CARD / MULKIYA
TC No: 4589123
Plate: Abu Dhabi 4 98765
Reg Exp: 25.11.2026
ADDED ABU DHABI
      ''';

      final res = parser.parseText(rawText);

      expect(res.documentType?.displayName, equals(DocumentType.vehicleRegistration.displayName));
      expect(res.emirate, equals(UaeEmirate.abuDhabi));
      expect(res.expiryDate, equals(DateTime(2026, 11, 25)));
    });
  });
}
