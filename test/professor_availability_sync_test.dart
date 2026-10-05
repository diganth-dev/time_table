import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/features/staff/screens/staff_availability_screen.dart';
import 'package:time_table/features/staff/screens/staff_list_screen.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/providers/providers.dart';
import 'package:time_table/repositories/repositories.dart';

void main() {
  group('Professor Availability UI Synchronization Tests', () {
    const testCollegeId = 'col_sync_test';

    final testCollege = College(
      id: testCollegeId,
      name: 'Sync Engineering College',
      code: 'SEC',
      workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      periodsPerDay: 4,
      periodDurationMinutes: 60,
      startTime: '08:50',
    );

    final testDepts = [
      Department(id: 'dept_cs', collegeId: testCollegeId, name: 'Computer Science', code: 'CS'),
    ];

    final scheduleSlots = [
      TimeSlot(id: 'ts_1', collegeId: testCollegeId, periodNumber: 1, startTime: '08:50', endTime: '09:50', order: 1),
      TimeSlot(id: 'ts_2', collegeId: testCollegeId, periodNumber: 2, startTime: '09:50', endTime: '10:50', order: 2),
      TimeSlot(id: 'ts_b1', collegeId: testCollegeId, periodNumber: 0, startTime: '10:50', endTime: '11:05', isBreak: true, breakTitle: 'Tea Break', order: 3),
      TimeSlot(id: 'ts_3', collegeId: testCollegeId, periodNumber: 3, startTime: '11:05', endTime: '12:05', order: 4),
      TimeSlot(id: 'ts_4', collegeId: testCollegeId, periodNumber: 4, startTime: '12:05', endTime: '13:05', order: 5),
    ];

    testWidgets('Scenario 1 & 4 (Grid -> Edit Professor): Marking periods in Grid saves contiguous ranges to Staff.unavailableTimes', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = LocalDatabaseRepository();
      await repo.saveTimeSlots(testCollegeId, scheduleSlots);

      final initialStaff = Staff(
        id: 'prof_sync_1',
        collegeId: testCollegeId,
        name: 'Dr. Alan Turing',
        departmentId: 'dept_cs',
        designation: 'Professor',
        unavailableTimes: const [],
      );
      await repo.createStaff(initialStaff);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            activeCollegeIdProvider.overrideWith((ref) => testCollegeId),
            currentCollegeProvider.overrideWith((ref) => Future.value(testCollege)),
            departmentListProvider.overrideWith((ref) => Future.value(testDepts)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StaffAvailabilityScreen(staff: initialStaff),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find cell for Monday Period 2 and toggle to Unavailable
      final cellP2 = find.byKey(const Key('cell_Monday_2'));
      expect(cellP2, findsOneWidget);
      expect(find.descendant(of: cellP2, matching: find.text('Available')), findsOneWidget);

      await tester.tap(cellP2);
      await tester.pumpAndSettle();
      expect(find.descendant(of: cellP2, matching: find.text('Unavailable')), findsOneWidget);

      // Save Availability
      final saveBtn = find.byKey(const Key('save_availability_button'));
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify the persisted staff in repository now has Monday 09:50 - 10:50 (Scenario 1)
      final savedStaff = await repo.getStaff(initialStaff.id);
      expect(savedStaff, isNotNull);
      expect(savedStaff!.unavailableTimes.length, 1);
      expect(savedStaff.unavailableTimes.first.dayOfWeek, 'Monday');
      expect(savedStaff.unavailableTimes.first.startTime, '09:50');
      expect(savedStaff.unavailableTimes.first.endTime, '10:50');

      // Now toggle Period 1 on Monday as well -> Consecutive periods P1 (08:50-09:50) and P2 (09:50-10:50)
      final cellP1 = find.byKey(const Key('cell_Monday_1'));
      await tester.tap(cellP1);
      await tester.pumpAndSettle();
      expect(find.descendant(of: cellP1, matching: find.text('Unavailable')), findsOneWidget);

      // Save Availability again (Scenario 4)
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      final savedStaff2 = await repo.getStaff(initialStaff.id);
      expect(savedStaff2, isNotNull);
      // P1 and P2 should merge cleanly into Monday 08:50 - 10:50
      expect(savedStaff2!.unavailableTimes.length, 1);
      expect(savedStaff2.unavailableTimes.first.dayOfWeek, 'Monday');
      expect(savedStaff2.unavailableTimes.first.startTime, '08:50');
      expect(savedStaff2.unavailableTimes.first.endTime, '10:50');
    });

    testWidgets('Scenario 2 & 3 (Edit Professor -> Grid): Added ranges in Edit Professor reflect in Grid accurately', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = LocalDatabaseRepository();
      await repo.saveTimeSlots(testCollegeId, scheduleSlots);

      // Dr. Hopper has Monday 09:50 - 10:50 (Scenario 2)
      final staffHopper = Staff(
        id: 'prof_hopper',
        collegeId: testCollegeId,
        name: 'Dr. Grace Hopper',
        departmentId: 'dept_cs',
        designation: 'Professor',
        unavailableTimes: const [
          UnavailableTime(dayOfWeek: 'Monday', startTime: '09:50', endTime: '10:50'),
        ],
      );
      await repo.createStaff(staffHopper);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            activeCollegeIdProvider.overrideWith((ref) => testCollegeId),
            currentCollegeProvider.overrideWith((ref) => Future.value(testCollege)),
            departmentListProvider.overrideWith((ref) => Future.value(testDepts)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StaffAvailabilityScreen(staff: staffHopper),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Monday Period 1 should be Available, Period 2 should be Unavailable, Period 3 Available
      final p1Cell = find.byKey(const Key('cell_Monday_1'));
      final p2Cell = find.byKey(const Key('cell_Monday_2'));
      final p3Cell = find.byKey(const Key('cell_Monday_3'));

      expect(find.descendant(of: p1Cell, matching: find.text('Available')), findsOneWidget);
      expect(find.descendant(of: p2Cell, matching: find.text('Unavailable')), findsOneWidget);
      expect(find.descendant(of: p3Cell, matching: find.text('Available')), findsOneWidget);
    });

    testWidgets('Scenario 3: Multi-period range 08:50 - 12:05 in Edit Professor marks P1, P2, and P3 unavailable in Grid', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = LocalDatabaseRepository();
      await repo.saveTimeSlots(testCollegeId, scheduleSlots);

      // Staff configured with multi-period range covering P1 through P3
      final staffMulti = Staff(
        id: 'prof_multi',
        collegeId: testCollegeId,
        name: 'Dr. Ada Lovelace',
        departmentId: 'dept_cs',
        designation: 'Professor',
        unavailableTimes: const [
          UnavailableTime(dayOfWeek: 'Monday', startTime: '08:50', endTime: '12:05'),
        ],
      );
      await repo.createStaff(staffMulti);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            activeCollegeIdProvider.overrideWith((ref) => testCollegeId),
            currentCollegeProvider.overrideWith((ref) => Future.value(testCollege)),
            departmentListProvider.overrideWith((ref) => Future.value(testDepts)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StaffAvailabilityScreen(staff: staffMulti),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // P1, P2, P3 must all be Unavailable; P4 must remain Available
      final p1Cell = find.byKey(const Key('cell_Monday_1'));
      final p2Cell = find.byKey(const Key('cell_Monday_2'));
      final p3Cell = find.byKey(const Key('cell_Monday_3'));
      final p4Cell = find.byKey(const Key('cell_Monday_4'));

      expect(find.descendant(of: p1Cell, matching: find.text('Unavailable')), findsOneWidget);
      expect(find.descendant(of: p2Cell, matching: find.text('Unavailable')), findsOneWidget);
      expect(find.descendant(of: p3Cell, matching: find.text('Unavailable')), findsOneWidget);
      expect(find.descendant(of: p4Cell, matching: find.text('Available')), findsOneWidget);
    });

    testWidgets('Scenario D: Removal in Grid updates Staff and clears unavailable times', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = LocalDatabaseRepository();
      await repo.saveTimeSlots(testCollegeId, scheduleSlots);

      final staffWithUnavail = Staff(
        id: 'prof_remove',
        collegeId: testCollegeId,
        name: 'Prof. Donald Knuth',
        departmentId: 'dept_cs',
        unavailableTimes: const [
          UnavailableTime(dayOfWeek: 'Monday', startTime: '09:50', endTime: '10:50'),
        ],
      );
      await repo.createStaff(staffWithUnavail);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            activeCollegeIdProvider.overrideWith((ref) => testCollegeId),
            currentCollegeProvider.overrideWith((ref) => Future.value(testCollege)),
            departmentListProvider.overrideWith((ref) => Future.value(testDepts)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StaffAvailabilityScreen(staff: staffWithUnavail),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Monday P2 is currently Unavailable
      final p2Cell = find.byKey(const Key('cell_Monday_2'));
      expect(find.descendant(of: p2Cell, matching: find.text('Unavailable')), findsOneWidget);

      // Tap cell to mark it Available again
      await tester.tap(p2Cell);
      await tester.pumpAndSettle();
      expect(find.descendant(of: p2Cell, matching: find.text('Available')), findsOneWidget);

      // Save Availability
      await tester.tap(find.byKey(const Key('save_availability_button')));
      await tester.pumpAndSettle();

      // Repository must now have empty unavailableTimes
      final savedStaff = await repo.getStaff(staffWithUnavail.id);
      expect(savedStaff, isNotNull);
      expect(savedStaff!.unavailableTimes, isEmpty);
    });

    testWidgets('Non-consecutive unavailable periods save as separate distinct ranges', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = LocalDatabaseRepository();
      await repo.saveTimeSlots(testCollegeId, scheduleSlots);

      final staff = Staff(
        id: 'prof_gaps',
        collegeId: testCollegeId,
        name: 'Dr. Shannon',
        departmentId: 'dept_cs',
        unavailableTimes: const [],
      );
      await repo.createStaff(staff);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            activeCollegeIdProvider.overrideWith((ref) => testCollegeId),
            currentCollegeProvider.overrideWith((ref) => Future.value(testCollege)),
            departmentListProvider.overrideWith((ref) => Future.value(testDepts)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StaffAvailabilityScreen(staff: staff),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mark Period 1 Unavailable (08:50 - 09:50)
      await tester.tap(find.byKey(const Key('cell_Monday_1')));
      await tester.pumpAndSettle();

      // Leave Period 2 Available

      // Mark Period 3 Unavailable (11:05 - 12:05)
      await tester.tap(find.byKey(const Key('cell_Monday_3')));
      await tester.pumpAndSettle();

      // Save Availability
      await tester.tap(find.byKey(const Key('save_availability_button')));
      await tester.pumpAndSettle();

      final savedStaff = await repo.getStaff(staff.id);
      expect(savedStaff, isNotNull);

      // Must have exactly two distinct ranges preserving the gap (P2 available)
      expect(savedStaff!.unavailableTimes.length, 2);
      expect(savedStaff.unavailableTimes[0].startTime, '08:50');
      expect(savedStaff.unavailableTimes[0].endTime, '09:50');
      expect(savedStaff.unavailableTimes[1].startTime, '11:05');
      expect(savedStaff.unavailableTimes[1].endTime, '12:05');
    });

    testWidgets('Preserves non-working day unavailable times when saving from Grid', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = LocalDatabaseRepository();
      await repo.saveTimeSlots(testCollegeId, scheduleSlots);

      // Staff has an unavailable time on Sunday (non-working day)
      final staffWithSunday = Staff(
        id: 'prof_weekend',
        collegeId: testCollegeId,
        name: 'Dr. Weekend',
        departmentId: 'dept_cs',
        unavailableTimes: const [
          UnavailableTime(dayOfWeek: 'Sunday', startTime: '09:00', endTime: '12:00'),
        ],
      );
      await repo.createStaff(staffWithSunday);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            activeCollegeIdProvider.overrideWith((ref) => testCollegeId),
            currentCollegeProvider.overrideWith((ref) => Future.value(testCollege)),
            departmentListProvider.overrideWith((ref) => Future.value(testDepts)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StaffAvailabilityScreen(staff: staffWithSunday),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle Monday Period 1 as Unavailable
      await tester.tap(find.byKey(const Key('cell_Monday_1')));
      await tester.pumpAndSettle();

      // Save Availability
      await tester.tap(find.byKey(const Key('save_availability_button')));
      await tester.pumpAndSettle();

      final savedStaff = await repo.getStaff(staffWithSunday.id);
      expect(savedStaff, isNotNull);

      // Both the Sunday unavailable time AND the new Monday unavailable time must be present
      expect(savedStaff!.unavailableTimes.any((u) => u.dayOfWeek == 'Sunday' && u.startTime == '09:00'), isTrue);
      expect(savedStaff.unavailableTimes.any((u) => u.dayOfWeek == 'Monday' && u.startTime == '08:50'), isTrue);
    });

    testWidgets('College Schedule change dynamically adapts both availability UIs without hardcoding', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Updated schedule timings: Period 1 shifted to 09:00 - 10:00, Period 2 to 10:00 - 11:00
      final updatedScheduleSlots = [
        TimeSlot(id: 'ts_1', collegeId: testCollegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
        TimeSlot(id: 'ts_2', collegeId: testCollegeId, periodNumber: 2, startTime: '10:00', endTime: '11:00', order: 2),
      ];

      final timingOptions = buildScheduleTimingOptions(updatedScheduleSlots);

      // Dropdown options must contain the newly updated schedule timings
      expect(timingOptions.any((o) => o.label == 'Period 1 — 9:00 AM' && o.value == '09:00'), isTrue);
      expect(timingOptions.any((o) => o.label == 'Period 2 — 10:00 AM' && o.value == '10:00'), isTrue);
      expect(timingOptions.any((o) => o.label == 'Period 2 End — 11:00 AM' && o.value == '11:00'), isTrue);

      // Staff member with unavailability under new schedule
      final staff = Staff(
        id: 'prof_sched',
        collegeId: testCollegeId,
        name: 'Dr. Dynamic',
        departmentId: 'dept_cs',
        unavailableTimes: const [
          UnavailableTime(dayOfWeek: 'Monday', startTime: '10:00', endTime: '11:00'),
        ],
      );

      // Period 1 is 09:00-10:00 (Available)
      expect(staff.isUnavailableDuring(day: 'Monday', slot: updatedScheduleSlots[0]), isFalse);
      // Period 2 is 10:00-11:00 (Unavailable)
      expect(staff.isUnavailableDuring(day: 'Monday', slot: updatedScheduleSlots[1]), isTrue);
    });

    testWidgets('Full Circle: Edit Dialog -> Grid -> Modify in Grid -> Edit Dialog confirms bidirectional sync', (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = LocalDatabaseRepository();
      await repo.saveTimeSlots(testCollegeId, scheduleSlots);

      var staff = Staff(
        id: 'prof_circle',
        collegeId: testCollegeId,
        name: 'Prof. Circle',
        departmentId: 'dept_cs',
        unavailableTimes: const [],
      );
      await repo.createStaff(staff);

      // Part 1: Open Edit Dialog, add Monday Period 2 (09:50 - 10:50)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffAddEditDialog(
              existing: staff,
              depts: testDepts,
              collegeId: testCollegeId,
              timeSlots: scheduleSlots,
              onSave: (updated) async {
                await repo.updateStaff(updated);
                staff = updated;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select From: Period 2 — 9:50 AM
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'From'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Period 2 — 9:50 AM').last);
      await tester.pumpAndSettle();

      // Select To: Tea Break — 10:50 AM
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'To'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tea Break — 10:50 AM').last);
      await tester.pumpAndSettle();

      // Add Unavailable Time
      await tester.tap(find.text('Add Unavailable Time'));
      await tester.pumpAndSettle();

      // Save Changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(staff.unavailableTimes.length, 1);
      expect(staff.unavailableTimes.first.startTime, '09:50');
      expect(staff.unavailableTimes.first.endTime, '10:50');

      // Part 2: Open Faculty Availability Grid with the updated staff
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            activeCollegeIdProvider.overrideWith((ref) => testCollegeId),
            currentCollegeProvider.overrideWith((ref) => Future.value(testCollege)),
            departmentListProvider.overrideWith((ref) => Future.value(testDepts)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StaffAvailabilityScreen(staff: staff),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Monday P2 is Unavailable
      final p2Cell = find.byKey(const Key('cell_Monday_2'));
      expect(find.descendant(of: p2Cell, matching: find.text('Unavailable')), findsOneWidget);

      // Part 3: In Grid, toggle Monday P2 back to Available and Save
      await tester.tap(p2Cell);
      await tester.pumpAndSettle();
      expect(find.descendant(of: p2Cell, matching: find.text('Available')), findsOneWidget);

      await tester.tap(find.byKey(const Key('save_availability_button')));
      await tester.pumpAndSettle();

      final updatedStaffFromRepo = await repo.getStaff(staff.id);
      expect(updatedStaffFromRepo, isNotNull);
      expect(updatedStaffFromRepo!.unavailableTimes, isEmpty);

      // Part 4: Re-open Edit Dialog with the newly saved staff
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffAddEditDialog(
              existing: updatedStaffFromRepo,
              depts: testDepts,
              collegeId: testCollegeId,
              timeSlots: scheduleSlots,
              onSave: (s) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The unavailable time chip is gone
      expect(find.text('No unavailable periods specified (available for all slots).'), findsOneWidget);
      expect(find.byType(Chip), findsNothing);
    });
  });
}
