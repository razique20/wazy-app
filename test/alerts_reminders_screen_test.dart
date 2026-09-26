import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finavig/screens/alerts_reminders_screen.dart';
import 'package:finavig/theme/app_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpAlertsReminders(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FinavigTheme.light(),
        home: const AlertsRemindersScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('renders all alert switches and reminder lead time dropdowns', (tester) async {
    await pumpAlertsReminders(tester);

    // Title
    expect(find.text('Alerts & Reminders'), findsOneWidget);

    // Section Titles
    expect(find.text('Alert Notifications'), findsOneWidget);
    expect(find.text('Reminder Lead Times & Schedule'), findsOneWidget);

    // Switches
    expect(find.text('Renewal notifications'), findsOneWidget);
    expect(find.text('Bill spike alerts'), findsOneWidget);
    expect(find.text('Budget alerts'), findsOneWidget);

    // Dropdowns
    expect(find.text('First reminder'), findsOneWidget);
    expect(find.text('Renewal task'), findsOneWidget);
    expect(find.text('Escalation'), findsOneWidget);
  });

  testWidgets('dropdown opens bottom sheet choices', (tester) async {
    await pumpAlertsReminders(tester);

    // Tap on First reminder row
    await tester.tap(find.text('First reminder'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Options inside the sheet
    expect(find.text('30 days before expiry'), findsWidgets);
    expect(find.text('60 days before expiry'), findsWidgets);
    expect(find.text('90 days before expiry'), findsWidgets);
    expect(find.text('120 days before expiry'), findsOneWidget);
  });
}
