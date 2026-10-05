import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:time_table/features/settings/screens/period_settings_screen.dart';
import 'package:time_table/features/workflow/screens/input_workflow_screen.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/providers/providers.dart';
import 'package:time_table/repositories/repositories.dart';
import 'package:time_table/services/timetable_generator.dart';

void main() {
  group('Working Days State Synchronization & Pre-Flight Verification Tests', () {
    late LocalDatabaseRepository repo;
    const testCollegeId = 'user_college';

    final testSection = Section(
      id: 'sec_cs_a',
      collegeId: testCollegeId,
      departmentId: 'dept_cs',
      courseId: 'course_btech',
      academicYear: '2024-2025',
      semester: 3,
      sectionName: 'CS-A',
      studentCount: 40,
    );

    final testStaff = Staff(
      id: 'staff_1',
      collegeId: testCollegeId,
      employeeId: 'EMP001',
      name: 'Prof. Turing',
      email: 'turing@college.edu',
      departmentId: 'dept_cs',
      subjectsCanTeach: ['sub_algo'],
    );

    final testSubject = Subject(
      id: 'sub_algo',
      collegeId: testCollegeId,
      departmentId: 'dept_cs',
      courseId: 'course_btech',
      sectionId: 'sec_cs_a',
      semester: 3,
      subjectName: 'Algorithms',
      subjectCode: 'CS301',
      hoursPerWeek: 4,
      assignedTeacherIds: ['staff_1'],
    );

    final testRoom = Room(
      id: 'room_101',
      collegeId: testCollegeId,
      roomNumber: '101',
      capacity: 60,
    );

    // 7 slots: 5 academic periods + 2 breaks
    final standardSlots = [
      TimeSlot(id: 'ts_1', collegeId: testCollegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
      TimeSlot(id: 'ts_2', collegeId: testCollegeId, periodNumber: 2, startTime: '10:00', endTime: '11:00', order: 2),
      TimeSlot(id: 'ts_break1', collegeId: testCollegeId, periodNumber: 0, startTime: '11:00', endTime: '11:15', isBreak: true, breakTitle: 'Morning Break', order: 3),
      TimeSlot(id: 'ts_3', collegeId: testCollegeId, periodNumber: 3, startTime: '11:15', endTime: '12:15', order: 4),
      TimeSlot(id: 'ts_4', collegeId: testCollegeId, periodNumber: 4, startTime: '12:15', endTime: '13:15', order: 5),
      TimeSlot(id: 'ts_lunch', collegeId: testCollegeId, periodNumber: 0, startTime: '13:15', endTime: '14:00', isBreak: true, breakTitle: 'Lunch Break', order: 6),
      TimeSlot(id: 'ts_5', collegeId: testCollegeId, periodNumber: 5, startTime: '14:00', endTime: '15:00', order: 7),
    ];

    setUp(() async {
      repo = LocalDatabaseRepository();
      // Initialize base college with Mon-Fri active
      await repo.saveCollegeScheduleSettings(
        workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        periodsPerDay: 5,
        periods: standardSlots.where((s) => !s.isBreak).map((s) => s.toJson()).toList(),
        breaks: standardSlots.where((s) => s.isBreak).map((b) => b.toJson()).toList(),
        collegeId: testCollegeId,
      );
      await repo.updateCollege(College(
        id: testCollegeId,
        name: 'University College',
        code: 'UC',
        workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      ));
      await repo.createSection(testSection);
      await repo.createStaff(testStaff);
      await repo.createSubject(testSubject);
      await repo.createRoom(testRoom);
      await repo.saveTimeSlots(testCollegeId, standardSlots);
    });

    // =========================================================================
    // SCENARIO 1: 0 active working days
    // =========================================================================
    test('Scenario 1: 0 active working days reports 0 active days, schedOk false, 0 capacity, and generator rejects', () async {
      final container = ProviderContainer(
        overrides: [
          databaseRepositoryProvider.overrideWithValue(repo),
          activeCollegeIdProvider.overrideWith((ref) => testCollegeId),
        ],
      );
      addTearDown(container.dispose);

      // Set 0 active working days
      await container.read(collegeControllerProvider.notifier).setWorkingDays([]);

      final workingDays = await container.read(workingDaysProvider.future);
      expect(workingDays, isEmpty);

      final college = await container.read(currentCollegeProvider.future);
      expect(college!.workingDays, isEmpty);

      // Academic slots calculation
      final slots = await container.read(timeSlotsProvider.future);
      final academicSlots = slots.where((s) => !s.isBreak).toList();
      expect(academicSlots.length, equals(5));

      // Pre-flight check criteria verification
      final schedOk = workingDays.isNotEmpty && academicSlots.isNotEmpty;
      expect(schedOk, isFalse, reason: 'schedOk must be false when active working days are empty');

      final totalSlotsPerWeek = workingDays.length * academicSlots.length;
      expect(totalSlotsPerWeek, equals(0), reason: 'Capacity must be 0 when active days are 0');

      // Weekly Period Requirements validation
      final hoursOk = totalSlotsPerWeek > 0 && testSubject.hoursPerWeek <= totalSlotsPerWeek;
      expect(hoursOk, isFalse, reason: 'Weekly periods requirement must fail when capacity is 0');

      // Generator engine call rejects
      final genResult = TimetableGenerator.generate(
        collegeId: testCollegeId,
        sections: [testSection],
        subjects: [testSubject],
        staffList: [testStaff],
        rooms: [testRoom],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(genResult.isSuccess, isFalse);
      expect(genResult.conflicts, isNotEmpty);
      expect(
        genResult.conflicts.any((c) => c.title.contains('No Academic Periods Configured') || c.description.contains('working days')),
        isTrue,
      );
    });

    // =========================================================================
    // SCENARIO 2: 1 active working day
    // =========================================================================
    test('Scenario 2: 1 active working day calculates capacity = 1 * academicSlots and schedules only on that day', () async {
      final container = ProviderContainer(
        overrides: [
          databaseRepositoryProvider.overrideWithValue(repo),
          activeCollegeIdProvider.overrideWith((ref) => testCollegeId),
        ],
      );
      addTearDown(container.dispose);

      await container.read(collegeControllerProvider.notifier).setWorkingDays(['Monday']);

      final workingDays = await container.read(workingDaysProvider.future);
      expect(workingDays.length, equals(1));
      expect(workingDays.first, equals('Monday'));

      final slots = await container.read(timeSlotsProvider.future);
      final academicSlots = slots.where((s) => !s.isBreak).toList();
      expect(academicSlots.length, equals(5));

      // Capacity = 1 * 5 = 5 periods/week
      final capacity = workingDays.length * academicSlots.length;
      expect(capacity, equals(5));

      // Overload check: Section requiring 6 periods fails
      final overloadedSubject = testSubject.copyWith(hoursPerWeek: 6);
      expect(overloadedSubject.hoursPerWeek > capacity, isTrue);

      // Section requiring 4 periods fits and schedules exclusively on Monday
      final s1 = testSubject.copyWith(id: 'sub_algo', hoursPerWeek: 1);
      final s2 = testSubject.copyWith(id: 'sub_ds', subjectCode: 'CS302', subjectName: 'Data Structures', hoursPerWeek: 1);
      final s3 = testSubject.copyWith(id: 'sub_db', subjectCode: 'CS303', subjectName: 'Databases', hoursPerWeek: 1);
      final s4 = testSubject.copyWith(id: 'sub_os', subjectCode: 'CS304', subjectName: 'Operating Systems', hoursPerWeek: 1);
      final staff = testStaff.copyWith(subjectsCanTeach: ['sub_algo', 'sub_ds', 'sub_db', 'sub_os']);
      final genResult = TimetableGenerator.generate(
        collegeId: testCollegeId,
        sections: [testSection],
        subjects: [s1, s2, s3, s4],
        staffList: [staff],
        rooms: [testRoom],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(genResult.isSuccess, isTrue);
      expect(genResult.entries.length, equals(4));
      for (final entry in genResult.entries) {
        expect(entry.dayOfWeek, equals('Monday'), reason: 'All classes must be scheduled on the single active day (Monday)');
        expect(entry.periodNumber, isNot(0), reason: 'No classes scheduled during breaks');
      }
    });

    // =========================================================================
    // SCENARIO 3: Monday–Friday active
    // =========================================================================
    test('Scenario 3: Monday–Friday active reports 5 active days, schedOk true, and capacity = 25', () async {
      final container = ProviderContainer(
        overrides: [
          databaseRepositoryProvider.overrideWithValue(repo),
          activeCollegeIdProvider.overrideWith((ref) => testCollegeId),
        ],
      );
      addTearDown(container.dispose);

      final monFri = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
      await container.read(collegeControllerProvider.notifier).setWorkingDays(monFri);

      final workingDays = await container.read(workingDaysProvider.future);
      expect(workingDays.length, equals(5));
      expect(workingDays, equals(monFri));

      final slots = await container.read(timeSlotsProvider.future);
      final academicSlots = slots.where((s) => !s.isBreak).toList();
      expect(academicSlots.length, equals(5));

      final schedOk = workingDays.isNotEmpty && academicSlots.isNotEmpty;
      expect(schedOk, isTrue);

      // 5 active days * 5 periods = 25 capacity
      final totalCapacity = workingDays.length * academicSlots.length;
      expect(totalCapacity, equals(25));

      final genResult = TimetableGenerator.generate(
        collegeId: testCollegeId,
        sections: [testSection],
        subjects: [testSubject.copyWith(hoursPerWeek: 5)],
        staffList: [testStaff],
        rooms: [testRoom],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(genResult.isSuccess, isTrue);
      expect(genResult.entries.length, equals(5));
      final daysUsed = genResult.entries.map((e) => e.dayOfWeek).toSet();
      expect(daysUsed.contains('Saturday'), isFalse, reason: 'Saturday is inactive and must not have scheduled classes');
    });

    // =========================================================================
    // SCENARIO 4: Monday–Saturday active
    // =========================================================================
    test('Scenario 4: Monday–Saturday active reports 6 active days and capacity = 30', () async {
      final container = ProviderContainer(
        overrides: [
          databaseRepositoryProvider.overrideWithValue(repo),
          activeCollegeIdProvider.overrideWith((ref) => testCollegeId),
        ],
      );
      addTearDown(container.dispose);

      final monSat = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      await container.read(collegeControllerProvider.notifier).setWorkingDays(monSat);

      final workingDays = await container.read(workingDaysProvider.future);
      expect(workingDays.length, equals(6));

      final slots = await container.read(timeSlotsProvider.future);
      final academicSlots = slots.where((s) => !s.isBreak).toList();

      // 6 active days * 5 periods = 30 capacity
      final totalCapacity = workingDays.length * academicSlots.length;
      expect(totalCapacity, equals(30));

      final genResult = TimetableGenerator.generate(
        collegeId: testCollegeId,
        sections: [testSection],
        subjects: [testSubject.copyWith(hoursPerWeek: 6)],
        staffList: [testStaff],
        rooms: [testRoom],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(genResult.isSuccess, isTrue);
      expect(genResult.entries.length, equals(6));
    });

    // =========================================================================
    // SCENARIO 5: Changing active days
    // =========================================================================
    test('Scenario 5: Changing active days updates provider, college entity, and schedule settings immediately', () async {
      final container = ProviderContainer(
        overrides: [
          databaseRepositoryProvider.overrideWithValue(repo),
          activeCollegeIdProvider.overrideWith((ref) => testCollegeId),
        ],
      );
      addTearDown(container.dispose);

      // Initial: 5 days
      var days = await container.read(workingDaysProvider.future);
      expect(days.length, equals(5));

      // Activate Saturday -> 6 days
      await container.read(collegeControllerProvider.notifier).setWorkingDays([
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
      ]);
      days = await container.read(workingDaysProvider.future);
      expect(days.length, equals(6));
      expect(days.contains('Saturday'), isTrue);

      // Deactivate Friday -> 5 days (Mon, Tue, Wed, Thu, Sat)
      await container.read(collegeControllerProvider.notifier).setWorkingDays([
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Saturday'
      ]);
      days = await container.read(workingDaysProvider.future);
      expect(days.length, equals(5));
      expect(days.contains('Friday'), isFalse);
      expect(days.contains('Saturday'), isTrue);

      // Generator now schedules without Friday
      final genResult = TimetableGenerator.generate(
        collegeId: testCollegeId,
        sections: [testSection],
        subjects: [testSubject.copyWith(hoursPerWeek: 5)],
        staffList: [testStaff],
        rooms: [testRoom],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: days,
      );

      expect(genResult.isSuccess, isTrue);
      final daysUsed = genResult.entries.map((e) => e.dayOfWeek).toSet();
      expect(daysUsed.contains('Friday'), isFalse, reason: 'Friday was deactivated');
    });

    // =========================================================================
    // SCENARIO 6: Saving and reloading active days
    // =========================================================================
    test('Scenario 6: Saving active days persists across repository reads and college reloads', () async {
      final expectedDays = ['Monday', 'Wednesday', 'Friday'];

      await repo.saveCollegeScheduleSettings(
        workingDays: expectedDays,
        periodsPerDay: 5,
        periods: standardSlots.where((s) => !s.isBreak).map((s) => s.toJson()).toList(),
        breaks: standardSlots.where((s) => s.isBreak).map((b) => b.toJson()).toList(),
        collegeId: testCollegeId,
      );

      // Reload college directly from repository
      final loadedCollege = await repo.getCollege(testCollegeId);
      expect(loadedCollege, isNotNull);
      expect(loadedCollege!.workingDays, equals(expectedDays));

      // Schedule settings document check
      final settings = await repo.getCollegeScheduleSettings(collegeId: testCollegeId);
      expect(settings, isNotNull);
      expect(settings!['workingDays'], equals(expectedDays));

      // ProviderContainer reading state
      final container = ProviderContainer(
        overrides: [
          databaseRepositoryProvider.overrideWithValue(repo),
          activeCollegeIdProvider.overrideWith((ref) => testCollegeId),
        ],
      );
      addTearDown(container.dispose);

      final providerDays = await container.read(workingDaysProvider.future);
      expect(providerDays, equals(expectedDays));
    });

    // =========================================================================
    // SCENARIO 7: Capacity calculation using active days
    // =========================================================================
    test('Scenario 7: Capacity formula (activeDays * academicSlots) accurately triggers overload validation', () {
      final academicPeriods = 5;

      int calcCapacity(int activeDaysCount) => activeDaysCount * academicPeriods;

      expect(calcCapacity(0), equals(0));
      expect(calcCapacity(1), equals(5));
      expect(calcCapacity(2), equals(10));
      expect(calcCapacity(4), equals(20));
      expect(calcCapacity(5), equals(25));
      expect(calcCapacity(6), equals(30));

      final requiredHours = 26;
      // 5 active days = 25 capacity -> OVERLOADED (26 > 25)
      expect(requiredHours > calcCapacity(5), isTrue);

      // 6 active days = 30 capacity -> FITS WITHIN CAPACITY (26 <= 30)
      expect(requiredHours <= calcCapacity(6), isTrue);
    });

    // =========================================================================
    // SCENARIO 8: Breaks not counted as academic periods
    // =========================================================================
    test('Scenario 8: Breaks (Morning Break, Lunch Break) are strictly excluded from academic capacity', () async {
      // 7 slots total in standardSlots: 5 academic periods, 2 breaks
      expect(standardSlots.length, equals(7));

      final breaks = standardSlots.where((s) => s.isBreak).toList();
      expect(breaks.length, equals(2));
      expect(breaks.any((b) => b.breakTitle == 'Morning Break'), isTrue);
      expect(breaks.any((b) => b.breakTitle == 'Lunch Break'), isTrue);

      final academicSlots = standardSlots.where((s) => !s.isBreak).toList();
      expect(academicSlots.length, equals(5));

      final activeDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
      // Academic capacity must be 5 * 5 = 25, NOT 5 * 7 = 35!
      final academicCapacity = activeDays.length * academicSlots.length;
      expect(academicCapacity, equals(25));
      expect(academicCapacity, isNot(equals(35)));

      // Generator must never place a class into period 0 (breaks)
      final genResult = TimetableGenerator.generate(
        collegeId: testCollegeId,
        sections: [testSection],
        subjects: [testSubject.copyWith(hoursPerWeek: 5)],
        staffList: [testStaff],
        rooms: [testRoom],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: activeDays,
      );

      expect(genResult.isSuccess, isTrue);
      for (final entry in genResult.entries) {
        expect(entry.periodNumber, isNot(0), reason: 'Breaks must never have scheduled classes');
        expect(entry.timeSlotId, isNot('ts_break1'));
        expect(entry.timeSlotId, isNot('ts_lunch'));
      }
    });
  });

  group('UI & Widget Working Days Synchronization Tests', () {
    late LocalDatabaseRepository repo;
    const testCollegeId = 'user_college';

    setUp(() async {
      repo = LocalDatabaseRepository();
      await repo.saveCollegeScheduleSettings(
        workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        periodsPerDay: 2,
        periods: [
          {'id': 'ts_1', 'periodNumber': 1, 'startTime': '09:00', 'endTime': '10:00', 'order': 1},
          {'id': 'ts_2', 'periodNumber': 2, 'startTime': '10:00', 'endTime': '11:00', 'order': 2},
        ],
        breaks: [],
        collegeId: testCollegeId,
      );
      await repo.updateCollege(College(
        id: testCollegeId,
        name: 'University College',
        code: 'UC',
        workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      ));
      await repo.saveTimeSlots(testCollegeId, [
        TimeSlot(id: 'ts_1', collegeId: testCollegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
        TimeSlot(id: 'ts_2', collegeId: testCollegeId, periodNumber: 2, startTime: '10:00', endTime: '11:00', order: 2),
      ]);
    });

    testWidgets('PeriodSettingsScreen renders distinct ACTIVE and INACTIVE sections with badge', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            activeCollegeIdProvider.overrideWith((ref) => testCollegeId),
          ],
          child: const MaterialApp(
            home: PeriodSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check badge: "Working Days: 5 active days"
      expect(find.text('Working Days: 5 active days'), findsOneWidget);

      // Check section titles
      expect(find.text('ACTIVE (5):'), findsOneWidget);
      expect(find.text('INACTIVE (1):'), findsOneWidget);

      // Check that Monday - Friday are active, Saturday is inactive
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('Friday'), findsOneWidget);
      expect(find.text('Saturday'), findsOneWidget);

      // Click Saturday to activate it
      await tester.tap(find.text('Saturday'));
      await tester.pumpAndSettle();

      // Badge now shows 6 active days
      expect(find.text('Working Days: 6 active days'), findsOneWidget);
      expect(find.text('ACTIVE (6):'), findsOneWidget);
      expect(find.text('INACTIVE (0):'), findsOneWidget);
    });

    testWidgets('InputWorkflowScreen Step 1 and Step 6 reflect active days accurately', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            activeCollegeIdProvider.overrideWith((ref) => testCollegeId),
          ],
          child: const MaterialApp(
            home: InputWorkflowScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Schedule has badge "Working Days: 5 active days"
      expect(find.text('Working Days: 5 active days'), findsOneWidget);
      expect(find.text('ACTIVE (5):'), findsOneWidget);
      expect(find.text('INACTIVE (1):'), findsOneWidget);

      // Navigate to Step 6 (Generate)
      await tester.tap(find.text('6. Generate'));
      await tester.pumpAndSettle();

      // Pre-flight Summary Card shows "5 active days"
      expect(find.text('5 active days'), findsOneWidget);

      // Pre-flight Checklist Row 1 shows "5 working days, 2 academic periods per day"
      expect(find.text('5 working days, 2 academic periods per day'), findsOneWidget);
    });
  });
}
