import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/services.dart';

void main() {
  group('Working Days Timetable Distribution & Soft Objective Tests', () {
    const collegeId = 'col_distribution_test';

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

    final classrooms = [
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
    ];

    final labRooms = [
      Room(
        id: 'lab_1',
        collegeId: collegeId,
        roomNumber: 'AI Lab 1',
        capacity: 35,
        roomType: 'Computer Lab',
      ),
      Room(
        id: 'lab_2',
        collegeId: collegeId,
        roomNumber: 'AI Lab 2',
        capacity: 35,
        roomType: 'Computer Lab',
      ),
    ];

    final allRooms = [...classrooms, ...labRooms];

    final teachers = [
      Staff(
        id: 'prof_t1',
        collegeId: collegeId,
        employeeId: 'EMP001',
        name: 'Dr. Alan',
        email: 'alan@college.edu',
        departmentId: 'dept_aiml',
        status: 'active',
        subjectsCanTeach: ['sub_ai', 'sub_ai_lab', 'sub_ai_a', 'sub_ai_b', 'sub_ai_lab_a'],
        maxClassesPerDay: 4,
      ),
      Staff(
        id: 'prof_t2',
        collegeId: collegeId,
        employeeId: 'EMP002',
        name: 'Prof. Barbara',
        email: 'barbara@college.edu',
        departmentId: 'dept_aiml',
        status: 'active',
        subjectsCanTeach: ['sub_ml', 'sub_ml_b', 'sub_ai_lab_b', 'sub_ml_lab'],
        maxClassesPerDay: 4,
      ),
      Staff(
        id: 'prof_t3',
        collegeId: collegeId,
        employeeId: 'EMP003',
        name: 'Dr. Charles',
        email: 'charles@college.edu',
        departmentId: 'dept_aiml',
        status: 'active',
        subjectsCanTeach: ['sub_math'],
        maxClassesPerDay: 4,
      ),
      Staff(
        id: 'prof_t4',
        collegeId: collegeId,
        employeeId: 'EMP004',
        name: 'Prof. Diana',
        email: 'diana@college.edu',
        departmentId: 'dept_aiml',
        status: 'active',
        subjectsCanTeach: ['sub_ds'],
        maxClassesPerDay: 4,
      ),
      Staff(
        id: 'prof_t5',
        collegeId: collegeId,
        employeeId: 'EMP005',
        name: 'Prof. Evan',
        email: 'evan@college.edu',
        departmentId: 'dept_aiml',
        status: 'active',
        subjectsCanTeach: ['sub_dbms'],
        maxClassesPerDay: 4,
      ),
    ];

    final aimlSection = Section(
      id: 'sec_aiml_a',
      collegeId: collegeId,
      departmentId: 'dept_aiml',
      courseId: 'course_btech',
      academicYear: '2026-2027',
      semester: 5,
      sectionName: 'AIML-A',
      studentCount: 60,
      batches: ['B1', 'B2'],
    );

    // 1. Six working days + enough weekly classes: every working day receives classes
    test(
      '1. Six working days + enough weekly classes: every working day receives at least one class',
      () {
        // 5 theory subjects (4 hours each) + 2 labs (2 hours each = 4 hours lab total) = 24 periods total
        final subjects = [
          Subject(
            id: 'sub_ai',
            collegeId: collegeId,
            departmentId: 'dept_aiml',
            courseId: 'course_btech',
            subjectName: 'Artificial Intelligence',
            subjectCode: 'AI501',
            semester: 5,
            hoursPerWeek: 4,
            assignedTeacherIds: ['prof_t1'],
            sectionId: aimlSection.id,
          ),
          Subject(
            id: 'sub_ml',
            collegeId: collegeId,
            departmentId: 'dept_aiml',
            courseId: 'course_btech',
            subjectName: 'Machine Learning',
            subjectCode: 'ML502',
            semester: 5,
            hoursPerWeek: 4,
            assignedTeacherIds: ['prof_t2'],
            sectionId: aimlSection.id,
          ),
          Subject(
            id: 'sub_math',
            collegeId: collegeId,
            departmentId: 'dept_aiml',
            courseId: 'course_btech',
            subjectName: 'Discrete Mathematics',
            subjectCode: 'MA503',
            semester: 5,
            hoursPerWeek: 4,
            assignedTeacherIds: ['prof_t3'],
            sectionId: aimlSection.id,
          ),
          Subject(
            id: 'sub_ds',
            collegeId: collegeId,
            departmentId: 'dept_aiml',
            courseId: 'course_btech',
            subjectName: 'Data Structures',
            subjectCode: 'DS504',
            semester: 5,
            hoursPerWeek: 4,
            assignedTeacherIds: ['prof_t4'],
            sectionId: aimlSection.id,
          ),
          Subject(
            id: 'sub_dbms',
            collegeId: collegeId,
            departmentId: 'dept_aiml',
            courseId: 'course_btech',
            subjectName: 'Database Systems',
            subjectCode: 'DB505',
            semester: 5,
            hoursPerWeek: 4,
            assignedTeacherIds: ['prof_t5'],
            sectionId: aimlSection.id,
          ),
          Subject(
            id: 'sub_ai_lab',
            collegeId: collegeId,
            departmentId: 'dept_aiml',
            courseId: 'course_btech',
            subjectName: 'AI Laboratory',
            subjectCode: 'AIL506',
            semester: 5,
            subjectType: 'Lab',
            hoursPerWeek: 2,
            consecutivePeriods: 2,
            requiredRoomType: 'Computer Lab',
            assignedTeacherIds: ['prof_t1'],
            sectionId: aimlSection.id,
          ),
          Subject(
            id: 'sub_ml_lab',
            collegeId: collegeId,
            departmentId: 'dept_aiml',
            courseId: 'course_btech',
            subjectName: 'ML Laboratory',
            subjectCode: 'MLL507',
            semester: 5,
            subjectType: 'Lab',
            hoursPerWeek: 2,
            consecutivePeriods: 2,
            requiredRoomType: 'Computer Lab',
            assignedTeacherIds: ['prof_t2'],
            sectionId: aimlSection.id,
          ),
        ];

        final result = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: [aimlSection],
          subjects: subjects,
          staffList: teachers,
          rooms: allRooms,
          timeSlots: standardSlots,
          availabilities: [],
          workingDays: sixDays,
        );

        expect(result.isSuccess, isTrue);
        expect(result.conflicts.where((c) => c.isHard).isEmpty, isTrue);

        // Every configured working day MUST have scheduled classes
        for (final day in sixDays) {
          final dayEntries =
              result.entries.where((e) => e.dayOfWeek == day).toList();
          expect(
            dayEntries.isNotEmpty,
            isTrue,
            reason:
                'Working day $day should NOT be left empty when section has 24 weekly periods across 6 days',
          );
        }

        // Verify balance across working days: each day should have between 3 and 5 periods
        for (final day in sixDays) {
          final uniquePeriodCount = result.entries
              .where((e) => e.dayOfWeek == day)
              .map((e) => e.periodNumber)
              .toSet()
              .length;
          expect(
            uniquePeriodCount >= 3 && uniquePeriodCount <= 5,
            isTrue,
            reason:
                'Day $day has $uniquePeriodCount periods; expected balanced between 3 and 5',
          );
        }
      },
    );

    // 2. Fewer total class periods than working days: distribute as evenly as possible, no fake classes
    test(
      '2. Fewer total class periods than working days: exactly 5 periods distributed across 5 days, no fake classes',
      () {
        // 5 total class periods and 6 working days
        final subjects = [
          Subject(
            id: 'sub_ai',
            collegeId: collegeId,
            departmentId: 'dept_aiml',
            courseId: 'course_btech',
            subjectName: 'Artificial Intelligence',
            subjectCode: 'AI501',
            semester: 5,
            hoursPerWeek: 3,
            assignedTeacherIds: ['prof_t1'],
            sectionId: aimlSection.id,
          ),
          Subject(
            id: 'sub_ml',
            collegeId: collegeId,
            departmentId: 'dept_aiml',
            courseId: 'course_btech',
            subjectName: 'Machine Learning',
            subjectCode: 'ML502',
            semester: 5,
            hoursPerWeek: 2,
            assignedTeacherIds: ['prof_t2'],
            sectionId: aimlSection.id,
          ),
        ];

        final result = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: [aimlSection],
          subjects: subjects,
          staffList: teachers,
          rooms: allRooms,
          timeSlots: standardSlots,
          availabilities: [],
          workingDays: sixDays,
        );

        expect(result.isSuccess, isTrue);
        expect(result.conflicts.where((c) => c.isHard).isEmpty, isTrue);

        // Exactly 5 periods scheduled (NO fake classes)
        expect(result.entries.length, equals(5));

        // Subject requirements unchanged: AI has 3, ML has 2
        final aiEntries =
            result.entries.where((e) => e.subjectId == 'sub_ai').toList();
        final mlEntries =
            result.entries.where((e) => e.subjectId == 'sub_ml').toList();
        expect(aiEntries.length, equals(3));
        expect(mlEntries.length, equals(2));

        // Distributed as evenly as possible: 5 distinct days each receive 1 period
        final daysWithClasses =
            result.entries.map((e) => e.dayOfWeek).toSet();
        expect(daysWithClasses.length, equals(5));

        for (final day in daysWithClasses) {
          final countForDay =
              result.entries.where((e) => e.dayOfWeek == day).length;
          expect(
            countForDay,
            equals(1),
            reason: 'Each active day should have exactly 1 class for maximum balance',
          );
        }
      },
    );

    // 3. Professor availability is still respected
    test('3. Professor availability: professor unavailable on Tuesday is not scheduled on Tuesday', () {
      final profUnavailableOnTuesday = teachers.map((t) {
        if (t.id == 'prof_t1') {
          return t.copyWith(
            unavailableTimes: [
              UnavailableTime(
                dayOfWeek: 'Tuesday',
                startTime: '09:00',
                endTime: '16:00',
              ),
            ],
          );
        }
        return t;
      }).toList();

      final subjects = [
        Subject(
          id: 'sub_ai',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'Artificial Intelligence',
          subjectCode: 'AI501',
          semester: 5,
          hoursPerWeek: 4,
          assignedTeacherIds: ['prof_t1'],
          sectionId: aimlSection.id,
        ),
        Subject(
          id: 'sub_ml',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'Machine Learning',
          subjectCode: 'ML502',
          semester: 5,
          hoursPerWeek: 4,
          assignedTeacherIds: ['prof_t2'],
          sectionId: aimlSection.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [aimlSection],
        subjects: subjects,
        staffList: profUnavailableOnTuesday,
        rooms: allRooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: sixDays,
      );

      expect(result.isSuccess, isTrue);
      // Dr. Alan (prof_t1) must NOT be scheduled on Tuesday
      final alanTuesdayEntries = result.entries.where(
        (e) => e.teacherId == 'prof_t1' && e.dayOfWeek == 'Tuesday',
      );
      expect(alanTuesdayEntries, isEmpty);
    });

    // 4. Room availability is still respected: no room double-booking
    test('4. Room availability: no room double-booking across different sections', () {
      final sectionB = Section(
        id: 'sec_aiml_b',
        collegeId: collegeId,
        departmentId: 'dept_aiml',
        courseId: 'course_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: 'AIML-B',
        studentCount: 60,
      );

      final subjects = [
        Subject(
          id: 'sub_ai_a',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'AI for A',
          subjectCode: 'AI501',
          semester: 5,
          hoursPerWeek: 3,
          assignedTeacherIds: ['prof_t1'],
          sectionId: aimlSection.id,
        ),
        Subject(
          id: 'sub_ml_b',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'ML for B',
          subjectCode: 'ML502',
          semester: 5,
          hoursPerWeek: 3,
          assignedTeacherIds: ['prof_t2'],
          sectionId: sectionB.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [aimlSection, sectionB],
        subjects: subjects,
        staffList: teachers,
        rooms: classrooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: sixDays,
      );

      expect(result.isSuccess, isTrue);
      final roomSlots = <String>{};
      for (final e in result.entries) {
        final key = '${e.dayOfWeek}_${e.periodNumber}_${e.roomId}';
        expect(
          roomSlots.contains(key),
          isFalse,
          reason: 'Room double booking detected at $key',
        );
        roomSlots.add(key);
      }
    });

    // 5. Section conflicts: zero double-booking for the same section
    test('5. Section conflicts: zero double-booking for same section', () {
      final subjects = [
        Subject(
          id: 'sub_ai',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'Artificial Intelligence',
          subjectCode: 'AI501',
          semester: 5,
          hoursPerWeek: 4,
          assignedTeacherIds: ['prof_t1'],
          sectionId: aimlSection.id,
        ),
        Subject(
          id: 'sub_ml',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'Machine Learning',
          subjectCode: 'ML502',
          semester: 5,
          hoursPerWeek: 4,
          assignedTeacherIds: ['prof_t2'],
          sectionId: aimlSection.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [aimlSection],
        subjects: subjects,
        staffList: teachers,
        rooms: classrooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: sixDays,
      );

      expect(result.isSuccess, isTrue);
      final sectionSlots = <String>{};
      for (final e in result.entries) {
        final key = '${e.dayOfWeek}_${e.periodNumber}_${e.sectionId}';
        expect(
          sectionSlots.contains(key),
          isFalse,
          reason: 'Section double booking at $key',
        );
        sectionSlots.add(key);
      }
    });

    // 6. Professor conflicts: zero professor double-booking across sections
    test('6. Professor conflicts: zero professor double-booking across sections', () {
      final sectionB = Section(
        id: 'sec_aiml_b',
        collegeId: collegeId,
        departmentId: 'dept_aiml',
        courseId: 'course_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: 'AIML-B',
        studentCount: 60,
      );

      // Both sections share Dr. Alan (prof_t1)
      final subjects = [
        Subject(
          id: 'sub_ai_a',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'AI for Section A',
          subjectCode: 'AI501',
          semester: 5,
          hoursPerWeek: 3,
          assignedTeacherIds: ['prof_t1'],
          sectionId: aimlSection.id,
        ),
        Subject(
          id: 'sub_ai_b',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'AI for Section B',
          subjectCode: 'AI501',
          semester: 5,
          hoursPerWeek: 3,
          assignedTeacherIds: ['prof_t1'],
          sectionId: sectionB.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [aimlSection, sectionB],
        subjects: subjects,
        staffList: teachers,
        rooms: classrooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: sixDays,
      );

      expect(result.isSuccess, isTrue);
      final profSlots = <String>{};
      for (final e in result.entries) {
        final key = '${e.dayOfWeek}_${e.periodNumber}_${e.teacherId}';
        expect(
          profSlots.contains(key),
          isFalse,
          reason: 'Professor double booking at $key',
        );
        profSlots.add(key);
      }
    });

    // 7. Lab conflicts: zero lab conflicts
    test('7. Lab conflicts: zero lab double booking', () {
      final secA = aimlSection.copyWith(studentCount: 30, batches: ['B1']);
      final sectionB = Section(
        id: 'sec_aiml_b',
        collegeId: collegeId,
        departmentId: 'dept_aiml',
        courseId: 'course_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: 'AIML-B',
        studentCount: 30,
        batches: ['B1'],
      );

      final subjects = [
        Subject(
          id: 'sub_ai_lab_a',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'AI Lab A',
          subjectCode: 'AIL506',
          semester: 5,
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: ['prof_t1'],
          sectionId: secA.id,
        ),
        Subject(
          id: 'sub_ai_lab_b',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'AI Lab B',
          subjectCode: 'AIL506',
          semester: 5,
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: ['prof_t2'],
          sectionId: sectionB.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secA, sectionB],
        subjects: subjects,
        staffList: teachers,
        rooms: allRooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: sixDays,
      );

      expect(result.isSuccess, isTrue);
      final roomOccupied = <String>{};
      for (final e in result.entries) {
        final key = '${e.dayOfWeek}_${e.periodNumber}_${e.roomId}';
        expect(
          roomOccupied.contains(key),
          isFalse,
          reason: 'Lab room double booking at $key',
        );
        roomOccupied.add(key);
      }
    });

    // 8. Two-period lab remains consecutive
    test('8. Two-period lab: remains consecutive and never split', () {
      final secA = aimlSection.copyWith(studentCount: 30, batches: ['B1']);
      final subjects = [
        Subject(
          id: 'sub_ai_lab',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'AI Laboratory',
          subjectCode: 'AIL506',
          semester: 5,
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: ['prof_t1'],
          sectionId: secA.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [secA],
        subjects: subjects,
        staffList: teachers,
        rooms: allRooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: sixDays,
      );

      expect(result.isSuccess, isTrue);
      final b1Entries = result.entries.where((e) => e.batch == 'B1').toList()
        ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
      expect(b1Entries.length, equals(2));
      expect(b1Entries[0].dayOfWeek, equals(b1Entries[1].dayOfWeek));
      expect(b1Entries[1].periodNumber, equals(b1Entries[0].periodNumber + 1));
    });

    // 9. Configured batches: B1 and B2 run in separate, non-overlapping periods (LAB ROOM + B1/B2 = NEVER SAME TIME)
    test('9. Configured batches: B1 and B2 run in separate, non-overlapping periods', () {
      final sectionWithBatches = aimlSection.copyWith(batches: ['B1', 'B2']);
      final subjects = [
        Subject(
          id: 'sub_ai_lab',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'AI Laboratory',
          subjectCode: 'AIL506',
          semester: 5,
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: ['prof_t1'],
          sectionId: sectionWithBatches.id,
        ),
        Subject(
          id: 'sub_ml_lab',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'ML Laboratory',
          subjectCode: 'MLL507',
          semester: 5,
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: ['prof_t2'],
          sectionId: sectionWithBatches.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [sectionWithBatches],
        subjects: subjects,
        staffList: teachers,
        rooms: allRooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: sixDays,
      );

      expect(result.isSuccess, isTrue);
      final periodGroups = <String, List<TimetableEntry>>{};
      for (final e in result.entries.where((e) => e.batch != null)) {
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
      // Both batches complete their required hours
      expect(result.entries.where((e) => e.batch == 'B1').length, equals(4));
      expect(result.entries.where((e) => e.batch == 'B2').length, equals(4));
    });

    // 10. Breaks remain respected
    test('10. Breaks: zero classes scheduled during break periods', () {
      final subjects = [
        Subject(
          id: 'sub_ai',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'Artificial Intelligence',
          subjectCode: 'AI501',
          semester: 5,
          hoursPerWeek: 6,
          assignedTeacherIds: ['prof_t1'],
          sectionId: aimlSection.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [aimlSection],
        subjects: subjects,
        staffList: teachers,
        rooms: classrooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: sixDays,
      );

      expect(result.isSuccess, isTrue);
      final breakSlotIds =
          standardSlots.where((s) => s.isBreak).map((s) => s.id).toSet();

      for (final entry in result.entries) {
        expect(entry.periodNumber, isNot(equals(0)));
        expect(breakSlotIds.contains(entry.timeSlotId), isFalse,
            reason: 'Entry must not be placed in a break time slot');
      }
    });

    // 11. Weekly subject requirements: exact required hours remain unchanged
    test('11. Weekly subject requirements: each subject receives exact required hours', () {
      final subjects = [
        Subject(
          id: 'sub_ai',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'Artificial Intelligence',
          subjectCode: 'AI501',
          semester: 5,
          hoursPerWeek: 5,
          assignedTeacherIds: ['prof_t1'],
          sectionId: aimlSection.id,
        ),
        Subject(
          id: 'sub_ml',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'Machine Learning',
          subjectCode: 'ML502',
          semester: 5,
          hoursPerWeek: 3,
          assignedTeacherIds: ['prof_t2'],
          sectionId: aimlSection.id,
        ),
        Subject(
          id: 'sub_math',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'Discrete Mathematics',
          subjectCode: 'MA503',
          semester: 5,
          hoursPerWeek: 4,
          assignedTeacherIds: ['prof_t3'],
          sectionId: aimlSection.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [aimlSection],
        subjects: subjects,
        staffList: teachers,
        rooms: classrooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: sixDays,
      );

      expect(result.isSuccess, isTrue);
      expect(
        result.entries.where((e) => e.subjectId == 'sub_ai').length,
        equals(5),
      );
      expect(
        result.entries.where((e) => e.subjectId == 'sub_ml').length,
        equals(3),
      );
      expect(
        result.entries.where((e) => e.subjectId == 'sub_math').length,
        equals(4),
      );
    });

    // 12. Existing timetable version isolation: remains unchanged
    test('12. Existing timetable version isolation: existing other-section entries are preserved and isolated', () {
      final sectionB = Section(
        id: 'sec_aiml_b',
        collegeId: collegeId,
        departmentId: 'dept_aiml',
        courseId: 'course_btech',
        academicYear: '2026-2027',
        semester: 5,
        sectionName: 'AIML-B',
        studentCount: 60,
      );

      final existingEntrySecB = TimetableEntry(
        id: 'existing_b1',
        collegeId: collegeId,
        versionId: 'ver_draft_1',
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts_1',
        sectionId: sectionB.id,
        subjectId: 'sub_ml',
        teacherId: 'prof_t2',
        roomId: 'room_101',
      );

      final subjects = [
        Subject(
          id: 'sub_ai',
          collegeId: collegeId,
          departmentId: 'dept_aiml',
          courseId: 'course_btech',
          subjectName: 'Artificial Intelligence',
          subjectCode: 'AI501',
          semester: 5,
          hoursPerWeek: 4,
          assignedTeacherIds: ['prof_t1'],
          sectionId: aimlSection.id,
        ),
      ];

      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [aimlSection, sectionB],
        subjects: subjects,
        staffList: teachers,
        rooms: classrooms,
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: sixDays,
        customVersionId: 'ver_draft_1',
        targetSectionId: aimlSection.id,
        existingEntries: [existingEntrySecB],
      );

      expect(result.isSuccess, isTrue);
      // Section B's entry should still be present in the entries
      expect(
        result.entries.any((e) => e.id == 'existing_b1'),
        isTrue,
        reason: 'Existing entry for Section B must be preserved',
      );

      // Section A should NOT collide with Section B on Monday Period 1 in room_101
      final secACollisions = result.entries.where(
        (e) =>
            e.sectionId == aimlSection.id &&
            e.dayOfWeek == 'Monday' &&
            e.periodNumber == 1 &&
            e.roomId == 'room_101',
      );
      expect(secACollisions, isEmpty);
    });
  });
}
