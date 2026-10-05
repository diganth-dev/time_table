import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/features/timetable/screens/timetable_editor_dialog.dart';
import 'package:time_table/features/timetable/screens/timetable_screen.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/providers/providers.dart';
import 'package:time_table/repositories/local_repository.dart';

void main() {
  testWidgets('INVESTIGATION: Edit / Reassign class to Friday Period 5', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    const collegeId = 'user_college';
    final workingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    final slots = [
      TimeSlot(id: 'ts_1', collegeId: collegeId, periodNumber: 1, startTime: '08:50', endTime: '09:50', order: 1),
      TimeSlot(id: 'ts_2', collegeId: collegeId, periodNumber: 2, startTime: '09:50', endTime: '10:50', order: 2),
      TimeSlot(id: 'ts_b1', collegeId: collegeId, periodNumber: 0, startTime: '10:50', endTime: '11:05', isBreak: true, breakTitle: 'Morning Break', order: 3),
      TimeSlot(id: 'ts_3', collegeId: collegeId, periodNumber: 3, startTime: '11:05', endTime: '12:05', order: 4),
      TimeSlot(id: 'ts_4', collegeId: collegeId, periodNumber: 4, startTime: '12:05', endTime: '13:05', order: 5),
      TimeSlot(id: 'ts_lunch', collegeId: collegeId, periodNumber: 0, startTime: '13:05', endTime: '13:45', isBreak: true, breakTitle: 'Lunch Break', order: 6),
      TimeSlot(id: 'ts_5', collegeId: collegeId, periodNumber: 5, startTime: '13:45', endTime: '14:45', order: 7),
      TimeSlot(id: 'ts_6', collegeId: collegeId, periodNumber: 6, startTime: '14:45', endTime: '15:45', order: 8),
    ];

    final college = College(
      id: collegeId,
      name: 'University College',
      code: 'UC',
      address: '',
      workingDays: workingDays,
    );

    final version = TimetableVersion(
      id: 'ver_test_1',
      collegeId: collegeId,
      versionNumber: 1,
      name: 'Draft Version 1',
      academicYear: '2026-2027',
      semester: 'Odd 2026',
      status: 'draft',
    );

    final section = Section(
      id: 'sec_aiml',
      collegeId: collegeId,
      departmentId: 'dept_cs',
      courseId: 'course_be',
      academicYear: '2026-2027',
      semester: 5,
      sectionName: 'CSE(AIML)',
      studentCount: 60,
      batches: ['B1', 'B2'],
    );

    final subjectTOC = Subject(
      id: 'sub_toc',
      collegeId: collegeId,
      departmentId: 'dept_cs',
      courseId: 'course_be',
      subjectName: 'Theory of Computation',
      courseShortName: 'TOC',
      subjectCode: 'BCS503',
      semester: 5,
      subjectType: 'Theory',
      hoursPerWeek: 4,
      consecutivePeriods: 1,
      requiredRoomType: 'Classroom',
      assignedTeacherIds: ['staff_gayatri'],
      sectionId: section.id,
    );

    final teacherGayatri = Staff(
      id: 'staff_gayatri',
      collegeId: collegeId,
      employeeId: '03',
      name: 'Gayatri Devadiga',
      email: 'gayatri@gmail.com',
      departmentId: 'dept_cs',
      status: 'active',
      subjectsCanTeach: ['Theory of Computation'],
      maxClassesPerDay: 5,
    );

    final roomLH312 = Room(
      id: 'room_312',
      collegeId: collegeId,
      roomNumber: 'LH 312',
      roomType: 'Classroom',
      capacity: 60,
      active: true,
    );

    final adminProfile = UserProfile(
      id: 'usr_admin',
      email: 'admin@test.edu',
      name: 'Admin',
      role: UserRole.collegeAdmin,
      collegeId: collegeId,
    );

    // Initial assignment: Monday Period 1
    final initialEntry = TimetableEntry(
      id: 'entry_toc_1',
      collegeId: collegeId,
      versionId: version.id,
      dayOfWeek: 'Monday',
      periodNumber: 1,
      timeSlotId: 'ts_1',
      sectionId: section.id,
      subjectId: subjectTOC.id,
      teacherId: teacherGayatri.id,
      roomId: roomLH312.id,
      status: 'draft',
    );

    final repo = LocalDatabaseRepository();
    await repo.deleteTimetable(collegeId);
    await repo.createCollege(college);
    await repo.createTimetableVersion(version);
    await repo.createSection(section);
    await repo.createSubject(subjectTOC);
    await repo.createStaff(teacherGayatri);
    await repo.createRoom(roomLH312);
    for (final s in slots) {
      await repo.createTimeSlot(s);
    }
    await repo.createTimetableEntry(initialEntry);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseRepositoryProvider.overrideWithValue(repo),
          currentProfileProvider.overrideWith((ref) => adminProfile),
          activeCollegeIdProvider.overrideWith((ref) => collegeId),
          currentCollegeProvider.overrideWith((ref) => Future.value(college)),
          timetableVersionsProvider.overrideWith((ref) => Future.value([version])),
          // Notice: selectedVersionIdProvider is left as default (null), just like in the app!
          sectionListProvider.overrideWith((ref) => Future.value([section])),
          subjectListProvider.overrideWith((ref) => Future.value([subjectTOC])),
          staffListProvider.overrideWith((ref) => Future.value([teacherGayatri])),
          roomListProvider.overrideWith((ref) => Future.value([roomLH312])),
          timeSlotsProvider.overrideWith((ref) => Future.value(slots)),
        ],
        child: const MaterialApp(home: TimetableScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial card is rendered on Monday Period 1
    expect(find.byKey(Key('entry_card_${initialEntry.id}')), findsOneWidget);

    // Click the card to open TimetableEditorDialog
    await tester.tap(find.byKey(Key('entry_card_${initialEntry.id}')));
    await tester.pumpAndSettle();

    expect(find.byType(TimetableEditorDialog), findsOneWidget);
    expect(find.text('Edit / Reassign Class'), findsOneWidget);

    // Reassign Day: Change to Friday
    final dayDropdown = find.byKey(const Key('editor_day_dropdown'));
    expect(dayDropdown, findsOneWidget);
    await tester.tap(dayDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Friday').last);
    await tester.pumpAndSettle();

    // Reassign Period: Change to Period 5
    final periodDropdown = find.byKey(const Key('editor_period_dropdown'));
    expect(periodDropdown, findsOneWidget);
    await tester.tap(periodDropdown);
    await tester.pumpAndSettle();
    // Period 5 is 'Period 5 (13:45 - 14:45)'
    final period5Item = find.textContaining('Period 5').last;
    await tester.tap(period5Item);
    await tester.pumpAndSettle();

    // Verify validation reports valid placement
    expect(find.textContaining('Valid placement'), findsOneWidget);

    // Tap Save Changes
    final saveButton = find.byKey(const Key('editor_save_button'));
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Dialog should be dismissed
    expect(find.byType(TimetableEditorDialog), findsNothing);

    // Check repository
    final entriesInRepo = await repo.getTimetableEntries(collegeId, versionId: version.id);
    print('Entries in repo for version ${version.id}: ${entriesInRepo.length}');
    for (final e in entriesInRepo) {
      print('  Entry: id=${e.id}, day=${e.dayOfWeek}, period=${e.periodNumber}, versionId=${e.versionId}, sectionId=${e.sectionId}');
    }

    // Now verify the cell in the timetable matrix
    // Friday Period 5 should NOT be empty!
    final emptyFriday5 = find.byKey(const Key('empty_cell_Friday_5'));
    print('empty_cell_Friday_5 found: ${emptyFriday5.evaluate().isNotEmpty}');

    // The entry card should now exist
    final entryCard = find.byKey(Key('entry_card_${initialEntry.id}'));
    print('entry_card found: ${entryCard.evaluate().isNotEmpty}');

    expect(emptyFriday5, findsNothing, reason: 'Target cell Friday Period 5 must NOT be empty after saving changes.');
    expect(entryCard, findsOneWidget, reason: 'Entry card should be rendered on Friday Period 5.');
  });

  testWidgets('INVESTIGATION 2: Click EMPTY CELL Friday Period 5, assign TOC Gayatri LH312, and save', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    const collegeId = 'user_college';
    final workingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    final slots = [
      TimeSlot(id: 'ts_1', collegeId: collegeId, periodNumber: 1, startTime: '08:50', endTime: '09:50', order: 1),
      TimeSlot(id: 'ts_2', collegeId: collegeId, periodNumber: 2, startTime: '09:50', endTime: '10:50', order: 2),
      TimeSlot(id: 'ts_b1', collegeId: collegeId, periodNumber: 0, startTime: '10:50', endTime: '11:05', isBreak: true, breakTitle: 'Morning Break', order: 3),
      TimeSlot(id: 'ts_3', collegeId: collegeId, periodNumber: 3, startTime: '11:05', endTime: '12:05', order: 4),
      TimeSlot(id: 'ts_4', collegeId: collegeId, periodNumber: 4, startTime: '12:05', endTime: '13:05', order: 5),
      TimeSlot(id: 'ts_lunch', collegeId: collegeId, periodNumber: 0, startTime: '13:05', endTime: '13:45', isBreak: true, breakTitle: 'Lunch Break', order: 6),
      TimeSlot(id: 'ts_5', collegeId: collegeId, periodNumber: 5, startTime: '13:45', endTime: '14:45', order: 7),
      TimeSlot(id: 'ts_6', collegeId: collegeId, periodNumber: 6, startTime: '14:45', endTime: '15:45', order: 8),
    ];

    final college = College(
      id: collegeId,
      name: 'University College',
      code: 'UC',
      address: '',
      workingDays: workingDays,
    );

    final version = TimetableVersion(
      id: 'ver_test_1',
      collegeId: collegeId,
      versionNumber: 1,
      name: 'Draft Version 1',
      academicYear: '2026-2027',
      semester: 'Odd 2026',
      status: 'draft',
    );

    final section = Section(
      id: 'sec_aiml',
      collegeId: collegeId,
      departmentId: 'dept_cs',
      courseId: 'course_be',
      academicYear: '2026-2027',
      semester: 5,
      sectionName: 'CSE(AIML)',
      studentCount: 60,
      batches: ['B1', 'B2'],
    );

    final subjectTOC = Subject(
      id: 'sub_toc',
      collegeId: collegeId,
      departmentId: 'dept_cs',
      courseId: 'course_be',
      subjectName: 'Theory of Computation',
      courseShortName: 'TOC',
      subjectCode: 'BCS503',
      semester: 5,
      subjectType: 'Theory',
      hoursPerWeek: 4,
      consecutivePeriods: 1,
      requiredRoomType: 'Classroom',
      assignedTeacherIds: ['staff_gayatri'],
      sectionId: section.id,
    );

    final teacherGayatri = Staff(
      id: 'staff_gayatri',
      collegeId: collegeId,
      employeeId: '03',
      name: 'Gayatri Devadiga',
      email: 'gayatri@gmail.com',
      departmentId: 'dept_cs',
      status: 'active',
      subjectsCanTeach: ['Theory of Computation'],
      maxClassesPerDay: 5,
    );

    final roomLH312 = Room(
      id: 'room_312',
      collegeId: collegeId,
      roomNumber: 'LH 312',
      roomType: 'Classroom',
      capacity: 60,
      active: true,
    );

    final adminProfile = UserProfile(
      id: 'usr_admin',
      email: 'admin@test.edu',
      name: 'Admin',
      role: UserRole.collegeAdmin,
      collegeId: collegeId,
    );

    final repo = LocalDatabaseRepository();
    await repo.deleteTimetable(collegeId);
    await repo.createCollege(college);
    await repo.createTimetableVersion(version);
    await repo.createSection(section);
    await repo.createSubject(subjectTOC);
    await repo.createStaff(teacherGayatri);
    await repo.createRoom(roomLH312);
    for (final s in slots) {
      await repo.createTimeSlot(s);
    }
    // Notice: NO initial timetable entries! All cells are empty.

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseRepositoryProvider.overrideWithValue(repo),
          currentProfileProvider.overrideWith((ref) => adminProfile),
          activeCollegeIdProvider.overrideWith((ref) => collegeId),
          currentCollegeProvider.overrideWith((ref) => Future.value(college)),
          timetableVersionsProvider.overrideWith((ref) => Future.value([version])),
          // Notice: selectedVersionIdProvider is left as default (null), just like when opening the screen!
          sectionListProvider.overrideWith((ref) => Future.value([section])),
          subjectListProvider.overrideWith((ref) => Future.value([subjectTOC])),
          staffListProvider.overrideWith((ref) => Future.value([teacherGayatri])),
          roomListProvider.overrideWith((ref) => Future.value([roomLH312])),
          timeSlotsProvider.overrideWith((ref) => Future.value(slots)),
        ],
        child: const MaterialApp(home: TimetableScreen()),
      ),
    );

    await tester.pumpAndSettle();

    final allTexts = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().toList();
    print('INVESTIGATION 2: All Texts on screen: $allTexts');

    // Verify empty cell on Friday Period 5
    final emptyFriday5 = find.byKey(const Key('empty_cell_Friday_5'));
    expect(emptyFriday5, findsOneWidget);

    // Tap the empty cell
    await tester.tap(emptyFriday5);
    await tester.pumpAndSettle();

    expect(find.byType(TimetableEditorDialog), findsOneWidget);

    // Verify validation
    expect(find.textContaining('Valid placement'), findsOneWidget);

    // Tap Save Changes
    final saveButton = find.byKey(const Key('editor_save_button'));
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Dialog should be dismissed
    expect(find.byType(TimetableEditorDialog), findsNothing);

    // Check repository
    final entriesInRepo = await repo.getTimetableEntries(collegeId, versionId: version.id);
    print('INVESTIGATION 2: Entries in repo for version ${version.id}: ${entriesInRepo.length}');
    final allEntriesInRepo = await repo.getTimetableEntries(collegeId);
    print('INVESTIGATION 2: ALL Entries in repo: ${allEntriesInRepo.length}');
    for (final e in allEntriesInRepo) {
      print('  Entry: id=${e.id}, day=${e.dayOfWeek}, period=${e.periodNumber}, versionId="${e.versionId}"');
    }

    // Now verify the cell in the timetable matrix
    final emptyFriday5After = find.byKey(const Key('empty_cell_Friday_5'));
    print('empty_cell_Friday_5 found after save: ${emptyFriday5After.evaluate().isNotEmpty}');

    expect(emptyFriday5After, findsNothing, reason: 'Target cell Friday Period 5 must NOT be empty after saving changes.');

    // Verify card content on Friday Period 5
    expect(find.text('TOC'), findsWidgets);
    expect(find.text('Theory of Computation'), findsWidgets);
    expect(find.textContaining('Gayatri Devadiga'), findsWidgets);
    expect(find.textContaining('LH 312'), findsWidgets);

    // Verify persistence across UI rebuild / re-mount (simulating navigating away and back)
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseRepositoryProvider.overrideWithValue(repo),
          currentProfileProvider.overrideWith((ref) => adminProfile),
          activeCollegeIdProvider.overrideWith((ref) => collegeId),
          currentCollegeProvider.overrideWith((ref) => Future.value(college)),
          timetableVersionsProvider.overrideWith((ref) => Future.value([version])),
          sectionListProvider.overrideWith((ref) => Future.value([section])),
          subjectListProvider.overrideWith((ref) => Future.value([subjectTOC])),
          staffListProvider.overrideWith((ref) => Future.value([teacherGayatri])),
          roomListProvider.overrideWith((ref) => Future.value([roomLH312])),
          timeSlotsProvider.overrideWith((ref) => Future.value(slots)),
        ],
        child: const MaterialApp(home: TimetableScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('empty_cell_Friday_5')), findsNothing);
    expect(find.text('TOC'), findsWidgets);
    expect(find.text('Theory of Computation'), findsWidgets);
    expect(find.textContaining('Gayatri Devadiga'), findsWidgets);
    expect(find.textContaining('LH 312'), findsWidgets);
  });
}

