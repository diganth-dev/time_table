import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'auth_provider.dart';
import 'repository_provider.dart';
import 'timetable_provider.dart';

final conflictsListProvider = FutureProvider<List<ConflictItem>>((ref) async {
  final db = ref.watch(databaseRepositoryProvider);
  final collegeId = ref.watch(activeCollegeIdProvider);
  return db.getConflicts(collegeId);
});

class ConflictController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ConflictController(this._ref) : super(const AsyncValue.data(null));

  Future<void> recomputeConflicts({String? versionId}) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      final collegeId = _ref.read(activeCollegeIdProvider);

      String? effectiveVersionId =
          versionId ?? _ref.read(selectedVersionIdProvider);
      if (effectiveVersionId == null) {
        final activePublished = await db.getActivePublishedVersion(collegeId);
        if (activePublished != null) {
          effectiveVersionId = activePublished.id;
        } else {
          final versions = await db.getTimetableVersions(collegeId);
          if (versions.isNotEmpty) {
            effectiveVersionId = versions.first.id;
          }
        }
      }

      // Never validate entries across historical versions. If no active version
      // can be resolved, there is no selected timetable to validate.
      final entries = effectiveVersionId != null
          ? await db.getTimetableEntries(
              collegeId,
              versionId: effectiveVersionId,
            )
          : <TimetableEntry>[];
      final sections = await db.getSections(collegeId);
      final subjects = await db.getSubjects(collegeId);
      final staffList = await db.getStaffList(collegeId);
      final rooms = await db.getRooms(collegeId);
      final timeSlots = await db.getTimeSlots(collegeId);
      final availabilities = await db.getTeacherAvailability(collegeId);

      final validation = ConflictValidator.validateSchedule(
        collegeId: collegeId,
        entries: entries,
        sections: sections,
        subjects: subjects,
        staffList: staffList,
        rooms: rooms,
        timeSlots: timeSlots,
        availabilities: availabilities,
      );

      await db.saveConflicts(collegeId, validation.allConflicts);
      _ref.invalidate(conflictsListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> clearAllConflicts() async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      final collegeId = _ref.read(activeCollegeIdProvider);
      await db.clearConflicts(collegeId);
      _ref.invalidate(conflictsListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final conflictControllerProvider =
    StateNotifierProvider<ConflictController, AsyncValue<void>>((ref) {
      return ConflictController(ref);
    });
