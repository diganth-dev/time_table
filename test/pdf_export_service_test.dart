import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:time_table/features/timetable/screens/export_screen.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/providers/providers.dart';
import 'package:time_table/repositories/repositories.dart';
import 'package:time_table/services/pdf_export_service.dart';

void main() {
  group('PdfExportService Unit & Integration Tests', () {
    const collegeId = 'test_college_1';
    final college = College(
      id: collegeId,
      name: 'Engineering Institute of Technology',
      code: 'EIT',
      address: 'Main Campus',
      workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      periodsPerDay: 4,
      academicYear: '2026-2027',
      currentSemester: 'Odd',
    );

    final version = TimetableVersion(
      id: 'version_1',
      collegeId: collegeId,
      versionNumber: 1,
      name: 'Spring 2026 Draft V1',
      status: 'draft',
      academicYear: '2026-2027',
      semester: 'Odd',
      isCurrentPublished: true,
    );

    final section1 = Section(
      id: 'sec_1',
      collegeId: collegeId,
      departmentId: 'dept_cse',
      courseId: 'course_btech',
      academicYear: '2026-2027',
      semester: 3,
      sectionName: 'A',
      studentCount: 60,
      batches: ['B1', 'B2'],
    );

    final teacher1 = Staff(
      id: 'staff_1',
      collegeId: collegeId,
      employeeId: 'EMP001',
      name: 'Dr. Alan Turing',
      email: 'alan@eit.edu',
      departmentId: 'dept_cse',
      designation: 'Professor',
      status: 'active',
      subjectsCanTeach: ['sub_theory', 'sub_lab'],
      maxClassesPerDay: 4,
    );

    final teacher2 = Staff(
      id: 'staff_2',
      collegeId: collegeId,
      employeeId: 'EMP002',
      name: 'Dr. Ada Lovelace',
      email: 'ada@eit.edu',
      departmentId: 'dept_cse',
      designation: 'Associate Professor',
      status: 'active',
      subjectsCanTeach: ['sub_lab_2'],
      maxClassesPerDay: 4,
    );

    final room1 = Room(
      id: 'room_1',
      collegeId: collegeId,
      roomNumber: 'LH-101',
      roomType: 'Classroom',
      capacity: 70,
      floor: 1,
      building: 'Academic Block',
      facilities: ['Projector'],
    );

    final labRoom1 = Room(
      id: 'lab_1',
      collegeId: collegeId,
      roomNumber: 'Lab-A',
      roomType: 'Lab',
      capacity: 35,
      floor: 2,
      building: 'Tech Block',
      facilities: ['Computers'],
    );

    final labRoom2 = Room(
      id: 'lab_2',
      collegeId: collegeId,
      roomNumber: 'Lab-B',
      roomType: 'Lab',
      capacity: 35,
      floor: 2,
      building: 'Tech Block',
      facilities: ['Computers'],
    );

    final subjectTheory = Subject(
      id: 'sub_theory',
      collegeId: collegeId,
      sectionId: section1.id,
      departmentId: 'dept_cse',
      courseId: 'course_btech',
      semester: 3,
      subjectCode: 'CS301',
      subjectName: 'Algorithms',
      subjectType: 'Theory',
      hoursPerWeek: 3,
      requiredRoomType: 'Classroom',
      assignedTeacherIds: [teacher1.id],
    );

    final subjectLab1 = Subject(
      id: 'sub_lab_1',
      collegeId: collegeId,
      sectionId: section1.id,
      departmentId: 'dept_cse',
      courseId: 'course_btech',
      semester: 3,
      subjectCode: 'CS302L',
      subjectName: 'DVL Lab',
      subjectType: 'Lab',
      hoursPerWeek: 2,
      consecutivePeriods: 2,
      requiredRoomType: 'Lab',
      assignedTeacherIds: [teacher1.id],
    );

    final subjectLab2 = Subject(
      id: 'sub_lab_2',
      collegeId: collegeId,
      sectionId: section1.id,
      departmentId: 'dept_cse',
      courseId: 'course_btech',
      semester: 3,
      subjectCode: 'CS303L',
      subjectName: 'MP Lab',
      subjectType: 'Lab',
      hoursPerWeek: 2,
      consecutivePeriods: 2,
      requiredRoomType: 'Lab',
      assignedTeacherIds: [teacher2.id],
    );

    final timeSlots = [
      TimeSlot(
        id: 'slot_1',
        collegeId: collegeId,
        periodNumber: 1,
        startTime: '09:00',
        endTime: '10:00',
        isBreak: false,
        order: 1,
      ),
      TimeSlot(
        id: 'slot_2',
        collegeId: collegeId,
        periodNumber: 2,
        startTime: '10:00',
        endTime: '11:00',
        isBreak: false,
        order: 2,
      ),
      TimeSlot(
        id: 'slot_break',
        collegeId: collegeId,
        periodNumber: 0,
        startTime: '11:00',
        endTime: '11:15',
        isBreak: true,
        order: 3,
      ),
      TimeSlot(
        id: 'slot_3',
        collegeId: collegeId,
        periodNumber: 3,
        startTime: '11:15',
        endTime: '12:15',
        isBreak: false,
        order: 4,
      ),
      TimeSlot(
        id: 'slot_4',
        collegeId: collegeId,
        periodNumber: 4,
        startTime: '12:15',
        endTime: '13:15',
        isBreak: false,
        order: 5,
      ),
    ];

    // Entries with concurrent independent batch labs and consecutive periods
    final entries = [
      // Theory session for whole section on Monday P1
      TimetableEntry(
        id: 'entry_1',
        collegeId: collegeId,
        versionId: version.id,
        sectionId: section1.id,
        subjectId: subjectTheory.id,
        teacherId: teacher1.id,
        roomId: room1.id,
        dayOfWeek: 'Monday',
        periodNumber: 1,
        batch: null,
      ),
      // B1 has DVL Lab on Monday P3-P4 (2 consecutive periods) in Lab-A
      TimetableEntry(
        id: 'entry_b1_p3',
        collegeId: collegeId,
        versionId: version.id,
        sectionId: section1.id,
        subjectId: subjectLab1.id,
        teacherId: teacher1.id,
        roomId: labRoom1.id,
        dayOfWeek: 'Monday',
        periodNumber: 3,
        batch: 'B1',
      ),
      TimetableEntry(
        id: 'entry_b1_p4',
        collegeId: collegeId,
        versionId: version.id,
        sectionId: section1.id,
        subjectId: subjectLab1.id,
        teacherId: teacher1.id,
        roomId: labRoom1.id,
        dayOfWeek: 'Monday',
        periodNumber: 4,
        batch: 'B1',
      ),
      // B2 has MP Lab concurrently on Monday P3-P4 in Lab-B with teacher2
      TimetableEntry(
        id: 'entry_b2_p3',
        collegeId: collegeId,
        versionId: version.id,
        sectionId: section1.id,
        subjectId: subjectLab2.id,
        teacherId: teacher2.id,
        roomId: labRoom2.id,
        dayOfWeek: 'Monday',
        periodNumber: 3,
        batch: 'B2',
      ),
      TimetableEntry(
        id: 'entry_b2_p4',
        collegeId: collegeId,
        versionId: version.id,
        sectionId: section1.id,
        subjectId: subjectLab2.id,
        teacherId: teacher2.id,
        roomId: labRoom2.id,
        dayOfWeek: 'Monday',
        periodNumber: 4,
        batch: 'B2',
      ),
    ];

    final staffMap = <String, Staff>{teacher1.id: teacher1, teacher2.id: teacher2};
    final sectionMap = <String, Section>{section1.id: section1};
    final roomMap = <String, Room>{
      room1.id: room1,
      labRoom1.id: labRoom1,
      labRoom2.id: labRoom2,
    };
    final subjectMap = <String, Subject>{
      subjectTheory.id: subjectTheory,
      subjectLab1.id: subjectLab1,
      subjectLab2.id: subjectLab2,
    };

    test('generateTimetablePdf returns valid PDF bytes for section view', () async {
      final bytes = await PdfExportService.generateTimetablePdf(
        pageFormat: PdfPageFormat.a4,
        college: college,
        version: version,
        entries: entries,
        timeSlots: timeSlots,
        staffMap: staffMap,
        sectionMap: sectionMap,
        roomMap: roomMap,
        subjectMap: subjectMap,
        targetView: 'section',
        selectedSectionId: section1.id,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      // Valid PDF magic header %PDF-
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('generateTimetablePdf returns valid PDF bytes for teacher view', () async {
      final bytes = await PdfExportService.generateTimetablePdf(
        pageFormat: PdfPageFormat.a4,
        college: college,
        version: version,
        entries: entries,
        timeSlots: timeSlots,
        staffMap: staffMap,
        sectionMap: sectionMap,
        roomMap: roomMap,
        subjectMap: subjectMap,
        targetView: 'teacher',
        selectedTeacherId: teacher1.id,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('generateTimetablePdf returns valid PDF bytes for course view', () async {
      final bytes = await PdfExportService.generateTimetablePdf(
        pageFormat: PdfPageFormat.a4,
        college: college,
        version: version,
        entries: entries,
        timeSlots: timeSlots,
        staffMap: staffMap,
        sectionMap: sectionMap,
        roomMap: roomMap,
        subjectMap: subjectMap,
        targetView: 'course',
        selectedSubjectId: subjectLab1.id,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('generateTimetablePdf returns valid PDF bytes for room view', () async {
      final bytes = await PdfExportService.generateTimetablePdf(
        pageFormat: PdfPageFormat.a4,
        college: college,
        version: version,
        entries: entries,
        timeSlots: timeSlots,
        staffMap: staffMap,
        sectionMap: sectionMap,
        roomMap: roomMap,
        subjectMap: subjectMap,
        targetView: 'room',
        selectedRoomId: labRoom1.id,
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('generateTimetablePdf returns valid PDF bytes for master view', () async {
      final bytes = await PdfExportService.generateTimetablePdf(
        pageFormat: PdfPageFormat.a4,
        college: college,
        version: version,
        entries: entries,
        timeSlots: timeSlots,
        staffMap: staffMap,
        sectionMap: sectionMap,
        roomMap: roomMap,
        subjectMap: subjectMap,
        targetView: 'master',
      );

      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });

    test('Firestore Safety: PDF generation leaves repository completely untouched', () async {
      final repo = LocalDatabaseRepository();
      await repo.createCollege(college);
      await repo.createSection(section1);
      await repo.createStaff(teacher1);

      final initialSections = await repo.getSections(collegeId);
      final initialStaff = await repo.getStaffList(collegeId);

      // Run PDF generation
      final bytes = await PdfExportService.generateTimetablePdf(
        pageFormat: PdfPageFormat.a4,
        college: college,
        version: version,
        entries: entries,
        timeSlots: timeSlots,
        staffMap: staffMap,
        sectionMap: sectionMap,
        roomMap: roomMap,
        subjectMap: subjectMap,
        targetView: 'section',
      );
      expect(bytes.isNotEmpty, isTrue);

      final postSections = await repo.getSections(collegeId);
      final postStaff = await repo.getStaffList(collegeId);

      expect(postSections.length, equals(initialSections.length));
      expect(postStaff.length, equals(initialStaff.length));
    });

    testWidgets('ExportScreen shows Print and Share buttons in PDF view', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = LocalDatabaseRepository();
      await repo.createCollege(college);
      await repo.createSection(section1);
      await repo.createStaff(teacher1);
      await repo.createStaff(teacher2);
      await repo.createRoom(room1);
      await repo.createRoom(labRoom1);
      await repo.createRoom(labRoom2);
      await repo.createSubject(subjectTheory);
      await repo.createSubject(subjectLab1);
      await repo.createSubject(subjectLab2);
      await repo.saveTimeSlots(collegeId, timeSlots);
      await repo.createTimetableVersion(version);
      await repo.saveTimetableEntries(collegeId, version.id, entries);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCollegeIdProvider.overrideWith((ref) => collegeId),
            databaseRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: ExportScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to PDF Document tab
      final pdfSegmentFinder = find.text('PDF Document');
      expect(pdfSegmentFinder, findsOneWidget);
      await tester.tap(pdfSegmentFinder);
      await tester.pumpAndSettle();

      // Verify "Print / Save PDF" and "Share PDF" are present on screen
      expect(find.text('Print / Save PDF'), findsWidgets);
      expect(find.text('Share PDF'), findsWidgets);
    });

    testWidgets('ExportScreen supports switching between Section, Faculty, Course, Room / Lab, and Master', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = LocalDatabaseRepository();
      await repo.createCollege(college);
      await repo.createSection(section1);
      await repo.createStaff(teacher1);
      await repo.createStaff(teacher2);
      await repo.createRoom(room1);
      await repo.createRoom(labRoom1);
      await repo.createRoom(labRoom2);
      await repo.createSubject(subjectTheory);
      await repo.createSubject(subjectLab1);
      await repo.createSubject(subjectLab2);
      await repo.saveTimeSlots(collegeId, timeSlots);
      await repo.createTimetableVersion(version);
      await repo.saveTimetableEntries(collegeId, version.id, entries);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeCollegeIdProvider.overrideWith((ref) => collegeId),
            databaseRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: ExportScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all 5 view chips are present
      expect(find.widgetWithText(ChoiceChip, 'Section'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Faculty'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Course'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Room / Lab'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Master'), findsOneWidget);

      // Tap Faculty chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Faculty'));
      await tester.pumpAndSettle();
      expect(find.text('Select Faculty'), findsOneWidget);

      // Tap Course chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Course'));
      await tester.pumpAndSettle();
      expect(find.text('Select Course / Subject'), findsOneWidget);

      // Tap Room / Lab chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Room / Lab'));
      await tester.pumpAndSettle();
      expect(find.text('Select Room / Lab'), findsOneWidget);

      // Tap Master chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Master'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Consolidated master timetable schedule'), findsOneWidget);
    });
  });
}
