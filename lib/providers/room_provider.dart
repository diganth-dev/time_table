import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'repository_provider.dart';

final roomListProvider = FutureProvider<List<Room>>((ref) async {
  final db = ref.watch(databaseRepositoryProvider);
  final collegeId = ref.watch(activeCollegeIdProvider);
  return db.getRooms(collegeId);
});

final activeRoomListProvider = Provider<List<Room>>((ref) {
  final rooms = ref.watch(roomListProvider).value ?? [];
  return rooms.where((r) => r.active && !r.isUnderMaintenance).toList();
});

class RoomController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  RoomController(this._ref) : super(const AsyncValue.data(null));

  Future<void> addRoom(Room room) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.createRoom(room);
      _ref.invalidate(roomListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateRoom(Room room) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.updateRoom(room);
      _ref.invalidate(roomListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteRoom(String id) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.deleteRoom(id);
      _ref.invalidate(roomListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> setMaintenance({
    required String roomId,
    required bool underMaintenance,
    String? reason,
    DateTime? from,
    DateTime? to,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      final room = await db.getRoom(roomId);
      if (room != null) {
        final updated = room.copyWith(
          isUnderMaintenance: underMaintenance,
          maintenanceReason: reason,
          maintenanceFrom: from,
          maintenanceTo: to,
        );
        await db.updateRoom(updated);
      }
      _ref.invalidate(roomListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final roomControllerProvider = StateNotifierProvider<RoomController, AsyncValue<void>>((ref) {
  return RoomController(ref);
});
