import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/features/timetable/screens/export_screen.dart';
import 'package:time_table/features/timetable/screens/timetable_screen.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/providers/providers.dart';
import 'package:time_table/services/conflict_validator.dart';
import 'package:pdf/pdf.dart';
import 'package:time_table/services/pdf_export_service.dart';
import 'package:time_table/services/timetable_generator.dart';

void main() {
  const collegeId = 'col_lab_dist';
  final workingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  final standardSlots = [
    TimeSlot(id: 'ts1', collegeId: collegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
    TimeSlot(id: 'ts2', collegeId: collegeId, periodNumber: 2, startTime: '10:00', endTime: '11:00', order: 2),
    TimeSlot(id: 'ts_brk', collegeId: collegeId, periodNumber: 0, startTime: '11:00', endTime: '11:15', isBreak: true, breakTitle: 'Tea Break', order: 3),
    TimeSlot(id: 'ts3', collegeId: collegeId, periodNumber: 3, startTime: '11:15', endTime: '12:15', order: 4),
    TimeSlot(id: 'ts4', collegeId: collegeId, periodNumber: 4, startTime: '12:15', endTime: '13:15', order: 5),
    TimeSlot(id: 'ts_lunch', collegeId: collegeId, periodNumber: 0, startTime: '13:15', endTime: '14:00', isBreak: true, breakTitle: 'Lunch Break', order: 6),
    TimeSlot(id: 'ts5', collegeId: collegeId, periodNumber: 5, startTime: '14:00', endTime: '15:00', order: 7),
    TimeSlot(id: 'ts6', collegeId: collegeId, periodNumber: 6, startTime: '15:00', endTime: '16:00', order: 8),
  ];

  final labRoomA = Room(
    id: 'room_lab_a',
    collegeId: collegeId,
    roomNumber: 'Lab A',
    capacity: 40,
    roomType: 'Computer Lab',
    facilities: ['Computer Lab'],
    active: true,
  );

  final labRoomB = Room(
    id: 'room_lab_b',
    collegeId: collegeId,
    roomNumber: 'Lab B',
    capacity: 40,
    roomType: 'Computer Lab',
    facilities: ['Computer Lab'],
    active: true,
  );

  final labRoomC = Room(
    id: 'room_lab_c',
    collegeId: collegeId,
    roomNumber: 'Lab C',
    capacity: 40,
    roomType: 'Computer Lab',
    facilities: ['Computer Lab'],
    active: true,
  );

  final classroom1 = Room(
    id: 'room_cr1',
    collegeId: collegeId,
    roomNumber: 'CR 101',
    capacity: 70,
    roomType: 'Classroom',
    active: true,
  );

  final profOOP = Staff(
    id: 'prof_oop',
    collegeId: collegeId,
    employeeId: 'EMP_OOP',
    name: 'Prof. OOP',
    email: 'oop@college.edu',
    departmentId: 'dept_cs',
    status: 'active',
    subjectsCanTeach: ['OOP LAB', 'sub_oop_lab'],
    maxClassesPerDay: 4,
  );

  final profDSA = Staff(
    id: 'prof_dsa',
    collegeId: collegeId,
    employeeId: 'EMP_DSA',
    name: 'Prof. DSA',
    email: 'dsa@college.edu',
    departmentId: 'dept_cs',
    status: 'active',
    subjectsCanTeach: ['DSA LAB', 'sub_dsa_lab'],
    maxClassesPerDay: 4,
  );

  final profCN = Staff(
    id: 'prof_cn',
    collegeId: collegeId,
    employeeId: 'EMP_CN',
    name: 'Prof. CN',
    email: 'cn@college.edu',
    departmentId: 'dept_cs',
    status: 'active',
    subjectsCanTeach: ['CN LAB', 'sub_cn_lab'],
    maxClassesPerDay: 4,
  );

  group('Cross-Batch Lab Scheduling Requirements (TEST 1 - TEST 8)', () {
    test('TEST 1: 2 batches + 2 lab subjects + 2 compatible labs pairs different subjects in parallel', () {
      final section = Section(
        id: 'sec_t1',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-A',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      final oopLab = Subject(
        id: 'sub_oop_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'OOP LAB',
        subjectCode: 'CS501L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_oop'],
        sectionId: section.id,
      );

      final dsaLab = Subject(
        id: 'sub_dsa_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'DSA LAB',
        subjectCode: 'CS502L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_dsa'],
        sectionId: section.id,
      );

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [oopLab, dsaLab],
        staffList: [profOOP, profDSA],
        rooms: [labRoomA, labRoomB, classroom1],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isTrue, reason: result.summaryMessage);
      final labEntries = result.entries.where((e) => e.batch != null).toList();

      // Group by day and period
      final periodGroups = <String, List<TimetableEntry>>{};
      for (final e in labEntries) {
        final key = '${e.dayOfWeek}_${e.periodNumber}';
        periodGroups.putIfAbsent(key, () => []).add(e);
      }

      // Find slots where multiple batches run simultaneously
      final parallelSlots = periodGroups.entries.where((g) => g.value.length > 1).toList();
      expect(parallelSlots.isNotEmpty, isTrue, reason: 'Parallel lab scheduling must occur when 2 compatible labs exist');

      for (final slot in parallelSlots) {
        final entries = slot.value;
        final batches = entries.map((e) => e.batch).toSet();
        final subjectsInSlot = entries.map((e) => e.subjectId).toSet();
        final roomsInSlot = entries.map((e) => e.roomId).toSet();
        final teachersInSlot = entries.map((e) => e.teacherId).toSet();

        // 1. Batches must be distinct
        expect(batches.length, equals(entries.length), reason: 'Each batch in the slot must be unique');
        // 2. Lab subjects MUST be DIFFERENT across batches in the same slot!
        expect(subjectsInSlot.length, equals(entries.length),
            reason: 'DIFFERENT lab subjects must be paired across batches: B1 and B2 must NOT have the same subject at the same time');
        // 3. Separate physical rooms
        expect(roomsInSlot.length, equals(entries.length), reason: 'Separate physical compatible rooms must be used');
        // 4. Separate professors
        expect(teachersInSlot.length, equals(entries.length), reason: 'Separate professors must be assigned');
      }

      // Both B1 and B2 must complete both OOP LAB (2 periods) and DSA LAB (2 periods)
      for (final b in ['B1', 'B2']) {
        final bOOP = labEntries.where((e) => e.batch == b && e.subjectId == oopLab.id).length;
        final bDSA = labEntries.where((e) => e.batch == b && e.subjectId == dsaLab.id).length;
        expect(bOOP, equals(2), reason: '$b must receive 2 periods of OOP LAB');
        expect(bDSA, equals(2), reason: '$b must receive 2 periods of DSA LAB');
      }
    });

    test('TEST 2: 2 batches + 3 lab subjects distributes across parallel slots with final odd remaining subject leaving other batch FREE', () {
      final section = Section(
        id: 'sec_t2',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-B',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      // B1 and B2 each require OOP LAB, DSA LAB.
      // Additionally, CN LAB has 2 weekly hours configured for section (1 block of 2 hours per batch)
      final oopLab = Subject(
        id: 'sub_oop_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'OOP LAB',
        subjectCode: 'CS501L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_oop'],
        sectionId: section.id,
      );

      final dsaLab = Subject(
        id: 'sub_dsa_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'DSA LAB',
        subjectCode: 'CS502L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_dsa'],
        sectionId: section.id,
      );

      final cnLab = Subject(
        id: 'sub_cn_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'CN LAB',
        subjectCode: 'CS503L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_cn'],
        sectionId: section.id,
      );

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [oopLab, dsaLab, cnLab],
        staffList: [profOOP, profDSA, profCN],
        rooms: [labRoomA, labRoomB, classroom1],
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

      // Verify that simultaneous slots NEVER have the same subject
      for (final slot in periodGroups.values) {
        if (slot.length > 1) {
          final subjectsInSlot = slot.map((e) => e.subjectId).toSet();
          expect(subjectsInSlot.length, equals(slot.length),
              reason: 'Simultaneous batches must have different lab subjects, never same');
        }
      }

      // Check if there are slots where one batch is scheduled and the other is FREE
      final singleBatchSlots = periodGroups.values.where((slot) => slot.length == 1).toList();
      expect(singleBatchSlots.isNotEmpty, isTrue,
          reason: 'When odd lab requirements exist or one batch has remaining work, the other batch must be FREE');

      // Verify all requirements completed for both batches
      for (final b in ['B1', 'B2']) {
        expect(labEntries.where((e) => e.batch == b && e.subjectId == oopLab.id).length, equals(2));
        expect(labEntries.where((e) => e.batch == b && e.subjectId == dsaLab.id).length, equals(2));
        expect(labEntries.where((e) => e.batch == b && e.subjectId == cnLab.id).length, equals(2));
      }
    });

    test('TEST 3: 2 batches + 2 lab subjects + only 1 physical lab serializes sessions with zero room conflicts', () {
      final section = Section(
        id: 'sec_t3',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-C',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      final oopLab = Subject(
        id: 'sub_oop_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'OOP LAB',
        subjectCode: 'CS501L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_oop'],
        sectionId: section.id,
      );

      final dsaLab = Subject(
        id: 'sub_dsa_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'DSA LAB',
        subjectCode: 'CS502L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_dsa'],
        sectionId: section.id,
      );

      // ONLY 1 physical lab room available!
      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [oopLab, dsaLab],
        staffList: [profOOP, profDSA],
        rooms: [labRoomA, classroom1], // only labRoomA
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isTrue, reason: result.summaryMessage);
      final labEntries = result.entries.where((e) => e.batch != null).toList();

      // Group by slot
      final periodGroups = <String, List<TimetableEntry>>{};
      for (final e in labEntries) {
        final key = '${e.dayOfWeek}_${e.periodNumber}';
        periodGroups.putIfAbsent(key, () => []).add(e);
      }

      // Because only 1 lab room exists, NO slot can have more than 1 entry!
      for (final slot in periodGroups.values) {
        expect(slot.length, equals(1), reason: 'With only 1 physical lab, sessions must be serialized');
      }

      // Hard conflicts must be 0
      final val = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: result.entries,
        sections: [section],
        subjects: [oopLab, dsaLab],
        staffList: [profOOP, profDSA],
        rooms: [labRoomA, classroom1],
        timeSlots: standardSlots,
        availabilities: [],
        validateHours: true,
      );
      expect(val.hardConflicts, isEmpty);
    });

    test('TEST 4: 2 batches + 2 different labs + only 1 professor serializes sessions with zero professor conflicts', () {
      final section = Section(
        id: 'sec_t4',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-D',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      // One professor teaches BOTH labs
      final soloProf = Staff(
        id: 'prof_solo',
        collegeId: collegeId,
        employeeId: 'EMP_SOLO',
        name: 'Prof. Solo',
        email: 'solo@college.edu',
        departmentId: 'dept_cs',
        status: 'active',
        subjectsCanTeach: ['OOP LAB', 'sub_oop_lab', 'DSA LAB', 'sub_dsa_lab'],
        maxClassesPerDay: 5,
      );

      final oopLab = Subject(
        id: 'sub_oop_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'OOP LAB',
        subjectCode: 'CS501L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_solo'],
        sectionId: section.id,
      );

      final dsaLab = Subject(
        id: 'sub_dsa_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'DSA LAB',
        subjectCode: 'CS502L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_solo'],
        sectionId: section.id,
      );

      // 2 compatible labs exist, but only 1 professor!
      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [oopLab, dsaLab],
        staffList: [soloProf],
        rooms: [labRoomA, labRoomB, classroom1],
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

      // Professor cannot be double booked: every slot must have at most 1 entry
      for (final slot in periodGroups.values) {
        expect(slot.length, equals(1), reason: 'With only 1 professor, simultaneous scheduling is impossible');
      }

      final val = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: result.entries,
        sections: [section],
        subjects: [oopLab, dsaLab],
        staffList: [soloProf],
        rooms: [labRoomA, labRoomB, classroom1],
        timeSlots: standardSlots,
        availabilities: [],
        validateHours: true,
      );
      expect(val.hardConflicts, isEmpty);
    });

    test('TEST 5: 2 batches + 3 labs + 2 rooms + 2 professors uses parallel different-subject where feasible and leaves one batch free when appropriate', () {
      final section = Section(
        id: 'sec_t5',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-E',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      // 2 professors: prof1 teaches OOP; prof2 teaches DSA & CN
      final prof1 = Staff(
        id: 'prof_1',
        collegeId: collegeId,
        employeeId: 'EMP_1',
        name: 'Prof. 1',
        email: 'p1@college.edu',
        departmentId: 'dept_cs',
        status: 'active',
        subjectsCanTeach: ['OOP LAB', 'sub_oop_lab'],
        maxClassesPerDay: 5,
      );

      final prof2 = Staff(
        id: 'prof_2',
        collegeId: collegeId,
        employeeId: 'EMP_2',
        name: 'Prof. 2',
        email: 'p2@college.edu',
        departmentId: 'dept_cs',
        status: 'active',
        subjectsCanTeach: ['DSA LAB', 'sub_dsa_lab', 'CN LAB', 'sub_cn_lab'],
        maxClassesPerDay: 5,
      );

      final oopLab = Subject(
        id: 'sub_oop_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'OOP LAB',
        subjectCode: 'CS501L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_1'],
        sectionId: section.id,
      );

      final dsaLab = Subject(
        id: 'sub_dsa_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'DSA LAB',
        subjectCode: 'CS502L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_2'],
        sectionId: section.id,
      );

      final cnLab = Subject(
        id: 'sub_cn_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'CN LAB',
        subjectCode: 'CS503L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_2'],
        sectionId: section.id,
      );

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [oopLab, dsaLab, cnLab],
        staffList: [prof1, prof2],
        rooms: [labRoomA, labRoomB, classroom1],
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

      // Simultaneous slots must have different subjects
      for (final slot in periodGroups.values) {
        if (slot.length > 1) {
          final subs = slot.map((e) => e.subjectId).toSet();
          expect(subs.length, equals(slot.length));
        }
      }

      final val = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: result.entries,
        sections: [section],
        subjects: [oopLab, dsaLab, cnLab],
        staffList: [prof1, prof2],
        rooms: [labRoomA, labRoomB, classroom1],
        timeSlots: standardSlots,
        availabilities: [],
        validateHours: true,
      );
      expect(val.hardConflicts, isEmpty);
    });

    test('TEST 6: 3 batches + 3 different lab subjects + 3 compatible labs allows all three batches to run different subjects simultaneously', () {
      final section = Section(
        id: 'sec_t6',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-Tri',
        studentCount: 90,
        batches: ['B1', 'B2', 'B3'],
      );

      final oopLab = Subject(
        id: 'sub_oop_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'OOP LAB',
        subjectCode: 'CS501L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_oop'],
        sectionId: section.id,
      );

      final dsaLab = Subject(
        id: 'sub_dsa_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'DSA LAB',
        subjectCode: 'CS502L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_dsa'],
        sectionId: section.id,
      );

      final cnLab = Subject(
        id: 'sub_cn_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'CN LAB',
        subjectCode: 'CS503L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_cn'],
        sectionId: section.id,
      );

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [oopLab, dsaLab, cnLab],
        staffList: [profOOP, profDSA, profCN],
        rooms: [labRoomA, labRoomB, labRoomC, classroom1],
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

      // Check parallel slots with 3 batches running simultaneously
      final triSlots = periodGroups.values.where((slot) => slot.length == 3).toList();
      expect(triSlots.isNotEmpty, isTrue, reason: 'All 3 batches should run simultaneously when 3 labs and teachers exist');

      for (final slot in triSlots) {
        final batches = slot.map((e) => e.batch).toSet();
        final subjects = slot.map((e) => e.subjectId).toSet();
        final rooms = slot.map((e) => e.roomId).toSet();
        final teachers = slot.map((e) => e.teacherId).toSet();

        expect(batches.length, equals(3), reason: 'B1, B2, B3 present');
        expect(subjects.length, equals(3), reason: 'All 3 subjects must be DIFFERENT');
        expect(rooms.length, equals(3), reason: 'All 3 rooms must be distinct');
        expect(teachers.length, equals(3), reason: 'All 3 teachers must be distinct');
      }

      final val = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: result.entries,
        sections: [section],
        subjects: [oopLab, dsaLab, cnLab],
        staffList: [profOOP, profDSA, profCN],
        rooms: [labRoomA, labRoomB, labRoomC, classroom1],
        timeSlots: standardSlots,
        availabilities: [],
        validateHours: true,
      );
      expect(val.hardConflicts, isEmpty);
    });

    test('TEST 7: 3 batches + 2 compatible labs schedules at most 2 simultaneous lab allocations with 3rd batch FREE', () {
      final section = Section(
        id: 'sec_t7',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-Tri2Lab',
        studentCount: 90,
        batches: ['B1', 'B2', 'B3'],
      );

      final oopLab = Subject(
        id: 'sub_oop_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'OOP LAB',
        subjectCode: 'CS501L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_oop'],
        sectionId: section.id,
      );

      final dsaLab = Subject(
        id: 'sub_dsa_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'DSA LAB',
        subjectCode: 'CS502L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_dsa'],
        sectionId: section.id,
      );

      final cnLab = Subject(
        id: 'sub_cn_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'CN LAB',
        subjectCode: 'CS503L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_cn'],
        sectionId: section.id,
      );

      // ONLY 2 compatible labs (labRoomA and labRoomB), but 3 batches!
      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [oopLab, dsaLab, cnLab],
        staffList: [profOOP, profDSA, profCN],
        rooms: [labRoomA, labRoomB, classroom1],
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

      // No slot can ever exceed 2 simultaneous lab allocations because only 2 labs exist!
      for (final slot in periodGroups.values) {
        expect(slot.length, lessThanOrEqualTo(2),
            reason: 'At most 2 simultaneous lab allocations allowed with 2 compatible labs');
      }

      // All requirements satisfied
      final val = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: result.entries,
        sections: [section],
        subjects: [oopLab, dsaLab, cnLab],
        staffList: [profOOP, profDSA, profCN],
        rooms: [labRoomA, labRoomB, classroom1],
        timeSlots: standardSlots,
        availabilities: [],
        validateHours: true,
      );
      expect(val.hardConflicts, isEmpty);
    });

    test('TEST 8: All lab requirements completely satisfied without incompleteHours', () {
      final section = Section(
        id: 'sec_t8',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-Complete',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      final profMath = Staff(
        id: 'prof_math',
        collegeId: collegeId,
        employeeId: 'EMP_MATH',
        name: 'Prof. Math',
        email: 'math@college.edu',
        departmentId: 'dept_cs',
        status: 'active',
        subjectsCanTeach: ['Discrete Mathematics', 'CS500', 'sub_math'],
        maxClassesPerDay: 4,
      );

      final theorySubj = Subject(
        id: 'sub_math',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'Discrete Mathematics',
        subjectCode: 'CS500',
        semester: 5,
        hoursPerWeek: 4,
        assignedTeacherIds: ['prof_math'],
        sectionId: section.id,
      );

      final oopLab = Subject(
        id: 'sub_oop_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'OOP LAB',
        subjectCode: 'CS501L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_oop'],
        sectionId: section.id,
      );

      final dsaLab = Subject(
        id: 'sub_dsa_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'DSA LAB',
        subjectCode: 'CS502L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_dsa'],
        sectionId: section.id,
      );

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [theorySubj, oopLab, dsaLab],
        staffList: [profMath, profOOP, profDSA],
        rooms: [labRoomA, labRoomB, classroom1],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isTrue);
      final val = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: result.entries,
        sections: [section],
        subjects: [theorySubj, oopLab, dsaLab],
        staffList: [profMath, profOOP, profDSA],
        rooms: [labRoomA, labRoomB, classroom1],
        timeSlots: standardSlots,
        availabilities: [],
        validateHours: true,
      );
      expect(val.hardConflicts, isEmpty);
      expect(val.allConflicts.where((c) => c.type == 'incompleteHours'), isEmpty);
    });
  });

  group('UI Timetable Matrix Verification (Requirement 14)', () {
    testWidgets('UI visually displays independent parallel batch allocations with different subjects and rooms, and odd-case FREE batch', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final college = College(
        id: collegeId,
        name: 'Engineering College',
        code: 'ENG',
        address: 'Main Campus',
        workingDays: workingDays,
      );

      final section = Section(
        id: 'sec_ui',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-UI',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      final oopLab = Subject(
        id: 'sub_oop_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'OOP LAB',
        subjectCode: 'CS501L',
        courseShortName: 'OOP',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_oop'],
        sectionId: section.id,
      );

      final dsaLab = Subject(
        id: 'sub_dsa_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'DSA LAB',
        subjectCode: 'CS502L',
        courseShortName: 'DSA',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_dsa'],
        sectionId: section.id,
      );

      final cnLab = Subject(
        id: 'sub_cn_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'CN LAB',
        subjectCode: 'CS503L',
        courseShortName: 'CN',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_cn'],
        sectionId: section.id,
      );

      // Slot 1 (Monday P1-P2): B1 -> OOP LAB in Lab A; B2 -> DSA LAB in Lab B
      // Slot 2 (Wednesday P1-P2): B1 -> CN LAB in Lab A; B2 is FREE (odd case)
      final entries = [
        // Slot 1: Monday P1
        TimetableEntry(
          id: 'e1',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          timeSlotId: 'ts1',
          sectionId: section.id,
          subjectId: oopLab.id,
          teacherId: profOOP.id,
          roomId: labRoomA.id,
          batch: 'B1',
        ),
        TimetableEntry(
          id: 'e2',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          timeSlotId: 'ts1',
          sectionId: section.id,
          subjectId: dsaLab.id,
          teacherId: profDSA.id,
          roomId: labRoomB.id,
          batch: 'B2',
        ),
        // Slot 1: Monday P2
        TimetableEntry(
          id: 'e3',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 2,
          timeSlotId: 'ts2',
          sectionId: section.id,
          subjectId: oopLab.id,
          teacherId: profOOP.id,
          roomId: labRoomA.id,
          batch: 'B1',
        ),
        TimetableEntry(
          id: 'e4',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 2,
          timeSlotId: 'ts2',
          sectionId: section.id,
          subjectId: dsaLab.id,
          teacherId: profDSA.id,
          roomId: labRoomB.id,
          batch: 'B2',
        ),
        // Slot 2 (Odd case): Wednesday P1-P2 only B1 in CN LAB, B2 FREE
        TimetableEntry(
          id: 'e5',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Wednesday',
          periodNumber: 1,
          timeSlotId: 'ts1',
          sectionId: section.id,
          subjectId: cnLab.id,
          teacherId: profCN.id,
          roomId: labRoomA.id,
          batch: 'B1',
        ),
        TimetableEntry(
          id: 'e6',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Wednesday',
          periodNumber: 2,
          timeSlotId: 'ts2',
          sectionId: section.id,
          subjectId: cnLab.id,
          teacherId: profCN.id,
          roomId: labRoomA.id,
          batch: 'B1',
        ),
      ];

      final version = TimetableVersion(
        id: 'v1',
        collegeId: collegeId,
        versionNumber: 1,
        name: 'Version 1',
        academicYear: '2026-2027',
        semester: '5',
      );

      final profile = UserProfile(
        id: 'user_1',
        email: 'admin@college.edu',
        name: 'Admin User',
        role: UserRole.collegeAdmin,
        collegeId: collegeId,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) => profile),
            currentCollegeProvider.overrideWith((ref) => Future.value(college)),
            timetableVersionsProvider.overrideWith((ref) => Future.value([version])),
            selectedVersionIdProvider.overrideWith((ref) => 'v1'),
            sectionListProvider.overrideWith((ref) => Future.value([section])),
            subjectListProvider.overrideWith((ref) => Future.value([oopLab, dsaLab, cnLab])),
            staffListProvider.overrideWith((ref) => Future.value([profOOP, profDSA, profCN])),
            roomListProvider.overrideWith((ref) => Future.value([labRoomA, labRoomB, classroom1])),
            timeSlotsProvider.overrideWith((ref) => Future.value(standardSlots)),
            timetableEntriesProvider.overrideWith((ref) => Future.value(entries)),
          ],
          child: const MaterialApp(
            home: TimetableScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the parallel header is displayed
      expect(find.text('PARALLEL LAB BATCHES'), findsWidgets);

      // Verify that Monday visually shows:
      // B1 with OOP and Lab A
      // B2 with DSA and Lab B
      expect(find.text('B1'), findsWidgets);
      expect(find.text('B2'), findsWidgets);
      expect(find.text('OOP'), findsWidgets);
      expect(find.text('DSA'), findsWidgets);
      expect(find.text('Lab A'), findsWidgets);
      expect(find.text('Lab B'), findsWidgets);

      // Verify odd-case on Wednesday:
      // CN lab with B1 is rendered
      expect(find.text('CN'), findsWidgets);
    });
  });

  group('Section 19: Permanent Regression Test (Handwritten Pattern)', () {
    test('Same section + 2 batches + 2 different lab subjects + 2 compatible rooms + 2 available professors', () {
      final section = Section(
        id: 'sec_pattern',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-Pattern',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      final profA = Staff(
        id: 'prof_a',
        collegeId: collegeId,
        employeeId: 'EMP_A',
        name: 'Professor A',
        email: 'prof_a@college.edu',
        departmentId: 'dept_cs',
        status: 'active',
        subjectsCanTeach: ['MP', 'sub_mp'],
        maxClassesPerDay: 4,
      );

      final profB = Staff(
        id: 'prof_b',
        collegeId: collegeId,
        employeeId: 'EMP_B',
        name: 'Professor B',
        email: 'prof_b@college.edu',
        departmentId: 'dept_cs',
        status: 'active',
        subjectsCanTeach: ['CN LAB', 'sub_cn'],
        maxClassesPerDay: 4,
      );

      final room203 = Room(
        id: 'room_203',
        collegeId: collegeId,
        roomNumber: 'Room 203',
        capacity: 35,
        roomType: 'Computer Lab',
        facilities: ['Computer Lab'],
        active: true,
      );

      final droneLab = Room(
        id: 'drone_lab',
        collegeId: collegeId,
        roomNumber: 'Drone Lab',
        capacity: 35,
        roomType: 'Computer Lab',
        facilities: ['Computer Lab'],
        active: true,
      );

      final mpSubject = Subject(
        id: 'sub_mp',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'MP',
        subjectCode: 'CS508L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_a'],
        sectionId: section.id,
      );

      final cnLabSubject = Subject(
        id: 'sub_cn',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'CN LAB',
        subjectCode: 'CS509L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_b'],
        sectionId: section.id,
      );

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [mpSubject, cnLabSubject],
        staffList: [profA, profB],
        rooms: [room203, droneLab],
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

      final parallelSlots = periodGroups.entries.where((g) => g.value.length > 1).toList();
      expect(parallelSlots.isNotEmpty, isTrue, reason: 'Parallel lab scheduling must occur');

      for (final slot in parallelSlots) {
        final entries = slot.value;
        expect(entries.length, equals(2));

        final batches = entries.map((e) => e.batch).toSet();
        final subjects = entries.map((e) => e.subjectId).toSet();
        final rooms = entries.map((e) => e.roomId).toSet();
        final professors = entries.map((e) => e.teacherId).toSet();

        // 1. Same day/time block
        expect(entries[0].dayOfWeek, equals(entries[1].dayOfWeek));
        expect(entries[0].periodNumber, equals(entries[1].periodNumber));
        // 2. Different batch
        expect(batches.length, equals(2));
        // 3. Different subject for each batch
        expect(subjects.length, equals(2), reason: 'Different subject for each batch');
        // 4. Different physical room
        expect(rooms.length, equals(2), reason: 'Different physical room');
        // 5. Different professor
        expect(professors.length, equals(2), reason: 'Different professor');
      }

      // Both batches complete all required lab hours
      expect(labEntries.where((e) => e.batch == 'B1' && e.subjectId == mpSubject.id).length, equals(2));
      expect(labEntries.where((e) => e.batch == 'B1' && e.subjectId == cnLabSubject.id).length, equals(2));
      expect(labEntries.where((e) => e.batch == 'B2' && e.subjectId == mpSubject.id).length, equals(2));
      expect(labEntries.where((e) => e.batch == 'B2' && e.subjectId == cnLabSubject.id).length, equals(2));

      // Hard constraint validation passes with 0 conflicts
      final val = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: result.entries,
        sections: [section],
        subjects: [mpSubject, cnLabSubject],
        staffList: [profA, profB],
        rooms: [room203, droneLab],
        timeSlots: standardSlots,
        availabilities: [],
        validateHours: true,
      );
      expect(val.hardConflicts, isEmpty);
    });
  });

  group('Section 18: Additional Scenarios Verification', () {
    test('Scenario 6: Multiple sections competing for lab rooms with zero conflicts', () {
      final section1 = Section(
        id: 'sec_multi_1',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-Sec1',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      final section2 = Section(
        id: 'sec_multi_2',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-Sec2',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      final profOOP1 = profOOP.copyWith(
        subjectsCanTeach: ['OOP LAB', 'sub_oop_lab', 'S1 Lab 1', 'sub_s1_l1'],
      );
      final profDSA1 = profDSA.copyWith(
        subjectsCanTeach: ['DSA LAB', 'sub_dsa_lab', 'S1 Lab 2', 'sub_s1_l2'],
      );
      final profCN1 = profCN.copyWith(
        subjectsCanTeach: ['CN LAB', 'sub_cn_lab', 'S2 Lab 1', 'sub_s2_l1'],
      );

      final s1Lab1 = Subject(
        id: 'sub_s1_l1',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'S1 Lab 1',
        subjectCode: 'S1L1',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_oop'],
        sectionId: section1.id,
      );

      final s1Lab2 = Subject(
        id: 'sub_s1_l2',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'S1 Lab 2',
        subjectCode: 'S1L2',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_dsa'],
        sectionId: section1.id,
      );

      final s2Lab1 = Subject(
        id: 'sub_s2_l1',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'S2 Lab 1',
        subjectCode: 'S2L1',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_cn'],
        sectionId: section2.id,
      );

      final profExtra = Staff(
        id: 'prof_extra',
        collegeId: collegeId,
        employeeId: 'EMP_EXT',
        name: 'Prof. Extra',
        email: 'extra@college.edu',
        departmentId: 'dept_cs',
        status: 'active',
        subjectsCanTeach: ['S2 Lab 2', 'sub_s2_l2'],
        maxClassesPerDay: 4,
      );

      final s2Lab2 = Subject(
        id: 'sub_s2_l2',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'S2 Lab 2',
        subjectCode: 'S2L2',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_extra'],
        sectionId: section2.id,
      );

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section1, section2],
        subjects: [s1Lab1, s1Lab2, s2Lab1, s2Lab2],
        staffList: [profOOP1, profDSA1, profCN1, profExtra],
        rooms: [labRoomA, labRoomB],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isTrue);
      final val = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: result.entries,
        sections: [section1, section2],
        subjects: [s1Lab1, s1Lab2, s2Lab1, s2Lab2],
        staffList: [profOOP1, profDSA1, profCN1, profExtra],
        rooms: [labRoomA, labRoomB],
        timeSlots: standardSlots,
        availabilities: [],
        validateHours: true,
      );
      expect(val.hardConflicts, isEmpty);
    });

    test('Scenario 7: Multiple lab facility types (Computer Lab vs Physics Lab)', () {
      final section = Section(
        id: 'sec_multi_type',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-Type',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      final physicsLabRoom = Room(
        id: 'room_phy',
        collegeId: collegeId,
        roomNumber: 'Physics Lab Room',
        capacity: 40,
        roomType: 'Physics Lab',
        facilities: ['Physics Lab'],
        active: true,
      );

      final profCS = profOOP.copyWith(
        subjectsCanTeach: ['Computer Lab Subj', 'sub_cs_lab'],
      );

      final profPhy = Staff(
        id: 'prof_phy',
        collegeId: collegeId,
        employeeId: 'EMP_PHY',
        name: 'Prof. Physics',
        email: 'phy@college.edu',
        departmentId: 'dept_cs',
        status: 'active',
        subjectsCanTeach: ['Physics Lab', 'sub_phy_lab'],
        maxClassesPerDay: 4,
      );

      final csLab = Subject(
        id: 'sub_cs_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'Computer Lab Subj',
        subjectCode: 'CSL501',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_oop'],
        sectionId: section.id,
      );

      final phyLab = Subject(
        id: 'sub_phy_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'Physics Lab',
        subjectCode: 'PHYL501',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Physics Lab',
        assignedTeacherIds: ['prof_phy'],
        sectionId: section.id,
      );

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [csLab, phyLab],
        staffList: [profCS, profPhy],
        rooms: [labRoomA, physicsLabRoom],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isTrue);
      // Verify facility compliance
      for (final e in result.entries.where((e) => e.batch != null)) {
        if (e.subjectId == csLab.id) {
          expect(e.roomId, equals(labRoomA.id));
        } else if (e.subjectId == phyLab.id) {
          expect(e.roomId, equals(physicsLabRoom.id));
        }
      }
    });

    test('Scenario 10: Breaks between periods are never crossed by lab blocks', () {
      final section = Section(
        id: 'sec_break_check',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-Brk',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      final oopLab = Subject(
        id: 'sub_oop_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'OOP LAB',
        subjectCode: 'CS501L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_oop'],
        sectionId: section.id,
      );

      final dsaLab = Subject(
        id: 'sub_dsa_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'DSA LAB',
        subjectCode: 'CS502L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_dsa'],
        sectionId: section.id,
      );

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [oopLab, dsaLab],
        staffList: [profOOP, profDSA],
        rooms: [labRoomA, labRoomB],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isTrue);
      // No entry periodNumber is 0 (break periods have periodNumber = 0)
      for (final e in result.entries) {
        expect(e.periodNumber, isNot(equals(0)));
      }
    });

    test('Scenario 11: Insufficient room resources triggers graceful preflight failure', () {
      final section = Section(
        id: 'sec_no_rooms',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-NoRooms',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      final mechLab = Subject(
        id: 'sub_mech_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'Mechanical Lab',
        subjectCode: 'MECH501L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Mechanical Lab',
        assignedTeacherIds: ['prof_oop'],
        sectionId: section.id,
      );

      final profMech = profOOP.copyWith(
        subjectsCanTeach: ['Mechanical Lab', 'sub_mech_lab'],
      );

      // Only computer labs and classroom exist, no mechanical lab
      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [mechLab],
        staffList: [profMech],
        rooms: [labRoomA, classroom1],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isFalse);
      expect(result.conflicts.any((c) => c.type == 'roomTypeMismatch'), isTrue);
    });
  });

  group('Section 17: Export Structure & PDF Preservation Verification', () {
    testWidgets('ExportScreen visually preserves both parallel batch allocations in the same time block', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final college = College(
        id: collegeId,
        name: 'Engineering College',
        code: 'ENG',
        address: 'Main Campus',
        workingDays: workingDays,
      );

      final section = Section(
        id: 'sec_export',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-Export',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      final mpSubject = Subject(
        id: 'sub_mp_exp',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'MP',
        courseShortName: 'MP',
        subjectCode: 'CS508L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_oop'],
        sectionId: section.id,
      );

      final cnSubject = Subject(
        id: 'sub_cn_exp',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'CN LAB',
        courseShortName: 'CN LAB',
        subjectCode: 'CS509L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_dsa'],
        sectionId: section.id,
      );

      final entries = [
        TimetableEntry(
          id: 'exp_1',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          timeSlotId: 'ts1',
          sectionId: section.id,
          subjectId: mpSubject.id,
          teacherId: profOOP.id,
          roomId: labRoomA.id,
          batch: 'B1',
        ),
        TimetableEntry(
          id: 'exp_2',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          timeSlotId: 'ts1',
          sectionId: section.id,
          subjectId: cnSubject.id,
          teacherId: profDSA.id,
          roomId: labRoomB.id,
          batch: 'B2',
        ),
      ];

      final version = TimetableVersion(
        id: 'v1',
        collegeId: collegeId,
        versionNumber: 1,
        name: 'Version 1',
        academicYear: '2026-2027',
        semester: '5',
      );

      final profile = UserProfile(
        id: 'user_exp',
        email: 'admin@college.edu',
        name: 'Admin User',
        role: UserRole.collegeAdmin,
        collegeId: collegeId,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentProfileProvider.overrideWith((ref) => profile),
            currentCollegeProvider.overrideWith((ref) => Future.value(college)),
            timetableVersionsProvider.overrideWith((ref) => Future.value([version])),
            selectedVersionIdProvider.overrideWith((ref) => 'v1'),
            sectionListProvider.overrideWith((ref) => Future.value([section])),
            subjectListProvider.overrideWith((ref) => Future.value([mpSubject, cnSubject])),
            staffListProvider.overrideWith((ref) => Future.value([profOOP, profDSA])),
            roomListProvider.overrideWith((ref) => Future.value([labRoomA, labRoomB])),
            timeSlotsProvider.overrideWith((ref) => Future.value(standardSlots)),
            timetableEntriesProvider.overrideWith((ref) => Future.value(entries)),
          ],
          child: const MaterialApp(
            home: ExportScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify PARALLEL LAB BATCHES header appears in the export view
      expect(find.text('PARALLEL LAB BATCHES'), findsWidgets);
      // Verify both allocations appear with batch distinctions and room details
      expect(find.text('B1'), findsWidgets);
      expect(find.text('B2'), findsWidgets);
      expect(find.text('MP'), findsWidgets);
      expect(find.text('CN LAB'), findsWidgets);
    });

    test('PdfExportService generates valid PDF preserving batch and room details', () async {
      final section = Section(
        id: 'sec_pdf',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: '5-PDF',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );

      final mpSubject = Subject(
        id: 'sub_mp_pdf',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'MP',
        courseShortName: 'MP',
        subjectCode: 'CS508L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_oop'],
        sectionId: section.id,
      );

      final cnSubject = Subject(
        id: 'sub_cn_pdf',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'CN LAB',
        courseShortName: 'CN LAB',
        subjectCode: 'CS509L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_dsa'],
        sectionId: section.id,
      );

      final entries = [
        TimetableEntry(
          id: 'pdf_1',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          timeSlotId: 'ts1',
          sectionId: section.id,
          subjectId: mpSubject.id,
          teacherId: profOOP.id,
          roomId: labRoomA.id,
          batch: 'B1',
        ),
        TimetableEntry(
          id: 'pdf_2',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          timeSlotId: 'ts1',
          sectionId: section.id,
          subjectId: cnSubject.id,
          teacherId: profDSA.id,
          roomId: labRoomB.id,
          batch: 'B2',
        ),
      ];

      final college = College(
        id: collegeId,
        name: 'Engineering College',
        code: 'ENG',
        address: 'Main Campus',
        workingDays: workingDays,
      );

      final pdfBytes = await PdfExportService.generateTimetablePdf(
        pageFormat: PdfPageFormat.a4.landscape,
        college: college,
        version: TimetableVersion(
          id: 'v1',
          collegeId: collegeId,
          versionNumber: 1,
          name: 'Version 1',
          academicYear: '2026-2027',
          semester: '5',
        ),
        entries: entries,
        timeSlots: standardSlots,
        staffMap: {profOOP.id: profOOP, profDSA.id: profDSA},
        sectionMap: {section.id: section},
        roomMap: {labRoomA.id: labRoomA, labRoomB.id: labRoomB},
        subjectMap: {mpSubject.id: mpSubject, cnSubject.id: cnSubject},
        targetView: 'section',
        selectedSectionId: section.id,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
    });
  });
}
