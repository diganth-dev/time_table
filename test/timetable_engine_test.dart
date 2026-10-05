import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/services.dart';

void main() {
  group('Timetable Constraint & Generation Engine Tests', () {
    late String collegeId;
    late List<TimeSlot> standardSlots;
    late List<Room> rooms;
    late List<Staff> teachers;
    late List<Section> sections;
    late List<Subject> subjects;

    setUp(() {
      collegeId = 'test_col';

      // 6 academic periods + morning break + lunch break
      standardSlots = [
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
          id: 'ts_b1',
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

      // Rooms
      rooms = [
        Room(
          id: 'room_101',
          collegeId: collegeId,
          roomNumber: 'Room 101',
          capacity: 70,
          roomType: 'Classroom',
        ),
        Room(
          id: 'room_102',
          collegeId: collegeId,
          roomNumber: 'Room 102',
          capacity: 70,
          roomType: 'Classroom',
        ),
        Room(
          id: 'room_lab1',
          collegeId: collegeId,
          roomNumber: 'Computer Lab 1',
          capacity: 65,
          roomType: 'Computer Lab',
        ),
        Room(
          id: 'room_lab2',
          collegeId: collegeId,
          roomNumber: 'Computer Lab 2',
          capacity: 65,
          roomType: 'Computer Lab',
        ),
      ];

      // Teachers
      teachers = [
        Staff(
          id: 'staff_ravi',
          collegeId: collegeId,
          employeeId: 'EMP001',
          name: 'Dr. Ravi',
          email: 'ravi@college.edu',
          departmentId: 'dept_cse',
          status: 'active',
          subjectsCanTeach: ['sub_dbms', 'sub_dbms_lab'],
          maxClassesPerDay: 4,
        ),
        Staff(
          id: 'staff_priya',
          collegeId: collegeId,
          employeeId: 'EMP002',
          name: 'Prof. Priya',
          email: 'priya@college.edu',
          departmentId: 'dept_cse',
          status: 'active',
          subjectsCanTeach: ['sub_math', 'sub_os_lab'],
          maxClassesPerDay: 4,
        ),
      ];

      // Section: CSE 3A with 60 students
      sections = [
        Section(
          id: 'sec_cse_3a',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'c1',
          academicYear: '2026-2027',
          semester: 3,
          sectionName: 'A',
          studentCount: 60,
          batches: ['B1', 'B2'],
        ),
      ];

      // Subjects: DBMS (Theory, 3 hrs/week), DBMS Lab (Lab, 2 hrs/week), OS Lab (Lab, 2 hrs/week), Math (Theory, 3 hrs/week)
      subjects = [
        Subject(
          id: 'sub_dbms',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'c1',
          semester: 3,
          subjectCode: 'CS301',
          subjectName: 'DBMS',
          subjectType: 'Theory',
          hoursPerWeek: 3,
          requiredRoomType: 'Classroom',
          assignedTeacherIds: ['staff_ravi'],
        ),
        Subject(
          id: 'sub_dbms_lab',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'c1',
          semester: 3,
          subjectCode: 'CS302L',
          subjectName: 'DBMS Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: ['staff_ravi'],
        ),
        Subject(
          id: 'sub_os_lab',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'c1',
          semester: 3,
          subjectCode: 'CS303L',
          subjectName: 'OS Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: ['staff_priya'],
        ),
        Subject(
          id: 'sub_math',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'c1',
          semester: 3,
          subjectCode: 'MA301',
          subjectName: 'Mathematics',
          subjectType: 'Theory',
          hoursPerWeek: 3,
          requiredRoomType: 'Classroom',
          assignedTeacherIds: ['staff_priya'],
        ),
      ];
    });

    test(
      'Engine produces valid conflict-free timetable satisfying all hours and constraints',
      () {
        final result = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: sections,
          subjects: subjects,
          staffList: teachers,
          rooms: rooms,
          timeSlots: standardSlots,
          availabilities: [],
          workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        );

        expect(result.isSuccess, isTrue);
        // Total periods: 3 (DBMS) + 4 (2 lab blocks of 2 periods each) + 3 (Math) = 10 periods
        // Total entries: 3 (DBMS) + 8 (Labs: 2 blocks x 2 periods x 2 batches) + 3 (Math) = 14 entries
        expect(result.entries.length, equals(14));
        expect(result.conflicts.where((c) => c.isHard).isEmpty, isTrue);

        // Verify no classes scheduled during break periods
        for (final entry in result.entries) {
          expect(entry.periodNumber, isNot(equals(0)));
        }

        // Verify Lab subjects assigned to Computer Labs only and have distinct subjects for B1 and B2
        final labEntries = result.entries.where(
          (e) => e.batch != null,
        ).toList();
        for (final e in labEntries) {
          expect(['room_lab1', 'room_lab2'].contains(e.roomId), isTrue);
          expect(['B1', 'B2'].contains(e.batch), isTrue);
        }
        final periodGroups = <String, List<TimetableEntry>>{};
        for (final e in labEntries) {
          final key = '${e.dayOfWeek}_${e.periodNumber}';
          periodGroups.putIfAbsent(key, () => []).add(e);
        }
        for (final slot in periodGroups.values) {
          if (slot.length > 1) {
            final subjectsInSlot = slot.map((e) => e.subjectId).toSet();
            final roomsInSlot = slot.map((e) => e.roomId).toSet();
            final teachersInSlot = slot.map((e) => e.teacherId).toSet();
            expect(subjectsInSlot.length, equals(slot.length),
                reason: 'Different lab subjects across batches in parallel');
            expect(roomsInSlot.length, equals(slot.length),
                reason: 'Separate physical compatible rooms');
            expect(teachersInSlot.length, equals(slot.length),
                reason: 'Separate professors');
          }
        }
      },
    );

    test(
      'ConflictValidator detects Teacher Double-Booking (Hard Conflict)',
      () {
        // Create another section
        final secB = Section(
          id: 'sec_cse_3b',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          courseId: 'c1',
          academicYear: '2026-2027',
          semester: 3,
          sectionName: 'B',
          studentCount: 50,
        );

        // Same teacher (Dr. Ravi) assigned to two sections on Monday Period 1
        final entries = [
          TimetableEntry(
            id: 'e1',
            collegeId: collegeId,
            versionId: 'v1',
            dayOfWeek: 'Monday',
            periodNumber: 1,
            sectionId: 'sec_cse_3a',
            subjectId: 'sub_dbms',
            teacherId: 'staff_ravi',
            roomId: 'room_101',
          ),
          TimetableEntry(
            id: 'e2',
            collegeId: collegeId,
            versionId: 'v1',
            dayOfWeek: 'Monday',
            periodNumber: 1,
            sectionId: 'sec_cse_3b',
            subjectId: 'sub_dbms',
            teacherId: 'staff_ravi',
            roomId: 'room_102',
          ),
        ];

        final validation = ConflictValidator.validateSchedule(
          collegeId: collegeId,
          entries: entries,
          sections: [...sections, secB],
          subjects: subjects,
          staffList: teachers,
          rooms: rooms,
          timeSlots: standardSlots,
          availabilities: [],
        );

        expect(validation.isValid, isFalse);
        expect(
          validation.hardConflicts.any((c) => c.type == 'teacherConflict'),
          isTrue,
        );
      },
    );

    test('ConflictValidator detects Room Double-Booking (Hard Conflict)', () {
      final secB = Section(
        id: 'sec_cse_3b',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'c1',
        academicYear: '2026-2027',
        semester: 3,
        sectionName: 'B',
        studentCount: 50,
      );

      // Two different teachers assigned to the same room (Room 101) on Monday Period 1
      final entries = [
        TimetableEntry(
          id: 'e1',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          sectionId: 'sec_cse_3a',
          subjectId: 'sub_dbms',
          teacherId: 'staff_ravi',
          roomId: 'room_101',
        ),
        TimetableEntry(
          id: 'e2',
          collegeId: collegeId,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          sectionId: 'sec_cse_3b',
          subjectId: 'sub_math',
          teacherId: 'staff_priya',
          roomId: 'room_101',
        ),
      ];

      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: entries,
        sections: [...sections, secB],
        subjects: subjects,
        staffList: teachers,
        rooms: rooms,
        timeSlots: standardSlots,
        availabilities: [],
      );

      expect(validation.isValid, isFalse);
      expect(
        validation.hardConflicts.any((c) => c.type == 'roomConflict'),
        isTrue,
      );
    });

    test(
      'ConflictValidator detects Section Double-Booking (Hard Conflict)',
      () {
        // Section CSE 3A assigned to two classes on Monday Period 2
        final entries = [
          TimetableEntry(
            id: 'e1',
            collegeId: collegeId,
            versionId: 'v1',
            dayOfWeek: 'Monday',
            periodNumber: 2,
            sectionId: 'sec_cse_3a',
            subjectId: 'sub_dbms',
            teacherId: 'staff_ravi',
            roomId: 'room_101',
          ),
          TimetableEntry(
            id: 'e2',
            collegeId: collegeId,
            versionId: 'v1',
            dayOfWeek: 'Monday',
            periodNumber: 2,
            sectionId: 'sec_cse_3a',
            subjectId: 'sub_math',
            teacherId: 'staff_priya',
            roomId: 'room_102',
          ),
        ];

        final validation = ConflictValidator.validateSchedule(
          collegeId: collegeId,
          entries: entries,
          sections: sections,
          subjects: subjects,
          staffList: teachers,
          rooms: rooms,
          timeSlots: standardSlots,
          availabilities: [],
        );

        expect(validation.isValid, isFalse);
        expect(
          validation.hardConflicts.any((c) => c.type == 'sectionConflict'),
          isTrue,
        );
      },
    );

    test(
      'ConflictValidator detects Room Capacity Insufficiency (Hard Conflict)',
      () {
        // Room with only 40 seats for a section of 60 students
        final smallRoom = Room(
          id: 'room_small',
          collegeId: collegeId,
          roomNumber: 'Small Room',
          capacity: 40,
          roomType: 'Classroom',
        );

        final entries = [
          TimetableEntry(
            id: 'e1',
            collegeId: collegeId,
            versionId: 'v1',
            dayOfWeek: 'Monday',
            periodNumber: 1,
            sectionId: 'sec_cse_3a', // 60 students
            subjectId: 'sub_dbms',
            teacherId: 'staff_ravi',
            roomId: 'room_small', // 40 capacity
          ),
        ];

        final validation = ConflictValidator.validateSchedule(
          collegeId: collegeId,
          entries: entries,
          sections: sections,
          subjects: subjects,
          staffList: teachers,
          rooms: [...rooms, smallRoom],
          timeSlots: standardSlots,
          availabilities: [],
        );

        expect(validation.isValid, isFalse);
        expect(
          validation.hardConflicts.any((c) => c.type == 'capacityConflict'),
          isTrue,
        );
      },
    );

    test(
      'ConflictValidator detects Teacher Availability / Leave Conflict (Hard Conflict)',
      () {
        // Prof. Priya marked unavailable on Tuesday Period 3
        final leaveRecord = TeacherAvailability(
          id: 'leave_1',
          collegeId: collegeId,
          teacherId: 'staff_priya',
          dayOfWeek: 'Tuesday',
          periodNumber: 3,
          isAvailable: false,
          isLeave: true,
          leaveReason: 'Medical Leave',
        );

        final entries = [
          TimetableEntry(
            id: 'e1',
            collegeId: collegeId,
            versionId: 'v1',
            dayOfWeek: 'Tuesday',
            periodNumber: 3,
            sectionId: 'sec_cse_3a',
            subjectId: 'sub_math',
            teacherId: 'staff_priya',
            roomId: 'room_101',
          ),
        ];

        final validation = ConflictValidator.validateSchedule(
          collegeId: collegeId,
          entries: entries,
          sections: sections,
          subjects: subjects,
          staffList: teachers,
          rooms: rooms,
          timeSlots: standardSlots,
          availabilities: [leaveRecord],
        );

        expect(validation.isValid, isFalse);
        expect(
          validation.hardConflicts.any((c) => c.type == 'availabilityConflict'),
          isTrue,
        );
      },
    );

    test(
      'ConflictValidator detects Incompatible Room Type for Labs (Hard Conflict)',
      () {
        // Scheduling DBMS Lab in standard Classroom instead of Computer Lab
        final entries = [
          TimetableEntry(
            id: 'e1',
            collegeId: collegeId,
            versionId: 'v1',
            dayOfWeek: 'Wednesday',
            periodNumber: 1,
            sectionId: 'sec_cse_3a',
            subjectId: 'sub_dbms_lab', // Requires Computer Lab
            teacherId: 'staff_ravi',
            roomId: 'room_101', // General Classroom
          ),
        ];

        final validation = ConflictValidator.validateSchedule(
          collegeId: collegeId,
          entries: entries,
          sections: sections,
          subjects: subjects,
          staffList: teachers,
          rooms: rooms,
          timeSlots: standardSlots,
          availabilities: [],
        );

        expect(validation.isValid, isFalse);
        expect(
          validation.hardConflicts.any((c) => c.type == 'roomTypeMismatch'),
          isTrue,
        );
      },
    );

    test(
      'ConflictValidator detects Class Scheduled during Break or Lunch (Hard Conflict)',
      () {
        final entries = [
          TimetableEntry(
            id: 'e1',
            collegeId: collegeId,
            versionId: 'v1',
            dayOfWeek: 'Thursday',
            periodNumber: 0, // Period 0 corresponds to break
            timeSlotId: 'ts_lunch',
            sectionId: 'sec_cse_3a',
            subjectId: 'sub_dbms',
            teacherId: 'staff_ravi',
            roomId: 'room_101',
          ),
        ];

        final validation = ConflictValidator.validateSchedule(
          collegeId: collegeId,
          entries: entries,
          sections: sections,
          subjects: subjects,
          staffList: teachers,
          rooms: rooms,
          timeSlots: standardSlots,
          availabilities: [],
        );

        expect(validation.isValid, isFalse);
        expect(
          validation.hardConflicts.any(
            (c) => c.type == 'breakCollisionConflict',
          ),
          isTrue,
        );
      },
    );
  });
}
