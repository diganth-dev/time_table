import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'repository_provider.dart';

final timeSlotsProvider = FutureProvider<List<TimeSlot>>((ref) async {
  final db = ref.watch(databaseRepositoryProvider);
  final collegeId = ref.watch(activeCollegeIdProvider);
  return db.getTimeSlots(collegeId);
});

final academicSlotsProvider = Provider<List<TimeSlot>>((ref) {
  final slots = ref.watch(timeSlotsProvider).value ?? [];
  return slots.where((s) => !s.isBreak).toList()..sort((a, b) => a.order.compareTo(b.order));
});

final breakSlotsProvider = Provider<List<TimeSlot>>((ref) {
  final slots = ref.watch(timeSlotsProvider).value ?? [];
  return slots.where((s) => s.isBreak).toList()..sort((a, b) => a.order.compareTo(b.order));
});

class TimeSlotController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  TimeSlotController(this._ref) : super(const AsyncValue.data(null));

  Future<void> saveSlots(List<TimeSlot> slots) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      final collegeId = _ref.read(activeCollegeIdProvider);
      await db.saveTimeSlots(collegeId, slots);
      _ref.invalidate(timeSlotsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> _syncScheduleSettings() async {
    try {
      final db = _ref.read(databaseRepositoryProvider);
      final collegeId = _ref.read(activeCollegeIdProvider);
      final allSlots = await db.getTimeSlots(collegeId);
      final col = await db.getCollege(collegeId);
      final workingDays = col?.workingDays ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
      final academic = allSlots.where((s) => !s.isBreak).toList()..sort((a, b) => a.order.compareTo(b.order));
      final breaks = allSlots.where((s) => s.isBreak).toList()..sort((a, b) => a.order.compareTo(b.order));

      await db.saveCollegeScheduleSettings(
        workingDays: workingDays,
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
    } catch (_) {}
  }

  Future<void> addSlot(TimeSlot slot) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.createTimeSlot(slot);
      await _syncScheduleSettings();
      _ref.invalidate(timeSlotsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateSlot(TimeSlot slot) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.updateTimeSlot(slot);
      await _syncScheduleSettings();
      _ref.invalidate(timeSlotsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteSlot(String id) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.deleteTimeSlot(id);
      await _syncScheduleSettings();
      _ref.invalidate(timeSlotsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final timeSlotControllerProvider = StateNotifierProvider<TimeSlotController, AsyncValue<void>>((ref) {
  return TimeSlotController(ref);
});
