import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ams_mobile_app/screens/auth/landing_screen.dart';
import 'package:ams_mobile_app/widgets/common/app_logo.dart';

void main() {
  testWidgets('AppLogo renders without overflow across various sizes', (WidgetTester tester) async {
    for (final size in [24.0, 38.0, 48.0, 80.0, 96.0, 120.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppLogo(size: size),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('LandingScreen renders cleanly on mobile viewport without layout exception', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LandingScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('AttendancePro'), findsWidgets);
    expect(find.text('ATTENDANCE WEB SYSTEM'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Sign Up'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
