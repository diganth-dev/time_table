import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/services.dart';

void main() {
  group('Independent Batch Scheduling & Constraint Tests (TEST 1 - TEST 6)', () {
    const collegeId = 'col_eng';
    final workingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    final timeSlots = [
      TimeSlot(id: 'ts_1', collegeId: collegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
      TimeSlot(id: 'ts_2', collegeId: collegeId, periodNumber: 2, startTime: '10:00', endTime: '11:00', order: 2),
      TimeSlot(id: 'ts_3', collegeId: collegeId, periodNumber: 3, startTime: '11:15', endTime: '12:15', order: 3),
      TimeSlot(id: 'ts_4', collegeId: collegeId, periodNumber: 4, startTime: '12:15', endTime: '13:15', order: 4),
    ];

    final section = Section(
      id: 'sec_1',
      collegeId: collegeId,
      departmentId: 'dept_cs',
      courseId: 'c_btech',
      academicYear: '2026-2027',
      semester: 5,
      sectionName: '5-A',
      studentCount: 60,
      batches: ['B1', 'B2'],
    );

    final profA = Staff(
      id: 'prof_a',
      collegeId: collegeId,
      employeeId: 'EMP001',
      name: 'Prof. A',
      email: 'a@col.edu',
      departmentId: 'dept_cs',
      status: 'active',
      subjectsCanTeach: ['DVL Lab', 'MP Lab', 'CN Lab'],
      maxClassesPerDay: 4,
    );

    final profB = Staff(
      id: 'prof_b',
      collegeId: collegeId,
      employeeId: 'EMP002',
      name: 'Prof. B',
      email: 'b@col.edu',
      departmentId: 'dept_cs',
      status: 'active',
      subjectsCanTeach: ['DVL Lab', 'MP Lab', 'CN Lab'],
      maxClassesPerDay: 4,
    );

    final lab1 = Room(
      id: 'lab_1',
      collegeId: collegeId,
      roomNumber: 'Lab 1',
      capacity: 35,
      roomType: 'Computer Lab',
    );

    final lab2 = Room(
      id: 'lab_2',
      collegeId: collegeId,
      roomNumber: 'Lab 2',
      capacity: 35,
      roomType: 'Computer Lab',
    );

    final lab3 = Room(
      id: 'lab_3',
      collegeId: collegeId,
      roomNumber: 'Lab 3',
      capacity: 35,
      roomType: 'Computer Lab',
    );

    final dvlLab = Subject(
      id: 'sub_dvl',
      collegeId: collegeId,
      departmentId: 'dept_cs',
      courseId: 'c_btech',
      subjectName: 'DVL Lab',
      subjectCode: 'CS501L',
      semester: 5,
      subjectType: 'Lab',
      hoursPerWeek: 2,
      consecutivePeriods: 2,
      requiredRoomType: 'Computer Lab',
      assignedTeacherIds: ['prof_a'],
      sectionId: section.id,
    );

    final mpLab = Subject(
      id: 'sub_mp',
      collegeId: collegeId,
      departmentId: 'dept_cs',
      courseId: 'c_btech',
      subjectName: 'MP Lab',
      subjectCode: 'CS502L',
      semester: 5,
      subjectType: 'Lab',
      hoursPerWeek: 2,
      consecutivePeriods: 2,
      requiredRoomType: 'Computer Lab',
      assignedTeacherIds: ['prof_b'],
      sectionId: section.id,
    );

    test('TEST 1: 3 compatible labs. B1 lab and B2 no lab at the same time -> B1 scheduled, B2 FREE', () {
      // Create entries where B1 has DVL Lab on Mon P1-P2, and B2 is FREE (no entries for B2)
      final entries = [
        TimetableEntry(
          id: 'e1',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          timeSlotId: 'ts_1',
          sectionId: section.id,
          subjectId: dvlLab.id,
          teacherId: profA.id,
          roomId: lab1.id,
          batch: 'B1',
        ),
        TimetableEntry(
          id: 'e2',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 2,
          timeSlotId: 'ts_2',
          sectionId: section.id,
          subjectId: dvlLab.id,
          teacherId: profA.id,
          roomId: lab1.id,
          batch: 'B1',
        ),
      ];

      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: entries,
        sections: [section],
        subjects: [dvlLab],
        staffList: [profA],
        rooms: [lab1, lab2, lab3],
        timeSlots: timeSlots,
        availabilities: [],
      );

      expect(validation.isValid, isTrue, reason: 'B1 scheduled while B2 is FREE must produce 0 hard conflicts');
      expect(validation.hardConflicts, isEmpty);

      // Verify B2 has no entries during Mon P1-P2 (B2 is FREE)
      final b2Mon = entries.where((e) => e.dayOfWeek == 'Monday' && e.batch == 'B2').toList();
      expect(b2Mon, isEmpty, reason: 'B2 is completely FREE during B1 lab');
    });

    test('TEST 2: 3 compatible labs. B1 lab and B2 lab at same time -> allowed only if they receive different physical labs', () {
      // B1 in Lab 1 and B2 in Lab 2 at Monday P1-P2 with different teachers
      final entriesDifferentLabs = [
        TimetableEntry(
          id: 'e1',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          timeSlotId: 'ts_1',
          sectionId: section.id,
          subjectId: dvlLab.id,
          teacherId: profA.id,
          roomId: lab1.id,
          batch: 'B1',
        ),
        TimetableEntry(
          id: 'e2',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 2,
          timeSlotId: 'ts_2',
          sectionId: section.id,
          subjectId: dvlLab.id,
          teacherId: profA.id,
          roomId: lab1.id,
          batch: 'B1',
        ),
        TimetableEntry(
          id: 'e3',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          timeSlotId: 'ts_1',
          sectionId: section.id,
          subjectId: mpLab.id,
          teacherId: profB.id,
          roomId: lab2.id,
          batch: 'B2',
        ),
        TimetableEntry(
          id: 'e4',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 2,
          timeSlotId: 'ts_2',
          sectionId: section.id,
          subjectId: mpLab.id,
          teacherId: profB.id,
          roomId: lab2.id,
          batch: 'B2',
        ),
      ];

      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: entriesDifferentLabs,
        sections: [section],
        subjects: [dvlLab, mpLab],
        staffList: [profA, profB],
        rooms: [lab1, lab2, lab3],
        timeSlots: timeSlots,
        availabilities: [],
      );

      expect(validation.isValid, isTrue, reason: 'B1 in Lab 1 and B2 in Lab 2 at same time is VALID');
      expect(validation.hardConflicts, isEmpty);
    });

    test('TEST 3: 1 compatible lab. B1 lab and B2 lab at same time -> conflict / one batch moved', () {
      // 1 compatible lab only. Attempt to place B1 and B2 in same lab at same time:
      final entriesSameLab = [
        TimetableEntry(
          id: 'e1',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          timeSlotId: 'ts_1',
          sectionId: section.id,
          subjectId: dvlLab.id,
          teacherId: profA.id,
          roomId: lab1.id,
          batch: 'B1',
        ),
        TimetableEntry(
          id: 'e2',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 2,
          timeSlotId: 'ts_2',
          sectionId: section.id,
          subjectId: dvlLab.id,
          teacherId: profA.id,
          roomId: lab1.id,
          batch: 'B1',
        ),
        TimetableEntry(
          id: 'e3',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          timeSlotId: 'ts_1',
          sectionId: section.id,
          subjectId: mpLab.id,
          teacherId: profB.id,
          roomId: lab1.id, // SAME LAB!
          batch: 'B2',
        ),
        TimetableEntry(
          id: 'e4',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 2,
          timeSlotId: 'ts_2',
          sectionId: section.id,
          subjectId: mpLab.id,
          teacherId: profB.id,
          roomId: lab1.id, // SAME LAB!
          batch: 'B2',
        ),
      ];

      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: entriesSameLab,
        sections: [section],
        subjects: [dvlLab, mpLab],
        staffList: [profA, profB],
        rooms: [lab1],
        timeSlots: timeSlots,
        availabilities: [],
      );

      expect(validation.isValid, isFalse, reason: 'Sharing same physical lab at same time is INVALID');
      expect(validation.hardConflicts.any((c) => c.type == 'roomConflict' || c.type == 'labSameRoomConflict'), isTrue);

      // Now verify that TimetableGenerator with only 1 compatible lab moves one batch to another time
      final genResult = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [dvlLab],
        staffList: [profA],
        rooms: [lab1],
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(genResult.isSuccess, isTrue, reason: 'Generator successfully moves one batch when only 1 lab is available');
      final b1Entries = genResult.entries.where((e) => e.batch == 'B1').toList();
      final b2Entries = genResult.entries.where((e) => e.batch == 'B2').toList();
      final b1Slots = b1Entries.map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();
      final b2Slots = b2Entries.map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();

      // With only 1 lab, B1 and B2 slots must NOT overlap
      expect(b1Slots.intersection(b2Slots).isEmpty, isTrue, reason: 'With 1 lab, batches are placed in non-overlapping slots');
    });

    test('TEST 4: B1 lab at one time and B2 lab at another time -> both valid, with the other batch FREE during each respective lab', () {
      // Mon P1-P2: B1 DVL Lab in Lab 1 (B2 FREE)
      // Mon P3-P4: B2 MP Lab in Lab 2 (B1 FREE)
      // Tue P1-P2: B1 CN Lab in Lab 1 (B2 FREE)
      final cnLab = Subject(
        id: 'sub_cn',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'CN Lab',
        subjectCode: 'CS503L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_a'],
        sectionId: section.id,
      );

      final entries = [
        // Mon P1-P2: B1 in DVL Lab
        TimetableEntry(id: 'e1', collegeId: collegeId, versionId: 'v1', dayOfWeek: 'Monday', periodNumber: 1, timeSlotId: 'ts_1', sectionId: section.id, subjectId: dvlLab.id, teacherId: profA.id, roomId: lab1.id, batch: 'B1'),
        TimetableEntry(id: 'e2', collegeId: collegeId, versionId: 'v1', dayOfWeek: 'Monday', periodNumber: 2, timeSlotId: 'ts_2', sectionId: section.id, subjectId: dvlLab.id, teacherId: profA.id, roomId: lab1.id, batch: 'B1'),
        // Mon P3-P4: B2 in MP Lab
        TimetableEntry(id: 'e3', collegeId: collegeId, versionId: 'v1', dayOfWeek: 'Monday', periodNumber: 3, timeSlotId: 'ts_3', sectionId: section.id, subjectId: mpLab.id, teacherId: profB.id, roomId: lab2.id, batch: 'B2'),
        TimetableEntry(id: 'e4', collegeId: collegeId, versionId: 'v1', dayOfWeek: 'Monday', periodNumber: 4, timeSlotId: 'ts_4', sectionId: section.id, subjectId: mpLab.id, teacherId: profB.id, roomId: lab2.id, batch: 'B2'),
        // Tue P1-P2: B1 in CN Lab
        TimetableEntry(id: 'e5', collegeId: collegeId, versionId: 'v1', dayOfWeek: 'Tuesday', periodNumber: 1, timeSlotId: 'ts_1', sectionId: section.id, subjectId: cnLab.id, teacherId: profA.id, roomId: lab1.id, batch: 'B1'),
        TimetableEntry(id: 'e6', collegeId: collegeId, versionId: 'v1', dayOfWeek: 'Tuesday', periodNumber: 2, timeSlotId: 'ts_2', sectionId: section.id, subjectId: cnLab.id, teacherId: profA.id, roomId: lab1.id, batch: 'B1'),
      ];

      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: entries,
        sections: [section],
        subjects: [dvlLab, mpLab, cnLab],
        staffList: [profA, profB],
        rooms: [lab1, lab2, lab3],
        timeSlots: timeSlots,
        availabilities: [],
      );

      expect(validation.isValid, isTrue, reason: 'Independent batch schedules with FREE periods must be completely VALID');
      expect(validation.hardConflicts, isEmpty);

      // Verify B2 is FREE during Mon P1-P2
      final b2MonP1P2 = entries.where((e) => e.dayOfWeek == 'Monday' && (e.periodNumber == 1 || e.periodNumber == 2) && e.batch == 'B2');
      expect(b2MonP1P2, isEmpty);

      // Verify B1 is FREE during Mon P3-P4
      final b1MonP3P4 = entries.where((e) => e.dayOfWeek == 'Monday' && (e.periodNumber == 3 || e.periodNumber == 4) && e.batch == 'B1');
      expect(b1MonP3P4, isEmpty);

      // Verify B2 is FREE during Tue P1-P2
      final b2TueP1P2 = entries.where((e) => e.dayOfWeek == 'Tuesday' && (e.periodNumber == 1 || e.periodNumber == 2) && e.batch == 'B2');
      expect(b2TueP1P2, isEmpty);
    });

    test('TEST 5: Lab remains exactly 2 consecutive periods for the assigned batch', () {
      final genResult = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [dvlLab],
        staffList: [profA],
        rooms: [lab1],
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(genResult.isSuccess, isTrue);
      for (final batch in ['B1', 'B2']) {
        final batchEntries = genResult.entries.where((e) => e.batch == batch).toList();
        expect(batchEntries.length, equals(2), reason: 'Batch $batch must have exactly 2 periods');
        expect(batchEntries[0].dayOfWeek, equals(batchEntries[1].dayOfWeek));
        expect((batchEntries[1].periodNumber - batchEntries[0].periodNumber).abs(), equals(1),
            reason: 'Batch $batch periods must be consecutive');
      }
    });

    test('TEST 6: No incompleteHours or unexpected extra sessions are created', () {
      final genResult = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [dvlLab],
        staffList: [profA],
        rooms: [lab1],
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(genResult.isSuccess, isTrue);
      expect(genResult.conflicts.where((c) => c.type == 'incompleteHours'), isEmpty);
      // For a 2-hour lab with 2 batches: B1 gets 2 hours, B2 gets 2 hours = 4 entries total
      expect(genResult.entries.length, equals(4), reason: 'No extra sessions created');
    });
  });
}
