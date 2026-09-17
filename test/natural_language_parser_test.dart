import 'package:flutter_test/flutter_test.dart';
import 'package:wazy/models/document_type.dart';
import 'package:wazy/screens/document_scan_screen.dart';
import 'package:wazy/services/natural_language_parser_service.dart';

void main() {
  group('NaturalLanguageParserService Typo & Variation Tests', () {
    final parser = NaturalLanguageParserService.instance;

    test('Parses user screenshot prompt: "Driving License Will Expire In October 12 2027 By Dubai Rta"', () {
      const prompt = 'Driving License Will Expire In October 12 2027 By Dubai Rta';
      final res = parser.parse(prompt);

      expect(res.title, equals('Driving License'));
      expect(res.docType.displayName, equals(DocumentType.drivingLicence.displayName));
      expect(res.expiryDate.year, equals(2027));
      expect(res.expiryDate.month, equals(10));
      expect(res.expiryDate.day, equals(12));
      expect(res.emirate, equals(UaeEmirate.dubai));
      expect(res.authority, contains('RTA'));
      expect(res.hasExtractedDate, isTrue);
    });

    test('Parses prompt with typo "drving lisence" & Month-first date', () {
      const prompt = 'drving lisence ending Nov 15 2026 fee 1.5k AED';
      final res = parser.parse(prompt);

      expect(res.docType.displayName, equals(DocumentType.drivingLicence.displayName));
      expect(res.expiryDate.year, equals(2026));
      expect(res.expiryDate.month, equals(11));
      expect(res.expiryDate.day, equals(15));
      expect(res.renewalFee, equals(1500.0));
    });

    test('Parses prompt with typo "ejri tenacy" & relative date', () {
      const prompt = 'ejri tenacy contract expiring in 45 days cost 4500 dhm Dubai';
      final res = parser.parse(prompt);

      expect(res.docType.displayName, equals(DocumentType.ejari.displayName));
      expect(res.renewalFee, equals(4500.0));
      expect(res.emirate, equals(UaeEmirate.dubai));
      expect(res.hasExtractedDate, isTrue);
    });

    test('Parses prompt with typo "viza residancy" & ISO date', () {
      const prompt = 'viza residancy for Ahmed expires 2026-11-15 fee 3500 dirhams';
      final res = parser.parse(prompt);

      expect(res.docType.displayName, equals(DocumentType.visa.displayName));
      expect(res.expiryDate, equals(DateTime(2026, 11, 15)));
      expect(res.renewalFee, equals(3500.0));
    });

    test('Parses prompt with typo "mulkya vehical" & Abu Dhabi Tamm', () {
      const prompt = 'mulkya vehical reg valid until 25/12/2026 Abu Dhabi Tamm fee 750 aed';
      final res = parser.parse(prompt);

      expect(res.docType.displayName, equals(DocumentType.vehicleRegistration.displayName));
      expect(res.emirate, equals(UaeEmirate.abuDhabi));
      expect(res.expiryDate, equals(DateTime(2026, 12, 25)));
      expect(res.renewalFee, equals(750.0));
    });

    test('Parses prompt with "passport" & ISO date', () {
      const prompt = 'passport renewal expires 2027-08-15 fee 1200 aed';
      final res = parser.parse(prompt);

      expect(res.docType.displayName, equals(DocumentType.passport.displayName));
      expect(res.expiryDate, equals(DateTime(2027, 8, 15)));
      expect(res.renewalFee, equals(1200.0));
    });

    test('Parses prompt with typo "passprt" as passport, not visa', () {
      const prompt = 'passprt of Ahmed valid until 15/03/2028';
      final res = parser.parse(prompt);

      expect(res.docType.displayName, equals(DocumentType.passport.displayName));
      expect(res.expiryDate, equals(DateTime(2028, 3, 15)));
    });

    test('Parses prompt with "emiratesid" & Month-Year date', () {
      const prompt = 'emiratesid card valid till October 2027';
      final res = parser.parse(prompt);

      expect(res.docType.displayName, equals(DocumentType.emiratesId.displayName));
      expect(res.expiryDate.year, equals(2027));
      expect(res.expiryDate.month, equals(10));
    });

    test('Parses prompt with typo "health insurane" & relative months', () {
      const prompt = 'health insurane policy due in 2 months cost 2k AED';
      final res = parser.parse(prompt);

      expect(res.docType.displayName, equals(DocumentType.insurance.displayName));
      expect(res.renewalFee, equals(2000.0));
      expect(res.hasExtractedDate, isTrue);
    });

    test('Parses prompt with typo "civil defence cert" & Sharjah SEDD', () {
      const prompt = 'civil defence cert exp in 90 days Sharjah SEDD';
      final res = parser.parse(prompt);

      expect(res.docType.displayName, equals(DocumentType.certificates.displayName));
      expect(res.emirate, equals(UaeEmirate.sharjah));
      expect(res.hasExtractedDate, isTrue);
    });

    test('Parses prompt with "establishment card" & fee', () {
      const prompt = 'establishment card exp 30 Jun 2027 fee 1800 dirhams';
      final res = parser.parse(prompt);

      expect(res.docType.displayName, equals(DocumentType.labourDocuments.displayName));
      expect(res.expiryDate, equals(DateTime(2027, 6, 30)));
      expect(res.renewalFee, equals(1800.0));
    });
  });
}
