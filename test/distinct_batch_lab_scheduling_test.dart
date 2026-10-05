import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/room.dart';
import 'package:time_table/models/section.dart';
import 'package:time_table/models/staff.dart';
import 'package:time_table/models/subject.dart';
import 'package:time_table/models/time_slot.dart';
import 'package:time_table/models/timetable_entry.dart';
import 'package:time_table/services/conflict_validator.dart';
import 'package:time_table/services/timetable_generator.dart';

void main() {
  const collegeId = 'col_engineering';

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

  final workingDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  final rooms = [
    Room(
      id: 'room_cr1',
      collegeId: collegeId,
      roomNumber: 'Classroom 101',
      capacity: 60,
      roomType: 'Classroom',
    ),
    Room(
      id: 'lab_cn_room',
      collegeId: collegeId,
      roomNumber: 'Networking Lab',
      capacity: 35,
      roomType: 'Computer Lab',
      facilities: ['Networking Lab', 'Computer Lab'],
    ),
    Room(
      id: 'lab_dbms_room',
      collegeId: collegeId,
      roomNumber: 'Database Systems Lab',
      capacity: 35,
      roomType: 'Computer Lab',
      facilities: ['Database Systems Lab', 'Computer Lab'],
    ),
    Room(
      id: 'lab_os_room',
      collegeId: collegeId,
      roomNumber: 'Systems Software Lab',
      capacity: 35,
      roomType: 'Computer Lab',
      facilities: ['Systems Software Lab', 'Computer Lab'],
    ),
  ];

  final staffList = [
    Staff(
      id: 'prof_theory',
      collegeId: collegeId,
      employeeId: 'EMP_T1',
      name: 'Dr. Turing',
      email: 'turing@college.edu',
      departmentId: 'dept_cse',
      status: 'active',
      subjectsCanTeach: ['sub_automata', 'sub_algo'],
      maxClassesPerDay: 5,
    ),
    Staff(
      id: 'prof_cn_guide',
      collegeId: collegeId,
      employeeId: 'EMP_L1',
      name: 'Prof. Cerf',
      email: 'cerf@college.edu',
      departmentId: 'dept_cse',
      status: 'active',
      subjectsCanTeach: ['sub_cn_lab'],
      maxClassesPerDay: 4,
    ),
    Staff(
      id: 'prof_dbms_guide',
      collegeId: collegeId,
      employeeId: 'EMP_L2',
      name: 'Prof. Codd',
      email: 'codd@college.edu',
      departmentId: 'dept_cse',
      status: 'active',
      subjectsCanTeach: ['sub_dbms_lab'],
      maxClassesPerDay: 4,
    ),
    Staff(
      id: 'prof_os_guide',
      collegeId: collegeId,
      employeeId: 'EMP_L3',
      name: 'Prof. Ritchie',
      email: 'ritchie@college.edu',
      departmentId: 'dept_cse',
      status: 'active',
      subjectsCanTeach: ['sub_os_lab'],
      maxClassesPerDay: 4,
    ),
  ];

  group('Distinct Batch-Lab Scheduling Constraints', () {
    test('1. Two batches (B1 & B2) receive distinct lab subjects in the same lab block and alternate', () {
      final section = Section(
        id: 'sec_cs_5a',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-A',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      final subjects = [
        Subject(
          id: 'sub_automata',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_btech',
          subjectName: 'Automata Theory',
          subjectCode: 'CS501',
          semester: 5,
          hoursPerWeek: 4,
          assignedTeacherIds: ['prof_theory'],
          sectionId: section.id,
        ),
        Subject(
          id: 'sub_cn_lab',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_btech',
          subjectName: 'CN Lab',
          subjectCode: 'CS502L',
          semester: 5,
          subjectType: 'Lab',
          hoursPerWeek: 4, // 2 sessions of 2 periods
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: ['prof_cn_guide'],
          sectionId: section.id,
        ),
        Subject(
          id: 'sub_dbms_lab',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_btech',
          subjectName: 'DBMS Lab',
          subjectCode: 'CS503L',
          semester: 5,
          subjectType: 'Lab',
          hoursPerWeek: 4, // 2 sessions of 2 periods
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: ['prof_dbms_guide'],
          sectionId: section.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isTrue, reason: 'Generation must succeed without conflicts: ${result.summaryMessage}');
      expect(result.conflicts.where((c) => c.isHard).isEmpty, isTrue);

      final labEntries = result.entries.where((e) => e.batch != null).toList();
      expect(labEntries.isNotEmpty, isTrue);

      // Group lab entries by (dayOfWeek, periodNumber)
      final periodGroups = <String, List<TimetableEntry>>{};
      for (final e in labEntries) {
        final key = '${e.dayOfWeek}_${e.periodNumber}';
        periodGroups.putIfAbsent(key, () => []).add(e);
      }

      // Verify parallel different-subject lab allocation and rotation
      for (final entry in periodGroups.entries) {
        final list = entry.value;
        if (list.length > 1) {
          final distinctRooms = list.map((e) => e.roomId).toSet();
          final distinctTeachers = list.map((e) => e.teacherId).toSet();
          final distinctBatches = list.map((e) => e.batch).toSet();
          final distinctSubjects = list.map((e) => e.subjectId).toSet();
          expect(distinctRooms.length, equals(list.length),
              reason: 'Simultaneous batches must use different physical rooms');
          expect(distinctTeachers.length, equals(list.length),
              reason: 'Simultaneous batches must have different professors');
          expect(distinctBatches.length, equals(list.length),
              reason: 'Each batch in the slot must be unique');
          expect(distinctSubjects.length, equals(list.length),
              reason: 'Simultaneous batches must have DIFFERENT lab subjects');
        }
      }

      // Verify rotation: B1 gets both CN Lab and DBMS Lab across different blocks
      final b1Subjects = labEntries.where((e) => e.batch == 'B1').map((e) => e.subjectId).toSet();
      final b2Subjects = labEntries.where((e) => e.batch == 'B2').map((e) => e.subjectId).toSet();
      expect(b1Subjects, containsAll(['sub_cn_lab', 'sub_dbms_lab']));
      expect(b2Subjects, containsAll(['sub_cn_lab', 'sub_dbms_lab']));

      // Validate entries using ConflictValidator
      final validationRes = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: result.entries,
        sections: [section],
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: standardSlots,
        availabilities: [],
      );
      expect(validationRes.hardConflicts.isEmpty, isTrue);
    });

    test('2. Three batches (B1, B2, B3) receive 3 distinct lab subjects simultaneously in each block', () {
      final section = Section(
        id: 'sec_cs_3batch',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-TriBatch',
        studentCount: 90,
        batches: ['B1', 'B2', 'B3'],
      );

      final subjects = [
        Subject(
          id: 'sub_cn_lab',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_btech',
          subjectName: 'CN Lab',
          subjectCode: 'CS502L',
          semester: 5,
          subjectType: 'Lab',
          hoursPerWeek: 6, // 3 sessions of 2 periods
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: ['prof_cn_guide'],
          sectionId: section.id,
        ),
        Subject(
          id: 'sub_dbms_lab',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_btech',
          subjectName: 'DBMS Lab',
          subjectCode: 'CS503L',
          semester: 5,
          subjectType: 'Lab',
          hoursPerWeek: 6,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: ['prof_dbms_guide'],
          sectionId: section.id,
        ),
        Subject(
          id: 'sub_os_lab',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_btech',
          subjectName: 'OS Lab',
          subjectCode: 'CS504L',
          semester: 5,
          subjectType: 'Lab',
          hoursPerWeek: 6,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: ['prof_os_guide'],
          sectionId: section.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isTrue, reason: result.summaryMessage);
      expect(result.conflicts.where((c) => c.isHard).isEmpty, isTrue);

      final labEntries = result.entries.where((e) => e.batch != null).toList();
      final periodGroups = <String, List<TimetableEntry>>{};
      for (final e in labEntries) {
        final key = '${e.dayOfWeek}_${e.periodNumber}';
        periodGroups.putIfAbsent(key, () => []).add(e);
      }

      for (final entriesInSlot in periodGroups.values) {
        final distinctRooms = entriesInSlot.map((e) => e.roomId).toSet();
        final distinctTeachers = entriesInSlot.map((e) => e.teacherId).toSet();
        final distinctBatches = entriesInSlot.map((e) => e.batch).toSet();
        expect(distinctRooms.length, equals(entriesInSlot.length),
            reason: 'Each simultaneous batch must have a distinct lab room');
        expect(distinctTeachers.length, equals(entriesInSlot.length),
            reason: 'Each simultaneous batch must have a distinct professor');
        expect(distinctBatches.length, equals(entriesInSlot.length),
            reason: 'No batch can be duplicated in the same slot');
      }

      final validationRes = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: result.entries,
        sections: [section],
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: standardSlots,
        availabilities: [],
      );
      expect(validationRes.hardConflicts.isEmpty, isTrue);
    });

    test('3. Dynamic batch naming (Batch-Alpha, Batch-Beta) is supported and distinct subjects assigned', () {
      final section = Section(
        id: 'sec_cs_custom_batches',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-Custom',
        studentCount: 60,
        batches: ['Batch-Alpha', 'Batch-Beta'],
      );

      final subjects = [
        Subject(
          id: 'sub_cn_lab',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_btech',
          subjectName: 'CN Lab',
          subjectCode: 'CS502L',
          semester: 5,
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: ['prof_cn_guide'],
          sectionId: section.id,
        ),
        Subject(
          id: 'sub_dbms_lab',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_btech',
          subjectName: 'DBMS Lab',
          subjectCode: 'CS503L',
          semester: 5,
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: ['prof_dbms_guide'],
          sectionId: section.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isTrue, reason: result.summaryMessage);
      final labEntries = result.entries.where((e) => e.batch != null).toList();
      final periodGroups = <String, List<TimetableEntry>>{};
      for (final e in labEntries) {
        final key = '${e.dayOfWeek}_${e.periodNumber}';
        periodGroups.putIfAbsent(key, () => []).add(e);
      }
      for (final list in periodGroups.values) {
        if (list.length > 1) {
          final distinctRooms = list.map((e) => e.roomId).toSet();
          final distinctTeachers = list.map((e) => e.teacherId).toSet();
          final distinctBatches = list.map((e) => e.batch).toSet();
          final distinctSubjects = list.map((e) => e.subjectId).toSet();
          expect(distinctRooms.length, equals(list.length));
          expect(distinctTeachers.length, equals(list.length));
          expect(distinctBatches.length, equals(list.length));
          expect(distinctSubjects.length, equals(list.length));
        }
      }
      expect(result.conflicts.where((c) => c.isHard).isEmpty, isTrue);
    });

    test('4. Multiple batches (B1 & B2) with only ONE lab subject: schedules each batch at DIFFERENT time blocks/days', () {
      final section = Section(
        id: 'sec_cs_insufficient',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-SingleLab',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      // Section has 2 batches, but ONLY 1 lab subject!
      final subjects = [
        Subject(
          id: 'sub_cn_lab',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_btech',
          subjectName: 'CN Lab',
          subjectCode: 'CS502L',
          semester: 5,
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Networking Lab',
          assignedTeacherIds: ['prof_cn_guide'],
          sectionId: section.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isTrue, reason: 'Generation must succeed without errors: ${result.summaryMessage}');
      expect(result.conflicts.where((c) => c.isHard).isEmpty, isTrue);

      final b1Entries = result.entries.where((e) => e.batch == 'B1').toList();
      final b2Entries = result.entries.where((e) => e.batch == 'B2').toList();

      expect(b1Entries.length, equals(2), reason: 'B1 must have 1 block of 2 consecutive periods');
      expect(b2Entries.length, equals(2), reason: 'B2 must have 1 block of 2 consecutive periods');

      // Check that B1 and B2 are scheduled at DIFFERENT time blocks/days
      final b1Slots = b1Entries.map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();
      final b2Slots = b2Entries.map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();

      // Intersection must be completely empty!
      expect(b1Slots.intersection(b2Slots).isEmpty, isTrue,
          reason: 'B1 and B2 must NEVER be scheduled in the same time slot for the single lab!');

      // When B1 is in lab, B2 is Free (not scheduled)
      for (final slot in b1Slots) {
        expect(b2Slots.contains(slot), isFalse);
      }
      // When B2 is in lab, B1 is Free (not scheduled)
      for (final slot in b2Slots) {
        expect(b1Slots.contains(slot), isFalse);
      }

      // Check consecutive periods (exactly 2 consecutive periods for each batch)
      expect(b1Entries[0].dayOfWeek, equals(b1Entries[1].dayOfWeek));
      expect((b1Entries[1].periodNumber - b1Entries[0].periodNumber).abs(), equals(1));
      expect(b2Entries[0].dayOfWeek, equals(b2Entries[1].dayOfWeek));
      expect((b2Entries[1].periodNumber - b2Entries[0].periodNumber).abs(), equals(1));

      // Validate with ConflictValidator
      final validationRes = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: result.entries,
        sections: [section],
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: standardSlots,
        availabilities: [],
      );
      expect(validationRes.hardConflicts.isEmpty, isTrue,
          reason: 'ConflictValidator must find 0 hard conflicts: ${validationRes.hardConflicts.map((c) => c.title).join(", ")}');
    });

    test('5. ConflictValidator rejects timetable if two batches of same section share same lab in same slot', () {
      final section = Section(
        id: 'sec_cs_conflict_test',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-Test',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      final subject = Subject(
        id: 'sub_cn_lab',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_btech',
        subjectName: 'CN Lab',
        subjectCode: 'CS502L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_cn_guide'],
        sectionId: section.id,
      );

      // Faulty entries: both B1 and B2 assigned to the same room lab_cn_room on Monday Period 5
      final badEntries = [
        TimetableEntry(
          id: 'entry_1',
          versionId: 'v1',
          collegeId: collegeId,
          sectionId: section.id,
          subjectId: subject.id,
          teacherId: 'prof_cn_guide',
          roomId: 'lab_cn_room',
          dayOfWeek: 'Monday',
          periodNumber: 5,
          batch: 'B1',
        ),
        TimetableEntry(
          id: 'entry_2',
          versionId: 'v1',
          collegeId: collegeId,
          sectionId: section.id,
          subjectId: subject.id,
          teacherId: 'prof_cn_guide',
          roomId: 'lab_cn_room', // SAME LAB ROOM!
          dayOfWeek: 'Monday',
          periodNumber: 5,
          batch: 'B2',
        ),
      ];

      final validationRes = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: badEntries,
        sections: [section],
        subjects: [subject],
        staffList: staffList,
        rooms: rooms,
        timeSlots: standardSlots,
        availabilities: [],
      );

      final sameRoomConflict = validationRes.hardConflicts.firstWhere(
        (c) => c.type == 'labSameRoomConflict',
      );
      expect(sameRoomConflict.isHard, isTrue);
      expect(sameRoomConflict.title, equals('Batches Sharing Same Lab'));
      expect(
        sameRoomConflict.description,
        contains('share room'),
      );
    });

    test('6. Three batches (B1, B2, B3) with only ONE lab subject: schedules all 3 batches on DIFFERENT time blocks/days', () {
      final section = Section(
        id: 'sec_cs_3batch_single_lab',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-TriBatch-SingleLab',
        studentCount: 90,
        batches: ['B1', 'B2', 'B3'],
      );

      final subjects = [
        Subject(
          id: 'sub_cn_lab',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_btech',
          subjectName: 'CN Lab',
          subjectCode: 'CS502L',
          semester: 5,
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Networking Lab',
          assignedTeacherIds: ['prof_cn_guide'],
          sectionId: section.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isTrue, reason: 'Generation must succeed: ${result.summaryMessage}');
      expect(result.conflicts.where((c) => c.isHard).isEmpty, isTrue);

      final b1Entries = result.entries.where((e) => e.batch == 'B1').toList();
      final b2Entries = result.entries.where((e) => e.batch == 'B2').toList();
      final b3Entries = result.entries.where((e) => e.batch == 'B3').toList();

      expect(b1Entries.length, equals(2));
      expect(b2Entries.length, equals(2));
      expect(b3Entries.length, equals(2));

      final b1Slots = b1Entries.map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();
      final b2Slots = b2Entries.map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();
      final b3Slots = b3Entries.map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();

      // No overlapping slots between any batches
      expect(b1Slots.intersection(b2Slots).isEmpty, isTrue);
      expect(b1Slots.intersection(b3Slots).isEmpty, isTrue);
      expect(b2Slots.intersection(b3Slots).isEmpty, isTrue);

      final validationRes = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: result.entries,
        sections: [section],
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: standardSlots,
        availabilities: [],
      );
      expect(validationRes.hardConflicts.isEmpty, isTrue);
    });
  });
}
