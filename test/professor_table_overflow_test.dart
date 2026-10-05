import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/features/staff/screens/staff_list_screen.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/providers/providers.dart';

void main() {
  final testDepts = [
    Department(id: 'dept_cse', collegeId: 'col_1', name: 'Computer Science', code: 'CSE'),
    Department(id: 'dept_ece', collegeId: 'col_1', name: 'Electronics & Communication', code: 'ECE'),
  ];

  final testStaffList = [
    // 1. Available for all slots (0 unavailable periods)
    Staff(
      id: 'prof_all_avail',
      collegeId: 'col_1',
      employeeId: 'EMP001',
      name: 'Dr. Alan Turing',
      email: 'alan.turing@university.edu',
      departmentId: 'dept_cse',
      designation: 'Professor',
      maxClassesPerDay: 4,
      status: 'active',
      unavailableTimes: [],
      subjectsCanTeach: ['Algorithms', 'TOC'],
    ),

    // 2. Exactly 1 unavailable period
    Staff(
      id: 'prof_single_unavail',
      collegeId: 'col_1',
      employeeId: 'EMP002',
      name: 'Dr. Ada Lovelace',
      email: 'ada.lovelace@university.edu',
      departmentId: 'dept_cse',
      designation: 'Associate Professor',
      maxClassesPerDay: 3,
      status: 'active',
      unavailableTimes: [
        const UnavailableTime(dayOfWeek: 'Monday', startTime: '09:00', endTime: '10:00'),
      ],
      subjectsCanTeach: ['Compiler Design'],
    ),

    // 3. Multiple unavailable periods (5 periods)
    Staff(
      id: 'prof_multi_unavail',
      collegeId: 'col_1',
      employeeId: 'EMP003',
      name: 'Dr. Grace Hopper',
      email: 'grace.hopper@university.edu',
      departmentId: 'dept_ece',
      designation: 'Professor & Head',
      maxClassesPerDay: 4,
      status: 'active',
      unavailableTimes: [
        const UnavailableTime(dayOfWeek: 'Monday', startTime: '09:00', endTime: '10:00'),
        const UnavailableTime(dayOfWeek: 'Tuesday', startTime: '11:00', endTime: '12:00'),
        const UnavailableTime(dayOfWeek: 'Wednesday', startTime: '14:00', endTime: '15:00'),
        const UnavailableTime(dayOfWeek: 'Thursday', startTime: '10:00', endTime: '11:00'),
        const UnavailableTime(dayOfWeek: 'Friday', startTime: '15:00', endTime: '16:00'),
      ],
      subjectsCanTeach: ['Computer Networks', 'OS'],
    ),

    // 4. Very long name and email to test wrapping and ellipsis without overflow
    Staff(
      id: 'prof_long_name',
      collegeId: 'col_1',
      employeeId: 'EMP999',
      name: 'Prof. Wolfeschlegelsteinhausenbergerdorff The Extraordinarily Senior Distinguished Chair of Distributed Cloud Systems',
      email: 'wolfeschlegelsteinhausenbergerdorff.extraordinarily.senior.distinguished.chair@extremelylongsubdomain.engineeringfaculty.university.edu',
      departmentId: 'dept_cse',
      designation: 'Distinguished Professor',
      maxClassesPerDay: 2,
      status: 'invited',
      unavailableTimes: [
        const UnavailableTime(dayOfWeek: 'Saturday', startTime: '09:00', endTime: '12:00'),
      ],
      subjectsCanTeach: ['Distributed Systems Architectures and Cloud Infrastructure Engineering'],
    ),
  ];

  Widget buildStaffListScreen({required Size screenSize}) {
    return ProviderScope(
      overrides: [
        staffListProvider.overrideWith((ref) => Future.value(testStaffList)),
        departmentListProvider.overrideWith((ref) => Future.value(testDepts)),
        activeCollegeIdProvider.overrideWith((ref) => 'col_1'),
      ],
      child: MaterialApp(
        home: const Scaffold(
          body: StaffListScreen(),
        ),
      ),
    );
  }

  group('Professors Table Layout & Overflow Tests', () {
    testWidgets('Table renders with zero overflow warnings on desktop (1280x800)', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildStaffListScreen(screenSize: const Size(1280, 800)));
      await tester.pumpAndSettle();

      // Verify no overflow exceptions occurred
      expect(tester.takeException(), isNull);

      // Verify table column headers
      expect(find.text('Faculty Member'), findsOneWidget);
      expect(find.text('Employee ID'), findsOneWidget);
      expect(find.text('Department'), findsOneWidget);
      expect(find.text('Designation'), findsOneWidget);
      expect(find.text('Max Load'), findsOneWidget);
      expect(find.text('Account Status'), findsOneWidget);
      expect(find.text('Availability'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);
    });

    testWidgets('Table renders with zero overflow warnings on narrow viewport (800x600)', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildStaffListScreen(screenSize: const Size(800, 600)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('Table renders with zero overflow warnings on very narrow mobile/split viewport (600x900)', (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildStaffListScreen(screenSize: const Size(600, 900)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Availability displays "All slots available" for professor with 0 unavailable periods', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildStaffListScreen(screenSize: const Size(1400, 900)));
      await tester.pumpAndSettle();

      expect(find.text('All slots available'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('Availability displays single unavailable period badge cleanly', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildStaffListScreen(screenSize: const Size(1400, 900)));
      await tester.pumpAndSettle();

      expect(find.text('Unavailable: Mon 09:00-10:00'), findsOneWidget);
    });

    testWidgets('Availability displays compact "5 unavailable periods" for professor with multiple unavailable times', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildStaffListScreen(screenSize: const Size(1400, 900)));
      await tester.pumpAndSettle();

      expect(find.text('5 unavailable periods'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('Tapping "5 unavailable periods" badge opens details dialog with all periods and edit action', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildStaffListScreen(screenSize: const Size(1400, 900)));
      await tester.pumpAndSettle();

      final badge = find.text('5 unavailable periods');
      expect(badge, findsOneWidget);

      await tester.ensureVisible(badge);
      await tester.pumpAndSettle();
      await tester.tap(badge);
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Dr. Grace Hopper'), findsWidgets);
      expect(find.text('Availability & Schedule Constraints'), findsOneWidget);
      expect(find.text('5 Unavailable Periods:'), findsOneWidget);

      // Verify individual unavailable periods are displayed
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('09:00 - 10:00'), findsOneWidget);
      expect(find.text('Tuesday'), findsOneWidget);
      expect(find.text('11:00 - 12:00'), findsOneWidget);
      expect(find.text('Wednesday'), findsOneWidget);
      expect(find.text('14:00 - 15:00'), findsOneWidget);
      expect(find.text('Thursday'), findsOneWidget);
      expect(find.text('10:00 - 11:00'), findsOneWidget);
      expect(find.text('Friday'), findsOneWidget);
      expect(find.text('15:00 - 16:00'), findsOneWidget);

      // Verify Edit Professor button
      expect(find.text('Edit Professor'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Tapping Edit Professor opens StaffAddEditDialog
      await tester.tap(find.text('Edit Professor'));
      await tester.pumpAndSettle();

      expect(find.byType(StaffAddEditDialog), findsOneWidget);
    });

    testWidgets('Tapping "All slots available" badge opens dialog confirming full availability', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildStaffListScreen(screenSize: const Size(1400, 900)));
      await tester.pumpAndSettle();

      final allSlotsBadge = find.text('All slots available');
      await tester.ensureVisible(allSlotsBadge);
      await tester.pumpAndSettle();
      await tester.tap(allSlotsBadge);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Dr. Alan Turing'), findsWidgets);
      expect(find.textContaining('available for all timetable slots'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('Extremely long professor name and email do not overflow the cell', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildStaffListScreen(screenSize: const Size(1280, 800)));
      await tester.pumpAndSettle();

      // No overflow exceptions thrown despite huge name & email
      expect(tester.takeException(), isNull);
    });

    testWidgets('All Action buttons (Manage Availability, Absence, Edit, Delete) are rendered and functional', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildStaffListScreen(screenSize: const Size(1400, 900)));
      await tester.pumpAndSettle();

      // 4 professors = 4 edit buttons, 4 delete buttons, etc.
      expect(find.byIcon(Icons.event_available), findsNWidgets(4));
      expect(find.byIcon(Icons.event_busy), findsWidgets); // Used in badges and action button
      expect(find.byIcon(Icons.edit), findsNWidgets(4));
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(4));
    });

    testWidgets('Search and Filter bar filters faculty members dynamically without layout issues', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildStaffListScreen(screenSize: const Size(1280, 800)));
      await tester.pumpAndSettle();

      // Search for "Hopper"
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Hopper');
      await tester.pumpAndSettle();

      // Only Dr. Grace Hopper is displayed
      expect(find.text('5 unavailable periods'), findsOneWidget);
      expect(find.text('Dr. Alan Turing'), findsNothing);
      expect(find.text('Dr. Ada Lovelace'), findsNothing);

      expect(tester.takeException(), isNull);
    });
  });
}
