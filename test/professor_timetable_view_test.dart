// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/features/timetable/screens/export_screen.dart';
import 'package:time_table/features/timetable/timetable_utils.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/providers/providers.dart';
import 'package:time_table/services/services.dart';

void main() {
  late List<TimeSlot> timeSlots;
  late List<Section> sections;
  late List<Subject> subjects;
  late List<Staff> staffList;
  late List<Room> rooms;
  late List<String> workingDays;
  late GenerationResult generationResult;
  late College college;

  setUpAll(() {
    final dumpFile = File(
      'C:/Users/deeek/.gemini/antigravity-cli/brain/62a4306d-b687-485e-9541-9355f72736b9/scratch/live_dump_now.json',
    );
    final jsonMap = jsonDecode(dumpFile.readAsStringSync()) as Map<String, dynamic>;

    timeSlots = (jsonMap['timeSlots'] as List)
        .map((t) => TimeSlot.fromJson(t as Map<String, dynamic>, id: t['id']))
        .toList();
    sections = (jsonMap['sections'] as List)
        .map((s) => Section.fromJson(s as Map<String, dynamic>, id: s['id']))
        .toList();
    subjects = (jsonMap['subjects'] as List)
        .map((s) => Subject.fromJson(s as Map<String, dynamic>, id: s['id']))
        .toList();
    staffList = (jsonMap['staff'] as List)
        .map((st) => Staff.fromJson(st as Map<String, dynamic>, id: st['id']))
        .toList();
    rooms = (jsonMap['rooms'] as List)
        .map((r) => Room.fromJson(r as Map<String, dynamic>, id: r['id']))
        .toList();
    final collegesRaw = jsonMap['colleges'] as List;
    workingDays = (collegesRaw.first['workingDays'] as List).cast<String>();

    college = College.fromJson(
      collegesRaw.first as Map<String, dynamic>,
      id: 'user_college',
    );

    generationResult = TimetableGenerator.generate(
      collegeId: 'user_college',
      sections: sections,
      subjects: subjects,
      staffList: staffList,
      rooms: rooms,
      timeSlots: timeSlots,
      availabilities: [],
      workingDays: workingDays,
    );
    expect(generationResult.isSuccess, true);
  });

  group('Professor Workload Calculation Unit Tests', () {
    test('Verifies workload metrics for Murlidhara B K, Shrinidhi N, and Amresh kumar', () {
      final secMap = {for (var s in sections) s.id: s};
      final subjMap = {for (var s in subjects) s.id: s};

      // 1. Murlidhara B K
      final murli = staffList.firstWhere((s) => s.id == 'staff_b267100e');
      final murliSummary = calculateProfessorWorkload(
        teacher: murli,
        allSubjects: subjects,
        sectionMap: secMap,
        entries: generationResult.entries,
        subjectMap: subjMap,
      );
      expect(murliSummary.requiredWorkload, 14);
      expect(murliSummary.scheduledTotal, 14);
      expect(murliSummary.scheduledTheory, 6);
      expect(murliSummary.scheduledLab, 8);
      expect(murliSummary.remaining, 0);
      expect(murliSummary.isOverload, false);

      // 2. Shrinidhi N
      final shrinidhi = staffList.firstWhere((s) => s.id == 'staff_8db74e0e');
      final shrinidhiSummary = calculateProfessorWorkload(
        teacher: shrinidhi,
        allSubjects: subjects,
        sectionMap: secMap,
        entries: generationResult.entries,
        subjectMap: subjMap,
      );
      expect(shrinidhiSummary.requiredWorkload, 17);
      expect(shrinidhiSummary.scheduledTotal, 17);
      expect(shrinidhiSummary.scheduledTheory, 1);
      expect(shrinidhiSummary.scheduledLab, 16);
      expect(shrinidhiSummary.remaining, 0);

      // 3. Amresh kumar
      final amresh = staffList.firstWhere((s) => s.id == 'staff_3fcb5ccb');
      final amreshSummary = calculateProfessorWorkload(
        teacher: amresh,
        allSubjects: subjects,
        sectionMap: secMap,
        entries: generationResult.entries,
        subjectMap: subjMap,
      );
      expect(amreshSummary.requiredWorkload, 15);
      expect(amreshSummary.scheduledTotal, 15);
      expect(amreshSummary.scheduledTheory, 11);
      expect(amreshSummary.scheduledLab, 4);
      expect(amreshSummary.remaining, 0);
    });

    test('Verifies remaining workload calculation when scheduled < required', () {
      final secMap = {for (var s in sections) s.id: s};
      final subjMap = {for (var s in subjects) s.id: s};
      final murli = staffList.firstWhere((s) => s.id == 'staff_b267100e');

      // Filter out 2 entries to simulate partial schedule (12 scheduled instead of 14)
      final partialEntries = generationResult.entries
          .where((e) => e.teacherId == murli.id)
          .skip(2)
          .toList();

      final partialSummary = calculateProfessorWorkload(
        teacher: murli,
        allSubjects: subjects,
        sectionMap: secMap,
        entries: partialEntries,
        subjectMap: subjMap,
      );
      expect(partialSummary.requiredWorkload, 14);
      expect(partialSummary.scheduledTotal, 12);
      expect(partialSummary.remaining, 2);
    });

    test('Prints formatted weekly grid for Murlidhara B K, Shrinidhi N, and Amresh kumar', () {
      final secMap = {for (var s in sections) s.id: s};
      final subjMap = {for (var s in subjects) s.id: s};
      final roomMap = {for (var r in rooms) r.id: r};

      final targetProfIds = ['staff_b267100e', 'staff_8db74e0e', 'staff_3fcb5ccb'];
      for (final profId in targetProfIds) {
        final prof = staffList.firstWhere((s) => s.id == profId);
        final summary = calculateProfessorWorkload(
          teacher: prof,
          allSubjects: subjects,
          sectionMap: secMap,
          entries: generationResult.entries,
          subjectMap: subjMap,
        );

        print('\n===============================================================');
        print('Professor: ${prof.name}');
        print('Required Workload: ${summary.requiredWorkload} hrs');
        print('Scheduled Workload: ${summary.scheduledTotal} hrs (Theory: ${summary.scheduledTheory} hrs, Lab: ${summary.scheduledLab} hrs)');
        print('Remaining Workload: ${summary.remaining} hrs');
        print('---------------------------------------------------------------');

        final profEntries = generationResult.entries.where((e) => e.teacherId == profId).toList();
        for (final day in workingDays) {
          final dayEntries = profEntries.where((e) => e.dayOfWeek == day).toList()
            ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
          final line = StringBuffer('$day: ');
          if (dayEntries.isEmpty) {
            line.write('No scheduled classes');
          } else {
            line.write(dayEntries.map((e) {
              final sub = subjMap[e.subjectId];
              final sec = secMap[e.sectionId];
              final r = roomMap[e.roomId];
              final bStr = e.batch != null ? ' (${e.batch})' : '';
              return 'P${e.periodNumber}: ${sub?.shortName ?? ""}$bStr in ${sec?.sectionName ?? ""} [${r?.roomNumber ?? ""}]';
            }).join(' | '));
          }
          print('  $line');
        }
      }
    });
  });


  group('Professor Timetable Export Screen Widget Tests', () {
    testWidgets('Renders complete weekly workload timetable for Professor Murlidhara B K',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final version = TimetableVersion(
        id: 'ver_test_01',
        collegeId: 'user_college',
        versionNumber: 11,
        name: 'Version 11 (Verified)',
        status: 'published',
        academicYear: '2026-2027',
        semester: 'Odd 2026',
        isCurrentPublished: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentCollegeProvider.overrideWith((ref) => Future.value(college)),
            sectionListProvider.overrideWith((ref) => Future.value(sections)),
            staffListProvider.overrideWith((ref) => Future.value(staffList)),
            roomListProvider.overrideWith((ref) => Future.value(rooms)),
            subjectListProvider.overrideWith((ref) => Future.value(subjects)),
            timeSlotsProvider.overrideWith((ref) => Future.value(timeSlots)),
            timetableVersionsProvider.overrideWith((ref) => Future.value([version])),
            selectedVersionIdProvider.overrideWith((ref) => 'ver_test_01'),
            timetableEntriesProvider.overrideWith((ref) => Future.value(generationResult.entries)),
            selectedTeacherFilterProvider.overrideWith((ref) => 'staff_b267100e'),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ExportScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Switch to "By Professor" view
      final byProfessorChip = find.text('By Professor');
      expect(byProfessorChip, findsOneWidget);
      await tester.tap(byProfessorChip);
      await tester.pumpAndSettle();

      // 2. Verify Professor Header
      expect(find.text('Professor: Murlidhara B K'), findsOneWidget);
      expect(find.text('Required Workload'), findsOneWidget);
      expect(find.text('14 hrs'), findsAtLeastNWidgets(1));
      expect(find.text('Scheduled Workload'), findsOneWidget);
      expect(find.text('Remaining Workload'), findsOneWidget);
      expect(find.text('WORKLOAD COMPLETE'), findsOneWidget);

      // 3. Verify Breakdown strip (rendered via RichText)
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Theory: 6 hrs'),
        ),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Lab: 8 hrs'),
        ),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Total Scheduled: 14 hrs'),
        ),
        findsOneWidget,
      );

      // 4. Verify Weekday rows and Break columns
      for (final day in workingDays) {
        expect(find.text(day), findsAtLeastNWidgets(1));
      }
      expect(find.text('Period 1'), findsOneWidget);
      expect(find.text('Period 2'), findsOneWidget);
      expect(find.text('Morning Break'), findsAtLeastNWidgets(1));
      expect(find.text('Period 3'), findsOneWidget);
      expect(find.text('Period 4'), findsOneWidget);
      expect(find.text('Lunch Break'), findsAtLeastNWidgets(1));
      expect(find.text('Period 5'), findsOneWidget);
      expect(find.text('Period 6'), findsOneWidget);

      // 5. Verify Cell Content format (DSA LAB, section, batch, room)
      expect(find.text('DSA LAB'), findsAtLeastNWidgets(1));
      expect(find.text('DSA'), findsAtLeastNWidgets(1));
      expect(find.text('B1'), findsAtLeastNWidgets(1));
      expect(find.text('B2'), findsAtLeastNWidgets(1));

      // 6. Verify Empty cells are shown
      expect(find.text('—'), findsAtLeastNWidgets(1));

      // 7. Verify Teaching Course Allocations Table below matrix
      expect(find.text('Teaching Course Allocations • Murlidhara B K'), findsOneWidget);
      expect(find.text('Faculty Signature'), findsOneWidget);
    });

    testWidgets('Switching to Professor Shrinidhi N updates header and grid immediately',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final version = TimetableVersion(
        id: 'ver_test_01',
        collegeId: 'user_college',
        versionNumber: 11,
        name: 'Version 11 (Verified)',
        status: 'published',
        academicYear: '2026-2027',
        semester: 'Odd 2026',
        isCurrentPublished: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentCollegeProvider.overrideWith((ref) => Future.value(college)),
            sectionListProvider.overrideWith((ref) => Future.value(sections)),
            staffListProvider.overrideWith((ref) => Future.value(staffList)),
            roomListProvider.overrideWith((ref) => Future.value(rooms)),
            subjectListProvider.overrideWith((ref) => Future.value(subjects)),
            timeSlotsProvider.overrideWith((ref) => Future.value(timeSlots)),
            timetableVersionsProvider.overrideWith((ref) => Future.value([version])),
            selectedVersionIdProvider.overrideWith((ref) => 'ver_test_01'),
            timetableEntriesProvider.overrideWith((ref) => Future.value(generationResult.entries)),
            selectedTeacherFilterProvider.overrideWith((ref) => 'staff_8db74e0e'),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ExportScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('By Professor'));
      await tester.pumpAndSettle();

      // Shrinidhi N metrics: Required: 17 hrs, Theory: 1 hr, Lab: 16 hrs
      expect(find.text('Professor: Shrinidhi N'), findsOneWidget);
      expect(find.text('17 hrs'), findsAtLeastNWidgets(1));
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Theory: 1 hrs'),
        ),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Lab: 16 hrs'),
        ),
        findsAtLeastNWidgets(1),
      );
      expect(find.text('Teaching Course Allocations • Shrinidhi N'), findsOneWidget);
    });
  });
}
