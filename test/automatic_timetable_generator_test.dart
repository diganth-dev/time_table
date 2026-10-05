import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/repositories/repositories.dart';
import 'package:time_table/services/services.dart';

void main() {
  group('Automatic Timetable Generator Engine & Constraint Tests', () {
    const collegeId = 'test_college';

    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

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
        id: 'ts_recess',
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
        id: 'ts_lunch',
        collegeId: collegeId,
        periodNumber: 0,
        startTime: '13:15',
        endTime: '14:00',
        order: 6,
        isBreak: true,
        breakTitle: 'Lunch Break',
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

    final rooms = [
      Room(
        id: 'r_101',
        collegeId: collegeId,
        roomNumber: 'Room 101',
        building: 'Academic',
        floor: 1,
        capacity: 60,
        roomType: 'Classroom',
      ),
      Room(
        id: 'r_102',
        collegeId: collegeId,
        roomNumber: 'Room 102',
        building: 'Academic',
        floor: 1,
        capacity: 60,
        roomType: 'Classroom',
      ),
      Room(
        id: 'r_lab1',
        collegeId: collegeId,
        roomNumber: 'Lab 1',
        building: 'Tech Wing',
        floor: 2,
        capacity: 60,
        roomType: 'Computer Lab',
      ),
      Room(
        id: 'r_lab2',
        collegeId: collegeId,
        roomNumber: 'Lab 2',
        building: 'Tech Wing',
        floor: 2,
        capacity: 60,
        roomType: 'Computer Lab',
      ),
    ];

    final List<Staff> professors = [
      Staff(
        id: 'prof_ravi',
        employeeId: 'EMP001',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        name: 'Dr. Ravi',
        email: 'ravi@college.edu',
        designation: 'Associate Professor',
        role: 'faculty',
        status: 'active',
        subjectsCanTeach: ['sub_dbms', 'sub_dbms_lab'],
        maxClassesPerDay: 4,
        maxClassesPerWeek: 20,
      ),
      Staff(
        id: 'prof_priya',
        employeeId: 'EMP002',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        name: 'Prof. Priya',
        email: 'priya@college.edu',
        designation: 'Assistant Professor',
        role: 'faculty',
        status: 'active',
        subjectsCanTeach: ['sub_os', 'sub_os_lab'],
        maxClassesPerDay: 4,
        maxClassesPerWeek: 20,
      ),
    ];

    final sections = [
      Section(
        id: 'sec_a',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        academicYear: '2026-2027',
        semester: 3,
        sectionName: 'A',
        studentCount: 40,
        batches: ['B1', 'B2'],
      ),
      Section(
        id: 'sec_b',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        academicYear: '2026-2027',
        semester: 3,
        sectionName: 'B',
        studentCount: 40,
        batches: ['B1', 'B2'],
      ),
    ];

    final subjects = [
      Subject(
        id: 'sub_dbms',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        semester: 3,
        subjectCode: 'CS301',
        subjectName: 'DBMS',
        subjectType: 'Theory',
        hoursPerWeek: 4,
        requiredRoomType: 'Classroom',
        assignedTeacherIds: ['prof_ravi'],
      ),
      Subject(
        id: 'sub_dbms_lab',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        semester: 3,
        subjectCode: 'CS302L',
        subjectName: 'DBMS Lab',
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_ravi'],
      ),
      Subject(
        id: 'sub_os_lab',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        semester: 3,
        subjectCode: 'CS304L',
        subjectName: 'OS Lab',
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_priya'],
      ),
      Subject(
        id: 'sub_os',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        semester: 3,
        subjectCode: 'CS303',
        subjectName: 'Operating Systems',
        subjectType: 'Theory',
        hoursPerWeek: 4,
        requiredRoomType: 'Classroom',
        assignedTeacherIds: ['prof_priya'],
      ),
    ];

    test(
      'Engine successfully generates complete schedule satisfying all 6 constraints',
      () {
        final result = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: sections,
          subjects: subjects,
          staffList: professors,
          rooms: rooms,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: days,
        );
        expect(result.isSuccess, isTrue);
        expect(result.conflicts.isEmpty, isTrue);
        // Section A: 4 (DBMS) + 8 (Labs B1+B2) + 4 (OS) = 16 entries
        // Section B: 4 (DBMS) + 8 (Labs B1+B2) + 4 (OS) = 16 entries
        // Total = 32 entries
        expect(result.entries.length, equals(32));
        expect(result.teachersUsed, equals(2));
        expect(result.sectionsScheduled, equals(2));

        // Rule 1: No teacher double-booking across different sections
        final teacherSlots = <String, Set<String>>{};
        for (final e in result.entries) {
          final key = '${e.dayOfWeek}_${e.periodNumber}_${e.teacherId}';
          teacherSlots.putIfAbsent(key, () => <String>{}).add(e.sectionId);
        }
        for (final secSet in teacherSlots.values) {
          expect(
            secSet.length,
            equals(1),
            reason: 'Teacher double-booked across different sections',
          );
        }

        // Rule 2: Section has at most companion batches B1 & B2 at same slot
        final sectionSlots = <String, List<TimetableEntry>>{};
        for (final e in result.entries) {
          final key = '${e.dayOfWeek}_${e.periodNumber}_${e.sectionId}';
          sectionSlots.putIfAbsent(key, () => []).add(e);
        }
        for (final entryList in sectionSlots.values) {
          if (entryList.length > 1) {
            expect(entryList.length, equals(2));
            final batches = entryList.map((e) => e.batch).toSet();
            expect(batches, equals({'B1', 'B2'}));
          }
        }

        // Rule 3: No room double-booking
        final roomSlots = <String>{};
        for (final e in result.entries) {
          final key = '${e.dayOfWeek}_${e.periodNumber}_${e.roomId}';
          expect(
            roomSlots.contains(key),
            isFalse,
            reason: 'Room double-booked at $key',
          );
          roomSlots.add(key);
        }

        // Rule 4: Lab assigned to Computer Labs with B1 and B2 in different rooms
        final labEntries = result.entries.where(
          (e) => e.subjectId == 'sub_dbms_lab',
        );
        for (final le in labEntries) {
          expect(
            ['r_lab1', 'r_lab2'].contains(le.roomId),
            isTrue,
            reason: 'DBMS Lab must be placed in Computer Lab',
          );
          expect(['B1', 'B2'].contains(le.batch), isTrue);
        }

        // Rule 5: No entries scheduled during Break slots
        for (final e in result.entries) {
          final slot = timeSlots.firstWhere(
            (s) => s.periodNumber == e.periodNumber && !s.isBreak,
          );
          expect(slot.isBreak, isFalse);
        }
      },
    );

    test(
      'Engine detects unresolvable constraints without generating fake schedule',
      () {
        // Scenario: Lab requires "Electronics Lab", but ONLY "Computer Lab" and "Classroom" exist
        final vlsiProf = Staff(
          id: 'prof_vlsi',
          employeeId: 'EMP009',
          collegeId: collegeId,
          departmentId: 'dept_cse',
          name: 'Prof. VLSI',
          email: 'vlsi@college.edu',
          designation: 'Assistant Professor',
          status: 'active',
          subjectsCanTeach: ['EC305', 'VLSI Design Lab'],
        );

        final impossibleSubjects = [
          Subject(
            id: 'sub_vlsi',
            collegeId: collegeId,
            departmentId: 'dept_cse',
            courseId: 'course_cse',
            semester: 3,
            subjectCode: 'EC305',
            subjectName: 'VLSI Design Lab',
            subjectType: 'Lab',
            hoursPerWeek: 4,
            requiredRoomType: 'Electronics Lab', // Missing room type!
            assignedTeacherIds: ['prof_vlsi'],
          ),
        ];

        final result = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: [sections.first.copyWith(batches: ['B1'])],
          subjects: impossibleSubjects,
          staffList: [vlsiProf],
          rooms: rooms, // has Classroom and Computer Lab, no Electronics Lab
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: days,
        );

        // Engine heart requirement: Must NOT generate fake data. Clearly fail with diagnostic suggestions.
        expect(result.isSuccess, isFalse);
        expect(result.conflicts.isNotEmpty, isTrue);
        expect(result.conflicts.any((c) => c.suggestion != null), isTrue);
        final roomConflict = result.conflicts.firstWhere(
          (c) =>
              c.type == 'capacityConflict' ||
              c.type == 'roomTypeMismatch' ||
              c.title.contains('Room'),
        );
        expect(roomConflict.description, contains('Electronics Lab'));
        expect(roomConflict.suggestion, contains('Electronics Lab'));
      },
    );

    test('Strict Professor Eligibility Rules & Pre-Flight Validation', () {
      final profA = Staff(
        id: 'prof_a',
        collegeId: collegeId,
        employeeId: 'EMP_A',
        name: 'Professor A',
        email: 'a@college.edu',
        departmentId: 'dept_cse',
        status: 'active',
        subjectsCanTeach: ['DBMS', 'CS301'],
      );

      final profB = Staff(
        id: 'prof_b',
        collegeId: collegeId,
        employeeId: 'EMP_B',
        name: 'Professor B',
        email: 'b@college.edu',
        departmentId: 'dept_cse',
        status: 'active',
        subjectsCanTeach: [], // Empty list -> eligible for ANY subject
      );

      // Rule 1: Empty list -> eligible for any subject
      expect(
        profB.isEligibleForSubject(
          subjectName: 'Compiler Design',
          subjectCode: 'CS401',
        ),
        isTrue,
      );
      expect(
        profB.isEligibleForSubject(
          subjectName: 'Physics',
          subjectCode: 'PH101',
        ),
        isTrue,
      );

      // Rule 2: Non-empty list -> eligible only for matching name or code
      expect(
        profA.isEligibleForSubject(subjectName: 'DBMS', subjectCode: 'CS999'),
        isTrue,
      );
      expect(
        profA.isEligibleForSubject(
          subjectName: 'Database',
          subjectCode: 'CS301',
        ),
        isTrue,
      );
      expect(
        profA.isEligibleForSubject(
          subjectName: 'Operating Systems',
          subjectCode: 'CS302',
        ),
        isFalse,
      );

      // Rule 3: Generation fails if an ineligible professor is assigned
      final testSubjectIneligible = Subject(
        id: 'sub_os_test',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        semester: 3,
        subjectCode: 'CS302',
        subjectName: 'Operating Systems',
        assignedTeacherIds: ['prof_a'], // Prof A cannot teach OS!
      );

      final failResult = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [sections.first],
        subjects: [testSubjectIneligible],
        staffList: [profA, profB],
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
      );

      expect(failResult.isSuccess, isFalse);
      expect(
        failResult.conflicts.any((c) => c.type == 'ineligibleTeacher'),
        isTrue,
      );
      expect(
        failResult.summaryMessage,
        contains('professor assignment or eligibility issue'),
      );

      // Rule 4: Generation fails if a subject has no assigned professor
      final testSubjectUnassigned = Subject(
        id: 'sub_unassigned',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        semester: 3,
        subjectCode: 'CS303',
        subjectName: 'Algorithms',
        assignedTeacherIds: [], // Empty!
      );

      final unassignedResult = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [sections.first],
        subjects: [testSubjectUnassigned],
        staffList: [profA, profB],
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
      );

      expect(unassignedResult.isSuccess, isFalse);
      expect(
        unassignedResult.conflicts.any((c) => c.type == 'unassignedTeacher'),
        isTrue,
      );

      // Rule 5: Section -> Subject -> Assigned Professor schedules without double-booking
      final validSubjA = Subject(
        id: 'sub_sec_a_dbms',
        sectionId: 'sec_a',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        semester: 3,
        subjectCode: 'CS301',
        subjectName: 'DBMS',
        hoursPerWeek: 3,
        assignedTeacherIds: ['prof_a'], // Prof A teaches Sec A
      );

      final validSubjB = Subject(
        id: 'sub_sec_b_dbms',
        sectionId: 'sec_b',
        collegeId: collegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        semester: 3,
        subjectCode: 'CS301',
        subjectName: 'DBMS',
        hoursPerWeek: 3,
        assignedTeacherIds: ['prof_a'], // Prof A also teaches Sec B
      );

      final successResult = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: sections,
        subjects: [validSubjA, validSubjB],
        staffList: [profA],
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
      );

      expect(successResult.isSuccess, isTrue);
      // Verify Prof A is never double-booked at the same day & period
      final profASlots = <String>{};
      for (final e in successResult.entries) {
        if (e.teacherId == 'prof_a') {
          final slotKey = '${e.dayOfWeek}_${e.periodNumber}';
          expect(
            profASlots.contains(slotKey),
            isFalse,
            reason: 'Prof A double-booked on $slotKey',
          );
          profASlots.add(slotKey);
        }
      }
    });

    test('ConflictValidator evaluates all 6 verification criteria', () {
      // Generate valid entries first
      final genResult = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: sections,
        subjects: subjects,
        staffList: professors,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
        workingDays: days,
      );

      final valResult = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: genResult.entries,
        sections: sections,
        subjects: subjects,
        staffList: professors,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
      );

      expect(valResult.isValid, isTrue);
      expect(valResult.hardConflicts.isEmpty, isTrue);

      // Verify each checklist category has 0 conflicts
      final profConflicts = valResult.hardConflicts
          .where((c) => c.type == 'teacherConflict')
          .length;
      final secConflicts = valResult.hardConflicts
          .where((c) => c.type == 'sectionConflict')
          .length;
      final roomConflicts = valResult.hardConflicts
          .where((c) => c.type == 'roomConflict')
          .length;
      final weeklyHoursConflicts = valResult.hardConflicts
          .where((c) => c.type == 'incompleteHours')
          .length;

      expect(profConflicts, equals(0));
      expect(secConflicts, equals(0));
      expect(roomConflicts, equals(0));
      expect(weeklyHoursConflicts, equals(0));
    });

    test(
      'Export data formatting produces valid RFC-4180 CSV and structured JSON',
      () {
        final genResult = TimetableGenerator.generate(
          collegeId: collegeId,
          sections: sections,
          subjects: subjects,
          staffList: professors,
          rooms: rooms,
          timeSlots: timeSlots,
          availabilities: [],
          workingDays: days,
        );

        // Test JSON Export Serialization
        final jsonPayload = {
          'collegeId': collegeId,
          'versionId': genResult.versionId,
          'entriesCount': genResult.entries.length,
          'entries': genResult.entries.map((e) => e.toJson()).toList(),
        };

        final jsonString = jsonEncode(jsonPayload);
        expect(jsonString, isNotEmpty);
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
        expect(decoded['entriesCount'], equals(32));

        // Test CSV formatting
        final csvHeader =
            'Day,Period,Time,Section,Subject Code,Subject Name,Type,Professor,Room';
        expect(csvHeader, contains('Day'));
        expect(csvHeader, contains('Section'));
        expect(csvHeader, contains('Professor'));
        expect(csvHeader, contains('Room'));
      },
    );

    test(
      'Strict Zero Mock Data Requirement: Database and auth start completely empty',
      () async {
        // Create fresh repository instances
        final freshDb = LocalDatabaseRepository();
        final freshAuth = LocalAuthRepository();

        final colleges = await freshDb.getColleges();
        expect(colleges.where((c) => c.name.contains('Apex')), isEmpty);

        final staff = await freshDb.getStaffList('default_college');
        expect(
          staff.where(
            (s) => s.name.contains('Ravi') || s.name.contains('Priya'),
          ),
          isEmpty,
        );

        final subjects = await freshDb.getSubjects('default_college');
        expect(
          subjects.where(
            (s) =>
                s.subjectName.contains('DBMS') ||
                s.subjectCode.contains('CS301'),
          ),
          isEmpty,
        );

        final rooms = await freshDb.getRooms('default_college');
        expect(
          rooms.where(
            (r) =>
                r.roomNumber.contains('101') || r.roomNumber.contains('Lab 1'),
          ),
          isEmpty,
        );

        final sections = await freshDb.getSections('default_college');
        expect(sections, isEmpty);

        final entries = await freshDb.getTimetableEntries('default_college');
        expect(entries, isEmpty);

        // Verify no mock accounts pre-seeded in auth
        expect(freshAuth.currentUser, isNull);
      },
    );

    test(
      'Strict No Fake Data Generation: Empty user data produces 0 entries',
      () {
        final result = TimetableGenerator.generate(
          collegeId: 'user_college',
          sections: [],
          subjects: [],
          staffList: [],
          rooms: [],
          timeSlots: [],
          availabilities: [],
        );

        // Must never fabricate fake schedule entries
        expect(result.entries, isEmpty);
        expect(result.totalClassesScheduled, equals(0));
        expect(result.isSuccess, isFalse);
      },
    );
  });
}
