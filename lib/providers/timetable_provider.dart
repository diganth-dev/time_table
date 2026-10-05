import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'auth_provider.dart';
import 'conflict_provider.dart';
import 'notification_provider.dart';
import 'repository_provider.dart';

final timetableVersionsProvider = FutureProvider<List<TimetableVersion>>((ref) async {
  final db = ref.watch(databaseRepositoryProvider);
  final collegeId = ref.watch(activeCollegeIdProvider);
  return db.getTimetableVersions(collegeId);
});

final selectedVersionIdProvider = StateProvider<String?>((ref) => null);

final selectedSectionFilterProvider = StateProvider<String?>((ref) => null);
final selectedTeacherFilterProvider = StateProvider<String?>((ref) => null);
final selectedRoomFilterProvider = StateProvider<String?>((ref) => null);
final selectedDepartmentFilterProvider = StateProvider<String?>((ref) => null);

final timetableEntriesProvider = FutureProvider<List<TimetableEntry>>((ref) async {
  final db = ref.watch(databaseRepositoryProvider);
  final collegeId = ref.watch(activeCollegeIdProvider);
  final versionId = ref.watch(selectedVersionIdProvider);

  // If user is a student or teacher and no specific version selected, default to active published version
  final user = ref.watch(currentProfileProvider);
  String? effectiveVersionId = versionId;

  if (effectiveVersionId == null) {
    final versions = await db.getTimetableVersions(collegeId);
    if (user?.role == UserRole.student || user?.role == UserRole.teacher) {
      final activePublished = await db.getActivePublishedVersion(collegeId);
      effectiveVersionId = activePublished?.id ?? (versions.isNotEmpty ? versions.first.id : null);
    } else {
      // For admins / schedulers: prioritize latest draft version if present, otherwise latest version
      final draft = versions.where((v) => v.status == 'draft').firstOrNull;
      effectiveVersionId = draft?.id ?? (versions.isNotEmpty ? versions.first.id : null);
    }
  }

  // Role based filtering: if student, lock to sectionId; if teacher, lock to staffId.
  // For collegeAdmin / coordinators, do NOT restrict by section/teacher/room at the DB level,
  // because Timetable Matrix, Export Timetable, Conflict Center, and Dashboard need all version entries
  // to perform dynamic in-memory filtering by view mode.
  String? effSection;
  String? effTeacher;
  String? effRoom;

  if (user?.role == UserRole.student && user?.sectionId != null) {
    effSection = user!.sectionId;
  } else if (user?.role == UserRole.teacher && user?.staffId != null) {
    effTeacher = user!.staffId;
  }

  return db.getTimetableEntries(
    collegeId,
    versionId: effectiveVersionId,
    sectionId: effSection,
    teacherId: effTeacher,
    roomId: effRoom,
  );
});

final lastGenerationResultProvider = StateProvider<GenerationResult?>((ref) => null);

class TimetableController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  TimetableController(this._ref) : super(const AsyncValue.data(null));

  /// Executes full constraint-based generation and saves draft entries.
  /// If [targetSectionId] is provided, generates specifically for that class/section.
  Future<GenerationResult> generateSchedule({
    String? customVersionName,
    String? targetSectionId,
    String? targetVersionId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      final collegeId = _ref.read(activeCollegeIdProvider);

      // Fetch all required scheduling data
      final college = await db.getCollege(collegeId);
      final sections = await db.getSections(collegeId);
      final subjects = await db.getSubjects(collegeId);
      final staffList = await db.getStaffList(collegeId);
      final rooms = await db.getRooms(collegeId);
      final timeSlots = await db.getTimeSlots(collegeId);
      final availabilities = await db.getTeacherAvailability(collegeId);
      final scheduleSettings = await db.getCollegeScheduleSettings(collegeId: collegeId);

      List<String>? workingDays = college?.workingDays;
      if (workingDays == null) {
        if (scheduleSettings != null && scheduleSettings['workingDays'] != null) {
          workingDays = List<String>.from(scheduleSettings['workingDays'] as List);
        }
      }
      workingDays ??= ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

      final existingVersions = await db.getTimetableVersions(collegeId);
      final selectedVerId = _ref.read(selectedVersionIdProvider);

      // Determine active target version
      String? effectiveVersionId = targetVersionId ?? selectedVerId;
      TimetableVersion? targetDraftVersion;

      if (effectiveVersionId != null) {
        targetDraftVersion = existingVersions.where((v) => v.id == effectiveVersionId && v.status == 'draft').firstOrNull;
      }
      targetDraftVersion ??= existingVersions.where((v) => v.status == 'draft').firstOrNull;

      List<TimetableEntry> existingEntries = [];
      String versionId;
      bool isNewVersion = false;

      if (targetSectionId != null && targetDraftVersion != null) {
        versionId = targetDraftVersion.id;
        existingEntries = await db.getTimetableEntries(collegeId, versionId: versionId);
      } else {
        isNewVersion = true;
        versionId = 'ver_${DateTime.now().millisecondsSinceEpoch}';
      }

      // Run generation engine
      final result = TimetableGenerator.generate(
        collegeId: collegeId,
        sections: sections,
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: availabilities,
        workingDays: workingDays,
        customVersionId: versionId,
        targetSectionId: targetSectionId,
        existingEntries: existingEntries,
      );

      _ref.read(lastGenerationResultProvider.notifier).state = result;

      // Always create a new draft version if there are entries or if success
      if (result.entries.isNotEmpty) {
        if (isNewVersion) {
          final nextVersionNum = existingVersions.isEmpty
              ? 1
              : (existingVersions.map((v) => v.versionNumber).reduce((a, b) => a > b ? a : b) + 1);

          final targetSec = targetSectionId != null
              ? sections.where((s) => s.id == targetSectionId).firstOrNull
              : null;
          final defaultName = targetSec != null
              ? 'Draft $nextVersionNum (${targetSec.displayName})'
              : 'Draft Version $nextVersionNum (${college?.currentSemester ?? 'Semester'})';

          final newVersion = TimetableVersion(
            id: result.versionId,
            collegeId: collegeId,
            versionNumber: nextVersionNum,
            name: customVersionName ?? defaultName,
            status: 'draft',
            academicYear: college?.academicYear ?? '2026-2027',
            semester: college?.currentSemester ?? 'Odd 2026',
          );

          await db.createTimetableVersion(newVersion);
        }

        await db.saveTimetableEntries(collegeId, result.versionId, result.entries);
        _ref.read(selectedVersionIdProvider.notifier).state = result.versionId;
        if (targetSectionId != null) {
          _ref.read(selectedSectionFilterProvider.notifier).state = targetSectionId;
        }
      }

      // Save conflicts to conflict center
      await db.saveConflicts(collegeId, result.conflicts);

      _ref.invalidate(timetableVersionsProvider);
      _ref.invalidate(timetableEntriesProvider);
      _ref.invalidate(conflictsListProvider);

      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      debugPrint('[GENERATION FIRESTORE EXCEPTION] Generation failed: $e\n$st');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Publishes a draft timetable version
  Future<void> publishVersion({
    required String versionId,
    required String publishedByName,
    String? changeLog,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      final collegeId = _ref.read(activeCollegeIdProvider);

      await db.publishTimetableVersion(
        collegeId,
        versionId,
        publishedByName,
        changeLog: changeLog,
      );

      _ref.invalidate(timetableVersionsProvider);
      _ref.invalidate(timetableEntriesProvider);
      _ref.invalidate(notificationsListProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Validates and saves a manual entry update
  Future<ValidationResult> updateEntryWithValidation(TimetableEntry entry) async {
    final db = _ref.read(databaseRepositoryProvider);
    final collegeId = _ref.read(activeCollegeIdProvider);

    final sections = await db.getSections(collegeId);
    final subjects = await db.getSubjects(collegeId);
    final staffList = await db.getStaffList(collegeId);
    final rooms = await db.getRooms(collegeId);
    final timeSlots = await db.getTimeSlots(collegeId);
    final availabilities = await db.getTeacherAvailability(collegeId);
    final currentEntries = await db.getTimetableEntries(collegeId, versionId: entry.versionId);

    final validation = ConflictValidator.validateSingleEntry(
      collegeId: collegeId,
      proposedEntry: entry,
      existingEntries: currentEntries,
      sections: sections,
      subjects: subjects,
      staffList: staffList,
      rooms: rooms,
      timeSlots: timeSlots,
      availabilities: availabilities,
    );

    if (validation.isValid) {
      await db.updateTimetableEntry(entry);
      _ref.invalidate(timetableEntriesProvider);
    }

    return validation;
  }

  Future<void> forceSaveEntry(TimetableEntry entry) async {
    final db = _ref.read(databaseRepositoryProvider);
    final existing = await db.getTimetableEntries(entry.collegeId, versionId: entry.versionId);
    if (existing.any((e) => e.id == entry.id)) {
      await db.updateTimetableEntry(entry);
    } else {
      await db.createTimetableEntry(entry);
    }
    _ref.invalidate(timetableEntriesProvider);
  }

  Future<void> saveEntries(List<TimetableEntry> entriesToSave, {List<String>? entriesToDelete}) async {
    final db = _ref.read(databaseRepositoryProvider);
    if (entriesToDelete != null) {
      for (final id in entriesToDelete) {
        await db.deleteTimetableEntry(id);
      }
    }
    if (entriesToSave.isNotEmpty) {
      final collegeId = entriesToSave.first.collegeId;
      final versionId = entriesToSave.first.versionId;
      final existing = await db.getTimetableEntries(collegeId, versionId: versionId);
      final existingIds = existing.map((e) => e.id).toSet();
      for (final entry in entriesToSave) {
        if (existingIds.contains(entry.id)) {
          await db.updateTimetableEntry(entry);
        } else {
          await db.createTimetableEntry(entry);
        }
      }
    }
    _ref.invalidate(timetableEntriesProvider);
  }

  Future<void> deleteEntry(String entryId) async {
    final db = _ref.read(databaseRepositoryProvider);
    await db.deleteTimetableEntry(entryId);
    _ref.invalidate(timetableEntriesProvider);
  }

  Future<void> deleteEntries(List<String> entryIds) async {
    final db = _ref.read(databaseRepositoryProvider);
    for (final id in entryIds) {
      await db.deleteTimetableEntry(id);
    }
    _ref.invalidate(timetableEntriesProvider);
  }

  Future<void> deleteTimetable({String? versionId}) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      final collegeId = _ref.read(activeCollegeIdProvider);

      await db.deleteTimetable(collegeId, versionId: versionId);

      _ref.read(lastGenerationResultProvider.notifier).state = null;
      _ref.read(selectedVersionIdProvider.notifier).state = null;

      _ref.invalidate(timetableVersionsProvider);
      _ref.invalidate(timetableEntriesProvider);
      _ref.invalidate(conflictsListProvider);

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final timetableControllerProvider = StateNotifierProvider<TimetableController, AsyncValue<void>>((ref) {
  return TimetableController(ref);
});
