import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'auth_provider.dart';
import 'repository_provider.dart';

final collegesListProvider = FutureProvider<List<College>>((ref) async {
  final db = ref.watch(databaseRepositoryProvider);
  return db.getColleges();
});

final currentCollegeProvider = FutureProvider<College?>((ref) async {
  final db = ref.watch(databaseRepositoryProvider);
  final collegeId = ref.watch(activeCollegeIdProvider);
  return db.getCollege(collegeId);
});

final workingDaysProvider = FutureProvider<List<String>>((ref) async {
  final college = await ref.watch(currentCollegeProvider.future);
  if (college != null) {
    return college.workingDays;
  }
  final db = ref.watch(databaseRepositoryProvider);
  final settings = await db.getCollegeScheduleSettings();
  if (settings != null && settings['workingDays'] != null) {
    return List<String>.from(settings['workingDays'] as List);
  }
  return const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
});

class CollegeController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  CollegeController(this._ref) : super(const AsyncValue.data(null));

  Future<void> updateCollege(College college) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.updateCollege(college);
      _ref.invalidate(currentCollegeProvider);
      _ref.invalidate(workingDaysProvider);
      _ref.invalidate(collegesListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> setWorkingDays(List<String> days) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      final collegeId = _ref.read(activeCollegeIdProvider);
      var college = await db.getCollege(collegeId);
      college ??= College(
        id: collegeId,
        name: 'University College',
        code: 'UC',
        workingDays: days,
      );
      final updatedCollege = college.copyWith(workingDays: days);
      await db.updateCollege(updatedCollege);

      // Sync college schedule settings document
      final slots = await db.getTimeSlots(collegeId);
      final academic = slots.where((s) => !s.isBreak).toList();
      final breaks = slots.where((s) => s.isBreak).toList();

      await db.saveCollegeScheduleSettings(
        workingDays: days,
        periodsPerDay: academic.length,
        periods: academic.map((s) => {
          'id': s.id,
          'periodNumber': s.periodNumber,
          'startTime': s.startTime,
          'endTime': s.endTime,
          'label': s.label,
          'order': s.order,
        }).toList(),
        breaks: breaks.map((b) => {
          'id': b.id,
          'name': b.breakTitle ?? 'Break',
          'startTime': b.startTime,
          'endTime': b.endTime,
          'order': b.order,
        }).toList(),
        collegeId: collegeId,
      );

      _ref.invalidate(currentCollegeProvider);
      _ref.invalidate(workingDaysProvider);
      _ref.invalidate(collegesListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> createCollege(College college) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.createCollege(college);
      _ref.invalidate(collegesListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> seedLargeScenario(String collegeId) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      if (db is LocalDatabaseRepository) {
        await db.seedLargeScenario(collegeId);
      }
      _ref.invalidate(currentCollegeProvider);
      _ref.invalidate(workingDaysProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final collegeControllerProvider = StateNotifierProvider<CollegeController, AsyncValue<void>>((ref) {
  return CollegeController(ref);
});
