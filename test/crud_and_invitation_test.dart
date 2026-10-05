import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/repositories/repositories.dart';
import 'package:time_table/services/services.dart';

void main() {
  group('Database CRUD, Staff Invitation & Publishing Tests', () {
    late LocalDatabaseRepository db;
    late LocalAuthRepository auth;
    final testCollegeId = 'col_test_aei';

    setUp(() {
      db = LocalDatabaseRepository();
      auth = LocalAuthRepository();
    });

    test('College CRUD operations work correctly', () async {
      final col = College(
        id: testCollegeId,
        name: 'Silicon Valley College of Technology',
        code: 'SVCT',
        address: 'Sector 5, Silicon Valley',
      );
      await db.createCollege(col);

      final fetched = await db.getCollege(testCollegeId);
      expect(fetched, isNotNull);
      expect(fetched!.name, equals('Silicon Valley College of Technology'));
      expect(fetched.code, equals('SVCT'));

      // Update
      final updated = fetched.copyWith(name: 'Silicon Valley Institute of Tech');
      await db.updateCollege(updated);
      final refetched = await db.getCollege(testCollegeId);
      expect(refetched!.name, equals('Silicon Valley Institute of Tech'));
    });

    test('Department CRUD operations work correctly', () async {
      final dept = Department(
        id: 'dept_aerospace',
        collegeId: testCollegeId,
        name: 'Aerospace Engineering',
        code: 'ASE',
      );
      await db.createDepartment(dept);

      final depts = await db.getDepartments(testCollegeId);
      expect(depts.any((d) => d.id == 'dept_aerospace'), isTrue);

      await db.deleteDepartment('dept_aerospace');
      final afterDelete = await db.getDepartments(testCollegeId);
      expect(afterDelete.any((d) => d.id == 'dept_aerospace'), isFalse);
    });

    test('Section CRUD and student count tracking', () async {
      final sec = Section(
        id: 'sec_ase_3a',
        collegeId: testCollegeId,
        departmentId: 'dept_aerospace',
        courseId: 'c_ase',
        academicYear: '2026-2027',
        semester: 3,
        sectionName: 'A',
        studentCount: 55,
      );
      await db.createSection(sec);

      final fetched = await db.getSection('sec_ase_3a');
      expect(fetched, isNotNull);
      expect(fetched!.studentCount, equals(55));
      expect(fetched.displayName, contains('55 students'));
    });

    test('Staff invitation and UID linking flow (Requirement #9)', () async {
      final staffEmail = 'invited.prof@apex.edu';

      // 1. Admin creates staff record with email. Status must be "invited"
      final newStaff = Staff(
        id: 'staff_invited_101',
        collegeId: 'col_apex',
        employeeId: 'EMP999',
        name: 'Dr. Jane Watson',
        email: staffEmail,
        departmentId: 'dept_cse',
        designation: 'Associate Professor',
        status: 'invited',
      );
      await db.createStaff(newStaff);

      final beforeSignup = await db.getStaff('staff_invited_101');
      expect(beforeSignup!.status, equals('invited'));
      expect(beforeSignup.isLinkedWithAuth, isFalse);

      // 2. Staff member receives invite and signs up using the same email
      final userProfile = await auth.completeStaffSignUp(
        email: staffEmail,
        password: 'securePassword123',
        name: 'Dr. Jane Watson',
      );

      // 3. Firebase Auth UID is linked to existing staff document and status becomes "active"
      expect(userProfile.email, equals(staffEmail));
      expect(userProfile.role, equals(UserRole.teacher));
      expect(userProfile.staffId, equals('staff_invited_101'));

      final afterSignup = await db.getStaff('staff_invited_101');
      expect(afterSignup!.status, equals('active'));
      expect(afterSignup.userId, equals(userProfile.id));
      expect(afterSignup.isLinkedWithAuth, isTrue);
    });

    test('Subject creation and teacher-subject authorization assignment', () async {
      final sub = Subject(
        id: 'sub_nlp',
        collegeId: 'col_apex',
        departmentId: 'dept_cse',
        courseId: 'c1',
        semester: 5,
        subjectCode: 'CS501',
        subjectName: 'Natural Language Processing',
        assignedTeacherIds: ['staff_sarah'],
      );
      await db.createSubject(sub);

      final fetchedSub = await db.getSubject('sub_nlp');
      expect(fetchedSub, isNotNull);
      expect(fetchedSub!.assignedTeacherIds, contains('staff_sarah'));
    });

    test('Room maintenance state toggling', () async {
      final room = Room(
        id: 'room_lab_chem',
        collegeId: 'col_apex',
        roomNumber: 'Chemistry Lab 1',
        capacity: 50,
        roomType: 'Chemistry Lab',
        isUnderMaintenance: false,
      );
      await db.createRoom(room);

      // Mark under maintenance
      final maintRoom = room.copyWith(
        isUnderMaintenance: true,
        maintenanceReason: 'Ventilation filter replacement',
      );
      await db.updateRoom(maintRoom);

      final fetched = await db.getRoom('room_lab_chem');
      expect(fetched!.isUnderMaintenance, isTrue);
      expect(fetched.maintenanceReason, equals('Ventilation filter replacement'));
    });

    test('Timetable publishing, version archiving and broadcast notification', () async {
      final collegeId = 'col_apex';

      // Create draft version
      final v1 = TimetableVersion(
        id: 'ver_pub_test',
        collegeId: collegeId,
        versionNumber: 99,
        name: 'Fall Semester Schedule 2026',
        status: 'draft',
        academicYear: '2026-2027',
        semester: 'Fall 2026',
      );
      await db.createTimetableVersion(v1);

      // Publish version
      await db.publishTimetableVersion(
        collegeId,
        'ver_pub_test',
        'Dean of Engineering',
        changeLog: 'Approved by curriculum board',
      );

      final activePublished = await db.getActivePublishedVersion(collegeId);
      expect(activePublished, isNotNull);
      expect(activePublished!.id, equals('ver_pub_test'));
      expect(activePublished.isPublished, isTrue);
      expect(activePublished.publishedBy, equals('Dean of Engineering'));

      // Check notification dispatched
      final notifs = await db.getNotifications(collegeId);
      expect(notifs.any((n) => n.relatedId == 'ver_pub_test'), isTrue);
    });

    test('Staff absence alternative faculty suggestions', () async {
      final collegeId = testCollegeId;
      final staffA = Staff(
        id: 'staff_test_1',
        collegeId: collegeId,
        employeeId: 'EMP_T1',
        name: 'Prof. Primary',
        email: 't1@college.edu',
        departmentId: 'dept_test',
        status: 'active',
        subjectsCanTeach: ['subj_test_1'],
      );
      final staffB = Staff(
        id: 'staff_test_2',
        collegeId: collegeId,
        employeeId: 'EMP_T2',
        name: 'Prof. Alternate',
        email: 't2@college.edu',
        departmentId: 'dept_test',
        status: 'active',
        subjectsCanTeach: ['subj_test_1'],
      );
      final subj = Subject(
        id: 'subj_test_1',
        collegeId: collegeId,
        departmentId: 'dept_test',
        courseId: 'course_test',
        semester: 1,
        subjectCode: 'T101',
        subjectName: 'Test Subject',
        assignedTeacherIds: ['staff_test_1', 'staff_test_2'],
      );

      final replacements = ConflictValidator.findReplacementTeachers(
        collegeId: collegeId,
        subjectId: subj.id,
        dayOfWeek: 'Monday',
        periodNumber: 1,
        allStaff: [staffA, staffB],
        allSubjects: [subj],
        activeEntries: [],
        availabilities: [],
        excludeTeacherId: staffA.id,
      );

      expect(replacements.any((s) => s.id == staffB.id), isTrue);
      expect(replacements.any((s) => s.id == staffA.id), isFalse);
    });
  });
}
