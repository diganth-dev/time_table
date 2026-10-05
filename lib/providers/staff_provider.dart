import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'repository_provider.dart';

final staffListProvider = FutureProvider<List<Staff>>((ref) async {
  final db = ref.watch(databaseRepositoryProvider);
  final collegeId = ref.watch(activeCollegeIdProvider);
  return db.getStaffList(collegeId);
});

final activeStaffListProvider = Provider<List<Staff>>((ref) {
  final staffList = ref.watch(staffListProvider).value ?? [];
  return staffList.where((s) => s.active && s.status == 'active').toList();
});

final invitedStaffListProvider = Provider<List<Staff>>((ref) {
  final staffList = ref.watch(staffListProvider).value ?? [];
  return staffList.where((s) => s.status == 'invited' || s.status == 'pending').toList();
});

final teacherAvailabilityProvider = FutureProvider.family<List<TeacherAvailability>, String?>((ref, teacherId) async {
  final db = ref.watch(databaseRepositoryProvider);
  final collegeId = ref.watch(activeCollegeIdProvider);
  return db.getTeacherAvailability(collegeId, teacherId: teacherId);
});

class StaffController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  StaffController(this._ref) : super(const AsyncValue.data(null));

  Future<void> addStaff(Staff staff) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.createStaff(staff);
      _ref.invalidate(staffListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateStaff(Staff staff) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.updateStaff(staff);
      _ref.invalidate(staffListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteStaff(String id) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.deleteStaff(id);
      _ref.invalidate(staffListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> setAvailability(TeacherAvailability availability) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.setTeacherAvailability(availability);
      _ref.invalidate(teacherAvailabilityProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> markStaffLeave(TeacherAvailability leave) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.markTeacherLeave(leave);
      _ref.invalidate(teacherAvailabilityProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final staffControllerProvider = StateNotifierProvider<StaffController, AsyncValue<void>>((ref) {
  return StaffController(ref);
});
