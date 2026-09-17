import 'package:flutter/material.dart';

import '../../models/document_type.dart';
import '../../models/expiry_item.dart';

/// Authority & Department brand logo badge widget for UAE government entities.
class DepartmentLogo extends StatelessWidget {
  final ExpiryItem item;
  final double size;

  const DepartmentLogo({
    super.key,
    required this.item,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final style = _resolveDepartmentStyle(item);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: style.borderColor,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: style.bgColor.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            style.icon,
            size: size * 0.42,
            color: style.textColor,
          ),
          SizedBox(height: size * 0.02),
          // FittedBox keeps the acronym inside the badge even when font
          // metrics (e.g. Ahem font in widget tests) exceed the box.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              style.acronym,
              style: TextStyle(
                color: style.textColor,
                fontSize: size * 0.22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static _DeptStyle _resolveDepartmentStyle(ExpiryItem item) {
    final loc = (item.location ?? '').toUpperCase();
    final type = item.docType;

    if (loc.contains('DED') || loc.contains('DET') || loc.contains('SEDD') || loc.contains('ADDED') || type.key == DocumentType.tradeLicence.name) {
      return const _DeptStyle(
        acronym: 'DED',
        icon: Icons.business_center_rounded,
        bgColor: Color(0xFF0F2942), // Deep Navy
        textColor: Color(0xFFFFD700), // Gold
        borderColor: Color(0xFF1E3A5F),
      );
    }

    if (loc.contains('RERA') || loc.contains('EJARI') || loc.contains('LAND') || type.key == DocumentType.ejari.name) {
      return const _DeptStyle(
        acronym: 'RERA',
        icon: Icons.home_work_rounded,
        bgColor: Color(0xFF0D5C3A), // Emerald Green
        textColor: Colors.white,
        borderColor: Color(0xFF137A4D),
      );
    }

    if (loc.contains('GDRFA') || loc.contains('RESIDENCY') || type.key == DocumentType.visa.name) {
      return const _DeptStyle(
        acronym: 'GDRFA',
        icon: Icons.card_membership_rounded,
        bgColor: Color(0xFF8B0000), // Crimson Red
        textColor: Color(0xFFFFD700), // Gold
        borderColor: Color(0xFFA52A2A),
      );
    }

    if (loc.contains('ICP') || loc.contains('IDENTITY') || type.key == DocumentType.emiratesId.name) {
      return const _DeptStyle(
        acronym: 'ICP',
        icon: Icons.badge_rounded,
        bgColor: Color(0xFF005F73), // Deep Teal
        textColor: Colors.white,
        borderColor: Color(0xFF0A9396),
      );
    }

    if (loc.contains('MOI') || loc.contains('INTERIOR') || type.key == DocumentType.passport.name) {
      return const _DeptStyle(
        acronym: 'MOI',
        icon: Icons.flight_takeoff_rounded,
        bgColor: Color(0xFF1B2631), // Midnight Navy
        textColor: Color(0xFFD4AF37), // Gold
        borderColor: Color(0xFF2E4053),
      );
    }

    if (loc.contains('MOHRE') || loc.contains('LABOUR') || type.key == DocumentType.labourDocuments.name) {
      return const _DeptStyle(
        acronym: 'MOHRE',
        icon: Icons.engineering_rounded,
        bgColor: Color(0xFF1D3557), // Royal Navy
        textColor: Color(0xFFE63946), // Red Accent
        borderColor: Color(0xFF457B9D),
      );
    }

    if (loc.contains('RTA') || type.key == DocumentType.vehicleRegistration.name || type.key == DocumentType.drivingLicence.name) {
      return const _DeptStyle(
        acronym: 'RTA',
        icon: Icons.directions_car_rounded,
        bgColor: Color(0xFFD62828), // RTA Red
        textColor: Colors.white,
        borderColor: Color(0xFFF77F00),
      );
    }

    if (loc.contains('DHA') || loc.contains('DOH') || type.key == DocumentType.insurance.name) {
      return const _DeptStyle(
        acronym: 'DHA',
        icon: Icons.health_and_safety_rounded,
        bgColor: Color(0xFF00A896), // Medical Cyan
        textColor: Colors.white,
        borderColor: Color(0xFF028090),
      );
    }

    if (loc.contains('DIFC') || loc.contains('ADGM')) {
      return const _DeptStyle(
        acronym: 'DIFC',
        icon: Icons.account_balance_rounded,
        bgColor: Color(0xFF2B2D42), // Slate Charcoal
        textColor: Color(0xFFD4AF37), // Metallic Gold
        borderColor: Color(0xFF8D99AE),
      );
    }

    if (loc.contains('FTA') || loc.contains('TAX') || loc.contains('VAT')) {
      return const _DeptStyle(
        acronym: 'FTA',
        icon: Icons.receipt_long_rounded,
        bgColor: Color(0xFF3D5A80), // Indigo Blue
        textColor: Color(0xFF98C1D9),
        borderColor: Color(0xFF293241),
      );
    }

    if (loc.contains('TDRA') || loc.contains('TRA') || type.key == DocumentType.domainNames.name) {
      return const _DeptStyle(
        acronym: 'TDRA',
        icon: Icons.language_rounded,
        bgColor: Color(0xFF1E6091), // Blue
        textColor: Colors.white,
        borderColor: Color(0xFF184E77),
      );
    }

    if (type.key == DocumentType.softwareSubscriptions.name) {
      return const _DeptStyle(
        acronym: 'SAAS',
        icon: Icons.cloud_done_rounded,
        bgColor: Color(0xFF6A0572), // Purple
        textColor: Colors.white,
        borderColor: Color(0xFF880E4F),
      );
    }

    // Default UAE Government Emblem style
    return const _DeptStyle(
      acronym: 'UAE',
      icon: Icons.verified_user_rounded,
      bgColor: Color(0xFF1F2421), // Charcoal Black
      textColor: Color(0xFFD4AF37), // Gold
      borderColor: Color(0xFF495057),
    );
  }
}

class _DeptStyle {
  final String acronym;
  final IconData icon;
  final Color bgColor;
  final Color textColor;
  final Color borderColor;

  const _DeptStyle({
    required this.acronym,
    required this.icon,
    required this.bgColor,
    required this.textColor,
    required this.borderColor,
  });
}
