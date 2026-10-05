import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/services.dart';

void main() {
  const collegeId = 'user_college';
  final workingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
  final timeSlots = [
    TimeSlot(id: 'ts1', collegeId: collegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
    TimeSlot(id: 'ts2', collegeId: collegeId, periodNumber: 2, startTime: '10:00', endTime: '11:00', order: 2),
    TimeSlot(id: 'ts3', collegeId: collegeId, periodNumber: 3, startTime: '11:15', endTime: '12:15', order: 3),
    TimeSlot(id: 'ts4', collegeId: collegeId, periodNumber: 4, startTime: '12:15', endTime: '13:15', order: 4),
    TimeSlot(id: 'ts5', collegeId: collegeId, periodNumber: 5, startTime: '14:00', endTime: '15:00', order: 5),
    TimeSlot(id: 'ts6', collegeId: collegeId, periodNumber: 6, startTime: '15:00', endTime: '16:00', order: 6),
  ];

  final dronesLab = Room(
    id: 'r_drones',
    collegeId: collegeId,
    roomNumber: 'Drones lab',
    capacity: 30,
    roomType: 'Computer Lab',
    active: true,
    isUnderMaintenance: false,
  );

  final lab203 = Room(
    id: 'r_203',
    collegeId: collegeId,
    roomNumber: '203',
    capacity: 30,
    roomType: 'Computer Lab',
    active: true,
    isUnderMaintenance: false,
  );

  final classrooms = [
    Room(
      id: 'r_101',
      collegeId: collegeId,
      roomNumber: '101',
      capacity: 60,
      roomType: 'Classroom',
      active: true,
      isUnderMaintenance: false,
    ),
    Room(
      id: 'r_102',
      collegeId: collegeId,
      roomNumber: '102',
      capacity: 60,
      roomType: 'Classroom',
      active: true,
      isUnderMaintenance: false,
    ),
  ];

  final section60 = Section(
    id: 'sec_aiml_5',
    collegeId: collegeId,
    departmentId: 'dept_cse',
    courseId: 'btech',
    academicYear: '2026-2027',
    semester: 5,
    sectionName: 'CSE(AIML)',
    studentCount: 60,
    batches: ['B1', 'B2'],
  );

  final staff1 = Staff(
    id: 't_dv1',
    collegeId: collegeId,
    name: 'Prof. Shrinidhi N',
    employeeId: 'EMP_DV1',
    email: 'shrinidhi@college.edu',
    departmentId: 'dept_cse',
    subjectsCanTeach: ['sub_dv', 'Data Visualization Lab'],
  );

  final staff2 = Staff(
    id: 't_dv2',
    collegeId: collegeId,
    name: 'Prof. Rajesh K',
    employeeId: 'EMP_DV2',
    email: 'rajesh@college.edu',
    departmentId: 'dept_cse',
    subjectsCanTeach: ['sub_dv', 'Data Visualization Lab'],
  );

  final dvLabSubjectSingleProf = Subject(
    id: 'sub_dv',
    collegeId: collegeId,
    departmentId: 'dept_cse',
    courseId: 'btech',
    semester: 5,
    subjectCode: 'CS501L',
    subjectName: 'Data Visualization Lab',
    subjectType: 'Lab',
    hoursPerWeek: 2,
    consecutivePeriods: 2,
    requiredRoomType: 'Computer Lab',
    assignedTeacherIds: ['t_dv1'],
    sectionId: section60.id,
  );

  final dvLabSubjectTwoProfs = Subject(
    id: 'sub_dv',
    collegeId: collegeId,
    departmentId: 'dept_cse',
    courseId: 'btech',
    semester: 5,
    subjectCode: 'CS501L',
    subjectName: 'Data Visualization Lab',
    subjectType: 'Lab',
    hoursPerWeek: 2,
    consecutivePeriods: 2,
    requiredRoomType: 'Computer Lab',
    assignedTeacherIds: ['t_dv1', 't_dv2'],
    sectionId: section60.id,
  );

  group('Batch-Aware Lab Scheduling Regression Tests', () {
    test('TEST A: One lab + B1/B2 — Expected: B1 and B2 are scheduled at different times', () {
      final rooms = [lab203, ...classrooms];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section60],
        subjects: [dvLabSubjectSingleProf],
        staffList: [staff1],
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isTrue, reason: 'Generation failed: ${result.summaryMessage}');
      expect(result.conflicts.where((c) => c.isHard).isEmpty, isTrue,
          reason: 'Hard conflicts found: ${result.conflicts.map((c) => c.title).join(", ")}');

      final b1Entries = result.entries.where((e) => e.batch == 'B1').toList();
      final b2Entries = result.entries.where((e) => e.batch == 'B2').toList();

      expect(b1Entries.length, equals(2), reason: 'B1 must have 2 periods scheduled');
      expect(b2Entries.length, equals(2), reason: 'B2 must have 2 periods scheduled');

      // Both batches use the only compatible lab (lab203)
      expect(b1Entries.every((e) => e.roomId == 'r_203'), isTrue);
      expect(b2Entries.every((e) => e.roomId == 'r_203'), isTrue);

      // B1 and B2 MUST be scheduled at different times
      final b1Slots = b1Entries.map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();
      final b2Slots = b2Entries.map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();
      expect(b1Slots.intersection(b2Slots).isEmpty, isTrue,
          reason: 'B1 and B2 must NOT be scheduled at the same time in the same lab');

      // Preferred different days when possible
      expect(b1Entries.first.dayOfWeek, isNot(equals(b2Entries.first.dayOfWeek)),
          reason: 'Generator should prefer different days for alternating batches when possible');
    });

    test('TEST B: One lab + B1/B2 — Expected: each batch receives exactly 2 consecutive periods', () {
      final rooms = [lab203, ...classrooms];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section60],
        subjects: [dvLabSubjectSingleProf],
        staffList: [staff1],
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isTrue, reason: 'Generation failed: ${result.summaryMessage}');

      final b1Entries = result.entries.where((e) => e.batch == 'B1').toList();
      final b2Entries = result.entries.where((e) => e.batch == 'B2').toList();

      // B1 gets exactly 2 consecutive periods on the same day in the same room
      expect(b1Entries.length, equals(2));
      expect((b1Entries[1].periodNumber - b1Entries[0].periodNumber).abs(), equals(1));
      expect(b1Entries[0].dayOfWeek, equals(b1Entries[1].dayOfWeek));
      expect(b1Entries[0].roomId, equals(b1Entries[1].roomId));

      // B2 gets exactly 2 consecutive periods on the same day in the same room
      expect(b2Entries.length, equals(2));
      expect((b2Entries[1].periodNumber - b2Entries[0].periodNumber).abs(), equals(1));
      expect(b2Entries[0].dayOfWeek, equals(b2Entries[1].dayOfWeek));
      expect(b2Entries[0].roomId, equals(b2Entries[1].roomId));
    });

    test('TEST C: Two compatible labs + B1/B2 — Expected: simultaneous scheduling is allowed only when each batch has a different compatible lab and all professor constraints are satisfied', () {
      // Subcase 1: Two compatible labs AND two professors available -> Simultaneous scheduling allowed in distinct rooms with distinct professors
      final rooms = [dronesLab, lab203, ...classrooms];

      final resultTwoProfs = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section60],
        subjects: [dvLabSubjectTwoProfs],
        staffList: [staff1, staff2],
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(resultTwoProfs.isSuccess, isTrue);
      final b1Entries2 = resultTwoProfs.entries.where((e) => e.batch == 'B1').toList();
      final b2Entries2 = resultTwoProfs.entries.where((e) => e.batch == 'B2').toList();
      expect(b1Entries2.length, equals(2));
      expect(b2Entries2.length, equals(2));

      // If scheduled simultaneously, they must have distinct rooms and distinct professors
      for (final b1 in b1Entries2) {
        final sameTimeB2 = b2Entries2.where(
          (b2) => b2.dayOfWeek == b1.dayOfWeek && b2.periodNumber == b1.periodNumber,
        ).toList();
        for (final b2 in sameTimeB2) {
          expect(b1.roomId, isNot(equals(b2.roomId)),
              reason: 'Simultaneously scheduled batches MUST be in different physical labs');
          expect(b1.teacherId, isNot(equals(b2.teacherId)),
              reason: 'The same professor must not be assigned to B1 and B2 simultaneously');
        }
      }

      // Subcase 2: Two compatible labs, but ONLY ONE professor assigned -> Simultaneous scheduling is strictly FORBIDDEN because 1 professor cannot teach both simultaneously
      final resultOneProf = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section60],
        subjects: [dvLabSubjectSingleProf],
        staffList: [staff1],
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(resultOneProf.isSuccess, isTrue);
      final b1Entries1 = resultOneProf.entries.where((e) => e.batch == 'B1').toList();
      final b2Entries1 = resultOneProf.entries.where((e) => e.batch == 'B2').toList();
      final b1Slots1 = b1Entries1.map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();
      final b2Slots1 = b2Entries1.map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();
      expect(b1Slots1.intersection(b2Slots1).isEmpty, isTrue,
          reason: 'When only one professor is available, B1 and B2 must NOT be scheduled simultaneously');
    });

    test('TEST D: Verify no generated timetable contains B1 and B2 simultaneously in the same physical lab', () {
      final rooms = [lab203, dronesLab, ...classrooms];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section60],
        subjects: [dvLabSubjectTwoProfs],
        staffList: [staff1, staff2],
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isTrue);

      // Verify across all generated entries that no physical room has multiple batches of same section at same time
      final slotRoomMap = <String, Set<String>>{};
      for (final e in result.entries) {
        if (e.batch != null) {
          final key = '${e.dayOfWeek}_${e.periodNumber}_${e.roomId}';
          slotRoomMap.putIfAbsent(key, () => <String>{}).add(e.batch!);
        }
      }
      for (final batches in slotRoomMap.values) {
        expect(batches.length, equals(1),
            reason: 'No physical lab room may contain more than one batch simultaneously: $batches');
      }

      // Explicit ConflictValidator verification:
      // SAME_SECTION + SAME_LAB_SUBJECT + DIFFERENT_BATCHES in same lab at same time produces hard conflict
      final illegalEntries = [
        TimetableEntry(
          id: 'illegal_b1',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          timeSlotId: 'ts1',
          sectionId: section60.id,
          subjectId: dvLabSubjectTwoProfs.id,
          teacherId: staff1.id,
          roomId: lab203.id,
          batch: 'B1',
        ),
        TimetableEntry(
          id: 'illegal_b2',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          timeSlotId: 'ts1',
          sectionId: section60.id,
          subjectId: dvLabSubjectTwoProfs.id,
          teacherId: staff2.id,
          roomId: lab203.id,
          batch: 'B2',
        ),
      ];

      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: illegalEntries,
        sections: [section60],
        subjects: [dvLabSubjectTwoProfs],
        staffList: [staff1, staff2],
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
      );

      expect(validation.hardConflicts.any((c) => c.type == 'labSameRoomConflict'), isTrue,
          reason: 'Validator must explicitly detect SAME_SECTION + SAME_LAB_SUBJECT + DIFFERENT_BATCHES in same physical lab');
    });
  });
}
