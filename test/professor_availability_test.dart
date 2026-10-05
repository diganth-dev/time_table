import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/features/staff/screens/staff_list_screen.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/services.dart';

void main() {
  group('Professor Availability Model & Parsing Tests', () {
    test('parseTimeToMinutes parses various standard formats correctly', () {
      expect(UnavailableTime.parseTimeToMinutes('09:00'), 9 * 60);
      expect(UnavailableTime.parseTimeToMinutes('9:00'), 9 * 60);
      expect(UnavailableTime.parseTimeToMinutes('9:00 AM'), 9 * 60);
      expect(UnavailableTime.parseTimeToMinutes('9am'), 9 * 60);
      expect(UnavailableTime.parseTimeToMinutes('9'), 9 * 60);
      expect(UnavailableTime.parseTimeToMinutes('10:00'), 10 * 60);
      expect(UnavailableTime.parseTimeToMinutes('10'), 10 * 60);
      expect(UnavailableTime.parseTimeToMinutes('14:00'), 14 * 60);
      expect(UnavailableTime.parseTimeToMinutes('14'), 14 * 60);
      expect(UnavailableTime.parseTimeToMinutes('2:00 PM'), 14 * 60);
      expect(UnavailableTime.parseTimeToMinutes('2pm'), 14 * 60);
      // Single digit college hours 1..6 default to PM (13:00..18:00)
      expect(UnavailableTime.parseTimeToMinutes('2'), 14 * 60);
      expect(UnavailableTime.parseTimeToMinutes('3:00'), 15 * 60);
      expect(UnavailableTime.parseTimeToMinutes('3'), 15 * 60);
    });

    test('validateTimeRange accurately validates invalid and valid time ranges', () {
      expect(UnavailableTime.validateTimeRange('', '10:00'), 'Please enter a "From" time.');
      expect(UnavailableTime.validateTimeRange('09:00', ''), 'Please enter a "To" time.');
      expect(UnavailableTime.validateTimeRange('10:00', '09:00'), '"From" time must be earlier than "To" time.');
      expect(UnavailableTime.validateTimeRange('10:00', '10:00'), '"From" time must be earlier than "To" time.');
      expect(UnavailableTime.validateTimeRange('2:00', '1:00'), '"From" time must be earlier than "To" time.');
      expect(UnavailableTime.validateTimeRange('abc', '10:00'), contains('Invalid "From" time format'));
      expect(UnavailableTime.validateTimeRange('09:00', 'xyz'), contains('Invalid "To" time format'));

      // Valid ranges return null (no error)
      expect(UnavailableTime.validateTimeRange('09:00', '10:00'), isNull);
      expect(UnavailableTime.validateTimeRange('9:00 AM', '10:00 AM'), isNull);
      expect(UnavailableTime.validateTimeRange('14:00', '15:00'), isNull);
      expect(UnavailableTime.validateTimeRange('2:00', '3:00'), isNull);
    });

    test('Staff backward compatibility: loads and serializes correctly without unavailableTimes', () {
      final json = {
        'id': 'prof_legacy',
        'collegeId': 'college_1',
        'employeeId': 'EMP099',
        'name': 'Legacy Prof',
        'email': 'legacy@college.edu',
        'departmentId': 'dept_1',
      };

      final staff = Staff.fromJson(json);
      expect(staff.unavailableTimes, isEmpty);

      // Professor with no unavailable periods is eligible for all slots
      final slot = TimeSlot(
        id: 'slot_1',
        collegeId: 'college_1',
        periodNumber: 1,
        startTime: '09:00',
        endTime: '10:00',
        order: 1,
      );
      expect(staff.isUnavailableDuring(day: 'Monday', slot: slot), isFalse);

      final serialized = staff.toJson();
      expect(serialized['unavailableTimes'], isEmpty);
    });

    test('Staff with unavailableTimes correctly detects unavailable day and slot', () {
      final staff = Staff(
        id: 'prof_ravi',
        collegeId: 'college_1',
        employeeId: 'EMP001',
        name: 'Dr. Ravi',
        email: 'ravi@college.edu',
        departmentId: 'dept_1',
        unavailableTimes: [
          const UnavailableTime(dayOfWeek: 'Monday', startTime: '9:00', endTime: '10:00'),
          const UnavailableTime(dayOfWeek: 'Monday', startTime: '2:00', endTime: '3:00'),
        ],
      );

      final slotMonday9to10 = TimeSlot(
        id: 'ts_1',
        collegeId: 'college_1',
        periodNumber: 1,
        startTime: '09:00',
        endTime: '10:00',
        order: 1,
      );
      final slotMonday10to11 = TimeSlot(
        id: 'ts_2',
        collegeId: 'college_1',
        periodNumber: 2,
        startTime: '10:00',
        endTime: '11:00',
        order: 2,
      );
      final slotMonday2to3 = TimeSlot(
        id: 'ts_5',
        collegeId: 'college_1',
        periodNumber: 5,
        startTime: '14:00',
        endTime: '15:00',
        order: 5,
      );
      final slotTuesday9to10 = TimeSlot(
        id: 'ts_1_tue',
        collegeId: 'college_1',
        periodNumber: 1,
        startTime: '09:00',
        endTime: '10:00',
        order: 1,
      );

      // Unavailable on Monday 9-10 and Monday 2-3
      expect(staff.isUnavailableDuring(day: 'Monday', slot: slotMonday9to10), isTrue);
      expect(staff.isUnavailableDuring(day: 'Monday', slot: slotMonday2to3), isTrue);

      // Available on Monday 10-11
      expect(staff.isUnavailableDuring(day: 'Monday', slot: slotMonday10to11), isFalse);

      // Available on Tuesday 9-10
      expect(staff.isUnavailableDuring(day: 'Tuesday', slot: slotTuesday9to10), isFalse);
    });
  });

  group('Timetable Generator Professor Availability Integration Tests', () {
    const collegeId = 'test_college';
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    final timeSlots = [
      TimeSlot(id: 'ts_1', collegeId: collegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
      TimeSlot(id: 'ts_2', collegeId: collegeId, periodNumber: 2, startTime: '10:00', endTime: '11:00', order: 2),
      TimeSlot(id: 'ts_3', collegeId: collegeId, periodNumber: 3, startTime: '11:00', endTime: '12:00', order: 3),
      TimeSlot(id: 'ts_lunch', collegeId: collegeId, periodNumber: 0, startTime: '12:00', endTime: '13:00', order: 4, isBreak: true, breakTitle: 'Lunch'),
      TimeSlot(id: 'ts_4', collegeId: collegeId, periodNumber: 4, startTime: '13:00', endTime: '14:00', order: 5),
      TimeSlot(id: 'ts_5', collegeId: collegeId, periodNumber: 5, startTime: '14:00', endTime: '15:00', order: 6),
      TimeSlot(id: 'ts_6', collegeId: collegeId, periodNumber: 6, startTime: '15:00', endTime: '16:00', order: 7),
    ];

    final rooms = [
      Room(id: 'r_101', collegeId: collegeId, roomNumber: 'Room 101', building: 'Block A', floor: 1, capacity: 60, roomType: 'Classroom'),
    ];

    final secCSE = Section(
      id: 'sec_cse_a',
      collegeId: collegeId,
      departmentId: 'dept_cse',
      courseId: 'btech_cse',
      academicYear: '2026-2027',
      semester: 3,
      sectionName: 'CSE-A',
      studentCount: 40,
    );

    test('Primary Scenario: Dr. Ravi, DBMS (3 hrs/wk), Unavailable Monday 9-10 & Monday 2-3 is NEVER scheduled in those slots', () {
      final profRavi = Staff(
        id: 'prof_ravi',
        collegeId: collegeId,
        employeeId: 'EMP001',
        name: 'Dr. Ravi',
        email: 'ravi@college.edu',
        departmentId: 'dept_cse',
        designation: 'Associate Professor',
        role: 'faculty',
        status: 'active',
        subjectsCanTeach: ['sub_dbms'],
        unavailableTimes: [
          const UnavailableTime(dayOfWeek: 'Monday', startTime: '09:00', endTime: '10:00'),
          const UnavailableTime(dayOfWeek: 'Monday', startTime: '14:00', endTime: '15:00'),
        ],
      );

      final subjDBMS = Subject(
        id: 'sub_dbms',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'btech_cse',
        sectionId: secCSE.id,
        semester: 3,
        subjectName: 'Database Management Systems',
        subjectCode: 'CS301',
        hoursPerWeek: 3,
        assignedTeacherIds: [profRavi.id],
      );

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secCSE],
        subjects: [subjDBMS],
        staffList: [profRavi],
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: days,
        targetSectionId: secCSE.id,
      );

      expect(result.isSuccess, isTrue);
      expect(result.conflicts, isEmpty);
      expect(result.entries.length, 3);

      for (final entry in result.entries) {
        expect(entry.teacherId, profRavi.id);
        expect(entry.subjectId, subjDBMS.id);

        // Verification 1: NEVER on Monday Period 1 (09:00-10:00)
        final isMondayPeriod1 = entry.dayOfWeek == 'Monday' && entry.periodNumber == 1;
        expect(isMondayPeriod1, isFalse, reason: 'Dr. Ravi must not be scheduled on Monday 9-10');

        // Verification 2: NEVER on Monday Period 5 (14:00-15:00)
        final isMondayPeriod5 = entry.dayOfWeek == 'Monday' && entry.periodNumber == 5;
        expect(isMondayPeriod5, isFalse, reason: 'Dr. Ravi must not be scheduled on Monday 2-3');

        // Verification 3: Never during lunch break (period 0)
        expect(entry.periodNumber, isNot(0));
      }

      // Conflict validator also verifies with 0 conflicts
      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: result.entries,
        sections: [secCSE],
        subjects: [subjDBMS],
        staffList: [profRavi],
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
      );
      expect(validation.isValid, isTrue);
      expect(validation.hardConflicts, isEmpty);
    });

    test('Multiple unavailable periods across different days are strictly avoided', () {
      final profRavi = Staff(
        id: 'prof_ravi',
        collegeId: collegeId,
        employeeId: 'EMP001',
        name: 'Dr. Ravi',
        email: 'ravi@college.edu',
        departmentId: 'dept_cse',
        subjectsCanTeach: ['sub_dbms'],
        unavailableTimes: [
          const UnavailableTime(dayOfWeek: 'Monday', startTime: '09:00', endTime: '10:00'),
          const UnavailableTime(dayOfWeek: 'Tuesday', startTime: '10:00', endTime: '11:00'),
          const UnavailableTime(dayOfWeek: 'Wednesday', startTime: '14:00', endTime: '15:00'),
        ],
      );

      final subjDBMS = Subject(
        id: 'sub_dbms',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'btech_cse',
        sectionId: secCSE.id,
        semester: 3,
        subjectName: 'DBMS',
        subjectCode: 'CS301',
        hoursPerWeek: 4,
        assignedTeacherIds: [profRavi.id],
      );

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secCSE],
        subjects: [subjDBMS],
        staffList: [profRavi],
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: days,
      );

      expect(result.isSuccess, isTrue);
      expect(result.entries.length, 4);

      for (final e in result.entries) {
        if (e.dayOfWeek == 'Monday') {
          expect(e.periodNumber, isNot(1));
        }
        if (e.dayOfWeek == 'Tuesday') {
          expect(e.periodNumber, isNot(2));
        }
        if (e.dayOfWeek == 'Wednesday') {
          expect(e.periodNumber, isNot(5));
        }
      }
    });

    test('Editing/removing unavailable period allows professor to be scheduled in that slot', () {
      // 1. Initially unavailable on Monday 14:00 - 15:00
      final profInitial = Staff(
        id: 'prof_ravi',
        collegeId: collegeId,
        employeeId: 'EMP001',
        name: 'Dr. Ravi',
        email: 'ravi@college.edu',
        departmentId: 'dept_cse',
        subjectsCanTeach: ['sub_dbms'],
        unavailableTimes: [
          const UnavailableTime(dayOfWeek: 'Monday', startTime: '09:00', endTime: '10:00'),
          const UnavailableTime(dayOfWeek: 'Monday', startTime: '14:00', endTime: '15:00'),
        ],
      );

      // 2. Professor is edited to remove the Monday 14:00-15:00 restriction
      final profUpdated = profInitial.copyWith(
        unavailableTimes: [
          const UnavailableTime(dayOfWeek: 'Monday', startTime: '09:00', endTime: '10:00'),
        ],
      );
      expect(profUpdated.unavailableTimes.length, 1);

      // Now verify slot 5 (14:00-15:00) on Monday is available for profUpdated
      final slot5 = timeSlots.firstWhere((s) => s.periodNumber == 5);
      expect(profUpdated.isUnavailableDuring(day: 'Monday', slot: slot5), isFalse);
    });

    test('ConflictValidator flags hard conflict if an entry violates professor unavailable times', () {
      final profRavi = Staff(
        id: 'prof_ravi',
        collegeId: collegeId,
        employeeId: 'EMP001',
        name: 'Dr. Ravi',
        email: 'ravi@college.edu',
        departmentId: 'dept_cse',
        unavailableTimes: [
          const UnavailableTime(dayOfWeek: 'Monday', startTime: '09:00', endTime: '10:00'),
        ],
      );

      final subjDBMS = Subject(
        id: 'sub_dbms',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'btech_cse',
        sectionId: secCSE.id,
        semester: 3,
        subjectName: 'DBMS',
        subjectCode: 'CS301',
        hoursPerWeek: 1,
        assignedTeacherIds: [profRavi.id],
      );

      // Manually create an entry on Monday Period 1 (09:00 - 10:00)
      final conflictingEntry = TimetableEntry(
        id: 'entry_conflict',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts_1',
        sectionId: secCSE.id,
        subjectId: subjDBMS.id,
        teacherId: profRavi.id,
        roomId: rooms.first.id,
        status: 'draft',
      );

      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: [conflictingEntry],
        sections: [secCSE],
        subjects: [subjDBMS],
        staffList: [profRavi],
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
      );

      expect(validation.isValid, isFalse);
      expect(validation.hardConflicts.any((c) => c.type == 'availabilityConflict'), isTrue);
      expect(validation.hardConflicts.first.description, contains('Dr. Ravi is marked unavailable on Monday'));
    });
  });

  group('StaffAddEditDialog UI & Enter Key Tests', () {
    final testDepts = [
      Department(id: 'dept_cse', collegeId: 'college_1', name: 'Computer Science', code: 'CSE'),
    ];

    final testTimeSlots = [
      TimeSlot(id: 'ts_1', collegeId: 'college_1', periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
      TimeSlot(id: 'ts_2', collegeId: 'college_1', periodNumber: 2, startTime: '10:00', endTime: '11:00', order: 2),
      TimeSlot(id: 'ts_b1', collegeId: 'college_1', periodNumber: 0, startTime: '11:00', endTime: '11:15', isBreak: true, breakTitle: 'Morning Break', order: 3),
      TimeSlot(id: 'ts_3', collegeId: 'college_1', periodNumber: 3, startTime: '11:15', endTime: '12:15', order: 4),
      TimeSlot(id: 'ts_4', collegeId: 'college_1', periodNumber: 4, startTime: '12:15', endTime: '13:15', order: 5),
      TimeSlot(id: 'ts_lunch', collegeId: 'college_1', periodNumber: 0, startTime: '13:15', endTime: '14:00', isBreak: true, breakTitle: 'Lunch Break', order: 6),
      TimeSlot(id: 'ts_5', collegeId: 'college_1', periodNumber: 5, startTime: '14:00', endTime: '15:00', order: 7),
      TimeSlot(id: 'ts_6', collegeId: 'college_1', periodNumber: 6, startTime: '15:00', endTime: '16:00', order: 8),
    ];

    testWidgets('Dialog renders all required UX labels', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffAddEditDialog(
              depts: testDepts,
              collegeId: 'college_1',
              timeSlots: testTimeSlots,
              onSave: (_) async {},
            ),
          ),
        ),
      );

      // Verify clear beginner-friendly labels required by prompt:
      // * Professor Name
      // * Subjects They Can Teach
      // * Professor Availability
      // * Add Unavailable Time
      // * Day
      // * From
      // * To
      expect(find.text('Professor Name'), findsOneWidget);
      expect(find.text('Subjects They Can Teach'), findsOneWidget);
      expect(find.text('Professor Availability'), findsOneWidget);
      expect(find.text('Add Unavailable Time'), findsOneWidget);
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('From'), findsOneWidget);
      expect(find.text('To'), findsOneWidget);
    });

    testWidgets('Adding invalid time range displays friendly validation error without adding', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffAddEditDialog(
              depts: testDepts,
              collegeId: 'college_1',
              timeSlots: testTimeSlots,
              onSave: (_) async {},
            ),
          ),
        ),
      );

      // Select From: Period 2 — 10:00 AM and To: Period 1 — 9:00 AM (invalid: From > To)
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'From'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Period 2 — 10:00 AM').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'To'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Period 1 — 9:00 AM').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Add Unavailable Time'));
      await tester.tap(find.text('Add Unavailable Time'));
      await tester.pumpAndSettle();

      // Error message should be visible
      expect(find.text('"From" time must be earlier than "To" time.'), findsOneWidget);
      // No chips should be added
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('Adding unavailable time slots, deleting, and saving works correctly', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Staff? savedStaff;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffAddEditDialog(
              depts: testDepts,
              collegeId: 'college_1',
              timeSlots: testTimeSlots,
              onSave: (s) async {
                savedStaff = s;
              },
            ),
          ),
        ),
      );

      // Fill Professor Name
      await tester.enterText(find.widgetWithText(TextField, 'Professor Name'), 'Dr. Ravi');

      // Select From: Period 1 — 9:00 AM & To: Period 2 — 10:00 AM
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'From'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Period 1 — 9:00 AM').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'To'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Period 2 — 10:00 AM').last);
      await tester.pumpAndSettle();

      final addButton = find.text('Add Unavailable Time');
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Unavailable time chip should now be visible
      expect(find.text('Monday: 09:00 - 10:00'), findsOneWidget);
      // Dialog was NOT submitted prematurely
      expect(savedStaff, isNull);

      // Add a second unavailable slot: Monday 14:00 - 15:00 (Period 5 to Period 6)
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'From'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Period 5 — 2:00 PM').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'To'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Period 6 — 3:00 PM').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Both chips should now be visible
      expect(find.text('Monday: 09:00 - 10:00'), findsOneWidget);
      expect(find.text('Monday: 14:00 - 15:00'), findsOneWidget);

      // Delete one of the chips
      final firstDeleteIcon = find.descendant(
        of: find.widgetWithText(Chip, 'Monday: 09:00 - 10:00'),
        matching: find.byIcon(Icons.close),
      );
      await tester.ensureVisible(firstDeleteIcon);
      await tester.tap(firstDeleteIcon);
      await tester.pumpAndSettle();

      // First chip should be deleted, second chip remains
      expect(find.text('Monday: 09:00 - 10:00'), findsNothing);
      expect(find.text('Monday: 14:00 - 15:00'), findsOneWidget);

      // Now save the professor
      final saveButton = find.text('Save & Close');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(savedStaff, isNotNull);
      expect(savedStaff!.name, 'Dr. Ravi');
      expect(savedStaff!.unavailableTimes.length, 1);
      expect(savedStaff!.unavailableTimes.first.startTime, '14:00');
      expect(savedStaff!.unavailableTimes.first.endTime, '15:00');
    });

    testWidgets('Optional availability: professor saved with 0 unavailable periods has empty list', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Staff? savedStaff;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffAddEditDialog(
              depts: testDepts,
              collegeId: 'college_1',
              onSave: (s) async {
                savedStaff = s;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Professor Name'), 'Prof. Anita');
      final saveButton = find.text('Save & Close');
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(savedStaff, isNotNull);
      expect(savedStaff!.name, 'Prof. Anita');
      // No unavailable times added, professor is eligible for all slots
      expect(savedStaff!.unavailableTimes, isEmpty);
    });

    testWidgets('Adding unavailable time does not submit dialog prematurely', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Staff? savedStaff;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffAddEditDialog(
              depts: testDepts,
              collegeId: 'college_1',
              timeSlots: testTimeSlots,
              onSave: (s) async {
                savedStaff = s;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'From'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Period 1 — 9:00 AM').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'To'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Period 2 — 10:00 AM').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Unavailable Time'));
      await tester.pumpAndSettle();

      expect(find.text('Monday: 09:00 - 10:00'), findsOneWidget);
      expect(savedStaff, isNull);
    });

    testWidgets('From and To dropdowns show College Schedule period timings clearly and disallow arbitrary text', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffAddEditDialog(
              depts: testDepts,
              collegeId: 'college_1',
              timeSlots: testTimeSlots,
              onSave: (_) async {},
            ),
          ),
        ),
      );

      // Verify From and To are DropdownButtonFormField widgets, not TextFields
      expect(find.widgetWithText(TextField, 'From'), findsNothing);
      expect(find.widgetWithText(TextField, 'To'), findsNothing);
      expect(find.widgetWithText(DropdownButtonFormField<String>, 'From'), findsOneWidget);
      expect(find.widgetWithText(DropdownButtonFormField<String>, 'To'), findsOneWidget);

      // Open From dropdown and verify College Schedule options
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, 'From'));
      await tester.pumpAndSettle();

      expect(find.text('Period 1 — 9:00 AM'), findsWidgets);
      expect(find.text('Period 2 — 10:00 AM'), findsWidgets);
      expect(find.text('Morning Break — 11:00 AM'), findsWidgets);
      expect(find.text('Period 3 — 11:15 AM'), findsWidgets);
      expect(find.text('Period 4 — 12:15 PM'), findsWidgets);
      expect(find.text('Lunch Break — 1:15 PM'), findsWidgets);
      expect(find.text('Period 5 — 2:00 PM'), findsWidgets);
      expect(find.text('Period 6 — 3:00 PM'), findsWidgets);
      expect(find.text('Period 6 End — 4:00 PM'), findsWidgets);
    });

    testWidgets('Attempting to add without selecting From or To displays validation error', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffAddEditDialog(
              depts: testDepts,
              collegeId: 'college_1',
              timeSlots: testTimeSlots,
              onSave: (_) async {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add Unavailable Time'));
      await tester.pumpAndSettle();

      expect(find.text('Please select a "From" time.'), findsOneWidget);
    });

    testWidgets('Empty College Schedule slots displays graceful warning when adding', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffAddEditDialog(
              depts: testDepts,
              collegeId: 'college_1',
              timeSlots: const [],
              onSave: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('No schedule'), findsNWidgets(2));

      await tester.tap(find.text('Add Unavailable Time'));
      await tester.pumpAndSettle();

      expect(find.text('No College Schedule timings found. Please configure College Schedule first.'), findsOneWidget);
    });
  });
}
