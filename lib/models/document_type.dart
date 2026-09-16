import 'package:flutter/material.dart';

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
