import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:time_table/core/widgets/stat_card.dart';
import 'package:time_table/main.dart';

void main() {
  testWidgets('App renders correctly with dashboard and navigation', (WidgetTester tester) async {
    // Set desktop screen dimension for full responsive sidebar view
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ProviderScope(child: CollegeTimetableApp()));
    await tester.pumpAndSettle();

    // Verify main app title in header
    expect(find.text('TimePilot'), findsOneWidget);
    // Verify primary CREATE TIMETABLE button in header and dashboard
    expect(find.text('CREATE TIMETABLE'), findsWidgets);
    // Verify Dashboard navigation in sidebar
    expect(find.text('1. Dashboard'), findsOneWidget);
    // Verify 6-step checklist title on dashboard
    expect(find.text('Input Workflow Checklist'), findsOneWidget);
    // Verify Timetable Engine Status
    expect(find.text('Timetable Engine Status'), findsOneWidget);

    // Verify all 4 StatCards render on the dashboard with no RenderFlex overflow
    expect(find.text('Scheduled Classes'), findsOneWidget);
    expect(find.text('Faculty Assigned'), findsOneWidget);
    expect(find.text('Rooms / Labs Utilized'), findsOneWidget);
    expect(find.text('Constraint Conflicts'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('StatCard renders without RenderFlex overflow in compact constrained heights', (WidgetTester tester) async {
    final testHeights = [140.0, 120.0, 110.0, 100.0, 85.0];

    for (final height in testHeights) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                height: height,
                child: const StatCard(
                  title: 'Rooms / Labs Utilized',
                  value: '9999',
                  subtitle: '✓ Zero Conflicts (Verified)',
                  icon: Icons.meeting_room,
                  iconColor: Colors.purple,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'RenderFlex overflow at height $height');
      expect(find.text('Rooms / Labs Utilized'), findsOneWidget);
      expect(find.text('9999'), findsOneWidget);
    }
  });

  testWidgets('Dashboard renders with 0 overflow warnings at various Chrome screen widths', (WidgetTester tester) async {
    final screenSizes = [
      const Size(1920, 1080), // Large Chrome
      const Size(1366, 768),  // Laptop Chrome
      const Size(1024, 768),  // Medium Chrome
      const Size(900, 700),   // Compact Chrome
    ];

    for (final size in screenSizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(const ProviderScope(child: CollegeTimetableApp()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Overflow occurred at screen size $size');
    }
  });
}
