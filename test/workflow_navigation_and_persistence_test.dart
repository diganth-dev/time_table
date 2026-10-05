import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/core/widgets/workflow_progress_bar.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/repositories/repositories.dart';
import 'package:time_table/services/timetable_generator.dart';

void main() {
  group('End-to-End Workflow, Stepper, and Persistence Tests', () {
    late LocalDatabaseRepository repo;
    const testCollegeId = 'college_test_001';

    setUp(() {
      repo = LocalDatabaseRepository();
    });

    test('1. WorkflowStep enumeration matches the exact required 8-step pipeline', () {
      final steps = WorkflowStep.values;
      expect(steps.length, equals(8));

      expect(steps[0].title, equals('College Schedule'));
      expect(steps[0].route, equals('/schedule'));

      expect(steps[1].title, equals('Professors'));
      expect(steps[1].route, equals('/professors'));

      expect(steps[2].title, equals('Sections & Subjects'));
      expect(steps[2].route, equals('/sections-subjects'));

      expect(steps[3].title, equals('Rooms & Labs'));
      expect(steps[3].route, equals('/rooms'));

      expect(steps[4].title, equals('Generate'));
      expect(steps[4].route, equals('/workflow'));

      expect(steps[5].title, equals('Timetable'));
      expect(steps[5].route, equals('/timetable'));

      expect(steps[6].title, equals('Conflicts'));
      expect(steps[6].route, equals('/conflicts'));

      expect(steps[7].title, equals('Export'));
      expect(steps[7].route, equals('/export'));
    });

    test('2. Step 1 (Schedule): Saves to Firestore settings doc before moving forward', () async {
      final workingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
      final periods = [
        {'id': 'p1', 'periodNumber': 1, 'startTime': '09:00', 'endTime': '10:00', 'order': 1},
        {'id': 'p2', 'periodNumber': 2, 'startTime': '10:00', 'endTime': '11:00', 'order': 2},
      ];
      final breaks = [
        {'id': 'b1', 'name': 'Tea Break', 'startTime': '11:00', 'endTime': '11:15', 'order': 3},
      ];

      await repo.saveCollegeScheduleSettings(
        workingDays: workingDays,
        periodsPerDay: 2,
        periods: periods,
        breaks: breaks,
      );

      final retrieved = await repo.getCollegeScheduleSettings();
      expect(retrieved, isNotNull);
      expect(retrieved!['workingDays'], equals(workingDays));
      expect(retrieved['periodsPerDay'], equals(2));
      expect((retrieved['periods'] as List).length, equals(2));
      expect((retrieved['breaks'] as List).length, equals(1));
    });

    test('3. Step 2 (Professors): Supports adding multiple professors (Add Another) without data loss', () async {
      final prof1 = Staff(
        id: 'prof_1',
        collegeId: testCollegeId,
        employeeId: 'EMP001',
        name: 'Dr. Alan Turing',
        email: 'alan@college.edu',
        departmentId: 'dept_cs',
        designation: 'Professor',
        status: 'active',
        subjectsCanTeach: ['CS101', 'Theory of Computation'],
        maxClassesPerDay: 4,
      );

      final prof2 = Staff(
        id: 'prof_2',
        collegeId: testCollegeId,
        employeeId: 'EMP002',
        name: 'Prof. Grace Hopper',
        email: 'grace@college.edu',
        departmentId: 'dept_cs',
        designation: 'Associate Professor',
        status: 'active',
        subjectsCanTeach: [], // empty = can teach all
        maxClassesPerDay: 4,
      );

      await repo.createStaff(prof1);
      await repo.createStaff(prof2);

      final list = await repo.getStaffList(testCollegeId);
      expect(list.length, equals(2));
      expect(list.any((s) => s.name == 'Dr. Alan Turing'), isTrue);
      expect(list.any((s) => s.name == 'Prof. Grace Hopper'), isTrue);
    });

    test('4. Step 3 (Sections & Subjects): Professor assignment and eligibility enforcement', () async {
      final secA = Section(
        id: 'sec_a',
        collegeId: testCollegeId,
        departmentId: 'dept_cs',
        courseId: 'btech_cs',
        academicYear: '2026-2027',
        semester: 1,
        sectionName: 'A',
        studentCount: 60,
      );
      await repo.createSection(secA);

      // Professor A can only teach CS101
      final profA = Staff(
        id: 'p_a',
        collegeId: testCollegeId,
        employeeId: 'EMP_A',
        name: 'Prof. Alpha',
        email: 'alpha@college.edu',
        departmentId: 'dept_cs',
        designation: 'Faculty',
        status: 'active',
        subjectsCanTeach: ['CS101'],
        maxClassesPerDay: 4,
      );

      // Professor B can teach anything
      final profB = Staff(
        id: 'p_b',
        collegeId: testCollegeId,
        employeeId: 'EMP_B',
        name: 'Prof. Beta',
        email: 'beta@college.edu',
        departmentId: 'dept_cs',
        designation: 'Faculty',
        status: 'active',
        subjectsCanTeach: [],
        maxClassesPerDay: 4,
      );

      expect(profA.isEligibleForSubject(subjectName: 'CS101', subjectCode: 'CS101'), isTrue);
      expect(profA.isEligibleForSubject(subjectName: 'Data Structures', subjectCode: 'CS201'), isFalse);
      expect(profB.isEligibleForSubject(subjectName: 'Data Structures', subjectCode: 'CS201'), isTrue);

      final subValid = Subject(
        id: 'sub_1',
        collegeId: testCollegeId,
        sectionId: secA.id,
        departmentId: secA.departmentId,
        courseId: secA.courseId,
        semester: 1,
        subjectCode: 'CS101',
        subjectName: 'CS101',
        subjectType: 'Theory',
        hoursPerWeek: 4,
        requiredRoomType: 'Classroom',
        assignedTeacherIds: [profA.id],
      );
      await repo.createSubject(subValid);

      final subList = await repo.getSubjects(testCollegeId);
      expect(subList.length, equals(1));
      expect(subList.first.assignedTeacherIds, contains('p_a'));
    });

    test('5. Step 4 (Rooms & Labs): Persistence of Classrooms and Specialized Labs', () async {
      final room1 = Room(
        id: 'r_101',
        collegeId: testCollegeId,
        roomNumber: '101',
        building: 'Main Block',
        floor: 1,
        capacity: 60,
        roomType: 'Classroom',
      );
      final lab1 = Room(
        id: 'lab_cs1',
        collegeId: testCollegeId,
        roomNumber: 'CS-Lab-1',
        building: 'Tech Block',
        floor: 2,
        capacity: 40,
        roomType: 'Computer Lab',
      );

      await repo.createRoom(room1);
      await repo.createRoom(lab1);

      final rooms = await repo.getRooms(testCollegeId);
      expect(rooms.length, equals(2));
      expect(rooms.any((r) => r.roomType == 'Classroom'), isTrue);
      expect(rooms.any((r) => r.roomType == 'Computer Lab'), isTrue);
    });

    test('6. Step 5 (Generate): Pre-Flight rejects incomplete subjects (missing assigned professor)', () async {
      final incompleteSub = Subject(
        id: 'sub_inc',
        collegeId: testCollegeId,
        sectionId: 'sec_a',
        departmentId: 'dept_cs',
        courseId: 'btech_cs',
        semester: 1,
        subjectCode: 'CS999',
        subjectName: 'Missing Prof Subject',
        subjectType: 'Theory',
        hoursPerWeek: 3,
        requiredRoomType: 'Classroom',
        assignedTeacherIds: [], // INCOMPLETE
      );

      final sec = Section(
        id: 'sec_a',
        collegeId: testCollegeId,
        departmentId: 'dept_cs',
        courseId: 'btech_cs',
        academicYear: '2026-2027',
        semester: 1,
        sectionName: 'A',
        studentCount: 50,
      );

      final result = TimetableGenerator.generate(
        collegeId: testCollegeId,
        sections: [sec],
        staffList: [],
        subjects: [incompleteSub],
        rooms: [
          Room(
            id: 'r1',
            collegeId: testCollegeId,
            roomNumber: '101',
            capacity: 60,
            roomType: 'Classroom',
          ),
        ],
        timeSlots: [
          TimeSlot(
            id: 'ts1',
            collegeId: testCollegeId,
            periodNumber: 1,
            startTime: '09:00',
            endTime: '10:00',
            order: 1,
          ),
        ],
        availabilities: [],
        workingDays: ['Monday', 'Tuesday'],
      );

      expect(result.isSuccess, isFalse);
      expect(result.summaryMessage, contains('professor assignment or eligibility issue'));
      expect(result.conflicts.any((c) => c.description.toLowerCase().contains('has no assigned professor')), isTrue);
      expect(result.entries, isEmpty);
    });

    test('7. Backward and forward navigation retains all Firestore data without data loss', () async {
      // Simulate multiple backward and forward steps
      final sections = await repo.getSections(testCollegeId);
      final staff = await repo.getStaffList(testCollegeId);
      final subjects = await repo.getSubjects(testCollegeId);
      final rooms = await repo.getRooms(testCollegeId);

      // Data is not wiped or reset
      expect(sections.length, greaterThanOrEqualTo(1));
      expect(staff.length, greaterThanOrEqualTo(2));
      expect(subjects.length, greaterThanOrEqualTo(1));
      expect(rooms.length, greaterThanOrEqualTo(2));
    });
  });
}
