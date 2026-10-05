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

void main() {
  test(
    'Conflict recomputation validates only the selected timetable version',
    () async {
      const collegeId = 'version_scope_test_college';
      final repo = LocalDatabaseRepository();
      await repo.createTimetableEntry(
        TimetableEntry(
          id: 'old_1',
          collegeId: collegeId,
          versionId: 'version_old',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          sectionId: 'section_a',
          subjectId: 'subject_a',
          teacherId: 'teacher_a',
          roomId: 'room_a',
        ),
      );
      await repo.createTimetableEntry(
        TimetableEntry(
          id: 'old_2',
          collegeId: collegeId,
          versionId: 'version_old',
          dayOfWeek: 'Monday',
          periodNumber: 1,
          sectionId: 'section_b',
          subjectId: 'subject_b',
          teacherId: 'teacher_a',
          roomId: 'room_b',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          databaseRepositoryProvider.overrideWithValue(repo),
          activeCollegeIdProvider.overrideWith((ref) => collegeId),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(conflictControllerProvider.notifier)
          .recomputeConflicts(versionId: 'version_good');

      expect(
        await repo.getTimetableEntries(collegeId, versionId: 'version_good'),
        isEmpty,
      );
      expect(await repo.getConflicts(collegeId), isEmpty);
    },
  );

  test(
    'TASK 9: TimetableController & Conflict Lifecycle with Actual Firestore Dump Data',
    () async {
      final dumpFile = File(
        'C:/Users/deeek/.gemini/antigravity-cli/brain/4f176d6f-4e29-4fcf-a421-4637fd04c336/scratch/firestore_dump.json',
      );
      expect(dumpFile.existsSync(), isTrue);

      final jsonMap =
          jsonDecode(dumpFile.readAsStringSync()) as Map<String, dynamic>;

      final repo = LocalDatabaseRepository();
      const collegeId = 'user_college';

      // Populate repo from dump
      // 1. College
      final collegesRaw = jsonMap['colleges'] as List;
      for (final c in collegesRaw) {
        await repo.createCollege(
          College.fromJson(c as Map<String, dynamic>, id: c['id']),
        );
      }

      // 2. Sections
      final sectionsRaw = jsonMap['sections'] as List;
      for (final s in sectionsRaw) {
        await repo.createSection(
          Section.fromJson(s as Map<String, dynamic>, id: s['id']),
        );
      }

      // 3. Subjects
      final subjectsRaw = jsonMap['subjects'] as List;
      for (final s in subjectsRaw) {
        await repo.createSubject(
          Subject.fromJson(s as Map<String, dynamic>, id: s['id']),
        );
      }

      // 4. Staff
      final staffRaw = jsonMap['staff'] as List;
      for (final st in staffRaw) {
        await repo.createStaff(
          Staff.fromJson(st as Map<String, dynamic>, id: st['id']),
        );
      }

      // 5. Rooms
      final roomsRaw = jsonMap['rooms'] as List;
      for (final r in roomsRaw) {
        await repo.createRoom(
          Room.fromJson(r as Map<String, dynamic>, id: r['id']),
        );
      }

      // 6. TimeSlots
      final slotsRaw = jsonMap['timeSlots'] as List;
      for (final sl in slotsRaw) {
        await repo.createTimeSlot(
          TimeSlot.fromJson(sl as Map<String, dynamic>, id: sl['id']),
        );
      }

      // 7. Seed with the EXACT 2 stale conflicts currently in Firestore
      final staleConflicts = [
        ConflictItem(
          id: '092ca594-eca2-41bc-b248-b667878037fe',
          collegeId: collegeId,
          type: 'incompleteHours',
          severity: 'hard',
          title: 'Period Scheduling Conflict',
          description:
              'Cannot schedule session #4 (1 hr) of TOC for Sem 5 - Sec CSE(AIML) (57 students). All valid period slots conflict with teacher availability, room occupancy, or daily teaching limits.',
        ),
        ConflictItem(
          id: '54e5c202-b64d-44c2-850a-61547d3fa4c4',
          collegeId: collegeId,
          type: 'incompleteHours',
          severity: 'hard',
          title: 'Period Scheduling Conflict',
          description:
              'Cannot schedule session #5 (1 hr) of TOC for Sem 5 - Sec CSE(AIML) (57 students). All valid period slots conflict with teacher availability, room occupancy, or daily teaching limits.',
        ),
      ];
      await repo.saveConflicts(collegeId, staleConflicts);

      // Verify stale conflicts are present before generation
      final initialConflicts = await repo.getConflicts(collegeId);
      expect(initialConflicts.length, equals(2));
      expect(
        initialConflicts.first.id,
        equals('092ca594-eca2-41bc-b248-b667878037fe'),
      );

      // Setup Riverpod container overriding databaseRepositoryProvider
      final container = ProviderContainer(
        overrides: [
          databaseRepositoryProvider.overrideWithValue(repo),
          activeCollegeIdProvider.overrideWith((ref) => collegeId),
        ],
      );

      // Initial Conflict Center state
      final conflictCenterInitial = await container.read(
        conflictsListProvider.future,
      );
      expect(
        conflictCenterInitial.length,
        equals(2),
        reason: 'Conflict Center initially shows the 2 stale conflicts from DB',
      );

      // RUN GENERATION through TimetableController (exact call as UI button)
      final genResult = await container
          .read(timetableControllerProvider.notifier)
          .generateSchedule(customVersionName: 'Generated Timetable Test');

      // Verify Generation Result
      expect(genResult.isSuccess, isTrue);
      expect(genResult.totalClassesScheduled, equals(24));
      expect(genResult.conflicts, isEmpty);

      final tocEntries = genResult.entries
          .where((e) => e.subjectId == 'sub_f042dd28')
          .toList();
      expect(
        tocEntries.length,
        equals(5),
        reason: 'All 5 TOC sessions scheduled',
      );

      // Verify Repository State
      final updatedConflicts = await repo.getConflicts(collegeId);
      expect(
        updatedConflicts,
        isEmpty,
        reason:
            'Old conflicts in repo MUST be cleared when 0 conflicts are generated',
      );

      // Verify Conflict Center provider invalidation
      final conflictCenterUpdated = await container.read(
        conflictsListProvider.future,
      );
      expect(
        conflictCenterUpdated,
        isEmpty,
        reason:
            'Conflict Center provider MUST return 0 conflicts after generation',
      );

      // Verify Timetable Entries in DB
      final savedEntries = await repo.getTimetableEntries(
        collegeId,
        versionId: genResult.versionId,
      );
      expect(savedEntries.length, equals(24));

      // Verify New Version in DB
      final versions = await repo.getTimetableVersions(collegeId);
      expect(versions.isNotEmpty, isTrue);
      expect(versions.first.id, equals(genResult.versionId));
    },
  );
}
