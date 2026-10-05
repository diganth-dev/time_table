import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/repositories/local_repository.dart';
import 'package:time_table/services/timetable_generator.dart';

void main() {
  group('Firestore Schema & Integration Requirements', () {
    late LocalDatabaseRepository db;
    const testCollegeId = 'col_apex_engineering';

    setUp(() {
      db = LocalDatabaseRepository();
    });

    test('1. Room Model adheres to Firestore rooms collection schema', () {
      final now = DateTime.now();
      final roomData = {
        'id': 'room_101',
        'capacity': 75,
        'facilityType': 'Computer Lab',
        'isAvailable': true,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final room = Room.fromJson(roomData);
      expect(room.id, equals('room_101'));
      expect(room.capacity, equals(75));
      expect(room.facilityType, equals('Computer Lab'));
      expect(room.roomType, equals('Computer Lab'));
      expect(room.isAvailable, isTrue);
      expect(room.isUnderMaintenance, isFalse);
      expect(room.active, isTrue);

      final serialized = room.toJson();
      expect(serialized['capacity'], equals(75));
      expect(serialized['facilityType'], equals('Computer Lab'));
      expect(serialized['isAvailable'], isTrue);
      expect(serialized['createdAt'], isNotNull);
      expect(serialized['updatedAt'], isNotNull);
    });

    test('2. Rooms CRUD operations in repository work correctly', () async {
      final room = Room(
        id: 'lab_electronics',
        collegeId: testCollegeId,
        roomNumber: 'L-204',
        capacity: 40,
        roomType: 'Electronics Lab',
      );

      // Create (Add)
      await db.createRoom(room);
      var fetched = await db.getRoom('lab_electronics');
      expect(fetched, isNotNull);
      expect(fetched!.capacity, equals(40));
      expect(fetched.facilityType, equals('Electronics Lab'));
      expect(fetched.isAvailable, isTrue);

      // Read list
      final roomsList = await db.getRooms(testCollegeId);
      expect(roomsList.any((r) => r.id == 'lab_electronics'), isTrue);

      // Update (Edit)
      final updated = room.copyWith(
        capacity: 50,
        isUnderMaintenance: true,
        maintenanceReason: 'Oscilloscope calibration',
      );
      await db.updateRoom(updated);
      fetched = await db.getRoom('lab_electronics');
      expect(fetched!.capacity, equals(50));
      expect(fetched.isAvailable, isFalse);
      expect(fetched.isUnderMaintenance, isTrue);
      expect(fetched.maintenanceReason, equals('Oscilloscope calibration'));

      // Delete
      await db.deleteRoom('lab_electronics');
      fetched = await db.getRoom('lab_electronics');
      expect(fetched, isNull);
    });

    test('3. Section -> Subject -> Assigned Professor relationship & schema', () {
      final now = DateTime.now();
      final subjectData = {
        'id': 'subj_dbms',
        'name': 'Database Management Systems',
        'subjectCode': 'CS301',
        'requiredFacility': 'Classroom',
        'assignedProfessorId': 'prof_ravi_sharma',
        'sectionId': 'sec_cse_3a',
        'collegeId': testCollegeId,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      final subject = Subject.fromJson(subjectData);
      expect(subject.id, equals('subj_dbms'));
      expect(subject.name, equals('Database Management Systems'));
      expect(subject.subjectName, equals('Database Management Systems'));
      expect(subject.requiredFacility, equals('Classroom'));
      expect(subject.requiredRoomType, equals('Classroom'));
      expect(subject.assignedProfessorId, equals('prof_ravi_sharma'));
      expect(subject.assignedTeacherIds, contains('prof_ravi_sharma'));
      expect(subject.sectionId, equals('sec_cse_3a'));

      final json = subject.toJson();
      expect(json['name'], equals('Database Management Systems'));
      expect(json['requiredFacility'], equals('Classroom'));
      expect(json['assignedProfessorId'], equals('prof_ravi_sharma'));
      expect(json['sectionId'], equals('sec_cse_3a'));
      expect(json['createdAt'], isNotNull);
      expect(json['updatedAt'], isNotNull);
    });

    test('4. Professor Eligibility Rules: Rule 1 (empty list) and Rule 2 (non-empty)', () {
      final profGeneral = Staff(
        id: 'prof_general',
        collegeId: testCollegeId,
        employeeId: 'EMP_GEN',
        name: 'Dr. Universal',
        email: 'universal@college.edu',
        departmentId: 'dept_cse',
        status: 'active',
        subjectsCanTeach: [], // EMPTY -> eligible for ANY subject
      );

      final profSpecialist = Staff(
        id: 'prof_specialist',
        collegeId: testCollegeId,
        employeeId: 'EMP_SPEC',
        name: 'Dr. Specialist',
        email: 'specialist@college.edu',
        departmentId: 'dept_cse',
        status: 'active',
        subjectsCanTeach: ['DBMS', 'CS301'], // Non-empty -> only matching subjects
      );

      // Rule 1: Empty Can Teach list is eligible for any subject
      expect(profGeneral.isEligibleForSubject(subjectName: 'Artificial Intelligence', subjectCode: 'CS701'), isTrue);
      expect(profGeneral.isEligibleForSubject(subjectName: 'Thermodynamics', subjectCode: 'ME201'), isTrue);

      // Rule 2: Non-empty list is eligible ONLY for matching subjects
      expect(profSpecialist.isEligibleForSubject(subjectName: 'DBMS', subjectCode: 'CS301'), isTrue);
      expect(profSpecialist.isEligibleForSubject(subjectName: 'Operating Systems', subjectCode: 'CS302'), isFalse);
      expect(profSpecialist.isEligibleForSubject(subjectName: 'Compiler Design', subjectCode: 'CS501'), isFalse);
    });

    test('5. Timetable Generator rejects incomplete subjects (missing assigned professor)', () {
      final section = Section(
        id: 'sec_1a',
        collegeId: testCollegeId,
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        academicYear: '2026-2027',
        semester: 1,
        sectionName: 'A',
        studentCount: 50,
      );

      final incompleteSubject = Subject(
        id: 'sub_incomplete',
        collegeId: testCollegeId,
        sectionId: 'sec_1a',
        departmentId: 'dept_cse',
        courseId: 'course_cse',
        semester: 1,
        subjectCode: 'CS101',
        subjectName: 'Intro to CS',
        hoursPerWeek: 4,
        assignedTeacherIds: [], // INCOMPLETE: Missing assigned professor!
      );

      final slots = [
        TimeSlot(id: 'ts1', collegeId: testCollegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
        TimeSlot(id: 'ts2', collegeId: testCollegeId, periodNumber: 2, startTime: '10:00', endTime: '11:00', order: 2),
      ];

      final rooms = [
        Room(id: 'r1', collegeId: testCollegeId, roomNumber: '101', capacity: 60),
      ];

      final result = TimetableGenerator.generate(
        collegeId: testCollegeId,
        sections: [section],
        subjects: [incompleteSubject],
        staffList: [],
        rooms: rooms,
        timeSlots: slots,
        availabilities: [],
        workingDays: ['Monday', 'Tuesday'],
      );

      // Must reject generation and report incomplete subject without creating fake schedule
      expect(result.isSuccess, isFalse);
      expect(result.entries.isEmpty, isTrue);
      expect(result.conflicts.isNotEmpty, isTrue);
      final unassignedConflict = result.conflicts.firstWhere((c) => c.type == 'unassignedTeacher');
      expect(unassignedConflict.description, contains('CS101'));
      expect(unassignedConflict.description, contains('has no assigned professor'));
      expect(unassignedConflict.suggestion, contains('Assign an eligible professor'));
    });

    test('6. College Schedule settings read/write to collection collegeSettings, doc settings', () async {
      final workingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
      final periods = [
        {'id': 'p1', 'periodNumber': 1, 'startTime': '09:00', 'endTime': '10:00', 'label': 'Period 1', 'order': 1},
        {'id': 'p2', 'periodNumber': 2, 'startTime': '10:00', 'endTime': '11:00', 'label': 'Period 2', 'order': 2},
        {'id': 'p3', 'periodNumber': 3, 'startTime': '11:15', 'endTime': '12:15', 'label': 'Period 3', 'order': 4},
      ];
      final breaks = [
        {'id': 'b1', 'name': 'Morning Recess', 'startTime': '11:00', 'endTime': '11:15', 'order': 3},
      ];

      await db.saveCollegeScheduleSettings(
        workingDays: workingDays,
        periodsPerDay: 3,
        periods: periods,
        breaks: breaks,
        collegeId: testCollegeId,
      );

      final settings = await db.getCollegeScheduleSettings(collegeId: testCollegeId);
      expect(settings, isNotNull);
      expect(settings!['workingDays'], equals(workingDays));
      expect(settings['periodsPerDay'], equals(3));
      expect((settings['periods'] as List).length, equals(3));
      expect((settings['breaks'] as List).length, equals(1));
      expect(settings['updatedAt'], isNotNull);
    });

    test('7. TimetableEntry model adheres to Firestore timetableEntries schema', () {
      final now = DateTime.now();
      final entryData = {
        'id': 'entry_1001',
        'day': 'Monday',
        'periodId': 'period_1',
        'sectionId': 'sec_cse_3a',
        'subjectId': 'subj_dbms',
        'professorId': 'prof_ravi_sharma',
        'roomId': 'room_101',
        'createdAt': now.toIso8601String(),
      };

      final entry = TimetableEntry.fromJson(entryData);
      expect(entry.id, equals('entry_1001'));
      expect(entry.day, equals('Monday'));
      expect(entry.dayOfWeek, equals('Monday'));
      expect(entry.periodId, equals('period_1'));
      expect(entry.sectionId, equals('sec_cse_3a'));
      expect(entry.subjectId, equals('subj_dbms'));
      expect(entry.professorId, equals('prof_ravi_sharma'));
      expect(entry.teacherId, equals('prof_ravi_sharma'));
      expect(entry.roomId, equals('room_101'));

      final json = entry.toJson();
      expect(json['day'], equals('Monday'));
      expect(json['periodId'], equals('period_1'));
      expect(json['sectionId'], equals('sec_cse_3a'));
      expect(json['subjectId'], equals('subj_dbms'));
      expect(json['professorId'], equals('prof_ravi_sharma'));
      expect(json['roomId'], equals('room_101'));
      expect(json['createdAt'], isNotNull);
    });
  });
}
