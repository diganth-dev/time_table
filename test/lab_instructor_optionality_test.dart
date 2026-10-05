import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/features/sections/screens/sections_and_subjects_screen.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/providers/providers.dart';
import 'package:time_table/repositories/local_repository.dart';

void main() {
  group('Lab Instructor Optionality — Model & Repository Rules', () {
    const collegeId = 'col_test_model_optionality';
    late LocalDatabaseRepository repo;

    final testDept = Department(
      id: 'dept_cs_model',
      collegeId: collegeId,
      name: 'Computer Science',
      code: 'CS',
    );

    final testCourse = Course(
      id: 'course_btech_model',
      collegeId: collegeId,
      departmentId: testDept.id,
      name: 'B.Tech CS',
      code: 'BTCS',
      totalSemesters: 8,
    );

    final testSection = Section(
      id: 'sec_3a_model',
      collegeId: collegeId,
      departmentId: testDept.id,
      courseId: testCourse.id,
      academicYear: '2026-2027',
      semester: 3,
      sectionName: '3-A',
      studentCount: 60,
      batches: ['B1', 'B2'],
    );

    final testProfAlan = Staff(
      id: 'prof_alan_model',
      collegeId: collegeId,
      employeeId: 'EMP_ALAN_M',
      name: 'Dr. Alan Turing',
      email: 'alan.m@college.edu',
      departmentId: testDept.id,
      designation: 'Professor',
      status: 'active',
      active: true,
      subjectsCanTeach: [],
    );

    final testProfGrace = Staff(
      id: 'prof_grace_model',
      collegeId: collegeId,
      employeeId: 'EMP_GRACE_M',
      name: 'Dr. Grace Hopper',
      email: 'grace.m@college.edu',
      departmentId: testDept.id,
      designation: 'Associate Professor',
      status: 'active',
      active: true,
      subjectsCanTeach: ['Compiler Design', 'Data Structures Lab'],
    );

    final testRoomClassroom = Room(
      id: 'room_101_model',
      collegeId: collegeId,
      roomNumber: '101',
      capacity: 60,
      roomType: 'Classroom',
    );

    final testRoomLab = Room(
      id: 'room_lab1_model',
      collegeId: collegeId,
      roomNumber: 'LAB-1',
      capacity: 30,
      roomType: 'Computer Lab',
    );

    setUp(() async {
      repo = LocalDatabaseRepository();
      await repo.createCollege(College(
        id: collegeId,
        name: 'Optionality Tech Institute',
        code: 'OTI',
        address: 'Main Campus',
      ));
      await repo.createDepartment(testDept);
      await repo.createCourse(testCourse);
      await repo.createSection(testSection);
      await repo.createStaff(testProfAlan);
      await repo.createStaff(testProfGrace);
      await repo.createRoom(testRoomClassroom);
      await repo.createRoom(testRoomLab);
    });

    test('A. Theory + professor -> still saves successfully', () async {
      final theorySubject = Subject(
        id: 'sub_algo',
        collegeId: collegeId,
        sectionId: testSection.id,
        departmentId: testDept.id,
        courseId: testCourse.id,
        semester: 3,
        subjectCode: 'CS301',
        subjectName: 'Algorithms',
        subjectType: 'Theory',
        hoursPerWeek: 4,
        requiredRoomType: 'Classroom',
        assignedTeacherIds: [testProfAlan.id],
      );

      await repo.createSubject(theorySubject);
      final fetched = await repo.getSubject('sub_algo');
      expect(fetched, isNotNull);
      expect(fetched!.assignedTeacherIds, equals([testProfAlan.id]));
      expect(fetched.assignedProfessorId, equals(testProfAlan.id));
      expect(fetched.isLab, isFalse);
    });

    test('B. Theory + no professor -> has empty teacher IDs and null assignedProfessorId', () {
      final unassignedTheory = Subject(
        id: 'sub_theory_unassigned',
        collegeId: collegeId,
        sectionId: testSection.id,
        departmentId: testDept.id,
        courseId: testCourse.id,
        semester: 3,
        subjectCode: 'CS302',
        subjectName: 'Operating Systems',
        subjectType: 'Theory',
        hoursPerWeek: 4,
        requiredRoomType: 'Classroom',
        assignedTeacherIds: [],
      );

      expect(unassignedTheory.assignedTeacherIds, isEmpty);
      expect(unassignedTheory.assignedProfessorId, isNull);
      expect(unassignedTheory.isLab, isFalse);
    });

    test('C. Lab + professor -> saves exactly as before', () async {
      final labWithProf = Subject(
        id: 'sub_ds_lab',
        collegeId: collegeId,
        sectionId: testSection.id,
        departmentId: testDept.id,
        courseId: testCourse.id,
        semester: 3,
        subjectCode: 'CS303L',
        subjectName: 'Data Structures Lab',
        subjectType: 'Lab',
        hoursPerWeek: 4,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: [testProfGrace.id],
      );

      await repo.createSubject(labWithProf);
      final fetched = await repo.getSubject('sub_ds_lab');
      expect(fetched, isNotNull);
      expect(fetched!.assignedTeacherIds, equals([testProfGrace.id]));
      expect(fetched.assignedProfessorId, equals(testProfGrace.id));
      expect(fetched.isLab, isTrue);
    });

    test('D. Lab + no professor -> saves successfully with null/empty instructor', () async {
      final labWithoutProf = Subject(
        id: 'sub_open_lab',
        collegeId: collegeId,
        sectionId: testSection.id,
        departmentId: testDept.id,
        courseId: testCourse.id,
        semester: 3,
        subjectCode: 'CS304L',
        subjectName: 'Networks Lab',
        subjectType: 'Lab',
        hoursPerWeek: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: [],
      );

      await repo.createSubject(labWithoutProf);
      final fetched = await repo.getSubject('sub_open_lab');
      expect(fetched, isNotNull);
      expect(fetched!.assignedTeacherIds, isEmpty);
      expect(fetched.assignedProfessorId, isNull);
      expect(fetched.isLab, isTrue);
    });

    test('E. Existing lab with professor -> remains unchanged on edit', () async {
      final existingLab = Subject(
        id: 'sub_existing_lab',
        collegeId: collegeId,
        sectionId: testSection.id,
        departmentId: testDept.id,
        courseId: testCourse.id,
        semester: 3,
        subjectCode: 'CS305L',
        subjectName: 'Hardware Lab',
        subjectType: 'Lab',
        hoursPerWeek: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: [testProfAlan.id],
      );
      await repo.createSubject(existingLab);

      // Edit hours only
      final updatedLab = existingLab.copyWith(hoursPerWeek: 4);
      await repo.updateSubject(updatedLab);

      final fetched = await repo.getSubject('sub_existing_lab');
      expect(fetched, isNotNull);
      expect(fetched!.hoursPerWeek, equals(4));
      expect(fetched.assignedTeacherIds, equals([testProfAlan.id]));
      expect(fetched.assignedProfessorId, equals(testProfAlan.id));
    });

    test('F. Creating a lab without professor must NOT cause a fake professor to appear', () async {
      final labNoProf = Subject(
        id: 'sub_no_fake_prof',
        collegeId: collegeId,
        sectionId: testSection.id,
        departmentId: testDept.id,
        courseId: testCourse.id,
        semester: 3,
        subjectCode: 'CS306L',
        subjectName: 'Web Tech Lab',
        subjectType: 'Lab',
        hoursPerWeek: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: [],
      );
      await repo.createSubject(labNoProf);

      final fetched = await repo.getSubject('sub_no_fake_prof');
      expect(fetched, isNotNull);
      expect(fetched!.assignedTeacherIds, isEmpty);
      expect(fetched.assignedProfessorId, isNull);

      final json = fetched.toJson();
      expect(json['assignedProfessorId'], isNull);
      expect(json['assignedTeacherIds'], isEmpty);
    });

    test('G. Creating a lab without professor must NOT modify unrelated entities', () async {
      final initialTheory = Subject(
        id: 'sub_unrelated_theory',
        collegeId: collegeId,
        sectionId: testSection.id,
        departmentId: testDept.id,
        courseId: testCourse.id,
        semester: 3,
        subjectCode: 'CS307',
        subjectName: 'Database Systems',
        subjectType: 'Theory',
        hoursPerWeek: 4,
        requiredRoomType: 'Classroom',
        assignedTeacherIds: [testProfAlan.id],
      );
      await repo.createSubject(initialTheory);

      final allProfsBefore = await repo.getStaffList(collegeId);
      final allRoomsBefore = await repo.getRooms(collegeId);
      final allSectionsBefore = await repo.getSections(collegeId);

      final newLab = Subject(
        id: 'sub_new_lab',
        collegeId: collegeId,
        sectionId: testSection.id,
        departmentId: testDept.id,
        courseId: testCourse.id,
        semester: 3,
        subjectCode: 'CS308L',
        subjectName: 'AI Lab',
        subjectType: 'Lab',
        hoursPerWeek: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: [],
      );
      await repo.createSubject(newLab);

      // Verify unrelated theory subject is untouched
      final refetchedTheory = await repo.getSubject('sub_unrelated_theory');
      expect(refetchedTheory!.assignedTeacherIds, equals([testProfAlan.id]));

      // Verify professors, rooms, sections remain identical
      final allProfsAfter = await repo.getStaffList(collegeId);
      final allRoomsAfter = await repo.getRooms(collegeId);
      final allSectionsAfter = await repo.getSections(collegeId);

      expect(allProfsAfter.length, equals(allProfsBefore.length));
      expect(allRoomsAfter.length, equals(allRoomsBefore.length));
      expect(allSectionsAfter.length, equals(allSectionsBefore.length));
    });
  });

  group('Lab Instructor Optionality — UI & Dialog Interaction Tests', () {
    late LocalDatabaseRepository repo;
    int testCounter = 0;

    Future<String> createEnvironment() async {
      repo = LocalDatabaseRepository();
      final id = 'col_ui_opt_${++testCounter}';

      await repo.createCollege(College(
        id: id,
        name: 'UI Test College $testCounter',
        code: 'UI$testCounter',
        address: 'Campus Drive',
      ));

      final dept = Department(
        id: 'dept_cs_$testCounter',
        collegeId: id,
        name: 'Computer Science',
        code: 'CS',
      );
      await repo.createDepartment(dept);

      final course = Course(
        id: 'course_btech_$testCounter',
        collegeId: id,
        departmentId: dept.id,
        name: 'B.Tech CS',
        code: 'BTCS',
        totalSemesters: 8,
      );
      await repo.createCourse(course);

      final section = Section(
        id: 'sec_3a_$testCounter',
        collegeId: id,
        departmentId: dept.id,
        courseId: course.id,
        academicYear: '2026-2027',
        semester: 3,
        sectionName: '3-A',
        studentCount: 60,
        batches: ['B1', 'B2'],
      );
      await repo.createSection(section);

      final profAlan = Staff(
        id: 'prof_alan_$testCounter',
        collegeId: id,
        employeeId: 'EMP_ALAN_$testCounter',
        name: 'Dr. Alan Turing',
        email: 'alan$testCounter@college.edu',
        departmentId: dept.id,
        designation: 'Professor',
        status: 'active',
        active: true,
        subjectsCanTeach: [],
      );
      await repo.createStaff(profAlan);

      await repo.createRoom(Room(
        id: 'room_101_$testCounter',
        collegeId: id,
        roomNumber: '101',
        capacity: 60,
        roomType: 'Classroom',
      ));

      await repo.createRoom(Room(
        id: 'room_lab1_$testCounter',
        collegeId: id,
        roomNumber: 'LAB-1',
        capacity: 30,
        roomType: 'Computer Lab',
      ));

      return id;
    }

    Widget createScreen(String collegeId) {
      return ProviderScope(
        overrides: [
          databaseRepositoryProvider.overrideWithValue(repo),
          activeCollegeIdProvider.overrideWith((ref) => collegeId),
        ],
        child: const MaterialApp(
          home: SectionsAndSubjectsScreen(),
        ),
      );
    }

    testWidgets('UI Test A: Theory + professor selected in UI saves successfully', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final colId = await createEnvironment();
      await tester.pumpWidget(createScreen(colId));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Subject to Section'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Subject Code'), 'CS101');
      await tester.enterText(find.widgetWithText(TextField, 'Subject Name'), 'Theory Subject');
      await tester.pumpAndSettle();

      // Professor dropdown is the last DropdownButtonFormField
      final profDropdown = find.byType(DropdownButtonFormField<String>).last;
      await tester.tap(profDropdown);
      await tester.pumpAndSettle();

      // Select Alan Turing
      await tester.tap(find.textContaining('Dr. Alan Turing').last);
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('Save & Close'));
      await tester.pumpAndSettle();

      expect(find.text('Subject added successfully.'), findsOneWidget);

      final subjects = await repo.getSubjects(colId);
      final theory = subjects.firstWhere((s) => s.subjectCode == 'CS101');
      expect(theory.assignedTeacherIds.isNotEmpty, isTrue);
      expect(theory.assignedProfessorId, equals(theory.assignedTeacherIds.first));
    });

    testWidgets('UI Test B: Theory + no professor is rejected with error snackbar', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final colId = await createEnvironment();
      await tester.pumpWidget(createScreen(colId));
      await tester.pumpAndSettle();

      // Open Add Subject dialog
      await tester.tap(find.text('Add Subject to Section'));
      await tester.pumpAndSettle();

      expect(find.text('Add Subject to Section 3-A'), findsOneWidget);

      // Enter code and name
      await tester.enterText(find.widgetWithText(TextField, 'Subject Code'), 'CS101');
      await tester.enterText(find.widgetWithText(TextField, 'Subject Name'), 'Theory Subject');
      await tester.pumpAndSettle();

      // Type is Theory by default. Professor is not selected.
      // Click 'Save & Close'
      await tester.tap(find.text('Save & Close'));
      await tester.pumpAndSettle();

      // Validation snackbar must be triggered
      expect(find.text('Please select an eligible professor for this subject'), findsOneWidget);

      // Verify subject was NOT saved to repo
      final subjects = await repo.getSubjects(colId);
      expect(subjects.where((s) => s.subjectCode == 'CS101'), isEmpty);
    });

    testWidgets('UI Test C: Lab + professor selected saves with assigned instructor', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final colId = await createEnvironment();
      await tester.pumpWidget(createScreen(colId));
      await tester.pumpAndSettle();

      // Open Add Subject dialog
      await tester.tap(find.text('Add Subject to Section'));
      await tester.pumpAndSettle();

      // Enter code and name
      await tester.enterText(find.widgetWithText(TextField, 'Subject Code'), 'CS103L');
      await tester.enterText(find.widgetWithText(TextField, 'Subject Name'), 'Systems Lab');
      await tester.pumpAndSettle();

      // Change Type to Lab
      final typeDropdown = find.widgetWithText(DropdownButtonFormField<String>, 'Theory');
      await tester.tap(typeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lab').last);
      await tester.pumpAndSettle();

      // Select professor from optional dropdown
      final profDropdown = find.byType(DropdownButtonFormField<String>).last;
      await tester.tap(profDropdown);
      await tester.pumpAndSettle();

      // Tap Alan Turing
      await tester.tap(find.textContaining('Dr. Alan Turing').last);
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('Save & Close'));
      await tester.pumpAndSettle();

      expect(find.text('Subject added successfully.'), findsOneWidget);

      // Verify repo has lab with professor assigned
      final subjects = await repo.getSubjects(colId);
      final lab = subjects.firstWhere((s) => s.subjectCode == 'CS103L');
      expect(lab.assignedTeacherIds.isNotEmpty, isTrue);
      expect(lab.assignedProfessorId, equals(lab.assignedTeacherIds.first));
    });

    testWidgets('UI Test D: Lab + no professor saves successfully with empty instructor', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final colId = await createEnvironment();
      await tester.pumpWidget(createScreen(colId));
      await tester.pumpAndSettle();

      // Open Add Subject dialog
      await tester.tap(find.text('Add Subject to Section'));
      await tester.pumpAndSettle();

      // Enter code and name
      await tester.enterText(find.widgetWithText(TextField, 'Subject Code'), 'CS102L');
      await tester.enterText(find.widgetWithText(TextField, 'Subject Name'), 'Comp Lab');
      await tester.pumpAndSettle();

      // Change Type from Theory to Lab
      final typeDropdown = find.widgetWithText(DropdownButtonFormField<String>, 'Theory');
      await tester.tap(typeDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lab').last);
      await tester.pumpAndSettle();

      // Verify Assigned Professor header shows Optional
      expect(find.text('Assigned Professor / Lab Assistant (Optional)'), findsOneWidget);

      // Click 'Save & Close' without choosing any professor
      await tester.tap(find.text('Save & Close'));
      await tester.pumpAndSettle();

      // Dialog should close and success snackbar should appear
      expect(find.text('Subject added successfully.'), findsOneWidget);

      // Verify subject is in repository with empty teacher IDs and null professor
      final subjects = await repo.getSubjects(colId);
      final lab = subjects.firstWhere((s) => s.subjectCode == 'CS102L');
      expect(lab.assignedTeacherIds, isEmpty);
      expect(lab.assignedProfessorId, isNull);
      expect(lab.isLab, isTrue);

      // Verify the subjects table displays "None" in the professor column
      expect(find.text('None'), findsWidgets);
      expect(find.textContaining('INCOMPLETE'), findsNothing);
    });

    testWidgets('UI Test E & F: Edit existing lab with professor preserves professor; editing lab to None clears professor', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final colId = await createEnvironment();
      final profs = await repo.getStaffList(colId);
      final sec = (await repo.getSections(colId)).first;
      final dept = (await repo.getDepartments(colId)).first;
      final course = (await repo.getCourses(colId)).first;

      final initialLab = Subject(
        id: 'sub_editable_lab',
        collegeId: colId,
        sectionId: sec.id,
        departmentId: dept.id,
        courseId: course.id,
        semester: 3,
        subjectCode: 'CS104L',
        subjectName: 'Robotics Lab',
        subjectType: 'Lab',
        hoursPerWeek: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: [profs.first.id],
      );
      await repo.createSubject(initialLab);

      await tester.pumpWidget(createScreen(colId));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.edit).first);
      await tester.pumpAndSettle();

      // Click Edit icon on the subject
      await tester.tap(find.byIcon(Icons.edit).first);
      await tester.pumpAndSettle();

      expect(find.text('Edit Subject'), findsOneWidget);

      // Dropdown should have the professor selected
      final profDropdown = find.byType(DropdownButtonFormField<String>).last;
      await tester.tap(profDropdown);
      await tester.pumpAndSettle();

      // Switch to 'None (No instructor assigned)'
      await tester.tap(find.text('None (No instructor assigned)').last);
      await tester.pumpAndSettle();

      // Save changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Subject updated successfully.'), findsOneWidget);

      // Verify in repo: assignedTeacherIds is now empty, assignedProfessorId is null
      final subjects = await repo.getSubjects(colId);
      final updated = subjects.firstWhere((s) => s.id == 'sub_editable_lab');
      expect(updated.assignedTeacherIds, isEmpty);
      expect(updated.assignedProfessorId, isNull);
    });
  });
}
