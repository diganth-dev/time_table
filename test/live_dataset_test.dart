// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/features/timetable/timetable_utils.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/services.dart';

void main() {
  test('Debug live dataset generation and conflicts', () {
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

    print('Sections: ${sections.length}');
    for (final s in sections) {
      print('  Section ${s.id} (${s.sectionName}) batches: ${s.batches}');
    }

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

    print('\nGeneration result:');
    print('isSuccess: ${result.isSuccess}');
    print('totalClassesScheduled: ${result.totalClassesScheduled}');
    print('entries scheduled: ${result.entries.length}');
    print('conflicts count: ${result.conflicts.length}');
    print('summary: ${result.summaryMessage}');
    expect(result.isSuccess, true);
    expect(result.conflicts.isEmpty, true);
    expect(result.entries.length, greaterThanOrEqualTo(90));

    // Verify parallel batch labs run with distinct subjects in separate rooms and professors
    for (final sec in sections) {
      final secLabEntries = result.entries.where((e) => e.sectionId == sec.id && e.batch != null).toList();
      final periodGroups = <String, List<TimetableEntry>>{};
      for (final e in secLabEntries) {
        final key = '${e.dayOfWeek}_${e.periodNumber}';
        periodGroups.putIfAbsent(key, () => []).add(e);
      }
      for (final slot in periodGroups.values) {
        if (slot.length > 1) {
          final subjectsInSlot = slot.map((e) => e.subjectId).toSet();
          final roomsInSlot = slot.map((e) => e.roomId).toSet();
          final teachersInSlot = slot.map((e) => e.teacherId).toSet();
          expect(subjectsInSlot.length, equals(slot.length),
              reason: 'Different lab subjects across batches in parallel for section ${sec.sectionName}');
          expect(roomsInSlot.length, equals(slot.length),
              reason: 'Separate physical compatible rooms for section ${sec.sectionName}');
          expect(teachersInSlot.length, equals(slot.length),
              reason: 'Separate professors for section ${sec.sectionName}');
        }
      }
    }

    print('Subject section mappings:');
    for (final s in subjects) {
      print('Subject ${s.name} (${s.id}) sectionId: "${s.sectionId}" dept: "${s.departmentId}" sem: ${s.semester} teachers: ${s.assignedTeacherIds}');
    }

    print('\n=== PROFESSOR WORKLOAD SUMMARY ===');
    for (final st in staffList) {
      final assignedSubjects = subjects.where((s) => s.assignedTeacherIds.contains(st.id)).toList();
      final teacherEntries = result.entries.where((e) => e.teacherId == st.id).toList();
      print('Professor: ${st.name} (${st.id})');
      for (final s in assignedSubjects) {
        final sEntries = teacherEntries.where((e) => e.subjectId == s.id).toList();
        final sBatches = sEntries.map((e) => e.batch).toSet();
        print('    - ${s.name} (${s.isLab ? "Lab" : "Theory"}, hoursPerWeek=${s.hoursPerWeek}): scheduled=${sEntries.length} entries, batches=$sBatches');
      }

      final secMap = {for (var s in sections) s.id: s};
      final subjMap = {for (var s in subjects) s.id: s};
      final summary = calculateProfessorWorkload(
        teacher: st,
        allSubjects: subjects,
        sectionMap: secMap,
        entries: result.entries,
        subjectMap: subjMap,
      );

      print('  Required: ${summary.requiredWorkload} hrs, Scheduled: ${summary.scheduledTotal} hrs (Theory: ${summary.scheduledTheory}, Lab: ${summary.scheduledLab}), Remaining: ${summary.remaining} hrs');
      expect(summary.requiredWorkload, teacherEntries.length, reason: 'Mismatch for ${st.name}');
      expect(summary.scheduledTotal, teacherEntries.length);
      expect(summary.remaining, 0);
    }
  });
}

