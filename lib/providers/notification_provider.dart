import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'repository_provider.dart';

final notificationsListProvider = FutureProvider<List<NotificationItem>>((ref) async {
  final db = ref.watch(databaseRepositoryProvider);
  final collegeId = ref.watch(activeCollegeIdProvider);
  final user = ref.watch(currentProfileProvider);

  return db.getNotifications(
    collegeId,
    userId: user?.id,
    role: user?.role.toDbString(),
  );
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsListProvider).value ?? [];
  return notifs.where((n) => !n.isRead).length;
});

class NotificationController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  NotificationController(this._ref) : super(const AsyncValue.data(null));

  Future<void> markAsRead(String id) async {
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.markNotificationRead(id);
      _ref.invalidate(notificationsListProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> sendNotification(NotificationItem item) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.createNotification(item);
      _ref.invalidate(notificationsListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final notificationControllerProvider = StateNotifierProvider<NotificationController, AsyncValue<void>>((ref) {
  return NotificationController(ref);
});
