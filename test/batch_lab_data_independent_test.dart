import 'package:flutter_test/flutter_test.dart';
import 'dart:math';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/timetable_generator.dart';
import 'package:time_table/services/conflict_validator.dart';

void main() {
  const collegeId = 'test_college_data_independent';

  List<TimeSlot> createStandardSlots({int periodCount = 6, int lunchAfterPeriod = 3}) {
    final slots = <TimeSlot>[];
    var order = 0;
    for (var p = 1; p <= periodCount; p++) {
      slots.add(
        TimeSlot(
          id: 'slot_p$p',
          collegeId: collegeId,
          periodNumber: p,
          startTime: '${8 + p}:00',
          endTime: '${9 + p}:00',
          order: order++,
          isBreak: false,
        ),
      );
      if (p == lunchAfterPeriod) {
        slots.add(
          TimeSlot(
            id: 'slot_lunch',
            collegeId: collegeId,
            periodNumber: 0,
            breakTitle: 'Lunch',
            startTime: '${9 + p}:00',
            endTime: '${10 + p}:00',
            order: order++,
            isBreak: true,
          ),
        );
      }
    }
    return slots;
  }

  Section createSection({
    required String id,
    required String sectionName,
    int studentCount = 60,
    List<String> batches = const [],
    int semester = 3,
  }) {
    return Section(
      id: id,
      collegeId: collegeId,
      courseId: 'course_1',
      departmentId: 'dept_1',
      academicYear: '2026-2027',
      semester: semester,
      sectionName: sectionName,
      studentCount: studentCount,
      batches: batches,
    );
  }

  Subject createSubject({
    required String id,
    required String subjectCode,
    required String subjectName,
    required String subjectType,
    required int hoursPerWeek,
    required String requiredRoomType,
    List<String> assignedTeacherIds = const [],
    int semester = 3,
  }) {
    return Subject(
      id: id,
      collegeId: collegeId,
      courseId: 'course_1',
      departmentId: 'dept_1',
      semester: semester,
      subjectCode: subjectCode,
      subjectName: subjectName,
      subjectType: subjectType,
      hoursPerWeek: hoursPerWeek,
      requiredRoomType: requiredRoomType,
      assignedTeacherIds: assignedTeacherIds,
    );
  }

  Staff createStaff({
    required String id,
    required String name,
    List<String> subjectsCanTeach = const [],
    int maxClassesPerDay = 4,
    int maxClassesPerWeek = 20,
  }) {
    return Staff(
      id: id,
      collegeId: collegeId,
      employeeId: 'EMP_$id',
      name: name,
      email: '$id@college.edu',
      departmentId: 'dept_1',
      status: 'active',
      active: true,
      subjectsCanTeach: subjectsCanTeach,
      maxClassesPerDay: maxClassesPerDay,
      maxClassesPerWeek: maxClassesPerWeek,
    );
  }

  void assertTimetableInvariants({
    required GenerationResult result,
    required List<Section> sections,
    required List<Subject> subjects,
    required List<Staff> staff,
    required List<Room> rooms,
    required List<TimeSlot> timeSlots,
    required List<TeacherAvailability> availabilities,
    List<String>? workingDays,
    bool expectSuccess = true,
  }) {
    final days = workingDays ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    final validation = ConflictValidator.validateSchedule(
      collegeId: collegeId,
      entries: result.entries,
      sections: sections,
      subjects: subjects,
      staffList: staff,
      rooms: rooms,
      timeSlots: timeSlots,
      availabilities: availabilities,
      workingDays: days,
      validateHours: true,
    );

    if (expectSuccess) {
      expect(result.isSuccess, isTrue,
          reason: 'Expected timetable generation to succeed. Conflicts: ${result.conflicts.map((c) => "${c.title}: ${c.description}").join("; ")}');
      expect(validation.hardConflicts, isEmpty,
          reason: 'Generated timetable has hard conflicts: ${validation.hardConflicts.map((c) => "${c.type}: ${c.description}").join("; ")}');
    } else {
      expect(result.isSuccess, isFalse,
          reason: 'Expected generation to fail/report conflicts for impossible configuration.');
      expect(result.conflicts.where((c) => c.severity == 'hard'), isNotEmpty);
    }

    // 1. Room Occupancy Invariant: No room occupied by two allocations at overlapping periods
    final roomMap = <String, List<TimetableEntry>>{};
    for (final e in result.entries) {
      final key = '${e.dayOfWeek}_${e.periodNumber}_${e.roomId}';
      roomMap.putIfAbsent(key, () => []).add(e);
    }
    for (final entryList in roomMap.values) {
      expect(entryList.length, lessThanOrEqualTo(1),
          reason: 'Room ${entryList.first.roomId} double booked on ${entryList.first.dayOfWeek} P${entryList.first.periodNumber}');
    }

    // 2. Professor Occupancy Invariant: No professor double booked
    final profMap = <String, List<TimetableEntry>>{};
    for (final e in result.entries) {
      final key = '${e.dayOfWeek}_${e.periodNumber}_${e.teacherId}';
      profMap.putIfAbsent(key, () => []).add(e);
    }
    for (final entryList in profMap.values) {
      expect(entryList.length, lessThanOrEqualTo(1),
          reason: 'Professor ${entryList.first.teacherId} double booked on ${entryList.first.dayOfWeek} P${entryList.first.periodNumber}');
    }

    // 3. Batch Occupancy Invariant: No batch double booked
    final batchMap = <String, List<TimetableEntry>>{};
    for (final e in result.entries) {
      if (e.batch != null) {
        final key = '${e.dayOfWeek}_${e.periodNumber}_${e.sectionId}_${e.batch}';
        batchMap.putIfAbsent(key, () => []).add(e);
      }
    }
    for (final entryList in batchMap.values) {
      expect(entryList.length, lessThanOrEqualTo(1),
          reason: 'Batch ${entryList.first.batch} double booked on ${entryList.first.dayOfWeek} P${entryList.first.periodNumber}');
    }

    // 4. Section Occupancy Invariant: Whole section cannot overlap with batch or duplicate
    final secMap = <String, List<TimetableEntry>>{};
    for (final e in result.entries) {
      final key = '${e.dayOfWeek}_${e.periodNumber}_${e.sectionId}';
      secMap.putIfAbsent(key, () => []).add(e);
    }
    for (final entryList in secMap.values) {
      final wholeSec = entryList.where((e) => e.batch == null).toList();
      final batchSec = entryList.where((e) => e.batch != null).toList();
      if (wholeSec.isNotEmpty) {
        expect(batchSec, isEmpty,
            reason: 'Whole section class overlaps with batch lab on ${entryList.first.dayOfWeek} P${entryList.first.periodNumber}');
        expect(wholeSec.length, equals(1),
            reason: 'Duplicate whole section classes on ${entryList.first.dayOfWeek} P${entryList.first.periodNumber}');
      }
    }

    // 5. Break & Lunch Invariant: No entry during break or lunch
    final breakSlotIds = timeSlots.where((t) => t.isBreak).map((t) => t.id).toSet();
    final breakPeriods = timeSlots.where((t) => t.isBreak).map((t) => t.periodNumber).toSet();
    for (final e in result.entries) {
      expect(breakSlotIds.contains(e.timeSlotId), isFalse,
          reason: 'Class scheduled on break timeSlotId ${e.timeSlotId}');
      expect(breakPeriods.contains(e.periodNumber), isFalse,
          reason: 'Class scheduled on break period ${e.periodNumber}');
    }

    // 6. Working Days Invariant: No entry outside working days
    final validDays = days.toSet();
    for (final e in result.entries) {
      expect(validDays.contains(e.dayOfWeek), isTrue,
          reason: 'Class scheduled on non-working day ${e.dayOfWeek}');
    }

    // 7. Facility & Capacity Compatibility Invariant
    final roomLookup = {for (final r in rooms) r.id: r};
    final subjLookup = {for (final s in subjects) s.id: s};
    final secLookup = {for (final s in sections) s.id: s};

    for (final e in result.newlyScheduledEntries) {
      final room = roomLookup[e.roomId];
      final subj = subjLookup[e.subjectId];
      final sec = secLookup[e.sectionId];
      expect(room, isNotNull);
      expect(subj, isNotNull);
      expect(sec, isNotNull);

      // Facility
      final facilityMatch = TimetableGenerator.matchesFacility(room!, subj!.requiredRoomType);
      expect(facilityMatch, isTrue,
          reason: 'Room ${room.roomNumber} (${room.roomType}) does not match subject requirement ${subj.requiredRoomType}');

      // Capacity
      final neededCap = e.batch != null && sec!.batches.isNotEmpty
          ? (sec.studentCount / sec.batches.length).ceil()
          : sec!.studentCount;
      expect(room.capacity, greaterThanOrEqualTo(neededCap),
          reason: 'Room ${room.roomNumber} capacity (${room.capacity}) < required ($neededCap)');
    }
  }

  group('Data-Independent Batch Lab Scheduling: Core Test Cases A - M', () {
    test('CASE A: 1 section, 2 batches, 1 physical lab -> Batches placed in distinct non-overlapping time slots', () {
      final section = createSection(
        id: 'sec_alpha',
        sectionName: 'A',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );
      final theorySub = createSubject(
        id: 'sub_math',
        subjectCode: 'MTH301',
        subjectName: 'Advanced Math',
        subjectType: 'theory',
        hoursPerWeek: 3,
        requiredRoomType: 'Classroom',
        assignedTeacherIds: ['prof_ramanujan'],
      );
      final labSub = createSubject(
        id: 'sub_embedded',
        subjectCode: 'EMB302',
        subjectName: 'Embedded Systems Lab',
        subjectType: 'lab',
        hoursPerWeek: 2,
        requiredRoomType: 'Embedded_Lab',
        assignedTeacherIds: ['prof_turing'],
      );
      final profMath = createStaff(
        id: 'prof_ramanujan',
        name: 'Prof. Ramanujan',
        subjectsCanTeach: ['sub_math'],
      );
      final profLab = createStaff(
        id: 'prof_turing',
        name: 'Prof. Turing',
        subjectsCanTeach: ['sub_embedded'],
      );
      final classroom = Room(
        id: 'room_c101',
        collegeId: collegeId,
        roomNumber: 'C-101',
        roomType: 'Classroom',
        capacity: 70,
      );
      final embeddedLab = Room(
        id: 'room_emb_lab',
        collegeId: collegeId,
        roomNumber: 'EMB-LAB-1',
        roomType: 'Embedded_Lab',
        capacity: 35,
      );
      final timeSlots = createStandardSlots(periodCount: 6);

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [theorySub, labSub],
        staffList: [profMath, profLab],
        rooms: [classroom, embeddedLab],
        timeSlots: timeSlots,
        availabilities: [],
      );

      assertTimetableInvariants(
        result: result,
        sections: [section],
        subjects: [theorySub, labSub],
        staff: [profMath, profLab],
        rooms: [classroom, embeddedLab],
        timeSlots: timeSlots,
        availabilities: [],
      );

      final b1LabEntries = result.entries.where((e) => e.subjectId == labSub.id && e.batch == 'B1').toList();
      final b2LabEntries = result.entries.where((e) => e.subjectId == labSub.id && e.batch == 'B2').toList();
      expect(b1LabEntries.length, equals(2));
      expect(b2LabEntries.length, equals(2));

      final b1Slots = b1LabEntries.map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();
      final b2Slots = b2LabEntries.map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();
      expect(b1Slots.intersection(b2Slots), isEmpty,
          reason: 'B1 and B2 cannot share the single physical lab at the same time!');
    });

    test('CASE B: 1 section, 2 batches, 2 compatible labs -> Simultaneous allocation permitted if qualified faculty available', () {
      final section = createSection(
        id: 'sec_b',
        sectionName: 'B',
        studentCount: 60,
        batches: ['Group1', 'Group2'],
      );
      final labSub = createSubject(
        id: 'sub_net',
        subjectCode: 'NET301',
        subjectName: 'Computer Networks Lab',
        subjectType: 'lab',
        hoursPerWeek: 2,
        requiredRoomType: 'Network_Lab',
        assignedTeacherIds: ['prof_cerf', 'prof_kahn'],
      );
      final prof1 = createStaff(
        id: 'prof_cerf',
        name: 'Prof. Cerf',
        subjectsCanTeach: ['sub_net'],
      );
      final prof2 = createStaff(
        id: 'prof_kahn',
        name: 'Prof. Kahn',
        subjectsCanTeach: ['sub_net'],
      );
      final lab1 = Room(
        id: 'lab_net_1',
        collegeId: collegeId,
        roomNumber: 'Net-Lab-1',
        roomType: 'Network_Lab',
        capacity: 35,
      );
      final lab2 = Room(
        id: 'lab_net_2',
        collegeId: collegeId,
        roomNumber: 'Net-Lab-2',
        roomType: 'Network_Lab',
        capacity: 35,
      );
      final timeSlots = createStandardSlots(periodCount: 6);

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [labSub],
        staffList: [prof1, prof2],
        rooms: [lab1, lab2],
        timeSlots: timeSlots,
        availabilities: [],
      );

      assertTimetableInvariants(
        result: result,
        sections: [section],
        subjects: [labSub],
        staff: [prof1, prof2],
        rooms: [lab1, lab2],
        timeSlots: timeSlots,
        availabilities: [],
      );

      final g1 = result.entries.where((e) => e.batch == 'Group1').toList();
      final g2 = result.entries.where((e) => e.batch == 'Group2').toList();
      expect(g1.length, equals(2));
      expect(g2.length, equals(2));
    });

    test('CASE C: 1 section, 3 batches, 1 lab -> All 3 batches placed across non-overlapping slots', () {
      final section = createSection(
        id: 'sec_c',
        sectionName: 'C',
        studentCount: 90,
        batches: ['Batch_A', 'Batch_B', 'Batch_C'],
      );
      final labSub = createSubject(
        id: 'sub_chem',
        subjectCode: 'CHM101',
        subjectName: 'Organic Chemistry Lab',
        subjectType: 'lab',
        hoursPerWeek: 2,
        requiredRoomType: 'Chemistry_Lab',
        assignedTeacherIds: ['prof_curie'],
      );
      final prof = createStaff(
        id: 'prof_curie',
        name: 'Prof. Curie',
        subjectsCanTeach: ['sub_chem'],
      );
      final lab = Room(
        id: 'lab_chem_1',
        collegeId: collegeId,
        roomNumber: 'Chem-Lab-1',
        roomType: 'Chemistry_Lab',
        capacity: 35,
      );
      final timeSlots = createStandardSlots(periodCount: 6);

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [labSub],
        staffList: [prof],
        rooms: [lab],
        timeSlots: timeSlots,
        availabilities: [],
      );

      assertTimetableInvariants(
        result: result,
        sections: [section],
        subjects: [labSub],
        staff: [prof],
        rooms: [lab],
        timeSlots: timeSlots,
        availabilities: [],
      );

      final aSlots = result.entries.where((e) => e.batch == 'Batch_A').map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();
      final bSlots = result.entries.where((e) => e.batch == 'Batch_B').map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();
      final cSlots = result.entries.where((e) => e.batch == 'Batch_C').map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();

      expect(aSlots.length, equals(2));
      expect(bSlots.length, equals(2));
      expect(cSlots.length, equals(2));
      expect(aSlots.intersection(bSlots), isEmpty);
      expect(aSlots.intersection(cSlots), isEmpty);
      expect(bSlots.intersection(cSlots), isEmpty);
    });

    test('CASE D: 1 section, 3 batches, 2 labs -> At most 2 batches simultaneous, 3rd in separate slot', () {
      final section = createSection(
        id: 'sec_d',
        sectionName: 'D',
        studentCount: 90,
        batches: ['B1', 'B2', 'B3'],
      );
      final labSub = createSubject(
        id: 'sub_physics',
        subjectCode: 'PHY201',
        subjectName: 'Optics Lab',
        subjectType: 'lab',
        hoursPerWeek: 2,
        requiredRoomType: 'Optics_Lab',
        assignedTeacherIds: ['prof_newton', 'prof_feynman'],
      );
      final prof1 = createStaff(
        id: 'prof_newton',
        name: 'Prof. Newton',
        subjectsCanTeach: ['sub_physics'],
      );
      final prof2 = createStaff(
        id: 'prof_feynman',
        name: 'Prof. Feynman',
        subjectsCanTeach: ['sub_physics'],
      );
      final lab1 = Room(
        id: 'lab_opt_1',
        collegeId: collegeId,
        roomNumber: 'Optics-1',
        roomType: 'Optics_Lab',
        capacity: 35,
      );
      final lab2 = Room(
        id: 'lab_opt_2',
        collegeId: collegeId,
        roomNumber: 'Optics-2',
        roomType: 'Optics_Lab',
        capacity: 35,
      );
      final timeSlots = createStandardSlots(periodCount: 6);

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [labSub],
        staffList: [prof1, prof2],
        rooms: [lab1, lab2],
        timeSlots: timeSlots,
        availabilities: [],
      );

      assertTimetableInvariants(
        result: result,
        sections: [section],
        subjects: [labSub],
        staff: [prof1, prof2],
        rooms: [lab1, lab2],
        timeSlots: timeSlots,
        availabilities: [],
      );
    });

    test('CASE E: Multiple sections, multiple batches, multiple labs -> Full isolation between sections and batches', () {
      final sec1 = createSection(
        id: 'sec_cse',
        sectionName: 'CSE',
        studentCount: 60,
        batches: ['CSE_B1', 'CSE_B2'],
      );
      final sec2 = createSection(
        id: 'sec_ece',
        sectionName: 'ECE',
        studentCount: 60,
        batches: ['ECE_B1', 'ECE_B2'],
      );
      final cseLab = createSubject(
        id: 'sub_cselab',
        subjectCode: 'CS301',
        subjectName: 'DSA Lab',
        subjectType: 'lab',
        hoursPerWeek: 2,
        requiredRoomType: 'CS_Lab',
        assignedTeacherIds: ['prof_knuth'],
      );
      final eceLab = createSubject(
        id: 'sub_ecelab',
        subjectCode: 'EC301',
        subjectName: 'VLSI Lab',
        subjectType: 'lab',
        hoursPerWeek: 2,
        requiredRoomType: 'VLSI_Lab',
        assignedTeacherIds: ['prof_moore'],
      );
      final prof1 = createStaff(
        id: 'prof_knuth',
        name: 'Prof. Knuth',
        subjectsCanTeach: ['sub_cselab'],
      );
      final prof2 = createStaff(
        id: 'prof_moore',
        name: 'Prof. Moore',
        subjectsCanTeach: ['sub_ecelab'],
      );
      final csLab = Room(
        id: 'room_cs_lab',
        collegeId: collegeId,
        roomNumber: 'CS-Lab',
        roomType: 'CS_Lab',
        capacity: 35,
      );
      final vlsiLab = Room(
        id: 'room_vlsi_lab',
        collegeId: collegeId,
        roomNumber: 'VLSI-Lab',
        roomType: 'VLSI_Lab',
        capacity: 35,
      );
      final timeSlots = createStandardSlots(periodCount: 6);

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [sec1, sec2],
        subjects: [cseLab, eceLab],
        staffList: [prof1, prof2],
        rooms: [csLab, vlsiLab],
        timeSlots: timeSlots,
        availabilities: [],
      );

      assertTimetableInvariants(
        result: result,
        sections: [sec1, sec2],
        subjects: [cseLab, eceLab],
        staff: [prof1, prof2],
        rooms: [csLab, vlsiLab],
        timeSlots: timeSlots,
        availabilities: [],
      );
    });

    test('CASE F: Multiple lab subjects, multiple batches, shared lab resources', () {
      final section = createSection(
        id: 'sec_f',
        sectionName: 'F',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );
      final osLab = createSubject(
        id: 'sub_os',
        subjectCode: 'OS501',
        subjectName: 'OS Lab',
        subjectType: 'lab',
        hoursPerWeek: 2,
        requiredRoomType: 'General_Computing_Lab',
        assignedTeacherIds: ['prof_torvalds'],
      );
      final dbmsLab = createSubject(
        id: 'sub_dbms',
        subjectCode: 'DB502',
        subjectName: 'DBMS Lab',
        subjectType: 'lab',
        hoursPerWeek: 2,
        requiredRoomType: 'General_Computing_Lab',
        assignedTeacherIds: ['prof_codd'],
      );
      final prof1 = createStaff(
        id: 'prof_torvalds',
        name: 'Prof. Torvalds',
        subjectsCanTeach: ['sub_os'],
      );
      final prof2 = createStaff(
        id: 'prof_codd',
        name: 'Prof. Codd',
        subjectsCanTeach: ['sub_dbms'],
      );
      final compLab1 = Room(
        id: 'room_comp_1',
        collegeId: collegeId,
        roomNumber: 'Comp-Lab-1',
        roomType: 'General_Computing_Lab',
        capacity: 35,
      );
      final compLab2 = Room(
        id: 'room_comp_2',
        collegeId: collegeId,
        roomNumber: 'Comp-Lab-2',
        roomType: 'General_Computing_Lab',
        capacity: 35,
      );
      final timeSlots = createStandardSlots(periodCount: 6);

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [osLab, dbmsLab],
        staffList: [prof1, prof2],
        rooms: [compLab1, compLab2],
        timeSlots: timeSlots,
        availabilities: [],
      );

      assertTimetableInvariants(
        result: result,
        sections: [section],
        subjects: [osLab, dbmsLab],
        staff: [prof1, prof2],
        rooms: [compLab1, compLab2],
        timeSlots: timeSlots,
        availabilities: [],
      );

      for (final b in ['B1', 'B2']) {
        final osCount = result.entries.where((e) => e.subjectId == osLab.id && e.batch == b).length;
        final dbmsCount = result.entries.where((e) => e.subjectId == dbmsLab.id && e.batch == b).length;
        expect(osCount, equals(2));
        expect(dbmsCount, equals(2));
      }
    });

    test('CASE G: Professor availability restrictions respected for batch lab', () {
      final section = createSection(
        id: 'sec_g',
        sectionName: 'G',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );
      final labSub = createSubject(
        id: 'sub_g_lab',
        subjectCode: 'GLAB',
        subjectName: 'G Lab',
        subjectType: 'lab',
        hoursPerWeek: 2,
        requiredRoomType: 'Lab_G',
        assignedTeacherIds: ['prof_g'],
      );
      final prof = createStaff(
        id: 'prof_g',
        name: 'Prof. G',
        subjectsCanTeach: ['sub_g_lab'],
      );
      final lab = Room(
        id: 'room_g',
        collegeId: collegeId,
        roomNumber: 'Room-G',
        roomType: 'Lab_G',
        capacity: 35,
      );
      final timeSlots = createStandardSlots(periodCount: 6);

      final availabilities = [
        for (var p = 1; p <= 6; p++) ...[
          TeacherAvailability(id: 'av_m_$p', collegeId: collegeId, teacherId: 'prof_g', dayOfWeek: 'Monday', periodNumber: p, isAvailable: false, isLeave: true),
          TeacherAvailability(id: 'av_t_$p', collegeId: collegeId, teacherId: 'prof_g', dayOfWeek: 'Tuesday', periodNumber: p, isAvailable: false, isLeave: true),
        ],
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [labSub],
        staffList: [prof],
        rooms: [lab],
        timeSlots: timeSlots,
        availabilities: availabilities,
      );

      assertTimetableInvariants(
        result: result,
        sections: [section],
        subjects: [labSub],
        staff: [prof],
        rooms: [lab],
        timeSlots: timeSlots,
        availabilities: availabilities,
      );

      final monTue = result.entries.where((e) => e.dayOfWeek == 'Monday' || e.dayOfWeek == 'Tuesday').toList();
      expect(monTue, isEmpty);
    });

    test('CASE H: Lab availability restrictions respected (zero eligible rooms on certain slots)', () {
      final section = createSection(
        id: 'sec_h',
        sectionName: 'H',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );
      final labSub = createSubject(
        id: 'sub_h_lab',
        subjectCode: 'HLAB',
        subjectName: 'H Lab',
        subjectType: 'lab',
        hoursPerWeek: 2,
        requiredRoomType: 'Lab_H',
        assignedTeacherIds: ['prof_h'],
      );
      final prof = createStaff(
        id: 'prof_h',
        name: 'Prof. H',
        subjectsCanTeach: ['sub_h_lab'],
      );
      final lab = Room(
        id: 'room_h',
        collegeId: collegeId,
        roomNumber: 'Room-H',
        roomType: 'Lab_H',
        capacity: 35,
      );
      final timeSlots = createStandardSlots(periodCount: 6);

      final existingEntries = [
        for (var p = 1; p <= 6; p++) ...[
          TimetableEntry(
            id: 'ext_mon_$p',
            collegeId: collegeId,
            versionId: 'ext_ver',
            dayOfWeek: 'Monday',
            periodNumber: p,
            timeSlotId: 'slot_p$p',
            sectionId: 'other_section',
            subjectId: 'other_subj',
            teacherId: 'other_prof_mon_$p',
            roomId: 'room_h',
            status: 'confirmed',
          ),
          TimetableEntry(
            id: 'ext_wed_$p',
            collegeId: collegeId,
            versionId: 'ext_ver',
            dayOfWeek: 'Wednesday',
            periodNumber: p,
            timeSlotId: 'slot_p$p',
            sectionId: 'other_section',
            subjectId: 'other_subj',
            teacherId: 'other_prof_wed_$p',
            roomId: 'room_h',
            status: 'confirmed',
          ),
        ],
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [labSub],
        staffList: [prof],
        rooms: [lab],
        timeSlots: timeSlots,
        availabilities: [],
        existingEntries: existingEntries,
      );

      assertTimetableInvariants(
        result: result,
        sections: [section],
        subjects: [labSub],
        staff: [prof],
        rooms: [lab],
        timeSlots: timeSlots,
        availabilities: [],
      );

      final newEntries = result.newlyScheduledEntries;
      final clash = newEntries.where((e) => e.roomId == 'room_h' && (e.dayOfWeek == 'Monday' || e.dayOfWeek == 'Wednesday'));
      expect(clash, isEmpty);
    });

    test('CASE I: 2-period lab block cannot cross lunch or breaks', () {
      final section = createSection(
        id: 'sec_i',
        sectionName: 'I',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );
      final labSub = createSubject(
        id: 'sub_i_lab',
        subjectCode: 'ILAB',
        subjectName: 'I Lab',
        subjectType: 'lab',
        hoursPerWeek: 2,
        requiredRoomType: 'Lab_I',
        assignedTeacherIds: ['prof_i'],
      );
      final prof = createStaff(
        id: 'prof_i',
        name: 'Prof. I',
        subjectsCanTeach: ['sub_i_lab'],
      );
      final lab = Room(
        id: 'room_i',
        collegeId: collegeId,
        roomNumber: 'Room-I',
        roomType: 'Lab_I',
        capacity: 35,
      );
      final timeSlots = createStandardSlots(periodCount: 4, lunchAfterPeriod: 2);

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [labSub],
        staffList: [prof],
        rooms: [lab],
        timeSlots: timeSlots,
        availabilities: [],
      );

      assertTimetableInvariants(
        result: result,
        sections: [section],
        subjects: [labSub],
        staff: [prof],
        rooms: [lab],
        timeSlots: timeSlots,
        availabilities: [],
      );

      final periodsByDayBatch = <String, List<int>>{};
      for (final e in result.entries) {
        final key = '${e.dayOfWeek}_${e.batch}';
        periodsByDayBatch.putIfAbsent(key, () => []).add(e.periodNumber);
      }
      for (final pList in periodsByDayBatch.values) {
        pList.sort();
        final span = '${pList.first}-${pList.last}';
        expect(span == '1-2' || span == '3-4', isTrue,
            reason: 'Lab session cannot cross lunch between P2 and P3! Found span: $span');
      }
    });

    test('CASE J: Insufficient lab capacity/resources reports hard conflict and isSuccess=false', () {
      final section = createSection(
        id: 'sec_j',
        sectionName: 'J',
        studentCount: 80,
        batches: ['B1', 'B2'],
      );
      final labSub = createSubject(
        id: 'sub_j_lab',
        subjectCode: 'JLAB',
        subjectName: 'J Lab',
        subjectType: 'lab',
        hoursPerWeek: 2,
        requiredRoomType: 'Nano_Lab',
        assignedTeacherIds: ['prof_j'],
      );
      final prof = createStaff(
        id: 'prof_j',
        name: 'Prof. J',
        subjectsCanTeach: ['sub_j_lab'],
      );
      final classroom = Room(
        id: 'room_c',
        collegeId: collegeId,
        roomNumber: 'Class-1',
        roomType: 'Classroom',
        capacity: 100,
      );
      final timeSlots = createStandardSlots(periodCount: 6);

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [labSub],
        staffList: [prof],
        rooms: [classroom],
        timeSlots: timeSlots,
        availabilities: [],
      );

      assertTimetableInvariants(
        result: result,
        sections: [section],
        subjects: [labSub],
        staff: [prof],
        rooms: [classroom],
        timeSlots: timeSlots,
        availabilities: [],
        expectSuccess: false,
      );
      expect(result.conflicts.any((c) => c.title.contains('Suitable Lab') || c.type == 'roomTypeMismatch'), isTrue);
    });

    test('CASE K: Custom working days (4-day week) and 7 periods per day', () {
      final section = createSection(
        id: 'sec_k',
        sectionName: 'K',
        studentCount: 40,
        batches: ['K1', 'K2'],
      );
      final theorySub = createSubject(
        id: 'sub_k_th',
        subjectCode: 'KTH101',
        subjectName: 'K Theory',
        subjectType: 'theory',
        hoursPerWeek: 4,
        requiredRoomType: 'Classroom',
        assignedTeacherIds: ['prof_k1'],
      );
      final labSub = createSubject(
        id: 'sub_k_lab',
        subjectCode: 'KLAB102',
        subjectName: 'K Lab',
        subjectType: 'lab',
        hoursPerWeek: 2,
        requiredRoomType: 'K_Lab',
        assignedTeacherIds: ['prof_k2'],
      );
      final prof1 = createStaff(
        id: 'prof_k1',
        name: 'Prof. K1',
        subjectsCanTeach: ['sub_k_th'],
        maxClassesPerDay: 5,
        maxClassesPerWeek: 25,
      );
      final prof2 = createStaff(
        id: 'prof_k2',
        name: 'Prof. K2',
        subjectsCanTeach: ['sub_k_lab'],
        maxClassesPerDay: 5,
        maxClassesPerWeek: 25,
      );
      final classroom = Room(
        id: 'room_k_class',
        collegeId: collegeId,
        roomNumber: 'K-Room',
        roomType: 'Classroom',
        capacity: 50,
      );
      final kLab = Room(
        id: 'room_k_lab',
        collegeId: collegeId,
        roomNumber: 'K-Lab-Room',
        roomType: 'K_Lab',
        capacity: 25,
      );
      final timeSlots = createStandardSlots(periodCount: 7, lunchAfterPeriod: 4);
      final fourDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday'];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [theorySub, labSub],
        staffList: [prof1, prof2],
        rooms: [classroom, kLab],
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: fourDays,
      );

      assertTimetableInvariants(
        result: result,
        sections: [section],
        subjects: [theorySub, labSub],
        staff: [prof1, prof2],
        rooms: [classroom, kLab],
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: fourDays,
      );
      expect(result.entries.any((e) => e.dayOfWeek == 'Friday'), isFalse);
    });

    test('CASE L: Different room facility configurations (multiple rooms with distinct facilities)', () {
      final section = createSection(
        id: 'sec_l',
        sectionName: 'L',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );
      final labAI = createSubject(
        id: 'sub_ai',
        subjectCode: 'AI301',
        subjectName: 'Artificial Intelligence Lab',
        subjectType: 'lab',
        hoursPerWeek: 2,
        requiredRoomType: 'GPU_Cluster',
        assignedTeacherIds: ['prof_l1'],
      );
      final prof = createStaff(
        id: 'prof_l1',
        name: 'Prof. L1',
        subjectsCanTeach: ['sub_ai'],
      );
      final normalLab = Room(
        id: 'room_normal_lab',
        collegeId: collegeId,
        roomNumber: 'Lab-General',
        roomType: 'General_Lab',
        facilities: ['Computers'],
        capacity: 40,
      );
      final gpuLab = Room(
        id: 'room_gpu_lab',
        collegeId: collegeId,
        roomNumber: 'Lab-GPU',
        roomType: 'GPU_Cluster',
        facilities: ['NVIDIA A100', 'GPU_Cluster'],
        capacity: 40,
      );
      final timeSlots = createStandardSlots(periodCount: 6);

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [labAI],
        staffList: [prof],
        rooms: [normalLab, gpuLab],
        timeSlots: timeSlots,
        availabilities: [],
      );

      assertTimetableInvariants(
        result: result,
        sections: [section],
        subjects: [labAI],
        staff: [prof],
        rooms: [normalLab, gpuLab],
        timeSlots: timeSlots,
        availabilities: [],
      );

      for (final e in result.entries) {
        expect(e.roomId, equals('room_gpu_lab'),
            reason: 'AI Lab strictly requires GPU_Cluster room, cannot use normalLab');
      }
    });

    test('CASE M: Multiple professors and sections competing for the same resources', () {
      final sec1 = createSection(
        id: 'sec_m1',
        sectionName: 'M1',
        studentCount: 60,
        batches: ['M1_B1', 'M1_B2'],
      );
      final sec2 = createSection(
        id: 'sec_m2',
        sectionName: 'M2',
        studentCount: 60,
        batches: ['M2_B1', 'M2_B2'],
      );
      final labSub = createSubject(
        id: 'sub_m_lab',
        subjectCode: 'MLAB',
        subjectName: 'Shared Lab Subject',
        subjectType: 'lab',
        hoursPerWeek: 2,
        requiredRoomType: 'Shared_Lab',
        assignedTeacherIds: ['prof_m_shared', 'prof_m2'],
      );
      final profShared = createStaff(
        id: 'prof_m_shared',
        name: 'Prof. Shared',
        subjectsCanTeach: ['sub_m_lab'],
      );
      final prof2 = createStaff(
        id: 'prof_m2',
        name: 'Prof. M2',
        subjectsCanTeach: ['sub_m_lab'],
      );
      final sharedLab = Room(
        id: 'room_shared_lab',
        collegeId: collegeId,
        roomNumber: 'Shared-Lab-1',
        roomType: 'Shared_Lab',
        capacity: 35,
      );
      final timeSlots = createStandardSlots(periodCount: 6);

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [sec1, sec2],
        subjects: [labSub],
        staffList: [profShared, prof2],
        rooms: [sharedLab],
        timeSlots: timeSlots,
        availabilities: [],
      );

      assertTimetableInvariants(
        result: result,
        sections: [sec1, sec2],
        subjects: [labSub],
        staff: [profShared, prof2],
        rooms: [sharedLab],
        timeSlots: timeSlots,
        availabilities: [],
      );

      final allLabSlots = result.entries.map((e) => '${e.dayOfWeek}_${e.periodNumber}').toList();
      expect(allLabSlots.toSet().length, equals(allLabSlots.length),
          reason: 'Every batch allocation in the single physical lab must be completely disjoint!');
    });
  });

  group('Permanent Regression Protection Tests', () {
    test('REGRESSION TEST: Same physical lab + overlapping periods + different batches MUST NEVER HAPPEN', () {
      final section = createSection(
        id: 'sec_reg',
        sectionName: 'REG',
        studentCount: 60,
        batches: ['Batch_1', 'Batch_2'],
      );
      final labSub = createSubject(
        id: 'sub_reg_lab',
        subjectCode: 'REG101',
        subjectName: 'Regression Lab',
        subjectType: 'lab',
        hoursPerWeek: 2,
        requiredRoomType: 'Regression_Lab',
        assignedTeacherIds: ['prof_reg'],
      );
      final prof = createStaff(
        id: 'prof_reg',
        name: 'Prof. Reg',
        subjectsCanTeach: ['sub_reg_lab'],
      );
      final lab = Room(
        id: 'lab_reg_physical_203',
        collegeId: collegeId,
        roomNumber: 'Physical-Lab-203',
        roomType: 'Regression_Lab',
        capacity: 35,
      );
      final timeSlots = createStandardSlots(periodCount: 6);

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [section],
        subjects: [labSub],
        staffList: [prof],
        rooms: [lab],
        timeSlots: timeSlots,
        availabilities: [],
      );

      expect(result.isSuccess, isTrue);

      final b1Entries = result.entries.where((e) => e.batch == 'Batch_1').toList();
      final b2Entries = result.entries.where((e) => e.batch == 'Batch_2').toList();
      expect(b1Entries.length, equals(2));
      expect(b2Entries.length, equals(2));

      for (final e1 in b1Entries) {
        for (final e2 in b2Entries) {
          final isSameTime = e1.dayOfWeek == e2.dayOfWeek && e1.periodNumber == e2.periodNumber;
          expect(isSameTime, isFalse,
              reason: 'REGRESSION BUG DETECTED: Physical lab ${lab.roomNumber} is allocated to Batch_1 and Batch_2 at the same time (${e1.dayOfWeek} P${e1.periodNumber})!');
        }
      }
    });
  });

  group('Randomized & Stress Invariant Testing across diverse configurations', () {
    final rand = Random(42);

    for (var iter = 1; iter <= 5; iter++) {
      test('Randomized Test Configuration #$iter: Invariants strictly preserved', () {
        final secCount = rand.nextInt(3) + 1;
        final timeSlots = createStandardSlots(periodCount: 6, lunchAfterPeriod: 3);

        final sections = <Section>[];
        final subjects = <Subject>[];
        final staffList = <Staff>[];
        final rooms = <Room>[];

        final classroom1 = Room(
          id: 'rand_c1_$iter',
          collegeId: collegeId,
          roomNumber: 'CR-101-$iter',
          roomType: 'Classroom',
          capacity: 80,
        );
        final classroom2 = Room(
          id: 'rand_c2_$iter',
          collegeId: collegeId,
          roomNumber: 'CR-102-$iter',
          roomType: 'Classroom',
          capacity: 80,
        );
        final labRoom1 = Room(
          id: 'rand_lab1_$iter',
          collegeId: collegeId,
          roomNumber: 'Lab-A-$iter',
          roomType: 'Special_Lab_$iter',
          capacity: 40,
        );
        final labRoom2 = Room(
          id: 'rand_lab2_$iter',
          collegeId: collegeId,
          roomNumber: 'Lab-B-$iter',
          roomType: 'Special_Lab_$iter',
          capacity: 40,
        );
        rooms.addAll([classroom1, classroom2, labRoom1, labRoom2]);

        for (var sIdx = 1; sIdx <= secCount; sIdx++) {
          final batchCount = rand.nextInt(2) + 2;
          final batches = List.generate(batchCount, (i) => 'Batch_${sIdx}_${i + 1}');

          final sec = createSection(
            id: 'sec_rand_${sIdx}_$iter',
            sectionName: 'R$sIdx',
            studentCount: 60,
            batches: batches,
          );
          sections.add(sec);

          final thSub = createSubject(
            id: 'sub_th_${sIdx}_$iter',
            subjectCode: 'TH$sIdx',
            subjectName: 'Theory $sIdx',
            subjectType: 'theory',
            hoursPerWeek: 3,
            requiredRoomType: 'Classroom',
            assignedTeacherIds: ['staff_th_${sIdx}_$iter'],
          );
          final labSub = createSubject(
            id: 'sub_lab_${sIdx}_$iter',
            subjectCode: 'LAB$sIdx',
            subjectName: 'Lab $sIdx',
            subjectType: 'lab',
            hoursPerWeek: 2,
            requiredRoomType: 'Special_Lab_$iter',
            assignedTeacherIds: ['staff_lab_${sIdx}_$iter'],
          );
          subjects.addAll([thSub, labSub]);

          final thStaff = createStaff(
            id: 'staff_th_${sIdx}_$iter',
            name: 'Prof. Theory $sIdx',
            subjectsCanTeach: [thSub.id],
          );
          final labStaff = createStaff(
            id: 'staff_lab_${sIdx}_$iter',
            name: 'Prof. Lab $sIdx',
            subjectsCanTeach: [labSub.id],
          );
          staffList.addAll([thStaff, labStaff]);
        }

        final result = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: sections,
          subjects: subjects,
          staffList: staffList,
          rooms: rooms,
          timeSlots: timeSlots,
          availabilities: [],
        );

        assertTimetableInvariants(
          result: result,
          sections: sections,
          subjects: subjects,
          staff: staffList,
          rooms: rooms,
          timeSlots: timeSlots,
          availabilities: [],
          expectSuccess: result.isSuccess,
        );
      });
    }
  });
}
