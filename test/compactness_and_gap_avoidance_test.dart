// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/services.dart';

void main() {
  test('Analyze compactness and gaps in current timetable generator', () {
    final dumpFile = File('C:/Users/deeek/.gemini/antigravity-cli/brain/62a4306d-b687-485e-9541-9355f72736b9/scratch/live_dump_now.json');
    final jsonMap = jsonDecode(dumpFile.readAsStringSync()) as Map<String, dynamic>;

    final timeSlotsRaw = jsonMap['timeSlots'] as List;
    final timeSlots = timeSlotsRaw.map((t) => TimeSlot.fromJson(t as Map<String, dynamic>, id: t['id'])).toList();

    final sectionsRaw = jsonMap['sections'] as List;
    final sections = sectionsRaw.map((s) => Section.fromJson(s as Map<String, dynamic>, id: s['id'])).toList();

    final subjectsRaw = jsonMap['subjects'] as List;
    final subjects = subjectsRaw.map((s) => Subject.fromJson(s as Map<String, dynamic>, id: s['id'])).toList();

    final staffRaw = jsonMap['staff'] as List;
    final staffList = staffRaw.map((st) => Staff.fromJson(st as Map<String, dynamic>, id: st['id'])).toList();

    final roomsRaw = jsonMap['rooms'] as List;
    final rooms = roomsRaw.map((r) => Room.fromJson(r as Map<String, dynamic>, id: r['id'])).toList();

    final collegesRaw = jsonMap['colleges'] as List;
    final workingDays = (collegesRaw.first['workingDays'] as List).cast<String>();

    final result = TimetableGenerator.generate(
      collegeId: 'user_college',
      sections: sections,
      subjects: subjects,
      staffList: staffList,
      rooms: rooms,
      timeSlots: timeSlots,
      availabilities: [],
      workingDays: workingDays,
    );

    expect(result.isSuccess, true);
    expect(result.conflicts.isEmpty, true);

    int totalGaps = 0;
    print('\n================ SECTION DAILY SCHEDULE GAP ANALYSIS ================');
    for (final sec in sections) {
      print('\n--- Section: ${sec.displayName} ---');
      for (final day in workingDays) {
        final dayEntries = result.entries.where((e) => e.sectionId == sec.id && e.dayOfWeek == day).toList();
        if (dayEntries.isEmpty) continue;

        final periods = dayEntries.map((e) => e.periodNumber).toSet().toList()..sort();
        final minP = periods.first;
        final maxP = periods.last;
        final internalGaps = (maxP - minP + 1) - periods.length;
        if (internalGaps > 0) {
          totalGaps += internalGaps;
          final missing = <int>[];
          for (var p = minP; p <= maxP; p++) {
            if (!periods.contains(p)) missing.add(p);
          }
          print('  $day: Periods $periods -> GAP at $missing (Span: P$minP-P$maxP)');
        } else {
          print('  $day: Periods $periods -> COMPACT (Span: P$minP-P$maxP)');
        }
      }
    }
    print('\nTOTAL INTERNAL GAPS: $totalGaps');
    expect(totalGaps, 0);

    final subMap = {for (final s in subjects) s.id: s};
    print('\n================ VERIFY LABS ARE CONSECUTIVE ================');
    for (final sec in sections) {
      print('\n--- Section: ${sec.displayName} ---');
      final labEntries = result.entries.where((e) => e.sectionId == sec.id && subMap[e.subjectId]?.isLab == true).toList()
        ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek) != 0
            ? a.dayOfWeek.compareTo(b.dayOfWeek)
            : a.periodNumber.compareTo(b.periodNumber));

      final byDayBatch = <String, List<int>>{};
      for (final e in labEntries) {
        final key = '${e.dayOfWeek}_${e.subjectId}_${e.batch}';
        byDayBatch.putIfAbsent(key, () => []).add(e.periodNumber);
        final sub = subMap[e.subjectId]?.subjectName ?? e.subjectId;
        print('  ${e.dayOfWeek.padRight(10)} P${e.periodNumber} | Batch ${e.batch} | $sub');
      }

      for (final entry in byDayBatch.entries) {
        final pList = entry.value..sort();
        expect(pList.length, 2, reason: '${entry.key} must have exactly 2 periods');
        expect(pList[1], pList[0] + 1, reason: '${entry.key} must be consecutive');
      }
    }
  });
}
