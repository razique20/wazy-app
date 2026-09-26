import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finavig/theme/app_theme.dart';
import 'package:finavig/widgets/shimmer_skeleton.dart';

void main() {
  testWidgets('ShimmerSkeleton renders with pulsating animation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FinavigTheme.light(),
        home: const Scaffold(
          body: ShimmerSkeleton(width: 100, height: 20),
        ),
      ),
    );

    expect(find.byType(ShimmerSkeleton), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));
  });

  testWidgets('Skeleton views render correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FinavigTheme.light(),
        home: const Scaffold(
          body: HomeSkeletonView(),
        ),
      ),
    );

    expect(find.byType(HomeSkeletonView), findsOneWidget);
    expect(find.byType(TileSkeletonLoader), findsWidgets);
  });
}
