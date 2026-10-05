import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'repository_provider.dart';

final departmentListProvider = FutureProvider<List<Department>>((ref) async {
  final db = ref.watch(databaseRepositoryProvider);
  final collegeId = ref.watch(activeCollegeIdProvider);
  return db.getDepartments(collegeId);
});

class DepartmentController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  DepartmentController(this._ref) : super(const AsyncValue.data(null));

  Future<void> addDepartment(Department department) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.createDepartment(department);
      _ref.invalidate(departmentListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateDepartment(Department department) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.updateDepartment(department);
      _ref.invalidate(departmentListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteDepartment(String id) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.deleteDepartment(id);
      _ref.invalidate(departmentListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final departmentControllerProvider = StateNotifierProvider<DepartmentController, AsyncValue<void>>((ref) {
  return DepartmentController(ref);
});
