import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/conflict_validator.dart';
import 'package:time_table/services/timetable_generator.dart';

void main() {
  const collegeId = 'col_lab_venue_test';
  final workingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  final timeSlots = [
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
      id: 'ts_3',
      collegeId: collegeId,
      periodNumber: 3,
      startTime: '11:00',
      endTime: '12:00',
      order: 3,
    ),
    TimeSlot(
      id: 'ts_4',
      collegeId: collegeId,
      periodNumber: 4,
      startTime: '13:00',
      endTime: '14:00',
      order: 4,
    ),
  ];

  final teacher1 = Staff(
    id: 'staff_1',
    collegeId: collegeId,
    name: 'Dr. Alan Turing',
    email: 'turing@college.edu',
    departmentId: 'dept_cs',
    designation: 'Professor',
    subjectsCanTeach: ['Mini Project', 'CS Lab', 'Algorithms', 'Data Structures', 'Theory of Computation'],
    maxClassesPerDay: 5,
    active: true,
  );

  final teacher2 = Staff(
    id: 'staff_2',
    collegeId: collegeId,
    name: 'Dr. Grace Hopper',
    email: 'hopper@college.edu',
    departmentId: 'dept_cs',
    designation: 'Professor',
    subjectsCanTeach: ['Mini Project', 'CS Lab', 'Compiler Design', 'Data Structures', 'Operating Systems'],
    maxClassesPerDay: 5,
    active: true,
  );

  final classroom1 = Room(
    id: 'room_cr1',
    collegeId: collegeId,
    roomNumber: 'CR-101',
    roomType: 'Classroom',
    capacity: 60,
    active: true,
  );

  final classroom2 = Room(
    id: 'room_cr2',
    collegeId: collegeId,
    roomNumber: 'CR-102',
    roomType: 'Classroom',
    capacity: 60,
    active: true,
  );

  final computerLab = Room(
    id: 'room_lab1',
    collegeId: collegeId,
    roomNumber: 'LAB-201',
    roomType: 'Computer Lab',
    capacity: 40,
    active: true,
  );

  final physicsLab = Room(
    id: 'room_lab2',
    collegeId: collegeId,
    roomNumber: 'LAB-PHYS',
    roomType: 'Physics Lab',
    capacity: 40,
    active: true,
  );

  group('Subject Model - Generic Class Venue Capability', () {
    test('allowsClassroom returns true when "class" or "classroom" is in eligibleLabIds', () {
      final sub1 = Subject(
        id: 's1',
        collegeId: collegeId,
        departmentId: 'cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'MP101',
        subjectName: 'Mini Project',
        subjectType: 'Lab',
        eligibleLabIds: ['class'],
      );
      expect(sub1.allowsClassroom, isTrue);
      expect(sub1.allowsOnlyClassroom, isTrue);
      expect(sub1.allowsPhysicalLabs, isFalse);

      final sub2 = Subject(
        id: 's2',
        collegeId: collegeId,
        departmentId: 'cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'MP102',
        subjectName: 'Seminar',
        subjectType: 'Lab',
        eligibleLabIds: ['Classroom'],
      );
      expect(sub2.allowsClassroom, isTrue);
      expect(sub2.allowsOnlyClassroom, isTrue);
      expect(sub2.allowsPhysicalLabs, isFalse);
    });

    test('allowsClassroom and allowsPhysicalLabs when both class and physical labs are selected', () {
      final sub = Subject(
        id: 's1',
        collegeId: collegeId,
        departmentId: 'cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'CSL1',
        subjectName: 'Computational Lab',
        subjectType: 'Lab',
        eligibleLabIds: ['class', 'room_lab1'],
      );
      expect(sub.allowsClassroom, isTrue);
      expect(sub.allowsOnlyClassroom, isFalse);
      expect(sub.allowsPhysicalLabs, isTrue);
    });

    test('normal lab with only physical labs disallows classroom', () {
      final sub = Subject(
        id: 's1',
        collegeId: collegeId,
        departmentId: 'cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'CSL2',
        subjectName: 'Hardware Lab',
        subjectType: 'Lab',
        eligibleLabIds: ['room_lab1'],
      );
      expect(sub.allowsClassroom, isFalse);
      expect(sub.allowsOnlyClassroom, isFalse);
      expect(sub.allowsPhysicalLabs, isTrue);
    });

    test('normal lab with empty eligibleLabIds disallows classroom', () {
      final sub = Subject(
        id: 's1',
        collegeId: collegeId,
        departmentId: 'cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'CSL3',
        subjectName: 'Default Lab',
        subjectType: 'Lab',
        eligibleLabIds: [],
      );
      expect(sub.allowsClassroom, isFalse);
      expect(sub.allowsOnlyClassroom, isFalse);
      expect(sub.allowsPhysicalLabs, isTrue);
    });
  });

  group('Explicit 14 Required Regression Tests', () {
    // 1. Existing lab-only subject still requires a compatible lab.
    test('1. Existing lab-only subject still requires a compatible lab', () {
      final sub = Subject(
        id: 'sub_lab_only',
        collegeId: collegeId,
        departmentId: 'cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'CSL101',
        subjectName: 'Data Structures Lab',
        subjectType: 'Lab',
        requiredRoomType: 'Computer Lab',
        eligibleLabIds: ['room_lab1'],
      );

      // Must be eligible in its compatible physical lab
      expect(TimetableGenerator.isRoomEligibleForSubject(room: computerLab, subject: sub), isTrue);
      // Must NOT be eligible in an arbitrary classroom
      expect(TimetableGenerator.isRoomEligibleForSubject(room: classroom1, subject: sub), isFalse);
    });

    // 2. Lab subject with Class selected can use a normal classroom.
    test('2. Lab subject with Class selected can use a normal classroom', () {
      final sub = Subject(
        id: 'sub_class_allowed',
        collegeId: collegeId,
        departmentId: 'cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'MP101',
        subjectName: 'Mini Project',
        subjectType: 'Lab',
        requiredRoomType: 'Computer Lab',
        eligibleLabIds: ['class'],
      );

      expect(TimetableGenerator.isRoomEligibleForSubject(room: classroom1, subject: sub), isTrue);
      expect(TimetableGenerator.isRoomEligibleForSubject(room: classroom2, subject: sub), isTrue);
    });

    // 3. Lab subject with only Class selected does not require a lab.
    test('3. Lab subject with only Class selected does not require a lab', () {
      final section = Section(
        id: 'sec_1',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        academicYear: '2025-2026',
        semester: 6,
        sectionName: 'A',
        studentCount: 30,
        batches: ['B1', 'B2'],
      );

      final miniProject = Subject(
        id: 'sub_mini',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'MP601',
        subjectName: 'Mini Project',
        subjectType: 'Lab',
        requiredRoomType: 'Computer Lab',
        hoursPerWeek: 4,
        consecutivePeriods: 2,
        assignedTeacherIds: [teacher1.id],
        eligibleLabIds: ['class'], // Only Class selected
      );

      // Only classrooms provided, zero physical labs
      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [miniProject],
        staffList: [teacher1],
        rooms: [classroom1, classroom2], // No physical labs!
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isTrue, reason: 'Does not require a lab and generates successfully');
      expect(result.conflicts, isEmpty);
      for (final e in result.entries) {
        expect([classroom1.id, classroom2.id], contains(e.roomId));
      }
    });

    // 4. Lab subject with Class + compatible lab can use either valid venue.
    test('4. Lab subject with Class + compatible lab can use either valid venue', () {
      final sub = Subject(
        id: 'sub_flex',
        collegeId: collegeId,
        departmentId: 'cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'FLX101',
        subjectName: 'Flexible Lab',
        subjectType: 'Lab',
        requiredRoomType: 'Computer Lab',
        eligibleLabIds: ['class', computerLab.id],
      );

      // Both classroom and computer lab are eligible
      expect(TimetableGenerator.isRoomEligibleForSubject(room: classroom1, subject: sub), isTrue);
      expect(TimetableGenerator.isRoomEligibleForSubject(room: computerLab, subject: sub), isTrue);
      // Incompatible physical lab remains ineligible
      expect(TimetableGenerator.isRoomEligibleForSubject(room: physicsLab, subject: sub), isFalse);
    });

    // 5. Lab subject without Class cannot use an arbitrary classroom.
    test('5. Lab subject without Class cannot use an arbitrary classroom', () {
      final section = Section(
        id: 'sec_1',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        academicYear: '2025-2026',
        semester: 6,
        sectionName: 'A',
        studentCount: 30,
        batches: ['B1', 'B2'],
      );

      final strictLab = Subject(
        id: 'sub_strict',
        collegeId: collegeId,
        departmentId: 'cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'ST101',
        subjectName: 'Strict Physical Lab',
        subjectType: 'Lab',
        consecutivePeriods: 1,
        requiredRoomType: 'Computer Lab',
        eligibleLabIds: ['room_lab1'], // No class!
      );

      final entry = TimetableEntry(
        id: 'e1',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts_1',
        sectionId: section.id,
        subjectId: strictLab.id,
        teacherId: teacher1.id,
        roomId: classroom1.id, // Arbitrary classroom!
        batch: 'B1',
        status: 'draft',
      );

      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: [entry],
        sections: [section],
        subjects: [strictLab],
        staffList: [teacher1],
        rooms: [classroom1],
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(validation.isValid, isFalse);
      expect(validation.hardConflicts.any((c) => c.type == 'roomTypeMismatch'), isTrue);
    });

    // 6. Classroom capacity is enforced.
    test('6. Classroom capacity is enforced', () {
      final smallClassroom = Room(
        id: 'room_small',
        collegeId: collegeId,
        roomNumber: 'CR-TINY',
        roomType: 'Classroom',
        capacity: 10,
        active: true,
      );

      final section = Section(
        id: 'sec_1',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        academicYear: '2025-2026',
        semester: 6,
        sectionName: 'A',
        studentCount: 50, // 50 students > 10 capacity
        batches: ['B1', 'B2'],
      );

      final sub = Subject(
        id: 'sub_mini',
        collegeId: collegeId,
        departmentId: 'cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'MP101',
        subjectName: 'Mini Project',
        subjectType: 'Lab',
        consecutivePeriods: 1,
        eligibleLabIds: ['class'],
      );

      final entry = TimetableEntry(
        id: 'e1',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts_1',
        sectionId: section.id,
        subjectId: sub.id,
        teacherId: teacher1.id,
        roomId: smallClassroom.id,
        batch: 'B1', // 25 students > 10 capacity
        status: 'draft',
      );

      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: [entry],
        sections: [section],
        subjects: [sub],
        staffList: [teacher1],
        rooms: [smallClassroom],
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(validation.isValid, isFalse);
      expect(validation.hardConflicts.any((c) => c.type == 'capacityConflict'), isTrue);
    });

    // 7. Classroom conflicts are detected.
    test('7. Classroom conflicts are detected', () {
      final sectionA = Section(
        id: 'sec_a',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        academicYear: '2025-2026',
        semester: 6,
        sectionName: 'A',
        studentCount: 25,
      );
      final sectionB = Section(
        id: 'sec_b',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        academicYear: '2025-2026',
        semester: 6,
        sectionName: 'B',
        studentCount: 25,
      );

      final theorySub = Subject(
        id: 'sub_theory',
        collegeId: collegeId,
        departmentId: 'cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'TH101',
        subjectName: 'Theory',
        subjectType: 'Theory',
      );

      final projectSub = Subject(
        id: 'sub_proj',
        collegeId: collegeId,
        departmentId: 'cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'PR101',
        subjectName: 'Project',
        subjectType: 'Lab',
        consecutivePeriods: 1,
        eligibleLabIds: ['class'],
      );

      final entry1 = TimetableEntry(
        id: 'e1',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts_1',
        sectionId: sectionA.id,
        subjectId: theorySub.id,
        teacherId: teacher1.id,
        roomId: classroom1.id,
        status: 'draft',
      );

      // Section B tries to use the exact same classroom at the exact same time
      final entry2 = TimetableEntry(
        id: 'e2',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts_1',
        sectionId: sectionB.id,
        subjectId: projectSub.id,
        teacherId: teacher2.id,
        roomId: classroom1.id,
        status: 'draft',
      );

      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: [entry1, entry2],
        sections: [sectionA, sectionB],
        subjects: [theorySub, projectSub],
        staffList: [teacher1, teacher2],
        rooms: [classroom1],
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(validation.isValid, isFalse);
      expect(validation.hardConflicts.any((c) => c.type == 'roomConflict'), isTrue);
    });

    // 8. Lab conflicts are still detected.
    test('8. Lab conflicts are still detected', () {
      final section = Section(
        id: 'sec_1',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        academicYear: '2025-2026',
        semester: 6,
        sectionName: 'A',
        studentCount: 30,
        batches: ['B1', 'B2'],
      );

      final labSub = Subject(
        id: 'sub_cs_lab',
        collegeId: collegeId,
        departmentId: 'cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'CS101',
        subjectName: 'CS Lab',
        subjectType: 'Lab',
        consecutivePeriods: 1,
        eligibleLabIds: [computerLab.id],
      );

      final entryB1 = TimetableEntry(
        id: 'e1',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts_1',
        sectionId: section.id,
        subjectId: labSub.id,
        teacherId: teacher1.id,
        roomId: computerLab.id,
        batch: 'B1',
        status: 'draft',
      );

      // B2 booked into the same physical lab room simultaneously
      final entryB2 = TimetableEntry(
        id: 'e2',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts_1',
        sectionId: section.id,
        subjectId: labSub.id,
        teacherId: teacher2.id,
        roomId: computerLab.id,
        batch: 'B2',
        status: 'draft',
      );

      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: [entryB1, entryB2],
        sections: [section],
        subjects: [labSub],
        staffList: [teacher1, teacher2],
        rooms: [computerLab],
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(validation.isValid, isFalse);
      expect(
        validation.hardConflicts.any((c) => c.type == 'labSameRoomConflict' || c.type == 'roomConflict'),
        isTrue,
      );
    });

    // 9. Professor conflicts still work.
    test('9. Professor conflicts still work', () {
      final sectionA = Section(
        id: 'sec_a',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        academicYear: '2025-2026',
        semester: 6,
        sectionName: 'A',
        studentCount: 25,
      );
      final sectionB = Section(
        id: 'sec_b',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        academicYear: '2025-2026',
        semester: 6,
        sectionName: 'B',
        studentCount: 25,
      );

      final subA = Subject(
        id: 'sub_a',
        collegeId: collegeId,
        departmentId: 'cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'MP1',
        subjectName: 'Project A',
        subjectType: 'Lab',
        consecutivePeriods: 1,
        eligibleLabIds: ['class'],
      );

      final subB = Subject(
        id: 'sub_b',
        collegeId: collegeId,
        departmentId: 'cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'MP2',
        subjectName: 'Project B',
        subjectType: 'Lab',
        consecutivePeriods: 1,
        eligibleLabIds: ['class'],
      );

      // Teacher 1 booked in two different classrooms at the same time
      final entry1 = TimetableEntry(
        id: 'e1',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts_1',
        sectionId: sectionA.id,
        subjectId: subA.id,
        teacherId: teacher1.id,
        roomId: classroom1.id,
        status: 'draft',
      );

      final entry2 = TimetableEntry(
        id: 'e2',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts_1',
        sectionId: sectionB.id,
        subjectId: subB.id,
        teacherId: teacher1.id,
        roomId: classroom2.id,
        status: 'draft',
      );

      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: [entry1, entry2],
        sections: [sectionA, sectionB],
        subjects: [subA, subB],
        staffList: [teacher1],
        rooms: [classroom1, classroom2],
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(validation.isValid, isFalse);
      expect(validation.hardConflicts.any((c) => c.type == 'teacherConflict'), isTrue);
    });

    // 10. Section conflicts still work.
    test('10. Section conflicts still work', () {
      final section = Section(
        id: 'sec_1',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        academicYear: '2025-2026',
        semester: 6,
        sectionName: 'A',
        studentCount: 30,
      );

      final sub1 = Subject(
        id: 'sub_1',
        collegeId: collegeId,
        departmentId: 'cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'MP1',
        subjectName: 'Project A',
        subjectType: 'Lab',
        consecutivePeriods: 1,
        eligibleLabIds: ['class'],
      );

      final sub2 = Subject(
        id: 'sub_2',
        collegeId: collegeId,
        departmentId: 'cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'TH1',
        subjectName: 'Theory B',
        subjectType: 'Theory',
      );

      // Section A scheduled for two classes at the exact same period
      final entry1 = TimetableEntry(
        id: 'e1',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts_1',
        sectionId: section.id,
        subjectId: sub1.id,
        teacherId: teacher1.id,
        roomId: classroom1.id,
        status: 'draft',
      );

      final entry2 = TimetableEntry(
        id: 'e2',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts_1',
        sectionId: section.id,
        subjectId: sub2.id,
        teacherId: teacher2.id,
        roomId: classroom2.id,
        status: 'draft',
      );

      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: [entry1, entry2],
        sections: [section],
        subjects: [sub1, sub2],
        staffList: [teacher1, teacher2],
        rooms: [classroom1, classroom2],
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(validation.isValid, isFalse);
      expect(validation.hardConflicts.any((c) => c.type == 'sectionConflict'), isTrue);
    });

    // 11. "Two Suitable Labs Required" is not incorrectly triggered when Class is a valid option.
    test('11. "Two Suitable Labs Required" is not incorrectly triggered when Class is a valid option', () {
      final section = Section(
        id: 'sec_cs',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        academicYear: '2025-2026',
        semester: 6,
        sectionName: 'A',
        studentCount: 30,
        batches: ['B1', 'B2'],
      );

      final projectSub = Subject(
        id: 'sub_proj',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'PR601',
        subjectName: 'Mini Project',
        subjectType: 'Lab',
        requiredRoomType: 'Computer Lab',
        hoursPerWeek: 4,
        consecutivePeriods: 2,
        assignedTeacherIds: [teacher1.id],
        eligibleLabIds: ['class'], // Class is allowed
      );

      // Only standard classrooms are available
      final genResult = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [projectSub],
        staffList: [teacher1],
        rooms: [classroom1, classroom2],
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(genResult.isSuccess, isTrue);
      // Ensure no false lab-requirement conflicts were triggered
      expect(
        genResult.conflicts.any(
          (c) =>
              c.title.contains('Suitable Lab') ||
              c.type == 'insufficientLabs' ||
              c.description.contains('requires two suitable labs'),
        ),
        isFalse,
      );
    });

    // 12. Existing parallel lab-batch scheduling remains unchanged.
    test('12. Existing parallel lab-batch scheduling remains unchanged', () {
      final section = Section(
        id: 'sec_cs',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        academicYear: '2025-2026',
        semester: 6,
        sectionName: 'A',
        studentCount: 30,
        batches: ['B1', 'B2'],
      );

      final labA = Subject(
        id: 'sub_lab_a',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'LA1',
        subjectName: 'Algorithms Lab',
        subjectType: 'Lab',
        requiredRoomType: 'Computer Lab',
        hoursPerWeek: 4,
        consecutivePeriods: 2,
        assignedTeacherIds: [teacher1.id],
        eligibleLabIds: [computerLab.id],
      );

      final labB = Subject(
        id: 'sub_lab_b',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'LB1',
        subjectName: 'Physics Lab',
        subjectType: 'Lab',
        requiredRoomType: 'Physics Lab',
        hoursPerWeek: 4,
        consecutivePeriods: 2,
        assignedTeacherIds: [teacher2.id],
        eligibleLabIds: [physicsLab.id],
      );

      final genResult = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [labA, labB],
        staffList: [teacher1, teacher2],
        rooms: [computerLab, physicsLab],
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(genResult.isSuccess, isTrue);
      expect(genResult.conflicts, isEmpty);
      // Batches must receive their corresponding physical lab
      for (final e in genResult.entries) {
        if (e.subjectId == labA.id) {
          expect(e.roomId, equals(computerLab.id));
        } else if (e.subjectId == labB.id) {
          expect(e.roomId, equals(physicsLab.id));
        }
      }
    });

    // 13. Existing consecutive 2-period lab/project blocks remain consecutive.
    test('13. Existing consecutive 2-period lab/project blocks remain consecutive', () {
      final section = Section(
        id: 'sec_cs',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        academicYear: '2025-2026',
        semester: 6,
        sectionName: 'A',
        studentCount: 30,
        batches: ['B1', 'B2'],
      );

      final projectSub = Subject(
        id: 'sub_proj',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'PR601',
        subjectName: 'Mini Project',
        subjectType: 'Lab',
        requiredRoomType: 'Computer Lab',
        hoursPerWeek: 4,
        consecutivePeriods: 2, // 2-period block
        assignedTeacherIds: [teacher1.id],
        eligibleLabIds: ['class'],
      );

      final genResult = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [projectSub],
        staffList: [teacher1],
        rooms: [classroom1, classroom2],
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(genResult.isSuccess, isTrue);
      // Group entries by batch and day
      final batchDayEntries = <String, List<int>>{};
      for (final e in genResult.entries) {
        final key = '${e.batch}_${e.dayOfWeek}';
        (batchDayEntries[key] ??= []).add(e.periodNumber);
      }

      for (final periods in batchDayEntries.values) {
        periods.sort();
        expect(periods.length, equals(2));
        expect(periods[1], equals(periods[0] + 1), reason: 'Must be strictly consecutive periods');
      }

      // Also verify that a non-consecutive placement in validator triggers labDurationConflict
      final brokenEntry1 = TimetableEntry(
        id: 'be1',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts_1',
        sectionId: section.id,
        subjectId: projectSub.id,
        teacherId: teacher1.id,
        roomId: classroom1.id,
        batch: 'B1',
        status: 'draft',
      );
      final brokenEntry2 = TimetableEntry(
        id: 'be2',
        collegeId: collegeId,
        versionId: 'v1',
        dayOfWeek: 'Monday',
        periodNumber: 3, // Non-consecutive (gap between 1 and 3)
        timeSlotId: 'ts_3',
        sectionId: section.id,
        subjectId: projectSub.id,
        teacherId: teacher1.id,
        roomId: classroom1.id,
        batch: 'B1',
        status: 'draft',
      );

      final brokenValidation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: [brokenEntry1, brokenEntry2],
        sections: [section],
        subjects: [projectSub],
        staffList: [teacher1],
        rooms: [classroom1],
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(brokenValidation.isValid, isFalse);
      expect(brokenValidation.hardConflicts.any((c) => c.type == 'labDurationConflict'), isTrue);
    });

    // 14. Existing subjects and timetable generation remain unchanged when Class is not selected.
    test('14. Existing subjects and timetable generation remain unchanged when Class is not selected', () {
      final section = Section(
        id: 'sec_cs',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        academicYear: '2025-2026',
        semester: 6,
        sectionName: 'A',
        studentCount: 30,
        batches: ['B1', 'B2'],
      );

      final theory1 = Subject(
        id: 'sub_th1',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'TH1',
        subjectName: 'Algorithms',
        subjectType: 'Theory',
        hoursPerWeek: 3,
        assignedTeacherIds: [teacher1.id],
      );

      final standardLab = Subject(
        id: 'sub_std_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'LAB1',
        subjectName: 'CS Lab',
        subjectType: 'Lab',
        requiredRoomType: 'Computer Lab',
        hoursPerWeek: 4,
        consecutivePeriods: 2,
        assignedTeacherIds: [teacher2.id],
        eligibleLabIds: [computerLab.id], // Standard physical lab
      );

      final genResult = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [theory1, standardLab],
        staffList: [teacher1, teacher2],
        rooms: [classroom1, computerLab],
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(genResult.isSuccess, isTrue);
      expect(genResult.conflicts, isEmpty);

      // Theory classes are in classroom
      final theoryEntries = genResult.entries.where((e) => e.subjectId == theory1.id).toList();
      expect(theoryEntries.length, equals(3));
      for (final e in theoryEntries) {
        expect(e.roomId, equals(classroom1.id));
      }

      // Lab classes are strictly in computerLab
      final labEntries = genResult.entries.where((e) => e.subjectId == standardLab.id).toList();
      expect(labEntries.length, equals(4)); // 2 batches * 2 periods = 4
      for (final e in labEntries) {
        expect(e.roomId, equals(computerLab.id));
      }
    });
  });

  group('Manual Add/Edit Class UI & Dialog Logic', () {
    test('Compatible rooms list respects Class venue and avoids arbitrary classroom bypass', () {
      final section = Section(
        id: 'sec_cs',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        academicYear: '2025-2026',
        semester: 6,
        sectionName: 'A',
        studentCount: 30,
        batches: ['B1', 'B2'],
      );

      final allRooms = [classroom1, classroom2, computerLab, physicsLab];

      // Case A: Lab subject without Class configured -> only compatible lab
      final strictLab = Subject(
        id: 's_strict',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'ST1',
        subjectName: 'Strict Lab',
        subjectType: 'Lab',
        requiredRoomType: 'Computer Lab',
        eligibleLabIds: [computerLab.id],
      );

      final roomsForStrictLab = allRooms.where((r) {
        return TimetableGenerator.isRoomEligibleForSubject(room: r, subject: strictLab, section: section);
      }).toList();

      expect(roomsForStrictLab.map((r) => r.id), contains(computerLab.id));
      expect(roomsForStrictLab.map((r) => r.id), isNot(contains(classroom1.id)));
      expect(roomsForStrictLab.map((r) => r.id), isNot(contains(classroom2.id)));
      expect(roomsForStrictLab.map((r) => r.id), isNot(contains(physicsLab.id)));

      // Case B: Lab subject with only Class configured -> classrooms only
      final classOnlyLab = Subject(
        id: 's_class_only',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'CL1',
        subjectName: 'Classroom Project',
        subjectType: 'Lab',
        requiredRoomType: 'Computer Lab',
        eligibleLabIds: ['class'],
      );

      final roomsForClassOnlyLab = allRooms.where((r) {
        return TimetableGenerator.isRoomEligibleForSubject(room: r, subject: classOnlyLab, section: section);
      }).toList();

      expect(roomsForClassOnlyLab.map((r) => r.id), containsAll([classroom1.id, classroom2.id]));
      expect(roomsForClassOnlyLab.map((r) => r.id), isNot(contains(computerLab.id)));
      expect(roomsForClassOnlyLab.map((r) => r.id), isNot(contains(physicsLab.id)));

      // Case C: Lab subject with Class + physical lab -> both classroom and physical lab available
      final flexLab = Subject(
        id: 's_flex',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'FX1',
        subjectName: 'Flex Lab',
        subjectType: 'Lab',
        requiredRoomType: 'Computer Lab',
        eligibleLabIds: ['class', computerLab.id],
      );

      final roomsForFlexLab = allRooms.where((r) {
        return TimetableGenerator.isRoomEligibleForSubject(room: r, subject: flexLab, section: section);
      }).toList();

      expect(roomsForFlexLab.map((r) => r.id), containsAll([classroom1.id, classroom2.id, computerLab.id]));
      expect(roomsForFlexLab.map((r) => r.id), isNot(contains(physicsLab.id)));
    });

    testWidgets('Class checkbox renders and toggles class venue in subjectEligibleLabs', (tester) async {
      final sub = Subject(
        id: 'sub_mini',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c1',
        semester: 6,
        subjectCode: 'MP101',
        subjectName: 'Mini Project',
        subjectType: 'Lab',
        requiredRoomType: 'Computer Lab',
        eligibleLabIds: ['class'],
      );

      final subjectEligibleLabs = <String, Set<String>>{
        sub.id: Set<String>.from(sub.eligibleLabIds),
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setDialogState) {
                final assignedLabIds = subjectEligibleLabs[sub.id] ?? <String>{};
                return Column(
                  children: [
                    const Text('Compatible venues:'),
                    CheckboxListTile(
                      key: const Key('class_venue_checkbox'),
                      value: assignedLabIds.any((id) =>
                          id.toLowerCase() == 'class' ||
                          id.toLowerCase() == 'classroom'),
                      title: const Text('Class'),
                      subtitle: const Text('Allow conducting in a normal classroom instead of requiring a physical laboratory'),
                      onChanged: (val) {
                        setDialogState(() {
                          subjectEligibleLabs.putIfAbsent(sub.id, () => <String>{});
                          if (val == true) {
                            subjectEligibleLabs[sub.id]!.add(Subject.classVenueId);
                          } else {
                            subjectEligibleLabs[sub.id]!.removeWhere((id) =>
                                id.toLowerCase() == 'class' ||
                                id.toLowerCase() == 'classroom');
                          }
                        });
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Verify initially checked because eligibleLabIds contained 'class'
      expect(find.text('Class'), findsOneWidget);
      expect(find.text('Compatible venues:'), findsOneWidget);
      final checkboxFinder = find.byKey(const Key('class_venue_checkbox'));
      expect(checkboxFinder, findsOneWidget);

      final CheckboxListTile initialTile = tester.widget(checkboxFinder);
      expect(initialTile.value, isTrue);

      // Uncheck it
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      expect(subjectEligibleLabs[sub.id]!.contains('class'), isFalse);
      final CheckboxListTile uncheckedTile = tester.widget(checkboxFinder);
      expect(uncheckedTile.value, isFalse);

      // Check it again
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      expect(subjectEligibleLabs[sub.id]!.contains('class'), isTrue);
      final CheckboxListTile recheckedTile = tester.widget(checkboxFinder);
      expect(recheckedTile.value, isTrue);
    });
  });
}
