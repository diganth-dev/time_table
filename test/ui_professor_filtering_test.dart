import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/features/sections/screens/sections_and_subjects_screen.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/providers/providers.dart';
import 'package:time_table/repositories/local_repository.dart';

void main() {
  const collegeId = 'col_apex_engineering';

  setUp(() async {
    final db = LocalDatabaseRepository();
    final existingStaff = await db.getStaffList(collegeId);
    for (final s in existingStaff) {
      await db.deleteStaff(s.id);
    }
    final existingSections = await db.getSections(collegeId);
    for (final sec in existingSections) {
      await db.deleteSection(sec.id);
    }
  });

  Future<void> setupScreen(WidgetTester tester, LocalDatabaseRepository db) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseRepositoryProvider.overrideWithValue(db),
          activeCollegeIdProvider.overrideWith((ref) => collegeId),
        ],
        child: const MaterialApp(
          home: SectionsAndSubjectsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Add Subject to Section UI: Neutral prompt on open, Kumaraswamy ("software") matches "Software Engineering & Project Management"', (tester) async {
    final db = LocalDatabaseRepository();
    addTearDown(tester.view.resetPhysicalSize);

    final section = Section(
      id: 'sec_1',
      collegeId: collegeId,
      departmentId: 'dept_cse',
      courseId: 'cse',
      academicYear: '2026-2027',
      semester: 5,
      sectionName: '5A',
      studentCount: 40,
    );
    await db.createSection(section);

    final kuma = Staff(
      id: 'prof_kuma',
      collegeId: collegeId,
      departmentId: 'dept_cse',
      name: 'Kumaraswamy',
      subjectsCanTeach: ['software'],
      status: 'active',
    );
    await db.createStaff(kuma);

    await setupScreen(tester, db);

    // Click Add Subject to Section
    await tester.tap(find.text('Add Subject to Section'));
    await tester.pumpAndSettle();

    // 1. Initial State: Must NOT show the amber warning before entering subject details!
    expect(find.textContaining('No eligible professor available'), findsNothing);
    expect(find.textContaining('Enter a Subject Name or Code above to see eligible professors'), findsOneWidget);

    // 2. Enter Subject Name: "Software Engineering & Project Management"
    final nameField = find.widgetWithText(TextField, 'Subject Name');
    await tester.enterText(nameField, 'Software Engineering & Project Management');
    await tester.pumpAndSettle();

    // Must show 1 eligible professor available and Kumaraswamy in dropdown list
    expect(find.textContaining('No eligible professor available'), findsNothing);
    expect(find.textContaining('1 eligible professor(s) available'), findsOneWidget);

    // Open dropdown to verify Kumaraswamy appears
    final profDropdown = find.byType(DropdownButtonFormField<String>).last;
    await tester.tap(profDropdown);
    await tester.pumpAndSettle();

    expect(find.textContaining('Kumaraswamy'), findsWidgets);
  });

  testWidgets('Add Subject to Section UI: Kumaraswamy ("Operating systems, Software engineering and project management") matches subject "software"', (tester) async {
    final db = LocalDatabaseRepository();
    addTearDown(tester.view.resetPhysicalSize);

    final section = Section(
      id: 'sec_1',
      collegeId: collegeId,
      departmentId: 'dept_cse',
      courseId: 'cse',
      academicYear: '2026-2027',
      semester: 5,
      sectionName: '5A',
      studentCount: 40,
    );
    await db.createSection(section);

    final kuma = Staff(
      id: 'prof_kuma',
      collegeId: collegeId,
      departmentId: 'dept_cse',
      name: 'Kumaraswamy',
      subjectsCanTeach: [
        'Operating systems, Software engineering and project management'
      ],
      status: 'active',
    );
    await db.createStaff(kuma);

    await setupScreen(tester, db);

    await tester.tap(find.text('Add Subject to Section'));
    await tester.pumpAndSettle();

    // Enter "software" in Subject Name
    final nameField = find.widgetWithText(TextField, 'Subject Name');
    await tester.enterText(nameField, 'software');
    await tester.pumpAndSettle();

    // Kumaraswamy MUST appear as eligible
    expect(find.textContaining('No eligible professor available'), findsNothing);
    expect(find.textContaining('1 eligible professor(s) available'), findsOneWidget);

    final profDropdown = find.byType(DropdownButtonFormField<String>).last;
    await tester.tap(profDropdown);
    await tester.pumpAndSettle();

    expect(find.textContaining('Kumaraswamy'), findsWidgets);
  });

  testWidgets('Add Subject to Section UI: Global generic matching for Database, Computer, and False Positives', (tester) async {
    final db = LocalDatabaseRepository();
    addTearDown(tester.view.resetPhysicalSize);

    final section = Section(
      id: 'sec_1',
      collegeId: collegeId,
      departmentId: 'dept_cse',
      courseId: 'cse',
      academicYear: '2026-2027',
      semester: 5,
      sectionName: '5A',
      studentCount: 40,
    );
    await db.createSection(section);

    // Professor with "database"
    final dbProf = Staff(
      id: 'prof_db',
      collegeId: collegeId,
      departmentId: 'dept_cse',
      name: 'Dr. Ramesh (DBMS)',
      subjectsCanTeach: ['database'],
      status: 'active',
    );
    await db.createStaff(dbProf);

    // Professor with "computer"
    final netProf = Staff(
      id: 'prof_net',
      collegeId: collegeId,
      departmentId: 'dept_cse',
      name: 'Dr. Suresh (CN)',
      subjectsCanTeach: ['computer'],
      status: 'active',
    );
    await db.createStaff(netProf);

    // Professor with misspelled "softwre"
    final fuzzyProf = Staff(
      id: 'prof_fuzzy',
      collegeId: collegeId,
      departmentId: 'dept_cse',
      name: 'Dr. Anita (SE)',
      subjectsCanTeach: ['softwre'],
      status: 'active',
    );
    await db.createStaff(fuzzyProf);

    await setupScreen(tester, db);

    // Open Add Subject
    await tester.tap(find.text('Add Subject to Section'));
    await tester.pumpAndSettle();

    final nameField = find.widgetWithText(TextField, 'Subject Name');

    // Case 1: "Database Management Systems" -> Dr. Ramesh must be eligible
    await tester.enterText(nameField, 'Database Management Systems');
    await tester.pumpAndSettle();
    expect(find.textContaining('1 eligible professor(s) available'), findsOneWidget);
    final profDropdown1 = find.byType(DropdownButtonFormField<String>).last;
    await tester.tap(profDropdown1);
    await tester.pumpAndSettle();
    expect(find.textContaining('Dr. Ramesh (DBMS)'), findsWidgets);
    expect(find.textContaining('Dr. Suresh'), findsNothing);
    expect(find.textContaining('Dr. Anita'), findsNothing);
    // Tap to select Dr. Ramesh
    await tester.tap(find.textContaining('Dr. Ramesh (DBMS)').last);
    await tester.pumpAndSettle();

    // Case 2: "Computer Networks" -> Dr. Suresh must be eligible
    await tester.enterText(nameField, 'Computer Networks');
    await tester.pumpAndSettle();
    expect(find.textContaining('1 eligible professor(s) available'), findsOneWidget);
    final profDropdown2 = find.byType(DropdownButtonFormField<String>).last;
    await tester.tap(profDropdown2);
    await tester.pumpAndSettle();
    expect(find.textContaining('Dr. Suresh (CN)'), findsWidgets);
    expect(find.textContaining('Dr. Ramesh'), findsNothing);
    expect(find.textContaining('Dr. Anita'), findsNothing);
    // Tap to select Dr. Suresh
    await tester.tap(find.textContaining('Dr. Suresh (CN)').last);
    await tester.pumpAndSettle();

    // Case 3: "Software Engineering & Project Management" -> Dr. Anita (softwre) must be eligible via fuzzy matching
    await tester.enterText(nameField, 'Software Engineering & Project Management');
    await tester.pumpAndSettle();
    expect(find.textContaining('1 eligible professor(s) available'), findsOneWidget);
    final profDropdown3 = find.byType(DropdownButtonFormField<String>).last;
    await tester.tap(profDropdown3);
    await tester.pumpAndSettle();
    expect(find.textContaining('Dr. Anita (SE)'), findsWidgets);
    expect(find.textContaining('Dr. Ramesh'), findsNothing);
    expect(find.textContaining('Dr. Suresh'), findsNothing);
    // Tap to select Dr. Anita
    await tester.tap(find.textContaining('Dr. Anita (SE)').last);
    await tester.pumpAndSettle();

    // Case 4: Unrelated subject "Mechanical Thermodynamics" -> Amber warning box appears
    await tester.enterText(nameField, 'Mechanical Thermodynamics');
    await tester.pumpAndSettle();
    expect(find.textContaining('No eligible professor available for "Mechanical Thermodynamics"'), findsOneWidget);
  });
}
