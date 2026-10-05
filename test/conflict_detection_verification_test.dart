// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_table/models/models.dart';
import 'package:time_table/providers/auth_provider.dart';
import 'package:time_table/providers/conflict_provider.dart';
import 'package:time_table/providers/repository_provider.dart';
import 'package:time_table/providers/timetable_provider.dart';
import 'package:time_table/repositories/local_repository.dart';
import 'package:time_table/services/services.dart';

void main() {
  group('Conflict Detection & Verification Logic Tests', () {
    late Map<String, dynamic> liveDump;
    late List<Section> sections;
    late List<Subject> subjects;
    late List<Staff> staffList;
    late List<Room> rooms;
    late List<TimeSlot> timeSlots;
    late List<TimetableEntry> allEntries;
    late List<TimetableEntry> v3Entries;

    setUpAll(() {
      final dumpFile = File('C:/Users/deeek/.gemini/antigravity-cli/brain/9dd778b6-d43b-4ed3-8a88-7463be929799/scratch/live_firestore_dump.json');
      expect(dumpFile.existsSync(), isTrue, reason: 'Live Firestore dump must exist.');

      liveDump = jsonDecode(dumpFile.readAsStringSync()) as Map<String, dynamic>;

      sections = (liveDump['sections'] as List)
          .map((s) => Section.fromJson(s as Map<String, dynamic>, id: s['id']))
          .toList();

      subjects = (liveDump['subjects'] as List)
          .map((s) => Subject.fromJson(s as Map<String, dynamic>, id: s['id']))
          .toList();

      staffList = (liveDump['staff'] as List)
          .map((st) => Staff.fromJson(st as Map<String, dynamic>, id: st['id']))
          .toList();

      rooms = (liveDump['rooms'] as List)
          .map((r) => Room.fromJson(r as Map<String, dynamic>, id: r['id']))
          .toList();

      timeSlots = (liveDump['timeSlots'] as List)
          .map((t) => TimeSlot.fromJson(t as Map<String, dynamic>, id: t['id']))
          .toList();

      allEntries = (liveDump['timetableEntries'] as List)
          .map((e) => TimetableEntry.fromJson(e as Map<String, dynamic>, id: e['id']))
          .toList();

      v3Entries = allEntries.where((e) => e.versionId == 'ver_1790283772093').toList();
    });

    test('1. Current Active Timetable Data (Version 3) has EXACTLY 0 conflicts', () {
      expect(v3Entries.length, equals(74), reason: 'Version 3 must contain all 74 generated entries.');

      final validation = ConflictValidator.validateSchedule(
        collegeId: 'user_college',
        entries: v3Entries,
        sections: sections,
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
      );
      // Checklist criteria
      final profConflicts = validation.hardConflicts.where((c) => c.type == 'teacherConflict').length;
      final secConflicts = validation.hardConflicts.where((c) => c.type == 'sectionConflict').length;
      final roomConflicts = validation.hardConflicts.where((c) => c.type == 'roomConflict').length;

      expect(profConflicts, equals(0), reason: 'Professor Conflicts must be 0.');
      expect(secConflicts, equals(0), reason: 'Section Conflicts must be 0.');
      expect(roomConflicts, equals(0), reason: 'Room Conflicts must be 0.');
      expect(validation.hardConflicts, isEmpty, reason: 'Total hard conflicts must be 0.');
      expect(validation.isValid, isTrue, reason: 'Schedule must be completely valid.');
    });

    test('2. Isolated Professor Conflict: Only increments Professor Conflicts', () {
      // Create scenario: Professor A assigned to Section 1 and Section 2 at same slot, different rooms
      final sec1 = sections.first.id;
      final sec2 = sections.length > 1 ? sections[1].id : 'sec_other';
      final prof = staffList.first.id;
      final room1 = rooms.first.id;
      final room2 = rooms.length > 1 ? rooms[1].id : 'room_other';

      final conflictingEntries = [
        TimetableEntry(
          id: 'test_entry_1',
          collegeId: 'user_college',
          versionId: 'ver_test',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          timeSlotId: 'ts_1',
          sectionId: sec1,
          subjectId: subjects.first.id,
          teacherId: prof,
          roomId: room1,
        ),
        TimetableEntry(
          id: 'test_entry_2',
          collegeId: 'user_college',
          versionId: 'ver_test',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          timeSlotId: 'ts_1',
          sectionId: sec2,
          subjectId: subjects.length > 1 ? subjects[1].id : subjects.first.id,
          teacherId: prof,
          roomId: room2,
        ),
      ];

      final val = ConflictValidator.validateSchedule(
        collegeId: 'user_college',
        entries: conflictingEntries,
        sections: sections,
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
      );

      final profCount = val.hardConflicts.where((c) => c.type == 'teacherConflict').length;
      final secCount = val.hardConflicts.where((c) => c.type == 'sectionConflict').length;
      final roomCount = val.hardConflicts.where((c) => c.type == 'roomConflict').length;

      expect(profCount, equals(1), reason: 'Must detect exactly 1 professor conflict');
      expect(secCount, equals(0), reason: 'Section conflict must be 0 since sections are different');
      expect(roomCount, equals(0), reason: 'Room conflict must be 0 since rooms are different');
      expect(val.hardConflicts.first.id, contains('prof_$prof'));
      expect(val.hardConflicts.first.id, contains('test_entry_1'));
      expect(val.hardConflicts.first.id, contains('test_entry_2'));
    });

    test('3. Isolated Section Conflict: Only increments Section Conflicts', () {
      // Create scenario: Section 1 has Subject 1 (Prof 1) and Subject 2 (Prof 2) in different rooms at same slot
      final sec = sections.first.id;
      final prof1 = staffList.first.id;
      final prof2 = staffList.length > 1 ? staffList[1].id : 'prof_other';
      final room1 = rooms.first.id;
      final room2 = rooms.length > 1 ? rooms[1].id : 'room_other';

      final conflictingEntries = [
        TimetableEntry(
          id: 'test_sec_1',
          collegeId: 'user_college',
          versionId: 'ver_test',
          dayOfWeek: 'Tuesday',
          periodNumber: 2,
          timeSlotId: 'ts_2',
          sectionId: sec,
          subjectId: subjects.first.id,
          teacherId: prof1,
          roomId: room1,
        ),
        TimetableEntry(
          id: 'test_sec_2',
          collegeId: 'user_college',
          versionId: 'ver_test',
          dayOfWeek: 'Tuesday',
          periodNumber: 2,
          timeSlotId: 'ts_2',
          sectionId: sec,
          subjectId: subjects.length > 1 ? subjects[1].id : subjects.first.id,
          teacherId: prof2,
          roomId: room2,
        ),
      ];

      final val = ConflictValidator.validateSchedule(
        collegeId: 'user_college',
        entries: conflictingEntries,
        sections: sections,
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
      );

      final profCount = val.hardConflicts.where((c) => c.type == 'teacherConflict').length;
      final secCount = val.hardConflicts.where((c) => c.type == 'sectionConflict').length;
      final roomCount = val.hardConflicts.where((c) => c.type == 'roomConflict').length;

      expect(secCount, equals(1), reason: 'Must detect exactly 1 section conflict');
      expect(profCount, equals(0), reason: 'Prof conflict must be 0 since teachers are different');
      expect(roomCount, equals(0), reason: 'Room conflict must be 0 since rooms are different');
      expect(val.hardConflicts.first.id, contains('sec_$sec'));
    });

    test('4. Isolated Room Conflict: Only increments Room Conflicts', () {
      // Create scenario: Room 101 has Section 1 (Prof 1) and Section 2 (Prof 2) at same slot
      final sec1 = sections.first.id;
      final sec2 = sections.length > 1 ? sections[1].id : 'sec_other';
      final prof1 = staffList.first.id;
      final prof2 = staffList.length > 1 ? staffList[1].id : 'prof_other';
      final room = rooms.first.id;

      final conflictingEntries = [
        TimetableEntry(
          id: 'test_rm_1',
          collegeId: 'user_college',
          versionId: 'ver_test',
          dayOfWeek: 'Wednesday',
          periodNumber: 3,
          timeSlotId: 'ts_3',
          sectionId: sec1,
          subjectId: subjects.first.id,
          teacherId: prof1,
          roomId: room,
        ),
        TimetableEntry(
          id: 'test_rm_2',
          collegeId: 'user_college',
          versionId: 'ver_test',
          dayOfWeek: 'Wednesday',
          periodNumber: 3,
          timeSlotId: 'ts_3',
          sectionId: sec2,
          subjectId: subjects.length > 1 ? subjects[1].id : subjects.first.id,
          teacherId: prof2,
          roomId: room,
        ),
      ];

      final val = ConflictValidator.validateSchedule(
        collegeId: 'user_college',
        entries: conflictingEntries,
        sections: sections,
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
      );

      final profCount = val.hardConflicts.where((c) => c.type == 'teacherConflict').length;
      final secCount = val.hardConflicts.where((c) => c.type == 'sectionConflict').length;
      final roomCount = val.hardConflicts.where((c) => c.type == 'roomConflict').length;

      expect(roomCount, equals(1), reason: 'Must detect exactly 1 room conflict');
      expect(profCount, equals(0), reason: 'Prof conflict must be 0 since teachers are different');
      expect(secCount, equals(0), reason: 'Section conflict must be 0 since sections are different');
      expect(val.hardConflicts.first.id, contains('room_$room'));
    });

    test('5. Multi-session collision (3 sections for same teacher) produces ONE unique conflict', () {
      final prof = staffList.first.id;
      final threeEntries = <TimetableEntry>[
        TimetableEntry(
          id: 'entry_c',
          collegeId: 'user_college',
          versionId: 'ver_test',
          dayOfWeek: 'Thursday',
          periodNumber: 4,
          timeSlotId: 'ts_4',
          sectionId: 'sec_3',
          subjectId: subjects.first.id,
          teacherId: prof,
          roomId: 'rm_3',
        ),
        TimetableEntry(
          id: 'entry_a',
          collegeId: 'user_college',
          versionId: 'ver_test',
          dayOfWeek: 'Thursday',
          periodNumber: 4,
          timeSlotId: 'ts_4',
          sectionId: 'sec_1',
          subjectId: subjects.first.id,
          teacherId: prof,
          roomId: 'rm_1',
        ),
        TimetableEntry(
          id: 'entry_b',
          collegeId: 'user_college',
          versionId: 'ver_test',
          dayOfWeek: 'Thursday',
          periodNumber: 4,
          timeSlotId: 'ts_4',
          sectionId: 'sec_2',
          subjectId: subjects.first.id,
          teacherId: prof,
          roomId: 'rm_2',
        ),
      ];

      final val = ConflictValidator.validateSchedule(
        collegeId: 'user_college',
        entries: threeEntries,
        sections: sections,
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: [],
      );

      final teacherConflicts = val.hardConflicts.where((c) => c.type == 'teacherConflict').toList();
      expect(teacherConflicts.length, equals(1), reason: 'Must be exactly ONE collision object');
      // ID must have sorted entry IDs: entry_a_entry_b_entry_c
      expect(teacherConflicts.first.id, equals('prof_${prof}_Thursday_4_entry_a_entry_b_entry_c'));
    });

    test('6. ConflictItem Equality & HashCode behave correctly', () {
      final c1 = ConflictItem(
        id: 'unique_conflict_123',
        collegeId: 'user_college',
        type: 'teacherConflict',
        title: 'Collision 1',
        description: 'First description',
      );
      final c2 = ConflictItem(
        id: 'unique_conflict_123',
        collegeId: 'user_college',
        type: 'teacherConflict',
        title: 'Collision 2',
        description: 'Second description',
      );
      final c3 = ConflictItem(
        id: 'different_conflict_456',
        collegeId: 'user_college',
        type: 'teacherConflict',
        title: 'Collision 3',
        description: 'Third description',
      );

      expect(c1 == c2, isTrue, reason: 'ConflictItems with same ID must be equal');
      expect(c1.hashCode, equals(c2.hashCode), reason: 'HashCodes must match for equal items');
      expect(c1 == c3, isFalse, reason: 'ConflictItems with different IDs must not be equal');

      final set = {c1, c2, c3};
      expect(set.length, equals(2), reason: 'Set must deduplicate based on equality and hashCode');
    });

    test('7. ConflictController.recomputeConflicts resolves effective versionId correctly', () async {
      final repo = LocalDatabaseRepository();
      const collegeId = 'user_college';

      for (final c in liveDump['colleges'] as List) {
        await repo.createCollege(College.fromJson(c as Map<String, dynamic>, id: c['id']));
      }
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
      for (final sl in timeSlots) {
        await repo.createTimeSlot(sl);
      }
      for (final v in liveDump['timetableVersions'] as List) {
        await repo.createTimetableVersion(TimetableVersion.fromJson(v as Map<String, dynamic>, id: v['id']));
      }
      for (final e in allEntries) {
        await repo.createTimetableEntry(e);
      }

      final container = ProviderContainer(
        overrides: [
          databaseRepositoryProvider.overrideWithValue(repo),
          activeCollegeIdProvider.overrideWith((ref) => collegeId),
          selectedVersionIdProvider.overrideWith((ref) => 'ver_1790283772093'),
        ],
      );

      // Call recomputeConflicts WITHOUT passing versionId
      await container.read(conflictControllerProvider.notifier).recomputeConflicts();

      // Retrieve conflicts stored in DB
      final savedConflicts = await repo.getConflicts(collegeId);

      // Verify that it validated ONLY version 3 (74 entries) and saved 0 conflicts!
      expect(savedConflicts, isEmpty, reason: 'Recomputing conflicts for active version 3 must result in 0 conflicts in DB');
    });

    test('8. Re-evaluating multiple times produces idempotent, consistent results without duplication', () async {
      final repo = LocalDatabaseRepository();
      const collegeId = 'user_college';

      for (final c in liveDump['colleges'] as List) {
        await repo.createCollege(College.fromJson(c as Map<String, dynamic>, id: c['id']));
      }
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
      for (final sl in timeSlots) {
        await repo.createTimeSlot(sl);
      }
      for (final v in liveDump['timetableVersions'] as List) {
        await repo.createTimetableVersion(TimetableVersion.fromJson(v as Map<String, dynamic>, id: v['id']));
      }
      for (final e in allEntries) {
        await repo.createTimetableEntry(e);
      }

      final container = ProviderContainer(
        overrides: [
          databaseRepositoryProvider.overrideWithValue(repo),
          activeCollegeIdProvider.overrideWith((ref) => collegeId),
          selectedVersionIdProvider.overrideWith((ref) => 'ver_1790283772093'),
        ],
      );

      // Re-evaluate 3 times consecutively
      await container.read(conflictControllerProvider.notifier).recomputeConflicts();
      final pass1 = await repo.getConflicts(collegeId);

      await container.read(conflictControllerProvider.notifier).recomputeConflicts();
      final pass2 = await repo.getConflicts(collegeId);

      await container.read(conflictControllerProvider.notifier).recomputeConflicts();
      final pass3 = await repo.getConflicts(collegeId);

      expect(pass1.length, equals(0));
      expect(pass2.length, equals(0));
      expect(pass3.length, equals(0));
    });
  });
}
