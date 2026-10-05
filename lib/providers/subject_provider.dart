import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'repository_provider.dart';
import 'staff_provider.dart';

final subjectListProvider = FutureProvider<List<Subject>>((ref) async {
  final db = ref.watch(databaseRepositoryProvider);
  final collegeId = ref.watch(activeCollegeIdProvider);
  return db.getSubjects(collegeId);
});

class SubjectController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  SubjectController(this._ref) : super(const AsyncValue.data(null));

  Future<void> addSubject(Subject subject) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.createSubject(subject);
      _ref.invalidate(subjectListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateSubject(Subject subject) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.updateSubject(subject);
      _ref.invalidate(subjectListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteSubject(String id) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.deleteSubject(id);
      _ref.invalidate(subjectListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> assignTeachersToSubject(String subjectId, List<String> teacherIds) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      final subject = await db.getSubject(subjectId);
      if (subject != null) {
        final updated = subject.copyWith(assignedTeacherIds: teacherIds);
        await db.updateSubject(updated);

        // Update staff members' subjectsCanTeach list as well
        final allStaff = await db.getStaffList(subject.collegeId);
        for (final staff in allStaff) {
          if (teacherIds.contains(staff.id)) {
            if (!staff.subjectsCanTeach.contains(subjectId)) {
              await db.updateStaff(staff.copyWith(
                subjectsCanTeach: [...staff.subjectsCanTeach, subjectId],
              ));
            }
          }
        }
      }
      _ref.invalidate(subjectListProvider);
      _ref.invalidate(staffListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final subjectControllerProvider = StateNotifierProvider<SubjectController, AsyncValue<void>>((ref) {
  return SubjectController(ref);
});
