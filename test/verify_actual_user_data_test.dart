// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/services/services.dart';

void main() {
  test('TASK 10: Verify Generator with Actual Current User Data from Firestore', () {
    final dumpFile = File('C:/Users/deeek/.gemini/antigravity-cli/brain/4f176d6f-4e29-4fcf-a421-4637fd04c336/scratch/firestore_dump.json');
    expect(dumpFile.existsSync(), isTrue, reason: 'Firestore dump file must exist.');

    final jsonMap = jsonDecode(dumpFile.readAsStringSync()) as Map<String, dynamic>;

    // 1. TimeSlots
    final timeSlotsRaw = jsonMap['timeSlots'] as List;
    final timeSlots = timeSlotsRaw.map((t) => TimeSlot.fromJson(t as Map<String, dynamic>, id: t['id'])).toList();

    // 2. Sections
    final sectionsRaw = jsonMap['sections'] as List;
    final sections = sectionsRaw.map((s) => Section.fromJson(s as Map<String, dynamic>, id: s['id'])).toList();

    // 3. Subjects
    final subjectsRaw = jsonMap['subjects'] as List;
    final subjects = subjectsRaw.map((s) => Subject.fromJson(s as Map<String, dynamic>, id: s['id'])).toList();

    // 4. Staff
    final staffRaw = jsonMap['staff'] as List;
    final staffList = staffRaw.map((st) => Staff.fromJson(st as Map<String, dynamic>, id: st['id'])).toList();

    // 5. Rooms
    final roomsRaw = jsonMap['rooms'] as List;
    final rooms = roomsRaw.map((r) => Room.fromJson(r as Map<String, dynamic>, id: r['id'])).toList();

    final workingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    // Run Generator
    final result = TimetableGenerator.generate(
      collegeId: 'user_college',
      sections: sections,
      subjects: subjects,
      staffList: staffList,
      rooms: rooms,
      timeSlots: timeSlots,
      availabilities: [],
      workingDays: workingDays,
      targetSectionId: 'sec_36a81535',
    );

    // 1. Generation Success & Zero Hard Conflicts
    expect(result.isSuccess, isTrue, reason: 'Timetable must generate successfully.');
    final hardConflicts = result.conflicts.where((c) => c.isHard).toList();
    expect(hardConflicts, isEmpty, reason: 'Must have 0 hard conflicts. Found: ${hardConflicts.map((c) => c.description)}');

    // 2. Total classes scheduled = 24
    expect(result.totalClassesScheduled, equals(24), reason: 'All 24 weekly subject hours must be scheduled.');

    // 3. TOC Sessions: exactly 5 sessions scheduled
    final tocEntries = result.entries.where((e) => e.subjectId == 'sub_f042dd28').toList();
    expect(tocEntries.length, equals(5), reason: 'All 5 TOC sessions must be scheduled.');

    // 4. No professor scheduled in two places at the same time
    final profSlotMap = <String, TimetableEntry>{};
    for (final e in result.entries) {
      final key = '${e.dayOfWeek}_${e.periodNumber}_${e.teacherId}';
      expect(profSlotMap.containsKey(key), isFalse, reason: 'Professor scheduled twice at $key');
      profSlotMap[key] = e;
    }

    // 5. No room scheduled for two classes at the same time
    final roomSlotMap = <String, TimetableEntry>{};
    for (final e in result.entries) {
      final key = '${e.dayOfWeek}_${e.periodNumber}_${e.roomId}';
      expect(roomSlotMap.containsKey(key), isFalse, reason: 'Room scheduled twice at $key');
      roomSlotMap[key] = e;
    }

    // 6. No section has two classes at the same time
    final secSlotMap = <String, TimetableEntry>{};
    for (final e in result.entries) {
      final key = '${e.dayOfWeek}_${e.periodNumber}_${e.sectionId}';
      expect(secSlotMap.containsKey(key), isFalse, reason: 'Section scheduled twice at $key');
      secSlotMap[key] = e;
    }

    // 7. Professor availability is respected
    final staffMap = {for (var s in staffList) s.id: s};
    for (final e in result.entries) {
      final teacher = staffMap[e.teacherId]!;
      final slot = timeSlots.firstWhere((s) => s.periodNumber == e.periodNumber);
      expect(teacher.isUnavailableDuring(day: e.dayOfWeek, slot: slot), isFalse,
          reason: '${teacher.name} scheduled during unavailable time on ${e.dayOfWeek} ${slot.timeRange}');
    }

    // 8. Room capacity is respected
    final roomMap = {for (var r in rooms) r.id: r};
    for (final e in result.entries) {
      final room = roomMap[e.roomId]!;
      expect(room.capacity >= 57, isTrue, reason: 'Room ${room.roomNumber} capacity (${room.capacity}) < 57');
    }

    // 9. Daily teaching limits are respected
    final teacherDayCounts = <String, int>{};
    for (final e in result.entries) {
      final key = '${e.dayOfWeek}_${e.teacherId}';
      teacherDayCounts[key] = (teacherDayCounts[key] ?? 0) + 1;
    }
    for (final entry in teacherDayCounts.entries) {
      final tid = entry.key.substring(entry.key.indexOf('_') + 1);
      final teacher = staffMap[tid]!;
      expect(entry.value <= teacher.maxClassesPerDay, isTrue,
          reason: '${teacher.name} daily limit exceeded: ${entry.value} > ${teacher.maxClassesPerDay}');
    }

    // 10. Breaks are respected
    for (final e in result.entries) {
      final slot = timeSlots.firstWhere((s) => s.periodNumber == e.periodNumber);
      expect(slot.isBreak, isFalse, reason: 'Class scheduled during break slot ${slot.label}');
    }

    // 11. Run ConflictValidator on the generated entries
    final validation = ConflictValidator.validateSchedule(
      collegeId: 'user_college',
      entries: result.entries,
      sections: sections,
      subjects: subjects,
      staffList: staffList,
      rooms: rooms,
      timeSlots: timeSlots,
      availabilities: [],
    );
    expect(validation.hardConflicts, isEmpty, reason: 'ConflictValidator found hard conflicts: ${validation.hardConflicts.map((c) => c.description)}');

    // Print generated schedule grid
    print('\n================ GENERATED TIMETABLE GRID FOR CSE(AIML) ================');
    final subjMap = {for (var s in subjects) s.id: s};
    for (final day in workingDays) {
      final dayEntries = result.entries.where((e) => e.dayOfWeek == day).toList()
        ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
      final row = dayEntries.map((e) => 'P${e.periodNumber}: ${subjMap[e.subjectId]?.subjectName} (${staffMap[e.teacherId]?.name})').join(' | ');
      print('${day.padRight(10)} | $row');
    }
    print('=========================================================================\n');
  });
}
