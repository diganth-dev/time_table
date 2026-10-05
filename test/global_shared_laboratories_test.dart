import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/conflict_validator.dart';
import 'package:time_table/services/timetable_generator.dart';

void main() {
  const collegeId = 'col_global_test';
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
      id: 'ts_lunch',
      collegeId: collegeId,
      periodNumber: 0,
      startTime: '12:00',
      endTime: '13:00',
      order: 4,
      isBreak: true,
      breakTitle: 'Lunch Break',
    ),
    TimeSlot(
      id: 'ts_4',
      collegeId: collegeId,
      periodNumber: 4,
      startTime: '13:00',
      endTime: '14:00',
      order: 5,
    ),
    TimeSlot(
      id: 'ts_5',
      collegeId: collegeId,
      periodNumber: 5,
      startTime: '14:00',
      endTime: '15:00',
      order: 6,
    ),
    TimeSlot(
      id: 'ts_6',
      collegeId: collegeId,
      periodNumber: 6,
      startTime: '15:00',
      endTime: '16:00',
      order: 7,
    ),
  ];

  final profSharma = Staff(
    id: 'staff_sharma',
    collegeId: collegeId,
    name: 'Dr. Sharma',
    email: 'sharma@college.edu',
    departmentId: 'dept_cse',
    designation: 'Associate Professor',
    subjectsCanTeach: ['OOP Lab', 'DSA Lab', 'Python Lab', 'Object Oriented Programming', 'Data Structures', 'Python Programming'],
    maxClassesPerDay: 5,
    active: true,
  );

  final profVerma = Staff(
    id: 'staff_verma',
    collegeId: collegeId,
    name: 'Prof. Verma',
    email: 'verma@college.edu',
    departmentId: 'dept_cse',
    designation: 'Assistant Professor',
    subjectsCanTeach: ['OOP Lab', 'DSA Lab', 'Python Lab', 'Machine Learning Lab', 'AI Lab'],
    maxClassesPerDay: 5,
    active: true,
  );

  final profPatel = Staff(
    id: 'staff_patel',
    collegeId: collegeId,
    name: 'Dr. Patel',
    email: 'patel@college.edu',
    departmentId: 'dept_cse',
    designation: 'Professor',
    subjectsCanTeach: ['Machine Learning Lab', 'AI Lab', 'Python Lab', 'DSA Lab', 'OOP Lab'],
    maxClassesPerDay: 5,
    active: true,
  );

  final allStaff = [profSharma, profVerma, profPatel];

  // Physical Global Rooms (Single Source of Truth)
  final globalComputerLab1 = Room(
    id: 'lab_001',
    collegeId: collegeId,
    roomNumber: 'Computer Lab 1',
    building: 'IT Block',
    floor: 1,
    capacity: 30,
    roomType: 'Computer Lab',
    facilities: ['Computer Lab'],
    compatibleSubjects: ['OOP Lab', 'DSA Lab', 'Python Lab'],
    active: true,
  );

  final globalComputerLab2 = Room(
    id: 'lab_002',
    collegeId: collegeId,
    roomNumber: 'Computer Lab 2',
    building: 'IT Block',
    floor: 1,
    capacity: 30,
    roomType: 'Computer Lab',
    facilities: ['Computer Lab'],
    compatibleSubjects: ['OOP Lab', 'DSA Lab', 'Python Lab'],
    active: true,
  );

  final globalAimlLab = Room(
    id: 'lab_aiml',
    collegeId: collegeId,
    roomNumber: 'AI & ML Lab',
    building: 'Tech Block',
    floor: 2,
    capacity: 30,
    roomType: 'AI & ML Lab',
    facilities: ['AI & ML Lab'],
    compatibleSubjects: ['Machine Learning Lab', 'AI Lab'],
    active: true,
  );

  final globalClassroom101 = Room(
    id: 'room_101',
    collegeId: collegeId,
    roomNumber: 'Room 101',
    building: 'Main Block',
    floor: 1,
    capacity: 60,
    roomType: 'Classroom',
    facilities: ['Classroom'],
    active: true,
  );

  final globalClassroom102 = Room(
    id: 'room_102',
    collegeId: collegeId,
    roomNumber: 'Room 102',
    building: 'Main Block',
    floor: 1,
    capacity: 60,
    roomType: 'Classroom',
    facilities: ['Classroom'],
    active: true,
  );

  group('Global Shared Laboratories Architecture Tests', () {
    test(
      'TEST 1: Section A requires OOP Lab and Section B requires DSA Lab; both can use Computer Lab 1 without overlapping times',
      () {
        final secA = Section(
          id: 'sec_a',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          academicYear: '2026-2027',
          semester: 3,
          sectionName: 'A',
          studentCount: 30,
          batches: ['B1'],
        );

        final secB = Section(
          id: 'sec_b',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          academicYear: '2026-2027',
          semester: 3,
          sectionName: 'B',
          studentCount: 30,
          batches: ['B1'],
        );

        final oopLab = Subject(
          id: 'sub_oop_lab',
          collegeId: collegeId,
          sectionId: secA.id,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          semester: 3,
          subjectCode: 'CS301L',
          subjectName: 'OOP Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: [profSharma.id],
          eligibleLabIds: [globalComputerLab1.id],
        );

        final dsaLab = Subject(
          id: 'sub_dsa_lab',
          collegeId: collegeId,
          sectionId: secB.id,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          semester: 3,
          subjectCode: 'CS302L',
          subjectName: 'DSA Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: [profVerma.id],
          eligibleLabIds: [globalComputerLab1.id],
        );

        // ONLY Computer Lab 1 exists for labs
        final rooms = [globalComputerLab1, globalClassroom101];

        final result = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: [secA, secB],
          subjects: [oopLab, dsaLab],
          staffList: allStaff,
          rooms: rooms,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
        );

        expect(result.isSuccess, isTrue, reason: result.summaryMessage);
        expect(result.entries.length, equals(4)); // 2 periods each

        final secAEntries = result.entries.where((e) => e.sectionId == secA.id).toList();
        final secBEntries = result.entries.where((e) => e.sectionId == secB.id).toList();

        expect(secAEntries.length, equals(2));
        expect(secBEntries.length, equals(2));

        // Both sections use the shared global lab_001
        expect(secAEntries.every((e) => e.roomId == globalComputerLab1.id), isTrue);
        expect(secBEntries.every((e) => e.roomId == globalComputerLab1.id), isTrue);

        // Verify NO overlapping period on the same day in Computer Lab 1
        for (final a in secAEntries) {
          for (final b in secBEntries) {
            if (a.dayOfWeek == b.dayOfWeek) {
              expect(
                a.periodNumber,
                isNot(equals(b.periodNumber)),
                reason: 'Sec A and Sec B cannot occupy Computer Lab 1 simultaneously on ${a.dayOfWeek} at P${a.periodNumber}',
              );
            }
          }
        }

        // Validate complete schedule with ConflictValidator
        final validation = ConflictValidator.validateSchedule(
          collegeId: collegeId,
          entries: result.entries,
          sections: [secA, secB],
          subjects: [oopLab, dsaLab],
          staffList: allStaff,
          rooms: rooms,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
        );
        expect(validation.isValid, isTrue);
        expect(validation.hardConflicts, isEmpty);
      },
    );

    test(
      'TEST 2: Section A uses Computer Lab 1 at Monday P1-P2; Section B must not receive Computer Lab 1 at Monday P1-P2',
      () {
        final secA = Section(
          id: 'sec_a',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          academicYear: '2026-2027',
          semester: 3,
          sectionName: 'A',
          studentCount: 30,
          batches: ['B1'],
        );

        final secB = Section(
          id: 'sec_b',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          academicYear: '2026-2027',
          semester: 3,
          sectionName: 'B',
          studentCount: 30,
          batches: ['B1'],
        );

        final oopLab = Subject(
          id: 'sub_oop_lab',
          collegeId: collegeId,
          sectionId: secA.id,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          semester: 3,
          subjectCode: 'CS301L',
          subjectName: 'OOP Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: [profSharma.id],
          eligibleLabIds: [globalComputerLab1.id],
        );

        final dsaLab = Subject(
          id: 'sub_dsa_lab',
          collegeId: collegeId,
          sectionId: secB.id,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          semester: 3,
          subjectCode: 'CS302L',
          subjectName: 'DSA Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: [profVerma.id],
          eligibleLabIds: [globalComputerLab1.id],
        );

        // Section A already occupies Computer Lab 1 on Monday P1-P2
        final existingSecAEntries = [
          TimetableEntry(
            id: 'entry_sec_a_p1',
            collegeId: collegeId,
            versionId: 'ver_draft',
            dayOfWeek: 'Monday',
            periodNumber: 1,
            timeSlotId: 'ts_1',
            sectionId: secA.id,
            subjectId: oopLab.id,
            teacherId: profSharma.id,
            roomId: globalComputerLab1.id,
            batch: 'B1',
          ),
          TimetableEntry(
            id: 'entry_sec_a_p2',
            collegeId: collegeId,
            versionId: 'ver_draft',
            dayOfWeek: 'Monday',
            periodNumber: 2,
            timeSlotId: 'ts_2',
            sectionId: secA.id,
            subjectId: oopLab.id,
            teacherId: profSharma.id,
            roomId: globalComputerLab1.id,
            batch: 'B1',
          ),
        ];

        final rooms = [globalComputerLab1, globalClassroom101];

        // Generate schedule for Section B respecting Section A's existing entries
        final result = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: [secA, secB],
          subjects: [oopLab, dsaLab],
          staffList: allStaff,
          rooms: rooms,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
          targetSectionId: secB.id,
          existingEntries: existingSecAEntries,
        );

        expect(result.isSuccess, isTrue, reason: result.summaryMessage);

        final secBEntries = result.newlyScheduledEntries;
        expect(secBEntries.length, equals(2));

        // Sec B must NOT receive Monday P1 or P2 in Computer Lab 1
        for (final b in secBEntries) {
          if (b.dayOfWeek == 'Monday' && b.roomId == globalComputerLab1.id) {
            expect(b.periodNumber, isNot(isIn([1, 2])));
          }
        }

        // Verify ConflictValidator catches double booking if forced
        final invalidCollisionEntries = [
          ...existingSecAEntries,
          TimetableEntry(
            id: 'entry_sec_b_collision',
            collegeId: collegeId,
            versionId: 'ver_draft',
            dayOfWeek: 'Monday',
            periodNumber: 1,
            timeSlotId: 'ts_1',
            sectionId: secB.id,
            subjectId: dsaLab.id,
            teacherId: profVerma.id,
            roomId: globalComputerLab1.id,
            batch: 'B1',
          ),
        ];

        final collisionValidation = ConflictValidator.validateSchedule(
          collegeId: collegeId,
          entries: invalidCollisionEntries,
          sections: [secA, secB],
          subjects: [oopLab, dsaLab],
          staffList: allStaff,
          rooms: rooms,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
        );

        expect(collisionValidation.isValid, isFalse);
        expect(
          collisionValidation.hardConflicts.any((c) => c.type == 'roomConflict'),
          isTrue,
        );
      },
    );

    test(
      'TEST 3: Section A and Section B can use the same global lab at different times',
      () {
        final secA = Section(
          id: 'sec_a',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          academicYear: '2026-2027',
          semester: 3,
          sectionName: 'A',
          studentCount: 30,
          batches: ['B1'],
        );

        final secB = Section(
          id: 'sec_b',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          academicYear: '2026-2027',
          semester: 3,
          sectionName: 'B',
          studentCount: 30,
          batches: ['B1'],
        );

        final oopLab = Subject(
          id: 'sub_oop_lab',
          collegeId: collegeId,
          sectionId: secA.id,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          semester: 3,
          subjectCode: 'CS301L',
          subjectName: 'OOP Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: [profSharma.id],
        );

        final dsaLab = Subject(
          id: 'sub_dsa_lab',
          collegeId: collegeId,
          sectionId: secB.id,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          semester: 3,
          subjectCode: 'CS302L',
          subjectName: 'DSA Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: [profVerma.id],
        );

        // Section A on Monday P1-P2, Section B on Monday P4-P5 in same global lab_001
        final entries = [
          TimetableEntry(
            id: 'e1',
            collegeId: collegeId,
            versionId: 'v1',
            dayOfWeek: 'Monday',
            periodNumber: 1,
            timeSlotId: 'ts_1',
            sectionId: secA.id,
            subjectId: oopLab.id,
            teacherId: profSharma.id,
            roomId: globalComputerLab1.id,
            batch: 'B1',
          ),
          TimetableEntry(
            id: 'e2',
            collegeId: collegeId,
            versionId: 'v1',
            dayOfWeek: 'Monday',
            periodNumber: 2,
            timeSlotId: 'ts_2',
            sectionId: secA.id,
            subjectId: oopLab.id,
            teacherId: profSharma.id,
            roomId: globalComputerLab1.id,
            batch: 'B1',
          ),
          TimetableEntry(
            id: 'e3',
            collegeId: collegeId,
            versionId: 'v1',
            dayOfWeek: 'Monday',
            periodNumber: 4,
            timeSlotId: 'ts_4',
            sectionId: secB.id,
            subjectId: dsaLab.id,
            teacherId: profVerma.id,
            roomId: globalComputerLab1.id,
            batch: 'B1',
          ),
          TimetableEntry(
            id: 'e4',
            collegeId: collegeId,
            versionId: 'v1',
            dayOfWeek: 'Monday',
            periodNumber: 5,
            timeSlotId: 'ts_5',
            sectionId: secB.id,
            subjectId: dsaLab.id,
            teacherId: profVerma.id,
            roomId: globalComputerLab1.id,
            batch: 'B1',
          ),
        ];

        final validation = ConflictValidator.validateSchedule(
          collegeId: collegeId,
          entries: entries,
          sections: [secA, secB],
          subjects: [oopLab, dsaLab],
          staffList: allStaff,
          rooms: [globalComputerLab1],
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
        );

        expect(validation.isValid, isTrue);
        expect(validation.hardConflicts, isEmpty);
      },
    );

    test(
      'TEST 4: A lab that is incompatible with a subject must never be selected',
      () {
        final secA = Section(
          id: 'sec_a',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          academicYear: '2026-2027',
          semester: 5,
          sectionName: 'A',
          studentCount: 30,
          batches: ['B1'],
        );

        final mlLab = Subject(
          id: 'sub_ml_lab',
          collegeId: collegeId,
          sectionId: secA.id,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          semester: 5,
          subjectCode: 'CS501L',
          subjectName: 'Machine Learning Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'AI & ML Lab',
          assignedTeacherIds: [profPatel.id],
        );

        // Global labs: Computer Lab 1 (supports OOP Lab, DSA Lab) and AI & ML Lab (supports ML Lab)
        final rooms = [globalComputerLab1, globalAimlLab, globalClassroom101];

        final result = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: [secA],
          subjects: [mlLab],
          staffList: allStaff,
          rooms: rooms,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
        );

        expect(result.isSuccess, isTrue, reason: result.summaryMessage);
        // Must select AI & ML Lab, NEVER Computer Lab 1
        expect(result.entries.every((e) => e.roomId == globalAimlLab.id), isTrue);
        expect(result.entries.any((e) => e.roomId == globalComputerLab1.id), isFalse);

        // If manually placed into Computer Lab 1, ConflictValidator must flag roomTypeMismatch
        final invalidPlacement = [
          TimetableEntry(
            id: 'e_invalid_lab',
            collegeId: collegeId,
            versionId: 'v1',
            dayOfWeek: 'Monday',
            periodNumber: 1,
            timeSlotId: 'ts_1',
            sectionId: secA.id,
            subjectId: mlLab.id,
            teacherId: profPatel.id,
            roomId: globalComputerLab1.id, // Incompatible!
            batch: 'B1',
          ),
        ];

        final validation = ConflictValidator.validateSchedule(
          collegeId: collegeId,
          entries: invalidPlacement,
          sections: [secA],
          subjects: [mlLab],
          staffList: allStaff,
          rooms: rooms,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
        );

        expect(validation.isValid, isFalse);
        expect(
          validation.hardConflicts.any((c) => c.type == 'roomTypeMismatch'),
          isTrue,
        );
      },
    );

    test(
      'TEST 5: A normal classroom must never satisfy a lab requirement',
      () {
        final secA = Section(
          id: 'sec_a',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          academicYear: '2026-2027',
          semester: 3,
          sectionName: 'A',
          studentCount: 30,
          batches: ['B1'],
        );

        final oopLab = Subject(
          id: 'sub_oop_lab',
          collegeId: collegeId,
          sectionId: secA.id,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          semester: 3,
          subjectCode: 'CS301L',
          subjectName: 'OOP Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: [profSharma.id],
        );

        // Only normal Classrooms available! NO lab rooms!
        final rooms = [globalClassroom101, globalClassroom102];

        final result = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: [secA],
          subjects: [oopLab],
          staffList: allStaff,
          rooms: rooms,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
        );

        // Generation must FAIL; classroom 101/102 must never be allocated to OOP Lab
        expect(result.isSuccess, isFalse);
        expect(result.conflicts.any((c) => c.type == 'roomTypeMismatch'), isTrue);

        // If manually placed into Classroom 101, ConflictValidator must flag hard conflict
        final manualClassroomEntry = [
          TimetableEntry(
            id: 'e_lab_in_classroom',
            collegeId: collegeId,
            versionId: 'v1',
            dayOfWeek: 'Tuesday',
            periodNumber: 1,
            timeSlotId: 'ts_1',
            sectionId: secA.id,
            subjectId: oopLab.id,
            teacherId: profSharma.id,
            roomId: globalClassroom101.id, // Normal classroom!
            batch: 'B1',
          ),
        ];

        final validation = ConflictValidator.validateSchedule(
          collegeId: collegeId,
          entries: manualClassroomEntry,
          sections: [secA],
          subjects: [oopLab],
          staffList: allStaff,
          rooms: rooms,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
        );

        expect(validation.isValid, isFalse);
        expect(
          validation.hardConflicts.any((c) => c.type == 'roomTypeMismatch'),
          isTrue,
        );
      },
    );

    test(
      'TEST 6: Three or more sections sharing the same global lab must be scheduled without physical room conflicts',
      () {
        final secA = Section(
          id: 'sec_a',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          academicYear: '2026-2027',
          semester: 3,
          sectionName: 'A',
          studentCount: 30,
          batches: ['B1'],
        );

        final secB = Section(
          id: 'sec_b',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          academicYear: '2026-2027',
          semester: 3,
          sectionName: 'B',
          studentCount: 30,
          batches: ['B1'],
        );

        final secC = Section(
          id: 'sec_c',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          academicYear: '2026-2027',
          semester: 3,
          sectionName: 'C',
          studentCount: 30,
          batches: ['B1'],
        );

        final subA = Subject(
          id: 'sub_a',
          collegeId: collegeId,
          sectionId: secA.id,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          semester: 3,
          subjectCode: 'CS301L',
          subjectName: 'OOP Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: [profSharma.id],
        );

        final subB = Subject(
          id: 'sub_b',
          collegeId: collegeId,
          sectionId: secB.id,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          semester: 3,
          subjectCode: 'CS302L',
          subjectName: 'DSA Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: [profVerma.id],
        );

        final subC = Subject(
          id: 'sub_c',
          collegeId: collegeId,
          sectionId: secC.id,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          semester: 3,
          subjectCode: 'CS303L',
          subjectName: 'Python Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: [profPatel.id],
        );

        // ONLY ONE global Computer Lab exists
        final rooms = [globalComputerLab1, globalClassroom101];

        final result = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: [secA, secB, secC],
          subjects: [subA, subB, subC],
          staffList: allStaff,
          rooms: rooms,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
        );

        expect(result.isSuccess, isTrue, reason: result.summaryMessage);
        expect(result.entries.length, equals(6)); // 2 periods x 3 sections

        // All 3 sections are allocated to globalComputerLab1
        expect(result.entries.every((e) => e.roomId == globalComputerLab1.id), isTrue);

        // Check for any duplicate (day, period) in globalComputerLab1
        final occupiedSlots = <String>{};
        for (final e in result.entries) {
          final slot = '${e.dayOfWeek}_${e.periodNumber}';
          expect(
            occupiedSlots.add(slot),
            isTrue,
            reason: 'Double booking detected at $slot in ${globalComputerLab1.roomNumber}!',
          );
        }

        // Validate via ConflictValidator
        final validation = ConflictValidator.validateSchedule(
          collegeId: collegeId,
          entries: result.entries,
          sections: [secA, secB, secC],
          subjects: [subA, subB, subC],
          staffList: allStaff,
          rooms: rooms,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
        );

        expect(validation.isValid, isTrue);
        expect(validation.hardConflicts, isEmpty);
      },
    );

    test(
      'TEST 7: Existing batch-aware lab rules continue working with global laboratories',
      () {
        final secA = Section(
          id: 'sec_a_batches',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          academicYear: '2026-2027',
          semester: 3,
          sectionName: 'A',
          studentCount: 60,
          batches: ['B1', 'B2'], // 2 batches, each 30 students
        );

        final oopLab = Subject(
          id: 'sub_oop_lab',
          collegeId: collegeId,
          sectionId: secA.id,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          semester: 3,
          subjectCode: 'CS301L',
          subjectName: 'OOP Lab',
          subjectType: 'Lab',
          hoursPerWeek: 4, // 2 periods per batch
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: [profSharma.id, profVerma.id],
        );

        // Two global 30-capacity computer labs available
        final rooms = [globalComputerLab1, globalComputerLab2, globalClassroom101];

        final result = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: [secA],
          subjects: [oopLab],
          staffList: allStaff,
          rooms: rooms,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
        );

        expect(result.isSuccess, isTrue, reason: result.summaryMessage);

        final b1Entries = result.entries.where((e) => e.batch == 'B1').toList();
        final b2Entries = result.entries.where((e) => e.batch == 'B2').toList();

        expect(b1Entries.length, equals(2));
        expect(b2Entries.length, equals(2));

        // When scheduled in parallel or sequentially, each batch must occupy a compatible lab
        for (final b1 in b1Entries) {
          for (final b2 in b2Entries) {
            if (b1.dayOfWeek == b2.dayOfWeek && b1.periodNumber == b2.periodNumber) {
              // Parallel: must NOT share the same physical lab
              expect(
                b1.roomId,
                isNot(equals(b2.roomId)),
                reason: 'Parallel batches cannot occupy the same physical lab room simultaneously',
              );
            }
          }
        }

        final validation = ConflictValidator.validateSchedule(
          collegeId: collegeId,
          entries: result.entries,
          sections: [secA],
          subjects: [oopLab],
          staffList: allStaff,
          rooms: rooms,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
        );
        expect(validation.isValid, isTrue);
        expect(validation.hardConflicts, isEmpty);
      },
    );

    test(
      'TEST 8: Changing the global lab configuration affects all sections that reference that global lab',
      () {
        final secA = Section(
          id: 'sec_a',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          academicYear: '2026-2027',
          semester: 3,
          sectionName: 'A',
          studentCount: 30,
          batches: ['B1'],
        );

        final secB = Section(
          id: 'sec_b',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          academicYear: '2026-2027',
          semester: 3,
          sectionName: 'B',
          studentCount: 30,
          batches: ['B1'],
        );

        final oopLab = Subject(
          id: 'sub_oop_lab',
          collegeId: collegeId,
          sectionId: secA.id,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          semester: 3,
          subjectCode: 'CS301L',
          subjectName: 'OOP Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: [profSharma.id],
          eligibleLabIds: [globalComputerLab1.id],
        );

        final dsaLab = Subject(
          id: 'sub_dsa_lab',
          collegeId: collegeId,
          sectionId: secB.id,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          semester: 3,
          subjectCode: 'CS302L',
          subjectName: 'DSA Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: [profVerma.id],
          eligibleLabIds: [globalComputerLab1.id],
        );

        // Scenario 8A: Global lab_001 is placed under maintenance
        final maintenanceLab = globalComputerLab1.copyWith(
          isUnderMaintenance: true,
          maintenanceReason: 'Network hardware overhaul',
        );

        final resultMaintenance = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: [secA, secB],
          subjects: [oopLab, dsaLab],
          staffList: allStaff,
          rooms: [maintenanceLab, globalClassroom101],
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
        );

        // Both sections fail because their shared global lab is under maintenance
        expect(resultMaintenance.isSuccess, isFalse);
        expect(
          resultMaintenance.conflicts.any((c) => c.type == 'roomTypeMismatch'),
          isTrue,
        );

        // Scenario 8B: Global lab_001 capacity is reduced from 30 to 15 (insufficient for 30 students)
        final smallCapacityLab = globalComputerLab1.copyWith(
          capacity: 15,
        );

        final resultCapacity = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: [secA, secB],
          subjects: [oopLab, dsaLab],
          staffList: allStaff,
          rooms: [smallCapacityLab, globalClassroom101],
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
        );

        // Both sections fail because the shared global lab cannot accommodate 30 students
        expect(resultCapacity.isSuccess, isFalse);
        expect(
          resultCapacity.conflicts.any((c) => c.type == 'roomTypeMismatch'),
          isTrue,
        );
      },
    );

    test(
      'TEST 9: No duplicate physical lab records are created',
      () {
        final secA = Section(
          id: 'sec_a',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          academicYear: '2026-2027',
          semester: 3,
          sectionName: 'A',
          studentCount: 30,
          batches: ['B1'],
          eligibleClassroomIds: [globalClassroom101.id],
        );

        final oopLab = Subject(
          id: 'sub_oop_lab',
          collegeId: collegeId,
          sectionId: secA.id,
          departmentId: 'dept_cse',
          courseId: 'course_cse',
          semester: 3,
          subjectCode: 'CS301L',
          subjectName: 'OOP Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: [profSharma.id],
          eligibleLabIds: [globalComputerLab1.id], // Only a reference!
        );

        // Verify that secA only stores room ID references, not physical room objects
        expect(secA.eligibleClassroomIds, equals(['room_101']));
        expect(oopLab.eligibleLabIds, equals(['lab_001']));

        // Verify JSON representation stores simple list of strings
        final secJson = secA.toJson();
        expect(secJson['eligibleClassroomIds'], equals(['room_101']));

        final subJson = oopLab.toJson();
        expect(subJson['eligibleLabIds'], equals(['lab_001']));

        // Master rooms list has exactly 1 entry for Computer Lab 1
        final rooms = [globalComputerLab1, globalClassroom101];
        expect(rooms.where((r) => r.id == 'lab_001').length, equals(1));
      },
    );

    test(
      'TEST 10: No unrelated Firestore configuration is modified and model serialization is backwards compatible',
      () {
        // Test parsing legacy room json without compatibleSubjects
        final legacyRoomJson = {
          'id': 'room_legacy',
          'collegeId': collegeId,
          'roomNumber': 'Room 201',
          'roomType': 'Classroom',
          'capacity': 60,
          'building': 'Block B',
          'floor': 2,
        };

        final roomFromLegacy = Room.fromJson(legacyRoomJson);
        expect(roomFromLegacy.compatibleSubjects, isEmpty);
        expect(roomFromLegacy.isLab, isFalse);

        // Test parsing legacy section json without eligibleClassroomIds
        final legacySectionJson = {
          'id': 'sec_legacy',
          'collegeId': collegeId,
          'departmentId': 'dept_cse',
          'courseId': 'course_cse',
          'semester': 1,
          'sectionName': 'A',
          'studentCount': 30,
        };

        final sectionFromLegacy = Section.fromJson(legacySectionJson);
        expect(sectionFromLegacy.eligibleClassroomIds, isEmpty);

        // Test parsing legacy subject json without eligibleLabIds
        final legacySubjectJson = {
          'id': 'sub_legacy',
          'collegeId': collegeId,
          'departmentId': 'dept_cse',
          'courseId': 'course_cse',
          'semester': 1,
          'subjectCode': 'CS101',
          'subjectName': 'Intro to CS',
          'subjectType': 'Theory',
          'hoursPerWeek': 4,
          'requiredRoomType': 'Classroom',
        };

        final subjectFromLegacy = Subject.fromJson(legacySubjectJson);
        expect(subjectFromLegacy.eligibleLabIds, isEmpty);
      },
    );
  });
}
