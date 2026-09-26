import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local reminder engine for Finavig.
///
/// Backed by [flutter_local_notifications] + `timezone`: reminders are
/// scheduled as OS-level local notifications so they fire even when the app
/// is closed. `scheduleReminder` is fully implemented (used by the document
/// add / update / renew flows and the "Schedule reminders" button);
/// `sendWhatsAppAlert` and `sendEmailAlert` are intentionally inactive until
/// a server-side provider (Meta WhatsApp Cloud API / SMTP via a Supabase Edge
/// Function) is wired up — secrets must never ship in the app bundle.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  factory NotificationService() => instance;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'renewal_reminders';
  static const _channelName = 'Renewal reminders';
  static const _channelDescription =
      'Reminders before company documents expire';

  static const _budgetChannelId = 'budget_alerts';
  static const _budgetChannelName = 'Budget alerts';
  static const _budgetChannelDescription =
      'Alerts when monthly spending reaches 80% or 100% of a category budget';

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Timezone database must be initialised before any TZDateTime is built.
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Dubai'));
      // ignore: avoid_catches_without_on_var_annotations
    } catch (_) {
      // Keep UTC default if the UAE location is unavailable for any reason.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    try {
      await _plugin.initialize(settings);
      // Android 13+ requires a runtime permission prompt; iOS already prompts
      // via DarwinInitializationSettings above.
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      // ignore: avoid_catches_without_on_var_annotations
    } catch (_) {
      // Plugin unavailable (e.g. tests) — service degrades to no-ops.
    }
  }

  /// Re-sync every document's reminders with what the OS has scheduled.
  ///
  /// Call once after documents are loaded on startup: clears stale pending
  /// reminders, then schedules the 90/60/30/7-day ladder for every active,
  /// non-expired document. Best-effort — failures leave startup unaffected.
  Future<void> resyncAll(
    List<({String id, String name, DateTime expiresAt})> items,
  ) async {
    await init();
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // Plugin unavailable.
      return;
    }
    for (final item in items) {
      if (item.expiresAt.isBefore(DateTime.now())) continue;
      await scheduleEscalationLadder(item.id, item.expiresAt, title: item.name);
    }
  }

  /// Compute the fire date for a reminder [daysBefore] expiry.
  ///
  /// Fires at 09:00 local time on `expiry - daysBefore`. If that moment is
  /// already in the past (document inside the window or overdue), the
  /// reminder fires shortly (1 hour) from now instead.
  static DateTime fireDateFor(DateTime expiresAt, int daysBefore) {
    final target = expiresAt.subtract(Duration(days: daysBefore));
    final nineAm = DateTime(target.year, target.month, target.day, 9);
    if (!nineAm.isAfter(DateTime.now())) {
      return DateTime.now().add(const Duration(hours: 1));
    }
    return nineAm;
  }

  /// Schedule an OS-level reminder [daysBefore] the document expires.
  ///
  /// Returns the notification id, or null when scheduling is unavailable.
  Future<int?> scheduleReminder(
    String itemId,
    int daysBefore, {
    String? title,
    String? body,
    DateTime? expiresAt,
  }) async {
    await init();

    final at = fireDateFor(
      expiresAt ?? DateTime.now().add(const Duration(days: 365)),
      daysBefore,
    );

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Ids are derived from the item so re-scheduling for the same document
    // replaces its pending reminder instead of stacking duplicates.
    final id = _notificationId(itemId, daysBefore);

    try {
      await _plugin.zonedSchedule(
        id,
        title ?? 'Document renewal reminder',
        body ?? 'A tracked document needs renewal soon.',
        tz.TZDateTime.from(at, tz.local),
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: itemId,
      );
      return id;
      // ignore: avoid_catches_without_on_var_annotations
    } catch (_) {
      return null;
    }
  }

  /// Schedule the escalation ladder for a document:
  /// Default: 90 / 60 / 30 / 7 days before expiry, or custom alert days if provided.
  Future<List<int>> scheduleEscalationLadder(
    String itemId,
    DateTime expiresAt, {
    String? title,
    List<int>? customReminderDays,
  }) async {
    final scheduled = <int>[];
    final daysList = (customReminderDays != null && customReminderDays.isNotEmpty)
        ? customReminderDays
        : const [90, 60, 30, 7];
    for (final days in daysList) {
      final id = await scheduleReminder(
        itemId,
        days,
        title: title,
        body: '$title expires in $days days — start the renewal now.',
        expiresAt: expiresAt,
      );
      if (id != null) scheduled.add(id);
    }
    return scheduled;
  }

  /// Cancel every pending reminder for [itemId] (all ladder tiers or custom offsets).
  Future<void> cancelReminders(String itemId, {List<int>? customReminderDays}) async {
    await init();
    final daysList = (customReminderDays != null && customReminderDays.isNotEmpty)
        ? customReminderDays
        : const [90, 60, 30, 7, 45, 15, 3, 1];
    for (final days in daysList) {
      try {
        await _plugin.cancel(_notificationId(itemId, days));
        // ignore: avoid_catches_without_on_var_annotations
      } catch (_) {
        // Plugin unavailable.
      }
    }
  }

  /// Show an immediate (non-scheduled) budget alert notification.
  /// Best-effort — returns silently when the plugin is unavailable (tests).
  Future<void> showBudgetAlertNotification({
    required String title,
    required String body,
  }) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      _budgetChannelId,
      _budgetChannelName,
      channelDescription: _budgetChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBanner: true,
      presentList: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    try {
      await _plugin.show(
        // Fixed id so successive alerts replace rather than stack up.
        _budgetChannelId.hashCode.toSigned(31),
        title,
        body,
        details,
      );
      // ignore: avoid_catches_without_on_var_annotations
    } catch (_) {
      // Plugin unavailable — degrade silently.
    }
  }

  /// Inactive: WhatsApp Business API requires a server-side secret
  /// (Meta Cloud API / Twilio). Never call it from the app — see
  /// PRODUCTION_READINESS.md. Kept as a no-op so existing call sites and
  /// the Profile toggles keep working until the Edge Function exists.
  Future<void> sendWhatsAppAlert(String itemId, String phoneNumber) async {
    // Inactive by design — no WhatsApp provider is wired up yet.
  }

  /// Inactive: email delivery requires a server-side provider (Resend/SMTP
  /// via a Supabase Edge Function). Kept as a no-op until then.
  Future<void> sendEmailAlert(String itemId, String email) async {
    // Inactive by design — no email provider is wired up yet.
  }

  /// Stable per-item notification id (Android caps int32).
  static int _notificationId(String itemId, int daysBefore) {
    return itemId.hashCode.toSigned(31) * 10 + (daysBefore ~/ 10);
  }
}
