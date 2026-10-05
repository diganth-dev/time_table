// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/services.dart';

void main() {
  const collegeId = 'inspect_college';

  List<TimeSlot> createSlots(int count) {
    return [
      for (var i = 1; i <= count; i++)
        TimeSlot(
          id: 'slot_$i',
          collegeId: collegeId,
          periodNumber: i,
          startTime: '${8 + i}:00',
          endTime: '${9 + i}:00',
          order: i - 1,
          isBreak: false,
        ),
    ];
  }

  test('Inspect Scenario 3: Single-lab / multiple-batch configuration', () {
    final section = Section(
      id: 'sec_single_lab',
      collegeId: collegeId,
      departmentId: 'dept_cs',
      courseId: 'course_be',
      academicYear: '2026-2027',
      semester: 4,
      sectionName: 'A',
      studentCount: 60,
      batches: ['Batch_1', 'Batch_2'],
    );
    final labSubj = Subject(
      id: 'subj_networks',
      collegeId: collegeId,
      departmentId: 'dept_cs',
      courseId: 'course_be',
      semester: 4,
      subjectCode: 'CS402L',
      subjectName: 'Network Systems Lab',
      subjectType: 'lab',
      hoursPerWeek: 2,
      requiredRoomType: 'Hardware_Lab',
      assignedTeacherIds: ['prof_hardy'],
    );
    final prof = Staff(
      id: 'prof_hardy',
      collegeId: collegeId,
      employeeId: 'EMP_H',
      name: 'Prof. Hardy',
      email: 'hardy@college.edu',
      departmentId: 'dept_cs',
      status: 'active',
      active: true,
      subjectsCanTeach: ['subj_networks'],
      maxClassesPerDay: 4,
      maxClassesPerWeek: 20,
    );
    final singleLab = Room(
      id: 'room_hw_1',
      collegeId: collegeId,
      roomNumber: 'HW-LAB-101',
      roomType: 'Hardware_Lab',
      capacity: 35,
    );
    final slots = createSlots(6);

    final result = TimetableGenerator.generate(
      collegeId: collegeId,
      sections: [section],
      subjects: [labSubj],
      staffList: [prof],
      rooms: [singleLab],
      timeSlots: slots,
      availabilities: [],
    );

    print('\n=== SCENARIO 3: SINGLE LAB / MULTIPLE BATCHES ===');
    print('isSuccess: ${result.isSuccess}, entries: ${result.entries.length}');
    for (final e in result.entries) {
      print('  Day: ${e.dayOfWeek}, Period: ${e.periodNumber}, Batch: ${e.batch}, Room: ${e.roomId}, Prof: ${e.teacherId}');
    }

    expect(result.isSuccess, isTrue);
    expect(result.entries.length, 4); // 2 batches * 2 hours
    final b1Slots = result.entries.where((e) => e.batch == 'Batch_1').map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();
    final b2Slots = result.entries.where((e) => e.batch == 'Batch_2').map((e) => '${e.dayOfWeek}_${e.periodNumber}').toSet();
    expect(b1Slots.intersection(b2Slots).isEmpty, isTrue, reason: 'Batches must not share time slots when only 1 lab exists');
  });

  test('Inspect Scenario 4: Multiple-lab / multiple-batch configuration', () {
    final section = Section(
      id: 'sec_multi_lab',
      collegeId: collegeId,
      departmentId: 'dept_cs',
      courseId: 'course_be',
      academicYear: '2026-2027',
      semester: 4,
      sectionName: 'B',
      studentCount: 60,
      batches: ['Batch_1', 'Batch_2'],
    );
    final labSubj = Subject(
      id: 'subj_ai_lab',
      collegeId: collegeId,
      departmentId: 'dept_cs',
      courseId: 'course_be',
      semester: 4,
      subjectCode: 'CS403L',
      subjectName: 'AI Systems Lab',
      subjectType: 'lab',
      hoursPerWeek: 2,
      requiredRoomType: 'AI_Lab',
      assignedTeacherIds: ['prof_mccarthy', 'prof_minsky'],
    );
    final prof1 = Staff(
      id: 'prof_mccarthy',
      collegeId: collegeId,
      employeeId: 'EMP_MC',
      name: 'Prof. McCarthy',
      email: 'mc@college.edu',
      departmentId: 'dept_cs',
      status: 'active',
      active: true,
      subjectsCanTeach: ['subj_ai_lab'],
      maxClassesPerDay: 4,
      maxClassesPerWeek: 20,
    );
    final prof2 = Staff(
      id: 'prof_minsky',
      collegeId: collegeId,
      employeeId: 'EMP_MI',
      name: 'Prof. Minsky',
      email: 'minsky@college.edu',
      departmentId: 'dept_cs',
      status: 'active',
      active: true,
      subjectsCanTeach: ['subj_ai_lab'],
      maxClassesPerDay: 4,
      maxClassesPerWeek: 20,
    );
    final lab1 = Room(
      id: 'room_ai_1',
      collegeId: collegeId,
      roomNumber: 'AI-LAB-1',
      roomType: 'AI_Lab',
      capacity: 35,
    );
    final lab2 = Room(
      id: 'room_ai_2',
      collegeId: collegeId,
      roomNumber: 'AI-LAB-2',
      roomType: 'AI_Lab',
      capacity: 35,
    );
    final slots = createSlots(6);

    final result = TimetableGenerator.generate(
      collegeId: collegeId,
      sections: [section],
      subjects: [labSubj],
      staffList: [prof1, prof2],
      rooms: [lab1, lab2],
      timeSlots: slots,
      availabilities: [],
    );

    print('\n=== SCENARIO 4: MULTIPLE LABS / MULTIPLE BATCHES ===');
    print('isSuccess: ${result.isSuccess}, entries: ${result.entries.length}');
    for (final e in result.entries) {
      print('  Day: ${e.dayOfWeek}, Period: ${e.periodNumber}, Batch: ${e.batch}, Room: ${e.roomId}, Prof: ${e.teacherId}');
    }

    expect(result.isSuccess, isTrue);
    expect(result.entries.length, 4);

    // Verify rooms are distinct if in same period
    for (final day in ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']) {
      for (var p = 1; p <= 6; p++) {
        final slotEntries = result.entries.where((e) => e.dayOfWeek == day && e.periodNumber == p).toList();
        if (slotEntries.length > 1) {
          final distinctRooms = slotEntries.map((e) => e.roomId).toSet();
          final distinctProfessors = slotEntries.map((e) => e.teacherId).toSet();
          expect(distinctRooms.length, slotEntries.length, reason: 'Parallel batches must occupy distinct physical rooms');
          expect(distinctProfessors.length, slotEntries.length, reason: 'Parallel batches must have distinct professors');
        }
      }
    }
  });

  test('Inspect Scenario 2: Different test configuration (3 Batches, 2 Distinct Labs, 5 Theory Subjects)', () {
    final section = Section(
      id: 'sec_diff_cfg',
      collegeId: collegeId,
      departmentId: 'dept_mech',
      courseId: 'course_btech',
      academicYear: '2026-2027',
      semester: 6,
      sectionName: 'ME-A',
      studentCount: 75,
      batches: ['Group_X', 'Group_Y', 'Group_Z'],
    );
    final subjects = [
      Subject(
        id: 'sub_thermo',
        collegeId: collegeId,
        departmentId: 'dept_mech',
        courseId: 'course_btech',
        semester: 6,
        subjectCode: 'ME601',
        subjectName: 'Thermodynamics',
        subjectType: 'theory',
        hoursPerWeek: 4,
        requiredRoomType: 'Lecture_Hall',
        assignedTeacherIds: ['prof_carnot'],
      ),
      Subject(
        id: 'sub_cad_lab',
        collegeId: collegeId,
        departmentId: 'dept_mech',
        courseId: 'course_btech',
        semester: 6,
        subjectCode: 'ME602L',
        subjectName: 'CAD Lab',
        subjectType: 'lab',
        hoursPerWeek: 2,
        requiredRoomType: 'CAD_Center',
        assignedTeacherIds: ['prof_otto', 'prof_diesel'],
      ),
    ];
    final staff = [
      Staff(
        id: 'prof_carnot',
        collegeId: collegeId,
        employeeId: 'EMP_C',
        name: 'Prof. Carnot',
        email: 'carnot@college.edu',
        departmentId: 'dept_mech',
        status: 'active',
        active: true,
        subjectsCanTeach: ['sub_thermo'],
        maxClassesPerDay: 4,
        maxClassesPerWeek: 20,
      ),
      Staff(
        id: 'prof_otto',
        collegeId: collegeId,
        employeeId: 'EMP_O',
        name: 'Prof. Otto',
        email: 'otto@college.edu',
        departmentId: 'dept_mech',
        status: 'active',
        active: true,
        subjectsCanTeach: ['sub_cad_lab'],
        maxClassesPerDay: 4,
        maxClassesPerWeek: 20,
      ),
      Staff(
        id: 'prof_diesel',
        collegeId: collegeId,
        employeeId: 'EMP_D',
        name: 'Prof. Diesel',
        email: 'diesel@college.edu',
        departmentId: 'dept_mech',
        status: 'active',
        active: true,
        subjectsCanTeach: ['sub_cad_lab'],
        maxClassesPerDay: 4,
        maxClassesPerWeek: 20,
      ),
    ];
    final rooms = [
      Room(
        id: 'hall_1',
        collegeId: collegeId,
        roomNumber: 'LH-101',
        roomType: 'Lecture_Hall',
        capacity: 80,
      ),
      Room(
        id: 'cad_1',
        collegeId: collegeId,
        roomNumber: 'CAD-1',
        roomType: 'CAD_Center',
        capacity: 30,
      ),
      Room(
        id: 'cad_2',
        collegeId: collegeId,
        roomNumber: 'CAD-2',
        roomType: 'CAD_Center',
        capacity: 30,
      ),
    ];
    final slots = createSlots(6);

    final result = TimetableGenerator.generate(
      collegeId: collegeId,
      sections: [section],
      subjects: subjects,
      staffList: staff,
      rooms: rooms,
      timeSlots: slots,
      availabilities: [],
    );

    print('\n=== SCENARIO 2: DIFFERENT TEST CONFIGURATION (3 Batches, 2 Labs, Theory) ===');
    print('isSuccess: ${result.isSuccess}, entries: ${result.entries.length}');
    for (final e in result.entries) {
      print('  Day: ${e.dayOfWeek}, Period: ${e.periodNumber}, Batch: ${e.batch ?? "WHOLE_SECTION"}, Subj: ${e.subjectId}, Room: ${e.roomId}, Prof: ${e.teacherId}');
    }

    expect(result.isSuccess, isTrue);
    expect(result.entries.length, 10); // 4 theory + (3 batches * 2 lab hours) = 10 entries
    
    // Invariant check
    final val = ConflictValidator.validateSchedule(
      collegeId: collegeId,
      entries: result.entries,
      sections: [section],
      subjects: subjects,
      staffList: staff,
      rooms: rooms,
      timeSlots: slots,
      availabilities: [],
      validateHours: true,
    );
    expect(val.hardConflicts, isEmpty);
  });
}
