import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/subscription_tier.dart';
import 'app_version_service.dart';
import 'auth_service.dart';
import 'entitlement_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Sends tier-upgrade requests to the Finavig team by email.
///
/// The one-button paywall flow: builds a pre-filled mailto: URI addressed to
/// [supportEmail] containing the user id, account email, current tier,
/// requested tier, the gated feature and device/app details, then opens the
/// platform mail client via url_launcher. If no mail client is available the
/// composed message is copied to the clipboard as a fallback.
/// Billing duration a user can request when choosing a plan.
enum PlanDuration {
  oneMonth('1_month', '1 Month', 1),
  threeMonths('3_months', '3 Months', 3),
  oneYear('1_year', '1 Year', 12);

  const PlanDuration(this.id, this.label, this.months);

  /// Stable id sent in upgrade-request emails and stored in
  /// `user_tiers.plan_duration` by the admin.
  final String id;

  /// Human-readable label shown in the plan picker.
  final String label;

  /// Length in months (12 for a year).
  final int months;

  static PlanDuration? tryFromId(String? id) {
    for (final d in PlanDuration.values) {
      if (d.id == id) return d;
    }
    return null;
  }
}

class UpgradeRequestService {
  UpgradeRequestService._();

  static final UpgradeRequestService instance = UpgradeRequestService._();

  /// Inbox that receives upgrade requests and provisions tiers manually in
  /// the Admin Console.
  static const String supportEmail = 'aethylglobal@gmail.com';

  /// Compose (but don't launch) the upgrade request email for [feature].
  ///
  /// Pass null for [feature] on a general upgrade (from the profile's
  /// subscription section). [requestedTier] defaults to the tier that
  /// unlocks [feature]. [duration] is the requested billing period (defaults
  /// to 1 month); the admin replies with a payment link for that duration
  /// and sets `user_tiers.plan_ends_at` once payment lands.
  ({Uri mailto, String body, String subject}) compose({
    EntitlementFeature? feature,
    SubscriptionTier? requestedTier,
    PlanDuration duration = PlanDuration.oneMonth,
  }) {
    final currentTier = EntitlementService.instance.tier;
    final target = requestedTier ??
        feature?.requiredTier ??
        SubscriptionTier.plus;
    final featureLabel = feature?.label ?? 'General tier upgrade';
    final currentEndsAt = EntitlementService.instance.planEndsAt;

    final userId = AuthService.instance.currentUserId ?? 'local-user';
    final userEmail = AuthService.instance.userEmail ?? 'not signed in';
    final platform = _platformLabel();
    final now = DateTime.now().toUtc();

    final subject =
        'Finavig upgrade request — ${target.name} (${duration.id}) — user $userId';

    final body = StringBuffer()
      ..writeln('Hello Finavig team,')
      ..writeln()
      ..writeln('I would like to upgrade my Finavig subscription.')
      ..writeln()
      ..writeln('— Request —')
      ..writeln('Requested tier: ${target.name}')
      ..writeln('Requested plan duration: ${duration.label}')
      ..writeln('Feature I need: $featureLabel')
      ..writeln('Current tier: ${currentTier.name}')
      ..writeln(
        'Current plan expires: '
        '${currentEndsAt == null ? '—' : _formatDate(currentEndsAt)}',
      )
      ..writeln()
      ..writeln('— Account details —')
      ..writeln('User ID: $userId')
      ..writeln('Account email: $userEmail')
      ..writeln('App version: ${AppVersionService.currentAppVersion}')
      ..writeln('Platform: $platform')
      ..writeln('Requested at: ${now.toIso8601String()}')
      ..writeln()
      ..writeln('(Sent from the Finavig app upgrade dialog.)');

    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {
        'subject': subject,
        'body': body.toString(),
      },
    );

    return (mailto: uri, body: body.toString(), subject: subject);
  }

  /// Open the platform mail client with the pre-filled request. Returns true
  /// when the mail client was launched; false means the message was only
  /// copied to the clipboard (no mail app available).
  Future<bool> send({
    EntitlementFeature? feature,
    SubscriptionTier? requestedTier,
    PlanDuration duration = PlanDuration.oneMonth,
  }) async {
    final message = compose(
      feature: feature,
      requestedTier: requestedTier,
      duration: duration,
    );

    if (await canLaunchUrl(message.mailto)) {
      await launchUrl(message.mailto, mode: LaunchMode.externalApplication);
      return true;
    }

    // Fallback: no mail client on this device — copy the request so the user
    // can paste it into any webmail client.
    await Clipboard.setData(ClipboardData(text: message.body));
    return false;
  }

  /// Log a pending request so the upgrade can be followed up even when the
  /// user never sends the email (visible in device logs / crash reporting).
  void logAttempt(EntitlementFeature? feature, SubscriptionTier target) {
    debugPrint(
      '[UpgradeRequestService] upgrade request: '
      'user=${AuthService.instance.currentUserId ?? 'local'} '
      'feature=${feature?.id ?? 'general'} requested=${target.id}',
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = date.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  static String _platformLabel() {
    if (kIsWeb) return 'Web';
    try {
      final os = Platform.operatingSystem;
      final version = Platform.operatingSystemVersion.split(' ').first;
      return '$os $version';
    } catch (_) {
      return 'unknown';
    }
  }
}
