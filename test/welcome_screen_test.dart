import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wazy/screens/welcome_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp() {
    final router = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (_, __) => const WelcomeScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('Login Page')),
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('WelcomeScreen renders hero, phone preview and Get Started', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Modern Fintech for\nPersonal Finance'), findsOneWidget);
    expect(find.text('Easy ways to manage your finances'), findsOneWidget);
    expect(find.text('WAZY'), findsOneWidget);
    // Main CTA (the in-phone pill reads "Get Started  →").
    expect(find.widgetWithText(ElevatedButton, 'Get Started'), findsOneWidget);
  });

  testWidgets('Get Started persists flag and navigates to login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Get Started'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Get Started'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('hasSeenWelcome'), isTrue);
    expect(find.text('Login Page'), findsOneWidget);
  });
}
