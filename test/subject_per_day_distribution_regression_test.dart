import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/services.dart';

void main() {
  const collegeId = 'test_college';

  final standardSlots = [
    TimeSlot(id: 'ts_1', collegeId: collegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
    TimeSlot(id: 'ts_2', collegeId: collegeId, periodNumber: 2, startTime: '10:00', endTime: '11:00', order: 2),
    TimeSlot(id: 'ts_break', collegeId: collegeId, periodNumber: 0, startTime: '11:00', endTime: '11:15', order: 3, isBreak: true),
    TimeSlot(id: 'ts_3', collegeId: collegeId, periodNumber: 3, startTime: '11:15', endTime: '12:15', order: 4),
    TimeSlot(id: 'ts_4', collegeId: collegeId, periodNumber: 4, startTime: '12:15', endTime: '13:15', order: 5),
    TimeSlot(id: 'ts_5', collegeId: collegeId, periodNumber: 5, startTime: '14:00', endTime: '15:00', order: 6),
    TimeSlot(id: 'ts_6', collegeId: collegeId, periodNumber: 6, startTime: '15:00', endTime: '16:00', order: 7),
  ];

  final testClassroom = Room(
    id: 'room_101',
    collegeId: collegeId,
    roomNumber: '101',
    capacity: 60,
    roomType: 'Classroom',
  );

  final testLabRoom = Room(
    id: 'room_lab_1',
    collegeId: collegeId,
    roomNumber: 'Lab 1',
    capacity: 60,
    roomType: 'Laboratory',
  );

  final testSectionA = Section(
    id: 'sec_a',
    collegeId: collegeId,
    departmentId: 'dept_cs',
    courseId: 'course_btech',
    academicYear: '2024-2025',
    semester: 3,
    sectionName: 'CS-A',
    studentCount: 40,
  );

  final testSectionB = Section(
    id: 'sec_b',
    collegeId: collegeId,
    departmentId: 'dept_cs',
    courseId: 'course_btech',
    academicYear: '2024-2025',
    semester: 3,
    sectionName: 'CS-B',
    studentCount: 40,
  );

  final testStaffMath = Staff(
    id: 'staff_math',
    collegeId: collegeId,
    employeeId: 'EMP_M',
    name: 'Prof. Gauss',
    email: 'gauss@college.edu',
    departmentId: 'dept_cs',
    subjectsCanTeach: ['sub_maths'],
  );

  final testStaffPhysics = Staff(
    id: 'staff_physics',
    collegeId: collegeId,
    employeeId: 'EMP_P',
    name: 'Prof. Newton',
    email: 'newton@college.edu',
    departmentId: 'dept_cs',
    subjectsCanTeach: ['sub_physics'],
  );

  final testStaffEnglish = Staff(
    id: 'staff_english',
    collegeId: collegeId,
    employeeId: 'EMP_E',
    name: 'Prof. Shakespeare',
    email: 'bard@college.edu',
    departmentId: 'dept_cs',
    subjectsCanTeach: ['sub_english'],
  );

  final testStaffLab = Staff(
    id: 'staff_lab',
    collegeId: collegeId,
    employeeId: 'EMP_L',
    name: 'Prof. Hopper',
    email: 'hopper@college.edu',
    departmentId: 'dept_cs',
    subjectsCanTeach: ['sub_dsa_lab'],
  );

  group('Subject-Per-Day Distribution Rule Regression Tests', () {
    // -------------------------------------------------------------------------
    // REGRESSION TEST 1:
    // Subject requiring 4 weekly theory periods across 6 working days
    // → sessions distributed over 4 different days.
    // -------------------------------------------------------------------------
    test('1. Subject requiring 4 weekly theory periods across 6 working days distributes over 4 different days', () {
      final sixWorkingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      final mathsSubject = Subject(
        id: 'sub_maths',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'course_btech',
        sectionId: 'sec_a',
        semester: 3,
        subjectName: 'Mathematics',
        subjectCode: 'MATH101',
        hoursPerWeek: 4,
        subjectType: 'Theory',
        assignedTeacherIds: ['staff_math'],
      );

      final genResult = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [testSectionA],
        subjects: [mathsSubject],
        staffList: [testStaffMath],
        rooms: [testClassroom],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: sixWorkingDays,
      );

      expect(genResult.isSuccess, isTrue, reason: 'Generation should succeed for 4 periods across 6 working days');
      expect(genResult.entries.length, equals(4));

      final scheduledDays = genResult.entries.map((e) => e.dayOfWeek).toSet();
      expect(scheduledDays.length, equals(4),
          reason: 'All 4 theory periods must be placed on 4 distinct working days');

      // Verify no day has more than 1 session
      final countsByDay = <String, int>{};
      for (final e in genResult.entries) {
        countsByDay[e.dayOfWeek] = (countsByDay[e.dayOfWeek] ?? 0) + 1;
      }
      for (final day in countsByDay.keys) {
        expect(countsByDay[day], equals(1),
            reason: 'Subject Mathematics must have at most 1 session on $day');
      }

      // Conflict validation must report 0 hard conflicts
      final valResult = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: genResult.entries,
        sections: [testSectionA],
        subjects: [mathsSubject],
        staffList: [testStaffMath],
        rooms: [testClassroom],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: sixWorkingDays,
      );
      expect(valResult.isValid, isTrue);
      expect(valResult.hardConflicts, isEmpty);
    });

    // -------------------------------------------------------------------------
    // REGRESSION TEST 2:
    // Subject requiring 3 weekly periods → never two sessions on the same day.
    // -------------------------------------------------------------------------
    test('2. Subject requiring 3 weekly periods never schedules two sessions on the same day', () {
      final fiveWorkingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
      final physicsSubject = Subject(
        id: 'sub_physics',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'course_btech',
        sectionId: 'sec_a',
        semester: 3,
        subjectName: 'Physics',
        subjectCode: 'PHYS101',
        hoursPerWeek: 3,
        subjectType: 'Theory',
        assignedTeacherIds: ['staff_physics'],
      );

      final genResult = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [testSectionA],
        subjects: [physicsSubject],
        staffList: [testStaffPhysics],
        rooms: [testClassroom],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: fiveWorkingDays,
      );

      expect(genResult.isSuccess, isTrue);
      expect(genResult.entries.length, equals(3));

      final scheduledDays = genResult.entries.map((e) => e.dayOfWeek).toSet();
      expect(scheduledDays.length, equals(3),
          reason: '3 weekly periods must be scheduled across 3 separate days');

      final countsByDay = <String, int>{};
      for (final e in genResult.entries) {
        countsByDay[e.dayOfWeek] = (countsByDay[e.dayOfWeek] ?? 0) + 1;
      }
      for (final entry in countsByDay.entries) {
        expect(entry.value, equals(1),
            reason: 'Subject Physics must never have more than 1 session on ${entry.key}');
      }
    });

    // -------------------------------------------------------------------------
    // REGRESSION TEST 3:
    // Subject requiring 2 weekly periods → two different days.
    // -------------------------------------------------------------------------
    test('3. Subject requiring 2 weekly periods is scheduled on two different days', () {
      final fiveWorkingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
      final englishSubject = Subject(
        id: 'sub_english',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'course_btech',
        sectionId: 'sec_a',
        semester: 3,
        subjectName: 'English Communication',
        subjectCode: 'ENG101',
        hoursPerWeek: 2,
        subjectType: 'Theory',
        assignedTeacherIds: ['staff_english'],
      );

      final genResult = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [testSectionA],
        subjects: [englishSubject],
        staffList: [testStaffEnglish],
        rooms: [testClassroom],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: fiveWorkingDays,
      );

      expect(genResult.isSuccess, isTrue);
      expect(genResult.entries.length, equals(2));

      final scheduledDays = genResult.entries.map((e) => e.dayOfWeek).toSet();
      expect(scheduledDays.length, equals(2),
          reason: '2 weekly periods must be placed on 2 distinct days');
    });

    // -------------------------------------------------------------------------
    // REGRESSION TEST 4:
    // Two-period lab → consecutive periods on one day must remain valid as ONE session.
    // -------------------------------------------------------------------------
    test('4. Two-period lab occupying consecutive periods on one day remains valid as ONE session', () {
      final fiveWorkingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
      final secWithBatches = testSectionA.copyWith(batches: ['B1']);
      final labSubject = Subject(
        id: 'sub_dsa_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'course_btech',
        sectionId: 'sec_a',
        semester: 3,
        subjectName: 'DSA Laboratory',
        subjectCode: 'CS302L',
        hoursPerWeek: 2,
        subjectType: 'Lab',
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['staff_lab'],
      );
      final labStaff = testStaffLab.copyWith(
        subjectsCanTeach: ['sub_dsa_lab', 'DSA Laboratory', 'CS302L'],
      );
      final labRoom = testLabRoom.copyWith(
        roomType: 'Computer Lab',
      );

      final genResult = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secWithBatches],
        subjects: [labSubject],
        staffList: [labStaff],
        rooms: [labRoom],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: fiveWorkingDays,
      );

      expect(genResult.isSuccess, isTrue,
          reason: 'Generation should succeed for 2-period lab session');
      expect(genResult.entries.length, equals(2));

      // Both periods should be on the same day and consecutive
      final labDay = genResult.entries.first.dayOfWeek;
      for (final e in genResult.entries) {
        expect(e.dayOfWeek, equals(labDay));
      }
      final periods = genResult.entries.map((e) => e.periodNumber).toList()..sort();
      expect(periods[1] - periods[0], equals(1), reason: 'Lab periods must be consecutive');

      // Conflict validation must accept this without sameDaySubjectConflict
      final valResult = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: genResult.entries,
        sections: [secWithBatches],
        subjects: [labSubject],
        staffList: [labStaff],
        rooms: [labRoom],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: fiveWorkingDays,
      );

      expect(valResult.isValid, isTrue, reason: 'Consecutive lab periods represent ONE session and are valid');
      expect(valResult.hardConflicts.where((c) => c.type == 'sameDaySubjectConflict'), isEmpty);
    });

    // -------------------------------------------------------------------------
    // REGRESSION TEST 5:
    // Multiple sections using the same subject → each section must be validated independently.
    // -------------------------------------------------------------------------
    test('5. Multiple sections using the same subject are validated independently', () {
      final fiveWorkingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
      final mathsSubA = Subject(
        id: 'sub_maths_a',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'course_btech',
        sectionId: 'sec_a',
        semester: 3,
        subjectName: 'Mathematics',
        subjectCode: 'MATH101',
        hoursPerWeek: 1,
        subjectType: 'Theory',
        assignedTeacherIds: ['staff_math'],
      );
      final mathsSubB = Subject(
        id: 'sub_maths_b',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'course_btech',
        sectionId: 'sec_b',
        semester: 3,
        subjectName: 'Mathematics',
        subjectCode: 'MATH101',
        hoursPerWeek: 1,
        subjectType: 'Theory',
        assignedTeacherIds: ['staff_math'],
      );

      // Both sections have Maths on Monday at different periods
      final entryA = TimetableEntry(
        id: 'entry_a_mon',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        sectionId: 'sec_a',
        subjectId: 'sub_maths_a',
        teacherId: 'staff_math',
        roomId: 'room_101',
      );
      final entryB = TimetableEntry(
        id: 'entry_b_mon',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 2,
        sectionId: 'sec_b',
        subjectId: 'sub_maths_b',
        teacherId: 'staff_math',
        roomId: 'room_101',
      );

      final valResult = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: [entryA, entryB],
        sections: [testSectionA, testSectionB],
        subjects: [mathsSubA, mathsSubB],
        staffList: [testStaffMath],
        rooms: [testClassroom],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: fiveWorkingDays,
      );

      expect(valResult.isValid, isTrue,
          reason: 'Both sections having Maths on Monday at different periods must be valid');
      expect(valResult.hardConflicts.where((c) => c.type == 'sameDaySubjectConflict'), isEmpty);
    });

    // -------------------------------------------------------------------------
    // REGRESSION TEST 6:
    // A timetable with Maths P2 + P3 on Friday must be rejected.
    // -------------------------------------------------------------------------
    test('6. Timetable with Maths P2 + P3 on Friday must be rejected with sameDaySubjectConflict', () {
      final fiveWorkingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
      final mathsSubject = Subject(
        id: 'sub_maths',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'course_btech',
        sectionId: 'sec_a',
        semester: 3,
        subjectName: 'Mathematics',
        subjectCode: 'MATH101',
        hoursPerWeek: 2,
        subjectType: 'Theory',
        assignedTeacherIds: ['staff_math'],
      );

      // Two separate theory periods on Friday for Section A
      final entryFriP2 = TimetableEntry(
        id: 'entry_fri_p2',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Friday',
        periodNumber: 2,
        sectionId: 'sec_a',
        subjectId: 'sub_maths',
        teacherId: 'staff_math',
        roomId: 'room_101',
      );
      final entryFriP3 = TimetableEntry(
        id: 'entry_fri_p3',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Friday',
        periodNumber: 3,
        sectionId: 'sec_a',
        subjectId: 'sub_maths',
        teacherId: 'staff_math',
        roomId: 'room_101',
      );

      final valResult = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: [entryFriP2, entryFriP3],
        sections: [testSectionA],
        subjects: [mathsSubject],
        staffList: [testStaffMath],
        rooms: [testClassroom],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: fiveWorkingDays,
      );

      expect(valResult.isValid, isFalse,
          reason: 'Two theory sessions of Mathematics on Friday must be rejected as invalid');
      final sameDayConflicts = valResult.hardConflicts
          .where((c) => c.type == 'sameDaySubjectConflict')
          .toList();
      expect(sameDayConflicts, isNotEmpty,
          reason: 'Must produce at least one sameDaySubjectConflict');
      expect(sameDayConflicts.first.description, contains('Mathematics'));
      expect(sameDayConflicts.first.description, contains('Friday'));
    });

    // -------------------------------------------------------------------------
    // REGRESSION TEST 7:
    // A timetable with Maths on Monday, Wednesday, Friday and Saturday must be accepted.
    // -------------------------------------------------------------------------
    test('7. Timetable with Maths on Monday, Wednesday, Friday, Saturday must be accepted with 0 conflicts', () {
      final sixWorkingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      final mathsSubject = Subject(
        id: 'sub_maths',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'course_btech',
        sectionId: 'sec_a',
        semester: 3,
        subjectName: 'Mathematics',
        subjectCode: 'MATH101',
        hoursPerWeek: 4,
        subjectType: 'Theory',
        assignedTeacherIds: ['staff_math'],
      );

      // Valid distribution across Mon, Wed, Fri, Sat
      final entries = [
        TimetableEntry(
          id: 'entry_mon',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 2,
          sectionId: 'sec_a',
          subjectId: 'sub_maths',
          teacherId: 'staff_math',
          roomId: 'room_101',
        ),
        TimetableEntry(
          id: 'entry_wed',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Wednesday',
          periodNumber: 3,
          sectionId: 'sec_a',
          subjectId: 'sub_maths',
          teacherId: 'staff_math',
          roomId: 'room_101',
        ),
        TimetableEntry(
          id: 'entry_fri',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Friday',
          periodNumber: 2,
          sectionId: 'sec_a',
          subjectId: 'sub_maths',
          teacherId: 'staff_math',
          roomId: 'room_101',
        ),
        TimetableEntry(
          id: 'entry_sat',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Saturday',
          periodNumber: 1,
          sectionId: 'sec_a',
          subjectId: 'sub_maths',
          teacherId: 'staff_math',
          roomId: 'room_101',
        ),
      ];

      final valResult = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: entries,
        sections: [testSectionA],
        subjects: [mathsSubject],
        staffList: [testStaffMath],
        rooms: [testClassroom],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: sixWorkingDays,
      );

      expect(valResult.isValid, isTrue,
          reason: 'Timetable with Maths distributed across Mon, Wed, Fri, Sat must be accepted');
      expect(valResult.hardConflicts, isEmpty,
          reason: 'Must have 0 hard conflicts');
      expect(valResult.hardConflicts.where((c) => c.type == 'sameDaySubjectConflict'), isEmpty);
    });

    // -------------------------------------------------------------------------
    // BONUS / FEASIBILITY TEST:
    // If weekly required theory sessions exceed working days, report infeasible.
    // -------------------------------------------------------------------------
    test('Pre-flight feasibility: Theory subject requiring 5 periods with only 4 working days reports infeasible', () {
      final fourWorkingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday'];
      final mathsSubject = Subject(
        id: 'sub_maths',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'course_btech',
        sectionId: 'sec_a',
        semester: 3,
        subjectName: 'Mathematics',
        subjectCode: 'MATH101',
        hoursPerWeek: 5, // 5 sessions > 4 days
        subjectType: 'Theory',
        assignedTeacherIds: ['staff_math'],
      );

      final genResult = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [testSectionA],
        subjects: [mathsSubject],
        staffList: [testStaffMath],
        rooms: [testClassroom],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: fourWorkingDays,
      );

      expect(genResult.isSuccess, isFalse,
          reason: 'Generator must reject when theory subject hours exceed available working days');
      expect(genResult.conflicts.any((c) => c.type == 'sameDaySubjectConflict'), isTrue);
      expect(genResult.conflicts.first.description, contains('working days are available'));
    });
  });
}
