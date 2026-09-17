import 'package:flutter_test/flutter_test.dart';
import 'package:wazy/models/document_type.dart';
import 'package:wazy/screens/document_scan_screen.dart';
import 'package:wazy/services/natural_language_parser_service.dart';

void main() {
  group('NaturalLanguageParserService Tests', () {
    final parser = NaturalLanguageParserService.instance;

    test('Parses user screenshot prompt: "Driving License Will Expire In October 12 2027 By Dubai Rta"', () {
      const prompt = 'Driving License Will Expire In October 12 2027 By Dubai Rta';
      final res = parser.parse(prompt);

      expect(res.title, equals('Driving License'));
      expect(res.docType.displayName, equals(DocumentType.vehicleRegistration.displayName));
      expect(res.expiryDate.year, equals(2027));
      expect(res.expiryDate.month, equals(10));
      expect(res.expiryDate.day, equals(12));
      expect(res.emirate, equals(UaeEmirate.dubai));
      expect(res.authority, contains('RTA'));
      expect(res.hasExtractedDate, isTrue);
    });

    test('Parses prompt: "Add my trade licence, expires 12 March 2027"', () {
      const prompt = 'Add my trade licence, expires 12 March 2027';
      final res = parser.parse(prompt);

      expect(res.title, equals('Trade Licence'));
      expect(res.docType.displayName, equals(DocumentType.tradeLicence.displayName));
      expect(res.expiryDate.year, equals(2027));
      expect(res.expiryDate.month, equals(3));
      expect(res.expiryDate.day, equals(12));
      expect(res.hasExtractedDate, isTrue);
    });

    test('Parses prompt with fee and emirate: "Remind me about Ejari contract expires in 60 days cost 2500 AED Dubai"', () {
      const prompt = 'Remind me about Ejari contract expires in 60 days cost 2500 AED Dubai';
      final res = parser.parse(prompt);

      expect(res.docType.displayName, equals(DocumentType.ejari.displayName));
      expect(res.renewalFee, equals(2500.0));
      expect(res.emirate, equals(UaeEmirate.dubai));
      expect(res.hasExtractedFee, isTrue);
      expect(res.hasExtractedEmirate, isTrue);
    });

    test('Parses prompt with ISO date and person name: "Visa renewal for John Doe expires 2026-11-15"', () {
      const prompt = 'Visa renewal for John Doe expires 2026-11-15';
      final res = parser.parse(prompt);

      expect(res.docType.displayName, equals(DocumentType.visa.displayName));
      expect(res.expiryDate, equals(DateTime(2026, 11, 15)));
      expect(res.title, contains('John Doe'));
    });

    test('Parses prompt with relative next month and fee: "Vehicle Mulkiya expires next month cost 800 AED Abu Dhabi"', () {
      const prompt = 'Vehicle Mulkiya expires next month cost 800 AED Abu Dhabi';
      final res = parser.parse(prompt);

      expect(res.docType.displayName, equals(DocumentType.vehicleRegistration.displayName));
      expect(res.renewalFee, equals(800.0));
      expect(res.emirate, equals(UaeEmirate.abuDhabi));
    });
  });
}
