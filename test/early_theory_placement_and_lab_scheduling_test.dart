import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/services.dart';

void main() {
  group('Early Theory Placement & Lab Scheduling Algorithm Tests', () {
    const collegeId = 'col_theory_early_test';

    final standardSlots = [
      TimeSlot(
        id: 'ts_1',
        collegeId: collegeId,
        periodNumber: 1,
        startTime: '09:00',
        endTime: '10:00',
        order: 1,
      ),
      TimeSlot(
        id: 'ts_2',
        collegeId: collegeId,
        periodNumber: 2,
        startTime: '10:00',
        endTime: '11:00',
        order: 2,
      ),
      TimeSlot(
        id: 'ts_break',
        collegeId: collegeId,
        periodNumber: 0,
        startTime: '11:00',
        endTime: '11:15',
        isBreak: true,
        breakTitle: 'Morning Break',
        order: 3,
      ),
      TimeSlot(
        id: 'ts_3',
        collegeId: collegeId,
        periodNumber: 3,
        startTime: '11:15',
        endTime: '12:15',
        order: 4,
      ),
      TimeSlot(
        id: 'ts_4',
        collegeId: collegeId,
        periodNumber: 4,
        startTime: '12:15',
        endTime: '13:15',
        order: 5,
      ),
      TimeSlot(
        id: 'ts_lunch',
        collegeId: collegeId,
        periodNumber: 0,
        startTime: '13:15',
        endTime: '14:00',
        isBreak: true,
        breakTitle: 'Lunch Break',
        order: 6,
      ),
      TimeSlot(
        id: 'ts_5',
        collegeId: collegeId,
        periodNumber: 5,
        startTime: '14:00',
        endTime: '15:00',
        order: 7,
      ),
      TimeSlot(
        id: 'ts_6',
        collegeId: collegeId,
        periodNumber: 6,
        startTime: '15:00',
        endTime: '16:00',
        order: 8,
      ),
    ];

    final sixDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];

    final rooms = [
      Room(
        id: 'room_101',
        collegeId: collegeId,
        roomNumber: 'Room 101',
        capacity: 60,
        roomType: 'Classroom',
      ),
      Room(
        id: 'room_102',
        collegeId: collegeId,
        roomNumber: 'Room 102',
        capacity: 60,
        roomType: 'Classroom',
      ),
      Room(
        id: 'lab_1',
        collegeId: collegeId,
        roomNumber: 'Lab 1',
        capacity: 35,
        roomType: 'Computer Lab',
      ),
      Room(
        id: 'lab_2',
        collegeId: collegeId,
        roomNumber: 'Lab 2',
        capacity: 35,
        roomType: 'Computer Lab',
      ),
    ];

    final teachers = [
      Staff(
        id: 'prof_t1',
        collegeId: collegeId,
        employeeId: 'EMP001',
        name: 'Prof. Theory One',
        email: 't1@college.edu',
        departmentId: 'dept_cs',
        status: 'active',
        subjectsCanTeach: ['sub_dbms', 'sub_ai', 'sub_dbms_a', 'sub_dbms_b'],
        maxClassesPerDay: 5,
      ),
      Staff(
        id: 'prof_t2',
        collegeId: collegeId,
        employeeId: 'EMP002',
        name: 'Prof. Theory Two',
        email: 't2@college.edu',
        departmentId: 'dept_cs',
        status: 'active',
        subjectsCanTeach: ['sub_os', 'sub_cn', 'sub_os_a', 'sub_os_b'],
        maxClassesPerDay: 5,
      ),
      Staff(
        id: 'prof_t3',
        collegeId: collegeId,
        employeeId: 'EMP003',
        name: 'Prof. Theory Three',
        email: 't3@college.edu',
        departmentId: 'dept_cs',
        status: 'active',
        subjectsCanTeach: ['sub_sepm', 'sub_math'],
        maxClassesPerDay: 5,
      ),
      Staff(
        id: 'prof_lab',
        collegeId: collegeId,
        employeeId: 'EMP004',
        name: 'Prof. Lab Guide',
        email: 'lab@college.edu',
        departmentId: 'dept_cs',
        status: 'active',
        subjectsCanTeach: ['sub_dbms_lab'],
        maxClassesPerDay: 4,
      ),
      Staff(
        id: 'prof_lab2',
        collegeId: collegeId,
        employeeId: 'EMP005',
        name: 'Prof. Lab Guide Two',
        email: 'lab2@college.edu',
        departmentId: 'dept_cs',
        status: 'active',
        subjectsCanTeach: ['sub_cn_lab'],
        maxClassesPerDay: 4,
      ),
    ];

    final sectionA = Section(
      id: 'sec_cs_a',
      collegeId: collegeId,
      departmentId: 'dept_cs',
      courseId: 'course_btech',
      academicYear: '2026-2027',
      semester: 5,
      sectionName: 'CSE(AIML)',
      studentCount: 60,
      batches: ['B1', 'B2'],
    );

    test('1. Theory classes start from Period 1 on all working days with classes (no empty Period 1)', () {
      // 5 theory subjects (3 hours each = 15 periods across 6 days)
      final subjects = [
        Subject(
          id: 'sub_dbms',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'Database Management Systems',
          subjectCode: 'CS501',
          semester: 5,
          hoursPerWeek: 3,
          assignedTeacherIds: ['prof_t1'],
          sectionId: sectionA.id,
        ),
        Subject(
          id: 'sub_os',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'Operating Systems',
          subjectCode: 'CS502',
          semester: 5,
          hoursPerWeek: 3,
          assignedTeacherIds: ['prof_t2'],
          sectionId: sectionA.id,
        ),
        Subject(
          id: 'sub_cn',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'Computer Networks',
          subjectCode: 'CS503',
          semester: 5,
          hoursPerWeek: 3,
          assignedTeacherIds: ['prof_t2'],
          sectionId: sectionA.id,
        ),
        Subject(
          id: 'sub_sepm',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'Software Engineering',
          subjectCode: 'CS504',
          semester: 5,
          hoursPerWeek: 3,
          assignedTeacherIds: ['prof_t3'],
          sectionId: sectionA.id,
        ),
        Subject(
          id: 'sub_math',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'Applied Mathematics',
          subjectCode: 'CS505',
          semester: 5,
          hoursPerWeek: 3,
          assignedTeacherIds: ['prof_t3'],
          sectionId: sectionA.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [sectionA],
        subjects: subjects,
        staffList: teachers,
        rooms: rooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: sixDays,
      );

      expect(result.isSuccess, isTrue);
      expect(result.conflicts.where((c) => c.isHard).isEmpty, isTrue);

      // Verify that every day that has classes starts at Period 1
      for (final day in sixDays) {
        final dayEntries = result.entries.where((e) => e.dayOfWeek == day).toList();
        if (dayEntries.isNotEmpty) {
          final periods = dayEntries.map((e) => e.periodNumber).toSet();
          expect(
            periods.contains(1),
            isTrue,
            reason: '$day has classes (${periods.join(", ")}) but leaves Period 1 unnecessarily empty!',
          );
        }
      }
    });

    test('2. Multi-period lab is placed in later/afternoon periods and theory classes occupy Period 1 and morning', () {
      // 4 theory subjects (3 hours each = 12 hours) + 1 2-period lab (4 hours = two 2-period blocks)
      final subjects = [
        Subject(
          id: 'sub_dbms',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'Database Management Systems',
          subjectCode: 'CS501',
          semester: 5,
          hoursPerWeek: 3,
          assignedTeacherIds: ['prof_t1'],
          sectionId: sectionA.id,
        ),
        Subject(
          id: 'sub_os',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'Operating Systems',
          subjectCode: 'CS502',
          semester: 5,
          hoursPerWeek: 3,
          assignedTeacherIds: ['prof_t2'],
          sectionId: sectionA.id,
        ),
        Subject(
          id: 'sub_cn',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'Computer Networks',
          subjectCode: 'CS503',
          semester: 5,
          hoursPerWeek: 3,
          assignedTeacherIds: ['prof_t2'],
          sectionId: sectionA.id,
        ),
        Subject(
          id: 'sub_math',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'Applied Mathematics',
          subjectCode: 'CS505',
          semester: 5,
          hoursPerWeek: 3,
          assignedTeacherIds: ['prof_t3'],
          sectionId: sectionA.id,
        ),
        Subject(
          id: 'sub_dbms_lab',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'DBMS Laboratory',
          subjectCode: 'CS506L',
          semester: 5,
          subjectType: 'Lab',
          hoursPerWeek: 4,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: ['prof_lab'],
          sectionId: sectionA.id,
        ),
        Subject(
          id: 'sub_cn_lab',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'CN Laboratory',
          subjectCode: 'CS507L',
          semester: 5,
          subjectType: 'Lab',
          hoursPerWeek: 4,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: ['prof_lab2'],
          sectionId: sectionA.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [sectionA],
        subjects: subjects,
        staffList: teachers,
        rooms: rooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: sixDays,
      );

      expect(result.isSuccess, isTrue);
      expect(result.conflicts.where((c) => c.isHard).isEmpty, isTrue);

      // Verify lab sessions:
      final labEntries = result.entries.where((e) => e.batch != null).toList();
      expect(labEntries.isNotEmpty, isTrue);

      // Check lab blocks: each block must be strictly consecutive 2 periods
      final labDays = labEntries.map((e) => e.dayOfWeek).toSet();
      for (final day in labDays) {
        final dayLabEntries = labEntries.where((e) => e.dayOfWeek == day).toList();
        final labPeriods = dayLabEntries.map((e) => e.periodNumber).toSet().toList()..sort();
        expect(labPeriods.length, equals(2), reason: 'Lab on $day must occupy exactly 2 consecutive periods');
        expect(labPeriods[1], equals(labPeriods[0] + 1), reason: 'Lab on $day must be consecutive');

        // Check that neither period is a break or lunch
        final slots = standardSlots.where((s) => labPeriods.contains(s.periodNumber)).toList();
        expect(slots.any((s) => s.isBreak), isFalse);

        // Check batches: When multiple compatible labs exist, parallel batches run with different subjects in separate rooms:
        for (final p in labPeriods) {
          final pEntries = dayLabEntries.where((e) => e.periodNumber == p).toList();
          final batches = pEntries.map((e) => e.batch).toSet();
          final roomsInP = pEntries.map((e) => e.roomId).toSet();
          final subjectsInP = pEntries.map((e) => e.subjectId).toSet();
          final teachersInP = pEntries.map((e) => e.teacherId).toSet();
          expect(batches.length, equals(pEntries.length), reason: 'Each batch is unique');
          expect(roomsInP.length, equals(pEntries.length), reason: 'Rooms must be distinct');
          expect(subjectsInP.length, equals(pEntries.length), reason: 'Different lab subjects across batches');
          expect(teachersInP.length, equals(pEntries.length), reason: 'Teachers must be distinct');
        }

        // On the day of the lab, if theory classes exist, Period 1 must be occupied!
        final dayTheory = result.entries.where((e) => e.dayOfWeek == day && e.subjectId != 'sub_dbms_lab').toList();
        if (dayTheory.isNotEmpty) {
          final allPeriods = result.entries.where((e) => e.dayOfWeek == day).map((e) => e.periodNumber).toSet();
          expect(allPeriods.contains(1), isTrue, reason: 'On lab day $day, Period 1 should not be left empty');
        }
      }
    });

    test('3. Period 1 skipped ONLY when genuine hard constraint prevents it, then Period 2 is used', () {
      // Create a section with a single subject where the assigned professor is UNAVAILABLE at Period 1 on Monday
      final profWithUnavailability = teachers.first.copyWith(
        unavailableTimes: [
          UnavailableTime(
            dayOfWeek: 'Monday',
            startTime: '09:00',
            endTime: '10:00', // Period 1 on Monday
          ),
        ],
      );

      final singleSubj = Subject(
        id: 'sub_dbms',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'course_btech',
        subjectName: 'Database Management Systems',
        subjectCode: 'CS501',
        semester: 5,
        hoursPerWeek: 1, // Only 1 period total
        assignedTeacherIds: [profWithUnavailability.id],
        sectionId: sectionA.id,
      );

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [sectionA],
        subjects: [singleSubj],
        staffList: [profWithUnavailability],
        rooms: rooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: ['Monday'], // Only Monday
      );

      expect(result.isSuccess, isTrue);
      expect(result.conflicts.where((c) => c.isHard).isEmpty, isTrue);
      expect(result.entries.length, equals(1));

      final scheduledEntry = result.entries.first;
      expect(scheduledEntry.dayOfWeek, equals('Monday'));
      // Period 1 was legally unavailable due to professor unavailable time
      // The generator MUST have chosen Period 2 (earliest available valid period)
      expect(
        scheduledEntry.periodNumber,
        equals(2),
        reason: 'When Period 1 has a hard unavailability constraint, the generator should use Period 2',
      );
    });

    test('4. Contiguous theory classes: no unnecessary gaps between morning theory classes', () {
      // 3 theory classes on a single day
      final subjects = [
        Subject(
          id: 'sub_dbms',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'DBMS',
          subjectCode: 'CS501',
          semester: 5,
          hoursPerWeek: 1,
          assignedTeacherIds: ['prof_t1'],
          sectionId: sectionA.id,
        ),
        Subject(
          id: 'sub_os',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'OS',
          subjectCode: 'CS502',
          semester: 5,
          hoursPerWeek: 1,
          assignedTeacherIds: ['prof_t2'],
          sectionId: sectionA.id,
        ),
        Subject(
          id: 'sub_math',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'Math',
          subjectCode: 'CS505',
          semester: 5,
          hoursPerWeek: 1,
          assignedTeacherIds: ['prof_t3'],
          sectionId: sectionA.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [sectionA],
        subjects: subjects,
        staffList: teachers,
        rooms: rooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: ['Monday'], // All 3 classes must fit on Monday
      );

      expect(result.isSuccess, isTrue);
      expect(result.entries.length, equals(3));

      final periods = result.entries.map((e) => e.periodNumber).toList()..sort();
      // Should be Period 1, Period 2, Period 3 (completely contiguous from Period 1 with 0 gaps)
      expect(periods, equals([1, 2, 3]), reason: 'Morning theory classes should be contiguous starting from Period 1');
    });

    test('5. Zero professor, room, section, and break hard conflicts across multi-section generation', () {
      final sectionB = Section(
        id: 'sec_cs_b',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'course_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: 'CSE(B)',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      final subjectsA = [
        Subject(
          id: 'sub_dbms_a',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'DBMS A',
          subjectCode: 'CS501A',
          semester: 5,
          hoursPerWeek: 4,
          assignedTeacherIds: ['prof_t1'],
          sectionId: sectionA.id,
        ),
        Subject(
          id: 'sub_os_a',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'OS A',
          subjectCode: 'CS502A',
          semester: 5,
          hoursPerWeek: 4,
          assignedTeacherIds: ['prof_t2'],
          sectionId: sectionA.id,
        ),
      ];

      final subjectsB = [
        Subject(
          id: 'sub_dbms_b',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'DBMS B',
          subjectCode: 'CS501B',
          semester: 5,
          hoursPerWeek: 4,
          assignedTeacherIds: ['prof_t1'], // Shared professor prof_t1
          sectionId: sectionB.id,
        ),
        Subject(
          id: 'sub_os_b',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'course_btech',
          subjectName: 'OS B',
          subjectCode: 'CS502B',
          semester: 5,
          hoursPerWeek: 4,
          assignedTeacherIds: ['prof_t2'], // Shared professor prof_t2
          sectionId: sectionB.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [sectionA, sectionB],
        subjects: [...subjectsA, ...subjectsB],
        staffList: teachers,
        rooms: rooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: sixDays,
      );

      expect(result.isSuccess, isTrue);
      expect(result.conflicts.where((c) => c.isHard).isEmpty, isTrue);

      // Verify no shared teacher is double booked
      for (final day in sixDays) {
        for (var p = 1; p <= 6; p++) {
          final entriesAtSlot = result.entries.where((e) => e.dayOfWeek == day && e.periodNumber == p).toList();
          final profIds = entriesAtSlot.map((e) => e.teacherId).toList();
          expect(profIds.length, equals(profIds.toSet().length), reason: 'Professor double booked at $day P$p');

          final roomIds = entriesAtSlot.map((e) => e.roomId).toList();
          expect(roomIds.length, equals(roomIds.toSet().length), reason: 'Room double booked at $day P$p');
        }
      }
    });
  });
}
