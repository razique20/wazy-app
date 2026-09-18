import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wazy/models/document_type.dart';
import 'package:wazy/screens/document_scan_screen.dart';
import 'package:wazy/services/natural_language_parser_service.dart';
import 'package:wazy/services/uae_authority_catalog.dart';

void main() {
  group('UaeAuthorityCatalog type → authority mapping', () {
    final catalog = UaeAuthorityCatalog.instance;

    test('Trade Licence maps to the emirate economic department', () {
      expect(
        catalog.suggestedAuthorityFor(
          DocumentTypeRegistry.instance.byEnum(DocumentType.tradeLicence),
          UaeEmirate.dubai,
        ),
        contains('DET / DED'),
      );
      expect(
        catalog.suggestedAuthorityFor(
          DocumentTypeRegistry.instance.byEnum(DocumentType.tradeLicence),
          UaeEmirate.abuDhabi,
        ),
        contains('ADDED'),
      );
      expect(
        catalog.suggestedAuthorityFor(
          DocumentTypeRegistry.instance.byEnum(DocumentType.tradeLicence),
          UaeEmirate.sharjah,
        ),
        contains('SEDD'),
      );
    });

    test('Emirates ID defaults to federal ICP', () {
      expect(
        catalog.suggestedAuthorityFor(
          DocumentTypeRegistry.instance.byEnum(DocumentType.emiratesId),
          UaeEmirate.dubai,
        ),
        contains('ICP'),
      );
    });

    test('Insurance has no confident mapping → null (Other default)', () {
      expect(
        catalog.suggestedAuthorityFor(
          DocumentTypeRegistry.instance.byEnum(DocumentType.insurance),
          UaeEmirate.dubai,
        ),
        isNull,
      );
    });

    test('Custom (user-defined) types → null (Other default)', () {
      const meta = DocumentTypeMeta(
        key: 'custom-test',
        displayName: 'My Custom Doc',
        icon: Icons.description_rounded,
        primaryColor: Color(0xFF000000),
        renewalAuthority: '',
      );
      expect(catalog.suggestedAuthorityFor(meta, UaeEmirate.dubai), isNull);
    });

    test('Suggested authority is always first in the option list', () {
      final options = catalog.authorityOptionsFor(
        DocumentTypeRegistry.instance.byEnum(DocumentType.vehicleRegistration),
        UaeEmirate.dubai,
      );
      expect(options.first, contains('RTA'));
      // Federal bodies are appended as valid UAE-wide options.
      expect(options, contains(contains('MOHRE')));
    });
  });

  group('NL parser uses the type+emirate authority mapping', () {
    final parser = NaturalLanguageParserService.instance;

    test('Driving licence in Dubai → RTA', () {
      final res = parser.parse('driving licence expires in 90 days Dubai');
      expect(res.authority, contains('RTA'));
    });

    test('Vehicle registration with Abu Dhabi mentioned → ITC', () {
      final res = parser.parse('vehicle registration expires in 60 days Abu Dhabi');
      expect(res.authority, contains('ITC'));
    });

    test('Visa in Dubai → GDRFA (emirate override beats federal ICP)', () {
      final res = parser.parse('visa for Ahmed expires 2027-01-10');
      expect(res.authority, contains('GDRFA'));
    });

    test('Labour document without authority named → MOHRE via catalog', () {
      final res = parser.parse('labour card expires in 6 months');
      expect(res.authority, contains('MOHRE'));
    });

    test('Insurance without authority named → Other / Custom label', () {
      final res = parser.parse('insurance policy expires in 30 days');
      expect(
        res.authority,
        equals(UaeAuthorityCatalog.otherAuthorityLabel),
      );
    });

    test('Named authority still wins over the catalog suggestion', () {
      final res = parser.parse('trade licence expires in 90 days GDRFA');
      expect(res.authority, contains('GDRFA'));
    });
  });
}
