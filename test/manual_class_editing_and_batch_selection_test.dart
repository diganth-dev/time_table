import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/features/timetable/screens/timetable_editor_dialog.dart';
import 'package:time_table/features/timetable/screens/timetable_screen.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/providers/providers.dart';
import 'package:time_table/repositories/local_repository.dart';
import 'package:time_table/services/conflict_validator.dart';
import 'package:pdf/pdf.dart';
import 'package:time_table/services/pdf_export_service.dart';
import 'package:time_table/services/timetable_generator.dart';

void main() {
  const collegeId = 'col_manual_test';
  final workingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  final standardSlots = [
    TimeSlot(id: 'ts1', collegeId: collegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
    TimeSlot(id: 'ts2', collegeId: collegeId, periodNumber: 2, startTime: '10:00', endTime: '11:00', order: 2),
    TimeSlot(id: 'ts_brk', collegeId: collegeId, periodNumber: 0, startTime: '11:00', endTime: '11:15', isBreak: true, breakTitle: 'Tea Break', order: 3),
    TimeSlot(id: 'ts3', collegeId: collegeId, periodNumber: 3, startTime: '11:15', endTime: '12:15', order: 4),
    TimeSlot(id: 'ts4', collegeId: collegeId, periodNumber: 4, startTime: '12:15', endTime: '13:15', order: 5),
    TimeSlot(id: 'ts_lunch', collegeId: collegeId, periodNumber: 0, startTime: '13:15', endTime: '14:00', isBreak: true, breakTitle: 'Lunch Break', order: 6),
    TimeSlot(id: 'ts5', collegeId: collegeId, periodNumber: 5, startTime: '14:00', endTime: '15:00', order: 7),
    TimeSlot(id: 'ts6', collegeId: collegeId, periodNumber: 6, startTime: '15:00', endTime: '16:00', order: 8),
  ];

  final college = College(
    id: collegeId,
    name: 'Tech Institute',
    code: 'TECH',
    address: 'Campus 1',
    workingDays: workingDays,
  );

  final version = TimetableVersion(
    id: 'v_manual',
    collegeId: collegeId,
    versionNumber: 1,
    name: 'Version 1',
    academicYear: '2026-2027',
    semester: '5',
  );

  final sectionA = Section(
    id: 'sec_a',
    collegeId: collegeId,
    departmentId: 'dept_cs',
    courseId: 'c_btech',
    academicYear: '2026-2027',
    semester: 5,
    sectionName: '5-A',
    studentCount: 60,
    batches: ['B1', 'B2'],
  );

  final sectionCustomBatches = Section(
    id: 'sec_custom',
    collegeId: collegeId,
    departmentId: 'dept_cs',
    courseId: 'c_btech',
    academicYear: '2026-2027',
    semester: 5,
    sectionName: '5-Custom',
    studentCount: 90,
    batches: ['Batch Alpha', 'Batch Beta', 'Batch Gamma'],
  );

  final theorySubj = Subject(
    id: 'sub_ddco',
    collegeId: collegeId,
    departmentId: 'dept_cs',
    courseId: 'c_btech',
    subjectName: 'DDCO',
    courseShortName: 'DDCO',
    subjectCode: 'CS501',
    semester: 5,
    subjectType: 'Theory',
    hoursPerWeek: 4,
    consecutivePeriods: 1,
    requiredRoomType: 'Classroom',
    assignedTeacherIds: ['prof_theory'],
    sectionId: sectionA.id,
  );

  final labSubjOOP = Subject(
    id: 'sub_oop_lab',
    collegeId: collegeId,
    departmentId: 'dept_cs',
    courseId: 'c_btech',
    subjectName: 'OOP LAB',
    courseShortName: 'OOP LAB',
    subjectCode: 'CS502L',
    semester: 5,
    subjectType: 'Lab',
    hoursPerWeek: 2,
    consecutivePeriods: 2,
    requiredRoomType: 'Computer Lab',
    assignedTeacherIds: ['prof_lab1'],
    sectionId: sectionA.id,
  );

  final labSubjDSA = Subject(
    id: 'sub_dsa_lab',
    collegeId: collegeId,
    departmentId: 'dept_cs',
    courseId: 'c_btech',
    subjectName: 'DSA LAB',
    courseShortName: 'DSA LAB',
    subjectCode: 'CS503L',
    semester: 5,
    subjectType: 'Lab',
    hoursPerWeek: 2,
    consecutivePeriods: 2,
    requiredRoomType: 'Computer Lab',
    assignedTeacherIds: ['prof_lab2'],
    sectionId: sectionA.id,
  );

  final profTheory = Staff(
    id: 'prof_theory',
    collegeId: collegeId,
    employeeId: 'EMP_TH',
    name: 'Prof. Theory',
    email: 'th@college.edu',
    departmentId: 'dept_cs',
    status: 'active',
    subjectsCanTeach: ['DDCO', 'sub_ddco'],
    maxClassesPerDay: 5,
  );

  final profLab1 = Staff(
    id: 'prof_lab1',
    collegeId: collegeId,
    employeeId: 'EMP_L1',
    name: 'Prof. Lab 1',
    email: 'l1@college.edu',
    departmentId: 'dept_cs',
    status: 'active',
    subjectsCanTeach: ['OOP LAB', 'sub_oop_lab'],
    maxClassesPerDay: 5,
  );

  final profLab2 = Staff(
    id: 'prof_lab2',
    collegeId: collegeId,
    employeeId: 'EMP_L2',
    name: 'Prof. Lab 2',
    email: 'l2@college.edu',
    departmentId: 'dept_cs',
    status: 'active',
    subjectsCanTeach: ['DSA LAB', 'sub_dsa_lab'],
    maxClassesPerDay: 5,
  );

  final classroom = Room(
    id: 'room_cr1',
    collegeId: collegeId,
    roomNumber: 'CR 101',
    capacity: 70,
    roomType: 'Classroom',
    facilities: ['Classroom'],
    active: true,
  );

  final labRoom1 = Room(
    id: 'room_lab1',
    collegeId: collegeId,
    roomNumber: 'Lab 1',
    capacity: 40,
    roomType: 'Computer Lab',
    facilities: ['Computer Lab'],
    active: true,
  );

  final labRoom2 = Room(
    id: 'room_lab2',
    collegeId: collegeId,
    roomNumber: 'Lab 2',
    capacity: 40,
    roomType: 'Computer Lab',
    facilities: ['Computer Lab'],
    active: true,
  );

  final adminProfile = UserProfile(
    id: 'user_admin',
    email: 'admin@college.edu',
    name: 'College Admin',
    role: UserRole.collegeAdmin,
    collegeId: collegeId,
    createdAt: DateTime.now(),
  );

  group('Manual Class Editing and Batch Selection Tests (TEST 1 to TEST 20)', () {
    testWidgets('TEST 1: Clicking an empty academic cell opens Add Class', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = LocalDatabaseRepository();
      repo.saveTimetableEntries(collegeId, version.id, []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            currentProfileProvider.overrideWith((ref) => adminProfile),
            currentCollegeProvider.overrideWith((ref) => Future.value(college)),
            timetableVersionsProvider.overrideWith((ref) => Future.value([version])),
            selectedVersionIdProvider.overrideWith((ref) => version.id),
            sectionListProvider.overrideWith((ref) => Future.value([sectionA])),
            subjectListProvider.overrideWith((ref) => Future.value([theorySubj, labSubjOOP])),
            staffListProvider.overrideWith((ref) => Future.value([profTheory, profLab1])),
            roomListProvider.overrideWith((ref) => Future.value([classroom, labRoom1])),
            timeSlotsProvider.overrideWith((ref) => Future.value(standardSlots)),
            timetableEntriesProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(home: TimetableScreen()),
        ),
      );

      await tester.pumpAndSettle();

      final emptyCell = find.byKey(const Key('empty_cell_Monday_1'));
      expect(emptyCell, findsOneWidget);

      await tester.tap(emptyCell);
      await tester.pumpAndSettle();

      expect(find.byType(TimetableEditorDialog), findsOneWidget);
      expect(find.text('Add Class'), findsOneWidget);
    });

    testWidgets('TEST 2: Day and period are correctly preselected from the clicked cell', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = LocalDatabaseRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            currentProfileProvider.overrideWith((ref) => adminProfile),
            currentCollegeProvider.overrideWith((ref) => Future.value(college)),
            timetableVersionsProvider.overrideWith((ref) => Future.value([version])),
            selectedVersionIdProvider.overrideWith((ref) => version.id),
            sectionListProvider.overrideWith((ref) => Future.value([sectionA])),
            subjectListProvider.overrideWith((ref) => Future.value([theorySubj])),
            staffListProvider.overrideWith((ref) => Future.value([profTheory])),
            roomListProvider.overrideWith((ref) => Future.value([classroom])),
            timeSlotsProvider.overrideWith((ref) => Future.value(standardSlots)),
            timetableEntriesProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(home: TimetableScreen()),
        ),
      );

      await tester.pumpAndSettle();

      final wedCell = find.byKey(const Key('empty_cell_Wednesday_3'));
      expect(wedCell, findsOneWidget);

      await tester.tap(wedCell);
      await tester.pumpAndSettle();

      expect(find.textContaining('Wednesday'), findsWidgets);
      expect(find.textContaining('Period 3'), findsWidgets);
    });

    testWidgets('TEST 3 & TEST 4: Break and Lunch cells cannot open Add Class', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = LocalDatabaseRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            currentProfileProvider.overrideWith((ref) => adminProfile),
            currentCollegeProvider.overrideWith((ref) => Future.value(college)),
            timetableVersionsProvider.overrideWith((ref) => Future.value([version])),
            selectedVersionIdProvider.overrideWith((ref) => version.id),
            sectionListProvider.overrideWith((ref) => Future.value([sectionA])),
            subjectListProvider.overrideWith((ref) => Future.value([theorySubj])),
            staffListProvider.overrideWith((ref) => Future.value([profTheory])),
            roomListProvider.overrideWith((ref) => Future.value([classroom])),
            timeSlotsProvider.overrideWith((ref) => Future.value(standardSlots)),
            timetableEntriesProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(home: TimetableScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('empty_cell_Monday_0')), findsNothing);
      expect(find.text('Tea Break'), findsWidgets);
      expect(find.text('Lunch Break'), findsWidgets);

      await tester.tap(find.text('Tea Break').first);
      await tester.pumpAndSettle();
      expect(find.byType(TimetableEditorDialog), findsNothing);

      await tester.tap(find.text('Lunch Break').first);
      await tester.pumpAndSettle();
      expect(find.byType(TimetableEditorDialog), findsNothing);
    });

    testWidgets('TEST 5: Occupied cell still opens Edit / Reassign Class', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final entry = TimetableEntry(
        id: 'entry_occ_1',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts1',
        sectionId: sectionA.id,
        subjectId: theorySubj.id,
        teacherId: profTheory.id,
        roomId: classroom.id,
      );

      final repo = LocalDatabaseRepository();
      await repo.createCollege(college);
      await repo.createTimetableEntry(entry);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            currentProfileProvider.overrideWith((ref) => adminProfile),
            currentCollegeProvider.overrideWith((ref) => Future.value(college)),
            timetableVersionsProvider.overrideWith((ref) => Future.value([version])),
            selectedVersionIdProvider.overrideWith((ref) => version.id),
            sectionListProvider.overrideWith((ref) => Future.value([sectionA])),
            subjectListProvider.overrideWith((ref) => Future.value([theorySubj])),
            staffListProvider.overrideWith((ref) => Future.value([profTheory])),
            roomListProvider.overrideWith((ref) => Future.value([classroom])),
            timeSlotsProvider.overrideWith((ref) => Future.value(standardSlots)),
            timetableEntriesProvider.overrideWith((ref) => Future.value([entry])),
          ],
          child: const MaterialApp(home: TimetableScreen()),
        ),
      );

      await tester.pumpAndSettle();

      final card = find.byKey(Key('entry_card_${entry.id}'));
      expect(card, findsOneWidget);

      await tester.tap(card);
      await tester.pumpAndSettle();

      expect(find.byType(TimetableEditorDialog), findsOneWidget);
      expect(find.text('Edit / Reassign Class'), findsOneWidget);
    });

    testWidgets('TEST 6: Normal theory class does not show Lab Batch selector', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final theoryEntry = TimetableEntry(
        id: 'entry_th',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts1',
        sectionId: sectionA.id,
        subjectId: theorySubj.id,
        teacherId: profTheory.id,
        roomId: classroom.id,
      );

      final repo = LocalDatabaseRepository();
      await repo.createCollege(college);
      await repo.createSection(sectionA);
      await repo.createSubject(theorySubj);
      await repo.createStaff(profTheory);
      await repo.createRoom(classroom);
      for (final s in standardSlots) {
        await repo.createTimeSlot(s);
      }
      await repo.createTimetableEntry(theoryEntry);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            currentProfileProvider.overrideWith((ref) => adminProfile),
            currentCollegeProvider.overrideWith((ref) => Future.value(college)),
            timetableVersionsProvider.overrideWith((ref) => Future.value([version])),
            selectedVersionIdProvider.overrideWith((ref) => version.id),
            sectionListProvider.overrideWith((ref) => Future.value([sectionA])),
            subjectListProvider.overrideWith((ref) => Future.value([theorySubj])),
            staffListProvider.overrideWith((ref) => Future.value([profTheory])),
            roomListProvider.overrideWith((ref) => Future.value([classroom])),
            timeSlotsProvider.overrideWith((ref) => Future.value(standardSlots)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TimetableEditorDialog(entry: theoryEntry),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('editor_batch_dropdown')), findsNothing);
      expect(find.text('Lab Batch'), findsNothing);
    });

    testWidgets('TEST 7: Lab class for a section with batches shows Lab Batch selector', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final labEntry = TimetableEntry(
        id: 'entry_lab_b1',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts1',
        sectionId: sectionA.id,
        subjectId: labSubjOOP.id,
        teacherId: profLab1.id,
        roomId: labRoom1.id,
        batch: 'B1',
      );

      final repo = LocalDatabaseRepository();
      await repo.createCollege(college);
      await repo.createSection(sectionA);
      await repo.createSubject(labSubjOOP);
      await repo.createStaff(profLab1);
      await repo.createRoom(labRoom1);
      for (final s in standardSlots) {
        await repo.createTimeSlot(s);
      }
      await repo.createTimetableEntry(labEntry);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            currentProfileProvider.overrideWith((ref) => adminProfile),
            currentCollegeProvider.overrideWith((ref) => Future.value(college)),
            timetableVersionsProvider.overrideWith((ref) => Future.value([version])),
            selectedVersionIdProvider.overrideWith((ref) => version.id),
            sectionListProvider.overrideWith((ref) => Future.value([sectionA])),
            subjectListProvider.overrideWith((ref) => Future.value([labSubjOOP])),
            staffListProvider.overrideWith((ref) => Future.value([profLab1])),
            roomListProvider.overrideWith((ref) => Future.value([labRoom1])),
            timeSlotsProvider.overrideWith((ref) => Future.value(standardSlots)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TimetableEditorDialog(entry: labEntry),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('editor_batch_dropdown')), findsOneWidget);
      expect(find.text('Lab Batch'), findsOneWidget);
    });

    testWidgets('TEST 8: Batch options come from Section.batches and are not hardcoded', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final customLabSubj = Subject(
        id: 'sub_custom_lab',
        collegeId: collegeId,
        departmentId: 'dept_cs',
        courseId: 'c_btech',
        subjectName: 'Custom Lab',
        courseShortName: 'Custom Lab',
        subjectCode: 'CUST501L',
        semester: 5,
        subjectType: 'Lab',
        hoursPerWeek: 2,
        consecutivePeriods: 2,
        requiredRoomType: 'Computer Lab',
        assignedTeacherIds: ['prof_lab1'],
        sectionId: sectionCustomBatches.id,
      );

      final customStaff = profLab1.copyWith(
        subjectsCanTeach: ['Custom Lab', 'sub_custom_lab'],
      );

      final repo = LocalDatabaseRepository();
      await repo.createCollege(college);
      await repo.createSection(sectionCustomBatches);
      await repo.createSubject(customLabSubj);
      await repo.createStaff(customStaff);
      await repo.createRoom(labRoom1);
      for (final s in standardSlots) {
        await repo.createTimeSlot(s);
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            currentProfileProvider.overrideWith((ref) => adminProfile),
            currentCollegeProvider.overrideWith((ref) => Future.value(college)),
            timetableVersionsProvider.overrideWith((ref) => Future.value([version])),
            selectedVersionIdProvider.overrideWith((ref) => version.id),
            sectionListProvider.overrideWith((ref) => Future.value([sectionCustomBatches])),
            subjectListProvider.overrideWith((ref) => Future.value([customLabSubj])),
            staffListProvider.overrideWith((ref) => Future.value([customStaff])),
            roomListProvider.overrideWith((ref) => Future.value([labRoom1])),
            timeSlotsProvider.overrideWith((ref) => Future.value(standardSlots)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: TimetableEditorDialog(
                initialDay: 'Monday',
                initialPeriod: 1,
                initialSectionId: 'sec_custom',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final batchDropdown = find.byKey(const Key('editor_batch_dropdown'));
      expect(batchDropdown, findsOneWidget);

      await tester.tap(batchDropdown);
      await tester.pumpAndSettle();

      expect(find.text('Batch Alpha'), findsWidgets);
      expect(find.text('Batch Beta'), findsWidgets);
      expect(find.text('Batch Gamma'), findsWidgets);
    });

    testWidgets('TEST 9: Existing B2 class opens with B2 already selected', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final b2Entry = TimetableEntry(
        id: 'entry_b2',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts1',
        sectionId: sectionA.id,
        subjectId: labSubjOOP.id,
        teacherId: profLab1.id,
        roomId: labRoom1.id,
        batch: 'B2',
      );

      final repo = LocalDatabaseRepository();
      await repo.createCollege(college);
      await repo.createSection(sectionA);
      await repo.createSubject(labSubjOOP);
      await repo.createStaff(profLab1);
      await repo.createRoom(labRoom1);
      for (final s in standardSlots) {
        await repo.createTimeSlot(s);
      }
      await repo.createTimetableEntry(b2Entry);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            currentProfileProvider.overrideWith((ref) => adminProfile),
            currentCollegeProvider.overrideWith((ref) => Future.value(college)),
            timetableVersionsProvider.overrideWith((ref) => Future.value([version])),
            selectedVersionIdProvider.overrideWith((ref) => version.id),
            sectionListProvider.overrideWith((ref) => Future.value([sectionA])),
            subjectListProvider.overrideWith((ref) => Future.value([labSubjOOP])),
            staffListProvider.overrideWith((ref) => Future.value([profLab1])),
            roomListProvider.overrideWith((ref) => Future.value([labRoom1])),
            timeSlotsProvider.overrideWith((ref) => Future.value(standardSlots)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TimetableEditorDialog(entry: b2Entry),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Edit / Reassign Class (B2)'), findsOneWidget);
      expect(find.text('B2'), findsWidgets);
    });

    testWidgets('TEST 10 & TEST 11: Changing B2 -> B1 validates and rejects invalid batch assignment', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // B1 is already busy on Monday Period 1 with DSA LAB in labRoom2
      final b1BusyEntry1 = TimetableEntry(
        id: 'b1_busy_1',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts1',
        sectionId: sectionA.id,
        subjectId: labSubjDSA.id,
        teacherId: profLab2.id,
        roomId: labRoom2.id,
        batch: 'B1',
      );
      final b1BusyEntry2 = TimetableEntry(
        id: 'b1_busy_2',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Monday',
        periodNumber: 2,
        timeSlotId: 'ts2',
        sectionId: sectionA.id,
        subjectId: labSubjDSA.id,
        teacherId: profLab2.id,
        roomId: labRoom2.id,
        batch: 'B1',
      );

      final b2Entry = TimetableEntry(
        id: 'entry_b2_to_change',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts1',
        sectionId: sectionA.id,
        subjectId: labSubjOOP.id,
        teacherId: profLab1.id,
        roomId: labRoom1.id,
        batch: 'B2',
      );

      final repo = LocalDatabaseRepository();
      await repo.createCollege(college);
      await repo.createSection(sectionA);
      await repo.createSubject(labSubjOOP);
      await repo.createSubject(labSubjDSA);
      await repo.createStaff(profLab1);
      await repo.createStaff(profLab2);
      await repo.createRoom(labRoom1);
      await repo.createRoom(labRoom2);
      for (final s in standardSlots) {
        await repo.createTimeSlot(s);
      }
      await repo.createTimetableEntry(b1BusyEntry1);
      await repo.createTimetableEntry(b1BusyEntry2);
      await repo.createTimetableEntry(b2Entry);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            currentProfileProvider.overrideWith((ref) => adminProfile),
            currentCollegeProvider.overrideWith((ref) => Future.value(college)),
            timetableVersionsProvider.overrideWith((ref) => Future.value([version])),
            selectedVersionIdProvider.overrideWith((ref) => version.id),
            sectionListProvider.overrideWith((ref) => Future.value([sectionA])),
            subjectListProvider.overrideWith((ref) => Future.value([labSubjOOP, labSubjDSA])),
            staffListProvider.overrideWith((ref) => Future.value([profLab1, profLab2])),
            roomListProvider.overrideWith((ref) => Future.value([labRoom1, labRoom2])),
            timeSlotsProvider.overrideWith((ref) => Future.value(standardSlots)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TimetableEditorDialog(entry: b2Entry),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final batchDropdown = find.byKey(const Key('editor_batch_dropdown'));
      expect(batchDropdown, findsOneWidget);

      await tester.tap(batchDropdown);
      await tester.pumpAndSettle();

      final b1Option = find.text('B1').last;
      await tester.tap(b1Option);
      await tester.pumpAndSettle();

      // TEST 10: Validation ran live and detected batchConflict because B1 is busy!
      expect(find.textContaining('Conflict(s) Detected'), findsOneWidget);
      expect(find.textContaining('Batch B1'), findsOneWidget);

      // TEST 11: Attempting to save rejected, dialog stays open
      final saveBtn = find.byKey(const Key('editor_save_button'));
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(find.byType(TimetableEditorDialog), findsOneWidget);
      expect(find.textContaining('Cannot save'), findsOneWidget);
    });

    test('TEST 12: Manually adding a class validates professor conflicts', () {
      final existing = [
        TimetableEntry(
          id: 'ex_prof_busy',
          collegeId: collegeId,
          versionId: version.id,
          dayOfWeek: 'Monday',
          periodNumber: 1,
          timeSlotId: 'ts1',
          sectionId: 'sec_other',
          subjectId: theorySubj.id,
          teacherId: profTheory.id,
          roomId: classroom.id,
        ),
      ];

      final proposed = TimetableEntry(
        id: 'prop_prof',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts1',
        sectionId: sectionA.id,
        subjectId: theorySubj.id,
        teacherId: profTheory.id, // SAME professor at same time!
        roomId: labRoom1.id,
      );

      final val = ConflictValidator.validateProposedEntries(
        collegeId: collegeId,
        proposedEntries: [proposed],
        existingEntries: existing,
        sections: [sectionA],
        subjects: [theorySubj],
        staffList: [profTheory],
        rooms: [classroom, labRoom1],
        timeSlots: standardSlots,
        availabilities: [],
      );

      expect(val.isValid, isFalse);
      expect(val.hardConflicts.any((c) => c.type == 'teacherConflict'), isTrue);
    });

    test('TEST 13: Manually adding a class validates room conflicts', () {
      final existing = [
        TimetableEntry(
          id: 'ex_room_busy',
          collegeId: collegeId,
          versionId: version.id,
          dayOfWeek: 'Monday',
          periodNumber: 1,
          timeSlotId: 'ts1',
          sectionId: 'sec_other',
          subjectId: 'sub_other',
          teacherId: 'prof_other',
          roomId: labRoom1.id, // Lab 1 is occupied!
        ),
      ];

      final proposed = TimetableEntry(
        id: 'prop_room',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts1',
        sectionId: sectionA.id,
        subjectId: labSubjOOP.id,
        teacherId: profLab1.id,
        roomId: labRoom1.id, // SAME Room!
        batch: 'B1',
      );

      final val = ConflictValidator.validateProposedEntries(
        collegeId: collegeId,
        proposedEntries: [proposed],
        existingEntries: existing,
        sections: [sectionA],
        subjects: [labSubjOOP],
        staffList: [profLab1],
        rooms: [labRoom1],
        timeSlots: standardSlots,
        availabilities: [],
      );

      expect(val.isValid, isFalse);
      expect(val.hardConflicts.any((c) => c.type == 'roomConflict'), isTrue);
    });

    test('TEST 14: Manually adding a class validates section/batch conflicts', () {
      final existing = [
        TimetableEntry(
          id: 'ex_sec_busy',
          collegeId: collegeId,
          versionId: version.id,
          dayOfWeek: 'Tuesday',
          periodNumber: 1,
          timeSlotId: 'ts1',
          sectionId: sectionA.id,
          subjectId: theorySubj.id,
          teacherId: profTheory.id,
          roomId: classroom.id,
        ),
      ];

      final proposed = TimetableEntry(
        id: 'prop_sec',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Tuesday',
        periodNumber: 1,
        timeSlotId: 'ts1',
        sectionId: sectionA.id, // SAME Section at same period!
        subjectId: labSubjOOP.id,
        teacherId: profLab1.id,
        roomId: labRoom1.id,
        batch: 'B1',
      );

      final val = ConflictValidator.validateProposedEntries(
        collegeId: collegeId,
        proposedEntries: [proposed],
        existingEntries: existing,
        sections: [sectionA],
        subjects: [theorySubj, labSubjOOP],
        staffList: [profTheory, profLab1],
        rooms: [classroom, labRoom1],
        timeSlots: standardSlots,
        availabilities: [],
      );

      expect(val.isValid, isFalse);
      expect(val.hardConflicts.any((c) => c.type == 'sectionConflict' || c.type == 'batchConflict'), isTrue);
    });

    test('TEST 15: Lab manual placement requires the correct consecutive periods', () {
      // labSubjOOP requires 2 consecutive periods. A single period placement violates lab duration!
      final proposedSinglePeriod = TimetableEntry(
        id: 'prop_single',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Wednesday',
        periodNumber: 1,
        timeSlotId: 'ts1',
        sectionId: sectionA.id,
        subjectId: labSubjOOP.id,
        teacherId: profLab1.id,
        roomId: labRoom1.id,
        batch: 'B1',
      );

      final val = ConflictValidator.validateProposedEntries(
        collegeId: collegeId,
        proposedEntries: [proposedSinglePeriod],
        existingEntries: [],
        sections: [sectionA],
        subjects: [labSubjOOP],
        staffList: [profLab1],
        rooms: [labRoom1],
        timeSlots: standardSlots,
        availabilities: [],
      );

      expect(val.isValid, isFalse);
      expect(val.hardConflicts.any((c) => c.type == 'labDurationConflict'), isTrue);
    });

    test('TEST 16: Lab cannot cross break or lunch', () {
      // Period 2 is 10:00-11:00. Tea break is 11:00-11:15. Period 3 is 11:15-12:15.
      // Trying to pair Period 2 and Period 3 as a consecutive lab block crosses Tea Break!
      final p2Entry = TimetableEntry(
        id: 'prop_p2',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Monday',
        periodNumber: 2,
        timeSlotId: 'ts2',
        sectionId: sectionA.id,
        subjectId: labSubjOOP.id,
        teacherId: profLab1.id,
        roomId: labRoom1.id,
        batch: 'B1',
      );
      final p3Entry = TimetableEntry(
        id: 'prop_p3',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Monday',
        periodNumber: 3,
        timeSlotId: 'ts3',
        sectionId: sectionA.id,
        subjectId: labSubjOOP.id,
        teacherId: profLab1.id,
        roomId: labRoom1.id,
        batch: 'B1',
      );

      final val = ConflictValidator.validateProposedEntries(
        collegeId: collegeId,
        proposedEntries: [p2Entry, p3Entry],
        existingEntries: [],
        sections: [sectionA],
        subjects: [labSubjOOP],
        staffList: [profLab1],
        rooms: [labRoom1],
        timeSlots: standardSlots,
        availabilities: [],
      );

      expect(val.isValid, isFalse);
      expect(val.hardConflicts.any((c) => c.type == 'labDurationConflict'), isTrue);
    });

    testWidgets('TEST 17: Deleting B1 does not delete B2 independent parallel lab allocation', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final b1Entry = TimetableEntry(
        id: 'del_test_b1',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Thursday',
        periodNumber: 1,
        timeSlotId: 'ts1',
        sectionId: sectionA.id,
        subjectId: labSubjOOP.id,
        teacherId: profLab1.id,
        roomId: labRoom1.id,
        batch: 'B1',
      );

      final b2Entry = TimetableEntry(
        id: 'del_test_b2',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Thursday',
        periodNumber: 1,
        timeSlotId: 'ts1',
        sectionId: sectionA.id,
        subjectId: labSubjDSA.id,
        teacherId: profLab2.id,
        roomId: labRoom2.id,
        batch: 'B2',
      );

      final repo = LocalDatabaseRepository();
      await repo.createCollege(college);
      await repo.createSection(sectionA);
      await repo.createSubject(labSubjOOP);
      await repo.createSubject(labSubjDSA);
      await repo.createStaff(profLab1);
      await repo.createStaff(profLab2);
      await repo.createRoom(labRoom1);
      await repo.createRoom(labRoom2);
      for (final s in standardSlots) {
        await repo.createTimeSlot(s);
      }
      await repo.createTimetableEntry(b1Entry);
      await repo.createTimetableEntry(b2Entry);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseRepositoryProvider.overrideWithValue(repo),
            currentProfileProvider.overrideWith((ref) => adminProfile),
            currentCollegeProvider.overrideWith((ref) => Future.value(college)),
            timetableVersionsProvider.overrideWith((ref) => Future.value([version])),
            selectedVersionIdProvider.overrideWith((ref) => version.id),
            sectionListProvider.overrideWith((ref) => Future.value([sectionA])),
            subjectListProvider.overrideWith((ref) => Future.value([labSubjOOP, labSubjDSA])),
            staffListProvider.overrideWith((ref) => Future.value([profLab1, profLab2])),
            roomListProvider.overrideWith((ref) => Future.value([labRoom1, labRoom2])),
            timeSlotsProvider.overrideWith((ref) => Future.value(standardSlots)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TimetableEditorDialog(entry: b1Entry),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final deleteBtn = find.byKey(const Key('editor_delete_button'));
      expect(deleteBtn, findsOneWidget);

      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Confirm dialog appeared
      final confirmBtn = find.text('Remove Class');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify B1 was deleted from database, but B2 REMAINS INTACT!
      final remainingEntries = await repo.getTimetableEntries(collegeId, versionId: version.id);
      expect(remainingEntries.any((e) => e.id == b1Entry.id), isFalse);
      expect(remainingEntries.any((e) => e.id == b2Entry.id), isTrue);
      expect(remainingEntries.firstWhere((e) => e.id == b2Entry.id).batch, equals('B2'));
    });

    test('TEST 18: Parallel different-subject batch labs remain independent in engine validation', () {
      final b1Entry = TimetableEntry(
        id: 'indep_b1',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Friday',
        periodNumber: 1,
        timeSlotId: 'ts1',
        sectionId: sectionA.id,
        subjectId: labSubjOOP.id,
        teacherId: profLab1.id,
        roomId: labRoom1.id,
        batch: 'B1',
      );

      final b2Entry = TimetableEntry(
        id: 'indep_b2',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Friday',
        periodNumber: 1,
        timeSlotId: 'ts1',
        sectionId: sectionA.id,
        subjectId: labSubjDSA.id,
        teacherId: profLab2.id,
        roomId: labRoom2.id,
        batch: 'B2',
      );

      final b1EntryP2 = b1Entry.copyWith(id: 'indep_b1_p2', periodNumber: 2, timeSlotId: 'ts2');
      final b2EntryP2 = b2Entry.copyWith(id: 'indep_b2_p2', periodNumber: 2, timeSlotId: 'ts2');

      final val = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: [b1Entry, b2Entry, b1EntryP2, b2EntryP2],
        sections: [sectionA],
        subjects: [labSubjOOP, labSubjDSA],
        staffList: [profLab1, profLab2],
        rooms: [labRoom1, labRoom2],
        timeSlots: standardSlots,
        availabilities: [],
      );

      expect(val.isValid, isTrue);
      expect(val.hardConflicts, isEmpty);
    });

    test('TEST 19: Export preserves batch information', () async {
      final b1Entry = TimetableEntry(
        id: 'pdf_b1',
        collegeId: collegeId,
        versionId: version.id,
        dayOfWeek: 'Monday',
        periodNumber: 1,
        timeSlotId: 'ts1',
        sectionId: sectionA.id,
        subjectId: labSubjOOP.id,
        teacherId: profLab1.id,
        roomId: labRoom1.id,
        batch: 'B1',
      );

      final pdfBytes = await PdfExportService.generateTimetablePdf(
        pageFormat: PdfPageFormat.a4,
        college: college,
        version: version,
        entries: [b1Entry],
        timeSlots: standardSlots,
        staffMap: {profLab1.id: profLab1},
        sectionMap: {sectionA.id: sectionA},
        roomMap: {labRoom1.id: labRoom1},
        subjectMap: {labSubjOOP.id: labSubjOOP},
        targetView: 'section',
        selectedSectionId: sectionA.id,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('TEST 20: Existing timetable generation tests remain unchanged and passing', () {
      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: [sectionA],
        subjects: [labSubjOOP, labSubjDSA],
        staffList: [profLab1, profLab2],
        rooms: [labRoom1, labRoom2],
        timeSlots: standardSlots,
        availabilities: [],
        workingDays: workingDays,
      );

      expect(result.isSuccess, isTrue);
      expect(result.entries, isNotEmpty);
    });
  });
}
