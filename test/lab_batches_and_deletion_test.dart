import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/repositories/repositories.dart';
import 'package:time_table/services/services.dart';

void main() {
  group('Comprehensive Lab Batches (B1/B2) & Deletion Validation Tests', () {
    const collegeId = 'test_uni';
    final workingDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
    ];

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
        id: 'ts_b',
        collegeId: collegeId,
        periodNumber: 0,
        startTime: '11:00',
        endTime: '11:15',
        order: 3,
        isBreak: true,
        breakTitle: 'Tea Break',
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
        id: 'ts_5',
        collegeId: collegeId,
        periodNumber: 5,
        startTime: '14:00',
        endTime: '15:00',
        order: 6,
      ),
    ];

    final staff = [
      Staff(
        id: 'prof_kumar',
        collegeId: collegeId,
        employeeId: 'EMP001',
        name: 'Prof. Kumar',
        email: 'kumar@college.edu',
        departmentId: 'dept_cs',
        status: 'active',
        subjectsCanTeach: ['Theory CS', 'DBMS Lab'],
        maxClassesPerDay: 4,
      ),
      Staff(
        id: 'prof_sharma',
        collegeId: collegeId,
        employeeId: 'EMP002',
        name: 'Prof. Sharma',
        email: 'sharma@college.edu',
        departmentId: 'dept_cs',
        status: 'active',
        subjectsCanTeach: ['Web Tech', 'CN Lab'],
        maxClassesPerDay: 4,
      ),
    ];

    final sectionA = Section(
      id: 'sec_a',
      collegeId: collegeId,
      departmentId: 'dept_cs',
      courseId: 'c_btech',
      academicYear: '2026-2027',
      semester: 3,
      sectionName: 'A',
      studentCount: 60,
      batches: ['B1', 'B2'],
    );

    final theorySubject = Subject(
      id: 'sub_theory',
      collegeId: collegeId,
      departmentId: 'dept_cs',
      courseId: 'c_btech',
      semester: 3,
      subjectCode: 'CS301',
      subjectName: 'Theory CS',
      subjectType: 'Theory',
      hoursPerWeek: 3,
      requiredRoomType: 'Classroom',
      assignedTeacherIds: ['prof_kumar'],
    );

    final labSubject = Subject(
      id: 'sub_lab',
      collegeId: collegeId,
      departmentId: 'dept_cs',
      courseId: 'c_btech',
      semester: 3,
      subjectCode: 'CS302L',
      subjectName: 'DBMS Lab',
      subjectType: 'Lab',
      hoursPerWeek: 2,
      consecutivePeriods: 2,
      requiredRoomType: 'Computer Lab',
      assignedTeacherIds: ['prof_kumar'],
    );

    final labSubject2 = Subject(
      id: 'sub_lab2',
      collegeId: collegeId,
      departmentId: 'dept_cs',
      courseId: 'c_btech',
      semester: 3,
      subjectCode: 'CS303L',
      subjectName: 'CN Lab',
      subjectType: 'Lab',
      hoursPerWeek: 2,
      consecutivePeriods: 2,
      requiredRoomType: 'Computer Lab',
      assignedTeacherIds: ['prof_sharma'],
    );

    final rooms2Labs = [
      Room(
        id: 'cr_1',
        collegeId: collegeId,
        roomNumber: 'CR 101',
        capacity: 70,
        roomType: 'Classroom',
      ),
      Room(
        id: 'cr_2',
        collegeId: collegeId,
        roomNumber: 'CR 102',
        capacity: 70,
        roomType: 'Classroom',
      ),
      Room(
        id: 'lab_1',
        collegeId: collegeId,
        roomNumber: 'Lab Alpha',
        capacity: 35,
        roomType: 'Computer Lab',
      ),
      Room(
        id: 'lab_2',
        collegeId: collegeId,
        roomNumber: 'Lab Beta',
        capacity: 40,
        roomType: 'Computer Lab',
      ),
    ];

    test('1. Normal classroom subject still generates normally', () {
      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [sectionA],
        subjects: [theorySubject],
        staffList: staff,
        rooms: rooms2Labs,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isTrue);
      expect(result.entries.length, equals(3));
      for (final e in result.entries) {
        expect(e.subjectId, equals('sub_theory'));
        expect(e.batch, isNull);
        final room = rooms2Labs.firstWhere((r) => r.id == e.roomId);
        expect(room.roomType, equals('Classroom'));
      }
    });

    test(
      '2, 3, 4, 5, 6, 7, 8, 9: Lab subject generates separate B1 and B2 in suitable labs without double-booking or batch overlap',
      () {
        final result = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: [sectionA],
          subjects: [theorySubject, labSubject, labSubject2],
          staffList: staff,
          rooms: rooms2Labs,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
        );

        expect(result.isSuccess, isTrue);
        // 3 theory periods (3 entries) + 4 lab periods (8 entries: 2 blocks x 2 periods x 2 batches) = 11 entries total
        expect(result.entries.length, equals(11));

        final labEntries = result.entries
            .where((e) => e.batch != null)
            .toList();
        // Requirement 2: Generates B1 and B2
        expect(labEntries.length, equals(8)); // 2 blocks x 2 periods x 2 batches
        final b1List = labEntries.where((e) => e.batch == 'B1').toList();
        final b2List = labEntries.where((e) => e.batch == 'B2').toList();
        expect(b1List.length, equals(4));
        expect(b2List.length, equals(4));

        // Requirement 3: B1 and B2 scheduled in parallel with different subjects in separate rooms
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

        // Requirements 4, 5, 6: Lab entries satisfy required facility (Computer Lab) and capacity
        for (final entry in labEntries) {
          final room = rooms2Labs.firstWhere((r) => r.id == entry.roomId);
          expect(room.roomType, equals('Computer Lab'));
          expect(room.capacity >= 30, isTrue);
        }

        // Requirement 7: Professor is not double-booked
        final profEntries = result.entries
            .where((e) => e.teacherId == 'prof_kumar')
            .toList();
        final profSlots = <String, Set<String>>{};
        for (final e in profEntries) {
          final key = '${e.dayOfWeek}_${e.periodNumber}';
          profSlots.putIfAbsent(key, () => <String>{}).add(e.sectionId);
        }
        for (final secSet in profSlots.values) {
          expect(secSet.length, equals(1)); // Only one section at any period
        }

        // Requirement 8: Section is not double-booked (whole section classes have 1 entry; parallel batch labs have unique batches)
        final secSlots = <String, List<TimetableEntry>>{};
        for (final e in result.entries) {
          final key = '${e.dayOfWeek}_${e.periodNumber}';
          secSlots.putIfAbsent(key, () => []).add(e);
        }
        for (final entriesInSlot in secSlots.values) {
          if (entriesInSlot.any((e) => e.batch == null)) {
            expect(entriesInSlot.length, equals(1), reason: 'Whole-section classes occupy the slot alone');
          } else {
            final batchesInSlot = entriesInSlot.map((e) => e.batch).toSet();
            expect(batchesInSlot.length, equals(entriesInSlot.length), reason: 'Each batch in the slot must be unique');
          }
        }

        // Requirement 9: Lab weekly requirement (each batch gets 4 periods total: 2 periods per subject)
        expect(b1List.length, equals(4));
        expect(b2List.length, equals(4));

        // Validate through ConflictValidator
        final validation = ConflictValidator.validateSchedule(
          collegeId: collegeId,
          entries: result.entries,
          sections: [sectionA],
          subjects: [theorySubject, labSubject, labSubject2],
          staffList: staff,
          rooms: rooms2Labs,
          timeSlots: timeSlots,
          availabilities: [],
        );
        expect(validation.isValid, isTrue);
        expect(validation.hardConflicts, isEmpty);
      },
    );

    test(
      '10. Zero suitable labs produce a clear generation error reporting suitable lab is required',
      () {
        // Provide ZERO computer labs
        final noLabRooms = [
          Room(
            id: 'cr_1',
            collegeId: collegeId,
            roomNumber: 'CR 101',
            capacity: 70,
            roomType: 'Classroom',
          ),
        ];

        final result = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: [sectionA],
          subjects: [theorySubject, labSubject, labSubject2],
          staffList: staff,
          rooms: noLabRooms,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
        );

        expect(result.isSuccess, isFalse);
        expect(
          result.summaryMessage,
          equals(
            'Timetable could not be generated because enough suitable lab rooms are not available.',
          ),
        );
        expect(
          result.conflicts.any((c) => c.title.contains('Suitable Lab')),
          isTrue,
        );
      },
    );

    test(
      'Configured batch names and count drive distinct batch lab entries and room allocation',
      () {
        final threeBatchSection = sectionA.copyWith(
          batches: ['Red', 'Blue', 'Green'],
        );
        final profThird = Staff(
          id: 'prof_third',
          collegeId: collegeId,
          employeeId: 'EMP003',
          name: 'Prof. Third',
          email: 'third@college.edu',
          departmentId: 'dept_cs',
          status: 'active',
          subjectsCanTeach: ['OS Lab'],
          maxClassesPerDay: 4,
        );
        final labSubject3 = Subject(
          id: 'sub_lab3',
          collegeId: collegeId,
          departmentId: 'dept_cs',
          courseId: 'c_btech',
          semester: 3,
          subjectCode: 'CS304L',
          subjectName: 'OS Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: 'Computer Lab',
          assignedTeacherIds: ['prof_third'],
        );
        final threeLabs = [
          ...rooms2Labs,
          Room(
            id: 'lab_3',
            collegeId: collegeId,
            roomNumber: 'Lab Gamma',
            capacity: 25,
            roomType: 'Computer Lab',
          ),
        ];
        final result = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: [threeBatchSection],
          subjects: [labSubject, labSubject2, labSubject3],
          staffList: [...staff, profThird],
          rooms: threeLabs,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: workingDays,
        );

        expect(result.isSuccess, isTrue);
        final labs = result.entries;
        expect(labs.length, equals(18)); // 3 subjects x 2 periods x 3 batches

        final redEntries = labs.where((e) => e.batch == 'Red').toList();
        final blueEntries = labs.where((e) => e.batch == 'Blue').toList();
        final greenEntries = labs.where((e) => e.batch == 'Green').toList();
        expect(redEntries.length, equals(6));
        expect(blueEntries.length, equals(6));
        expect(greenEntries.length, equals(6));

        // When batches run simultaneously, they must have distinct rooms and distinct teachers
        final periodMap = <String, List<TimetableEntry>>{};
        for (final entry in labs) {
          final key = '${entry.dayOfWeek}_${entry.periodNumber}';
          periodMap.putIfAbsent(key, () => []).add(entry);
        }
        for (final entriesInSlot in periodMap.values) {
          final distinctRooms = entriesInSlot.map((e) => e.roomId).toSet();
          final distinctTeachers = entriesInSlot.map((e) => e.teacherId).toSet();
          expect(distinctRooms.length, equals(entriesInSlot.length),
              reason: 'Batches at same time must use distinct physical rooms');
          expect(distinctTeachers.length, equals(entriesInSlot.length),
              reason: 'Batches at same time must have distinct professors');
        }

        for (final entry in labs) {
          final room = threeLabs.firstWhere((r) => r.id == entry.roomId);
          expect(room.roomType, equals('Computer Lab'));
        }

        final validation = ConflictValidator.validateSchedule(
          collegeId: collegeId,
          entries: labs,
          sections: [threeBatchSection],
          subjects: [labSubject, labSubject2, labSubject3],
          staffList: [...staff, profThird],
          rooms: threeLabs,
          timeSlots: timeSlots,
          availabilities: [],
        );
        expect(validation.isValid, isTrue);
      },
    );

    test('Room validator rejects two parallel batches assigned to one lab', () {
      final entries = [
        for (final batch in ['B1', 'B2'])
          TimetableEntry(
            id: 'entry_$batch',
            collegeId: collegeId,
            versionId: 'v1',
            dayOfWeek: 'Monday',
            periodNumber: 1,
            sectionId: sectionA.id,
            subjectId: labSubject.id,
            teacherId: 'prof_kumar',
            roomId: 'lab_1',
            batch: batch,
          ),
      ];
      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: entries,
        sections: [sectionA],
        subjects: [labSubject],
        staffList: staff,
        rooms: rooms2Labs,
        timeSlots: timeSlots,
        availabilities: [],
      );
      expect(
        validation.hardConflicts.any(
          (conflict) => conflict.type == 'roomConflict',
        ),
        isTrue,
      );
    });

    test(
      'Different sections can run parallel labs when distinct rooms and professors are available',
      () {
        final secondSection = sectionA.copyWith(id: 'sec_b', sectionName: 'B');
        final secondProfessor = Staff(
          id: 'prof_second',
          collegeId: collegeId,
          employeeId: 'EMP003',
          name: 'Prof. Second',
          email: 'second@college.edu',
          departmentId: 'dept_cs',
          status: 'active',
          subjectsCanTeach: ['Other Lab 1'],
          maxClassesPerDay: 4,
        );
        final fourthProfessor = Staff(
          id: 'prof_fourth',
          collegeId: collegeId,
          employeeId: 'EMP004',
          name: 'Prof. Fourth',
          email: 'fourth@college.edu',
          departmentId: 'dept_cs',
          status: 'active',
          subjectsCanTeach: ['Other Lab 2'],
          maxClassesPerDay: 4,
        );
        final firstSubject1 = labSubject.copyWith(
          sectionId: sectionA.id,
          hoursPerWeek: 2,
        );
        final firstSubject2 = labSubject2.copyWith(
          sectionId: sectionA.id,
          hoursPerWeek: 2,
        );
        final secondSubject1 = labSubject.copyWith(
          id: 'other_lab1',
          sectionId: secondSection.id,
          subjectCode: 'CS303L',
          subjectName: 'Other Lab 1',
          assignedTeacherIds: ['prof_second'],
          hoursPerWeek: 2,
        );
        final secondSubject2 = labSubject2.copyWith(
          id: 'other_lab2',
          sectionId: secondSection.id,
          subjectCode: 'CS304L',
          subjectName: 'Other Lab 2',
          assignedTeacherIds: ['prof_fourth'],
          hoursPerWeek: 2,
        );
        final fourLabs = [
          ...rooms2Labs,
          Room(
            id: 'lab_3',
            collegeId: collegeId,
            roomNumber: 'Lab Gamma',
            capacity: 35,
            roomType: 'Computer Lab',
          ),
          Room(
            id: 'lab_4',
            collegeId: collegeId,
            roomNumber: 'Lab Delta',
            capacity: 35,
            roomType: 'Computer Lab',
          ),
        ];
        final result = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: [sectionA, secondSection],
          subjects: [firstSubject1, firstSubject2, secondSubject1, secondSubject2],
          staffList: [...staff, secondProfessor, fourthProfessor],
          rooms: fourLabs,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: ['Monday', 'Tuesday'],
        );
        expect(result.isSuccess, isTrue);
        final firstPeriod = result.entries
            .where(
              (entry) =>
                  entry.periodNumber == result.entries.first.periodNumber,
            )
            .toList();
        expect(
          firstPeriod.map((entry) => entry.sectionId).toSet(),
          equals({sectionA.id, secondSection.id}),
        );
        expect(
          firstPeriod.map((entry) => entry.roomId).toSet().length,
          equals(4),
        );

        final validation = ConflictValidator.validateSchedule(
          collegeId: collegeId,
          entries: result.entries,
          sections: [sectionA, secondSection],
          subjects: [firstSubject1, firstSubject2, secondSubject1, secondSubject2],
          staffList: [...staff, secondProfessor, fourthProfessor],
          rooms: fourLabs,
          timeSlots: timeSlots,
          availabilities: [],
        );
        expect(validation.isValid, isTrue);
      },
    );

    test(
      'Different sections sharing a lab room at the same time produce a room conflict',
      () {
        final secondSection = sectionA.copyWith(
          id: 'sec_room_conflict',
          sectionName: 'B',
        );
        final secondProfessor = Staff(
          id: 'prof_room_conflict',
          collegeId: collegeId,
          employeeId: 'EMP004',
          name: 'Prof. Room',
          email: 'room@college.edu',
          departmentId: 'dept_cs',
          status: 'active',
          subjectsCanTeach: ['Other Lab'],
          maxClassesPerDay: 4,
        );
        final secondSubject = labSubject.copyWith(
          id: 'other_lab_room_conflict',
          sectionId: secondSection.id,
          subjectCode: 'CS304L',
          subjectName: 'Other Lab',
          assignedTeacherIds: [secondProfessor.id],
        );
        final entries = <TimetableEntry>[];
        for (final batch in ['B1', 'B2']) {
          entries.add(
            TimetableEntry(
              id: 'first_$batch',
              collegeId: collegeId,
              versionId: 'v1',
              dayOfWeek: 'Monday',
              periodNumber: 1,
              sectionId: sectionA.id,
              subjectId: labSubject.id,
              teacherId: 'prof_kumar',
              roomId: batch == 'B1' ? 'lab_1' : 'lab_2',
              batch: batch,
            ),
          );
          entries.add(
            TimetableEntry(
              id: 'second_$batch',
              collegeId: collegeId,
              versionId: 'v1',
              dayOfWeek: 'Monday',
              periodNumber: 1,
              sectionId: secondSection.id,
              subjectId: secondSubject.id,
              teacherId: secondProfessor.id,
              roomId: batch == 'B1' ? 'lab_1' : 'lab_3',
              batch: batch,
            ),
          );
        }
        final rooms = [
          ...rooms2Labs,
          Room(
            id: 'lab_3',
            collegeId: collegeId,
            roomNumber: 'Lab Gamma',
            capacity: 35,
            roomType: 'Computer Lab',
          ),
        ];
        final validation = ConflictValidator.validateSchedule(
          collegeId: collegeId,
          entries: entries,
          sections: [sectionA, secondSection],
          subjects: [labSubject, secondSubject],
          staffList: [...staff, secondProfessor],
          rooms: rooms,
          timeSlots: timeSlots,
          availabilities: [],
        );
        expect(
          validation.hardConflicts.any(
            (conflict) => conflict.type == 'roomConflict',
          ),
          isTrue,
        );
      },
    );

    test(
      'Generator prefers adjacent periods for a compact valid theory timetable',
      () {
        final oneDaySlots = [
          for (var period = 1; period <= 5; period++)
            TimeSlot(
              id: 'p$period',
              collegeId: collegeId,
              periodNumber: period,
              startTime: '${8 + period}:00',
              endTime: '${9 + period}:00',
              order: period,
            ),
        ];
        final compactSection = sectionA.copyWith(batches: []);
        final s1 = theorySubject.copyWith(id: 'sub_t1', subjectCode: 'CS301', subjectName: 'Theory CS 1', hoursPerWeek: 1);
        final s2 = theorySubject.copyWith(id: 'sub_t2', subjectCode: 'CS302', subjectName: 'Theory CS 2', hoursPerWeek: 1);
        final s3 = theorySubject.copyWith(id: 'sub_t3', subjectCode: 'CS303', subjectName: 'Theory CS 3', hoursPerWeek: 1);
        final s4 = theorySubject.copyWith(id: 'sub_t4', subjectCode: 'CS304', subjectName: 'Theory CS 4', hoursPerWeek: 1);
        final updatedStaff = staff.map((st) => st.copyWith(subjectsCanTeach: [...st.subjectsCanTeach, 'sub_t1', 'sub_t2', 'sub_t3', 'sub_t4', 'Theory CS 1', 'Theory CS 2', 'Theory CS 3', 'Theory CS 4'])).toList();
        final result = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: [compactSection],
          subjects: [s1, s2, s3, s4],
          staffList: updatedStaff,
          rooms: rooms2Labs,
          timeSlots: oneDaySlots,
          availabilities: [],
          workingDays: ['Monday'],
        );
        final periods =
            result.entries.map((entry) => entry.periodNumber).toList()..sort();
        expect(result.isSuccess, isTrue);
        expect(periods, equals([1, 2, 3, 4]));
      },
    );

    test(
      '11, 12. Deleting a section removes its related subjects and timetable entries without affecting unrelated sections',
      () async {
        final db = LocalDatabaseRepository();
        const testCol = 'col_delete_test';

        final sec1 = Section(
          id: 'sec_1',
          collegeId: testCol,
          departmentId: 'd1',
          courseId: 'c1',
          academicYear: '2026',
          semester: 1,
          sectionName: 'A',
          studentCount: 30,
        );
        final sec2 = Section(
          id: 'sec_2',
          collegeId: testCol,
          departmentId: 'd1',
          courseId: 'c1',
          academicYear: '2026',
          semester: 1,
          sectionName: 'B',
          studentCount: 30,
        );

        await db.createSection(sec1);
        await db.createSection(sec2);

        final subj1 = Subject(
          id: 'subj_1',
          collegeId: testCol,
          sectionId: 'sec_1',
          departmentId: 'd1',
          courseId: 'c1',
          semester: 1,
          subjectCode: 'CS101',
          subjectName: 'Intro CS',
        );
        final subj2 = Subject(
          id: 'subj_2',
          collegeId: testCol,
          sectionId: 'sec_2',
          departmentId: 'd1',
          courseId: 'c1',
          semester: 1,
          subjectCode: 'CS102',
          subjectName: 'Data Structures',
        );

        await db.createSubject(subj1);
        await db.createSubject(subj2);

        final entry1 = TimetableEntry(
          id: 'e_1',
          collegeId: testCol,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          sectionId: 'sec_1',
          subjectId: 'subj_1',
          teacherId: 't1',
          roomId: 'r1',
        );
        final entry2 = TimetableEntry(
          id: 'e_2',
          collegeId: testCol,
          versionId: 'v1',
          dayOfWeek: 'Monday',
          periodNumber: 2,
          sectionId: 'sec_2',
          subjectId: 'subj_2',
          teacherId: 't1',
          roomId: 'r1',
        );

        await db.createTimetableEntry(entry1);
        await db.createTimetableEntry(entry2);

        // Verify initial state
        expect((await db.getSections(testCol)).length, equals(2));
        expect((await db.getSubjects(testCol)).length, equals(2));
        expect((await db.getTimetableEntries(testCol)).length, equals(2));

        // Act: Delete section 1
        await db.deleteSection('sec_1');

        // Assert Requirement 11: Section 1, its subjects, and its timetable entries are removed
        final remainingSections = await db.getSections(testCol);
        expect(remainingSections.any((s) => s.id == 'sec_1'), isFalse);

        final remainingSubjects = await db.getSubjects(testCol);
        expect(remainingSubjects.any((s) => s.sectionId == 'sec_1'), isFalse);

        final remainingEntries = await db.getTimetableEntries(testCol);
        expect(remainingEntries.any((e) => e.sectionId == 'sec_1'), isFalse);

        // Assert Requirement 12: Unrelated section 2 and its data are completely unaffected
        expect(remainingSections.any((s) => s.id == 'sec_2'), isTrue);
        expect(remainingSubjects.any((s) => s.sectionId == 'sec_2'), isTrue);
        expect(remainingEntries.any((e) => e.sectionId == 'sec_2'), isTrue);
      },
    );

    test(
      '13, 14, 15. Deleting a timetable removes only timetable data, leaves inputs intact, and allows regenerating new timetable',
      () async {
        final db = LocalDatabaseRepository();
        const colDelete = 'col_tt_del';

        final sec = Section(
          id: 'sec_del',
          collegeId: colDelete,
          departmentId: 'd1',
          courseId: 'c1',
          academicYear: '2026',
          semester: 1,
          sectionName: 'A',
          studentCount: 30,
        );
        final sub = Subject(
          id: 'sub_del',
          collegeId: colDelete,
          sectionId: 'sec_del',
          departmentId: 'd1',
          courseId: 'c1',
          semester: 1,
          subjectCode: 'CS101',
          subjectName: 'Intro',
          hoursPerWeek: 1,
          assignedTeacherIds: ['t_del'],
        );
        final prof = Staff(
          id: 't_del',
          collegeId: colDelete,
          employeeId: 'E1',
          name: 'Dr. Test',
          email: 'test@college.edu',
          departmentId: 'd1',
          status: 'active',
          subjectsCanTeach: ['Intro'],
        );
        final room = Room(
          id: 'r_del',
          collegeId: colDelete,
          roomNumber: '101',
          capacity: 50,
          roomType: 'Classroom',
        );

        await db.createSection(sec);
        await db.createSubject(sub);
        await db.createStaff(prof);
        await db.createRoom(room);

        // Create generated timetable entries and version
        final version = TimetableVersion(
          id: 'v_test',
          collegeId: colDelete,
          versionNumber: 1,
          name: 'Draft 1',
          academicYear: '2026',
          semester: 'Odd',
        );
        await db.createTimetableVersion(version);

        final entry = TimetableEntry(
          id: 'e_del',
          collegeId: colDelete,
          versionId: 'v_test',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          sectionId: 'sec_del',
          subjectId: 'sub_del',
          teacherId: 't_del',
          roomId: 'r_del',
        );
        await db.createTimetableEntry(entry);
        await db.saveConflicts(colDelete, [
          ConflictItem(
            id: 'c1',
            collegeId: colDelete,
            type: 'warning',
            title: 'Test Warning',
            description: 'Test',
            dayOfWeek: 'Monday',
          ),
        ]);

        // Verify entries and conflicts exist
        expect((await db.getTimetableEntries(colDelete)).length, equals(1));
        expect((await db.getTimetableVersions(colDelete)).length, equals(1));
        expect((await db.getConflicts(colDelete)).length, equals(1));

        // Act: Delete timetable
        await db.deleteTimetable(colDelete);

        // Assert Requirement 13: Timetable data, versions, and conflicts are removed
        expect((await db.getTimetableEntries(colDelete)).isEmpty, isTrue);
        expect((await db.getTimetableVersions(colDelete)).isEmpty, isTrue);
        expect((await db.getConflicts(colDelete)).isEmpty, isTrue);

        // Input data remains completely unchanged
        expect((await db.getSections(colDelete)).length, equals(1));
        expect((await db.getSubjects(colDelete)).length, equals(1));
        expect((await db.getStaffList(colDelete)).length, equals(1));
        expect((await db.getRooms(colDelete)).length, equals(1));

        // Assert Requirement 14: User can generate another timetable from the same input data
        final regenResult = TimetableGenerator.generate(
          collegeId: colDelete,
          sections: await db.getSections(colDelete),
          subjects: await db.getSubjects(colDelete),
          staffList: await db.getStaffList(colDelete),
          rooms: await db.getRooms(colDelete),
          timeSlots: [
            TimeSlot(
              id: 'ts1',
              collegeId: colDelete,
              periodNumber: 1,
              startTime: '09:00',
              endTime: '10:00',
              order: 1,
            ),
          ],
          availabilities: [],
          workingDays: ['Monday'],
        );

        expect(regenResult.isSuccess, isTrue);
        expect(regenResult.entries.isNotEmpty, isTrue);
        expect(regenResult.entries.first.sectionId, equals('sec_del'));

        // Assert Requirement 15: Backward compatibility (serialization with null batch and with batch)
        final legacyJson = {
          'id': 'legacy_1',
          'collegeId': colDelete,
          'versionId': 'v1',
          'dayOfWeek': 'Monday',
          'periodNumber': 1,
          'sectionId': 'sec_del',
          'subjectId': 'sub_del',
          'teacherId': 't_del',
          'roomId': 'r_del',
          // 'batch' field omitted as in older records
        };
        final legacyEntry = TimetableEntry.fromJson(legacyJson);
        expect(legacyEntry.batch, isNull);

        final newJson = legacyEntry.copyWith(batch: 'B1').toJson();
        expect(newJson['batch'], equals('B1'));
      },
    );
  });
}
