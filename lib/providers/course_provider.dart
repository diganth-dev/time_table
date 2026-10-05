import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'repository_provider.dart';

final courseListProvider = FutureProvider<List<Course>>((ref) async {
  final db = ref.watch(databaseRepositoryProvider);
  final collegeId = ref.watch(activeCollegeIdProvider);
  return db.getCourses(collegeId);
});

class CourseController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  CourseController(this._ref) : super(const AsyncValue.data(null));

  Future<void> addCourse(Course course) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.createCourse(course);
      _ref.invalidate(courseListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateCourse(Course course) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.updateCourse(course);
      _ref.invalidate(courseListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteCourse(String id) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.deleteCourse(id);
      _ref.invalidate(courseListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final courseControllerProvider = StateNotifierProvider<CourseController, AsyncValue<void>>((ref) {
  return CourseController(ref);
});
