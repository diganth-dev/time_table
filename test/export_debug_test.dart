import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/features/timetable/screens/export_screen.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/providers/providers.dart';
import 'package:time_table/repositories/repositories.dart';

void main() {
  testWidgets('Debug Export Timetable data loading flow', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = LocalDatabaseRepository();
    const collegeId = 'user_college';

    // Check if firestore_dump exists
    final dumpFile = File('C:/Users/deeek/.gemini/antigravity-cli/brain/4f176d6f-4e29-4fcf-a421-4637fd04c336/scratch/firestore_dump.json');
    if (!dumpFile.existsSync()) {
      return;
    }

    final jsonMap = jsonDecode(dumpFile.readAsStringSync()) as Map<String, dynamic>;

    final timeSlots = (jsonMap['timeSlots'] as List)
        .map((t) => TimeSlot.fromJson(t as Map<String, dynamic>, id: t['id']))
        .toList();
    final sections = (jsonMap['sections'] as List)
        .map((s) => Section.fromJson(s as Map<String, dynamic>, id: s['id']))
        .toList();
    final subjects = (jsonMap['subjects'] as List)
        .map((s) => Subject.fromJson(s as Map<String, dynamic>, id: s['id']))
        .toList();
    final staffList = (jsonMap['staff'] as List)
        .map((st) => Staff.fromJson(st as Map<String, dynamic>, id: st['id']))
        .toList();
    final rooms = (jsonMap['rooms'] as List)
        .map((r) => Room.fromJson(r as Map<String, dynamic>, id: r['id']))
        .toList();

    // Populate repo
    for (final s in sections) {
      await repo.createSection(s);
    }
    for (final sub in subjects) {
      await repo.createSubject(sub);
    }
    for (final st in staffList) {
      await repo.createStaff(st);
    }
    for (final r in rooms) {
      await repo.createRoom(r);
    }
    await repo.saveTimeSlots(collegeId, timeSlots);

    // Add a second section
    final section2 = Section(
      id: 'sec_other_section',
      collegeId: collegeId,
      departmentId: 'dept_default',
      courseId: 'course_default',
      academicYear: '2026-2027',
      semester: 3,
      sectionName: 'CSE(A)',
      studentCount: 60,
    );
    await repo.createSection(section2);

    final staff2 = Staff(
      id: 'staff_extra',
      collegeId: collegeId,
      employeeId: 'EMP999',
      name: 'Extra Prof',
      email: 'extra@college.edu',
      departmentId: 'dept_default',
      designation: 'Assistant Professor',
      status: 'active',
      subjectsCanTeach: [],
      maxClassesPerDay: 5,
    );
    await repo.createStaff(staff2);

    final subOther = Subject(
      id: 'sub_other_1',
      collegeId: collegeId,
      sectionId: section2.id,
      departmentId: 'dept_default',
      courseId: 'course_default',
      semester: 3,
      subjectCode: 'CS301',
      subjectName: 'Data Structures',
      subjectType: 'Theory',
      hoursPerWeek: 4,
      requiredRoomType: 'Classroom',
      assignedTeacherIds: [staff2.id],
    );
    await repo.createSubject(subOther);

    final container = ProviderContainer(
      overrides: [
        databaseRepositoryProvider.overrideWithValue(repo),
        activeCollegeIdProvider.overrideWith((ref) => collegeId),
        currentProfileProvider.overrideWith((ref) => UserProfile(
          id: 'admin_1',
          email: 'admin@college.edu',
          name: 'Admin',
          role: UserRole.collegeAdmin,
          collegeId: collegeId,
          createdAt: DateTime.now(),
        )),
      ],
    );
    addTearDown(container.dispose);

    // 1. Generate Timetable Schedule
    final controller = container.read(timetableControllerProvider.notifier);
    final result = await controller.generateSchedule(customVersionName: 'Draft 1');
    expect(result.totalClassesScheduled, greaterThan(0));

    // 2. Active versionId after generation
    final activeVersionId = container.read(selectedVersionIdProvider);
    expect(activeVersionId, isNotNull);

    // Simulate user viewing TimetableScreen where section2 was selected
    container.read(selectedSectionFilterProvider.notifier).state = section2.id;

    // 3. Inspect what timetableEntriesProvider returns now!
    final loadedEntriesWithFilter = await container.read(timetableEntriesProvider.future);

    // 4. In ExportScreen, user selects AIML section (sec_36a81535)
    final aimlSectionId = 'sec_36a81535';
    final entriesMatchingAiml = loadedEntriesWithFilter.where((e) => e.sectionId == aimlSectionId).toList();
    expect(entriesMatchingAiml, isNotEmpty);

    // Test ExportScreen widget pump
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ExportScreen())),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial render: Section CSE(A) is selected because selectedSectionFilterProvider was set to it
    expect(find.text('Select Section'), findsOneWidget);

    // Now user selects AIML section from dropdown
    final sectionDropdown = find.widgetWithText(DropdownButtonFormField<String>, 'Select Section');
    expect(sectionDropdown, findsOneWidget);

    await tester.tap(sectionDropdown);
    await tester.pumpAndSettle();

    // Tap on AIML section option
    final aimlOption = find.text('Sem 5 - Sec CSE(AIML) (57 students)').last;
    await tester.tap(aimlOption);
    await tester.pumpAndSettle();

    // Verify: AIML classes are now displayed!
    expect(find.text('TOC'), findsAtLeastNWidgets(1));
    expect(find.text('SEPM'), findsAtLeastNWidgets(1));
    expect(find.text('CN LAB'), findsAtLeastNWidgets(1));

    // Verify Course / Faculty / Venue Information table is populated
    expect(find.text('Course / Faculty / Venue Information'), findsOneWidget);
    expect(find.text('Theory of Computation').evaluate().isNotEmpty || find.text('TOC').evaluate().isNotEmpty, isTrue);

    // Verify selectedSectionFilterProvider was updated
    expect(container.read(selectedSectionFilterProvider), equals(aimlSectionId));
  });

  testWidgets('ExportScreen handles null selectedVersionId and switches versions correctly', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final repo = LocalDatabaseRepository();
    const collegeId = 'user_college';

    final dumpFile = File('C:/Users/deeek/.gemini/antigravity-cli/brain/4f176d6f-4e29-4fcf-a421-4637fd04c336/scratch/firestore_dump.json');
    if (!dumpFile.existsSync()) return;

    final jsonMap = jsonDecode(dumpFile.readAsStringSync()) as Map<String, dynamic>;

    final timeSlots = (jsonMap['timeSlots'] as List)
        .map((t) => TimeSlot.fromJson(t as Map<String, dynamic>, id: t['id']))
        .toList();
    final sections = (jsonMap['sections'] as List)
        .map((s) => Section.fromJson(s as Map<String, dynamic>, id: s['id']))
        .toList();
    final subjects = (jsonMap['subjects'] as List)
        .map((s) => Subject.fromJson(s as Map<String, dynamic>, id: s['id']))
        .toList();
    final staffList = (jsonMap['staff'] as List)
        .map((st) => Staff.fromJson(st as Map<String, dynamic>, id: st['id']))
        .toList();
    final rooms = (jsonMap['rooms'] as List)
        .map((r) => Room.fromJson(r as Map<String, dynamic>, id: r['id']))
        .toList();

    for (final s in sections) {
      await repo.createSection(s);
    }
    for (final sub in subjects) {
      await repo.createSubject(sub);
    }
    for (final st in staffList) {
      await repo.createStaff(st);
    }
    for (final r in rooms) {
      await repo.createRoom(r);
    }
    await repo.saveTimeSlots(collegeId, timeSlots);

    final container = ProviderContainer(
      overrides: [
        databaseRepositoryProvider.overrideWithValue(repo),
        activeCollegeIdProvider.overrideWith((ref) => collegeId),
        currentProfileProvider.overrideWith((ref) => UserProfile(
          id: 'admin_1',
          email: 'admin@college.edu',
          name: 'Admin',
          role: UserRole.collegeAdmin,
          collegeId: collegeId,
          createdAt: DateTime.now(),
        )),
      ],
    );
    addTearDown(container.dispose);

    // Generate version 1
    final controller = container.read(timetableControllerProvider.notifier);
    final res1 = await controller.generateSchedule(customVersionName: 'Draft Version 1');
    expect(res1.totalClassesScheduled, greaterThan(0));

    // Reset selectedVersionIdProvider to null to simulate fresh screen load
    container.read(selectedVersionIdProvider.notifier).state = null;
    expect(container.read(selectedVersionIdProvider), isNull);

    // Pump ExportScreen
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ExportScreen())),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Timetable Version dropdown exists and displays Draft Version 1
    expect(find.text('Timetable Version'), findsOneWidget);
    expect(find.text('Draft Version 1'), findsOneWidget);

    // Verify classes are displayed even with null selectedVersionIdProvider initially
    expect(find.text('TOC'), findsAtLeastNWidgets(1));
    expect(find.text('Course / Faculty / Venue Information'), findsOneWidget);
  });
}

