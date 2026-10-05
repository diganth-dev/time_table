import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'repository_provider.dart';

final authStateStreamProvider = StreamProvider<UserProfile?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

final currentProfileProvider = StateProvider<UserProfile?>((ref) {
  final useFirebase = ref.watch(useFirebaseBackendProvider);
  if (useFirebase) {
    return null;
  }
  return UserProfile(
    id: 'usr_default',
    email: 'admin@timepilot.edu',
    name: 'Administrator',
    role: UserRole.collegeAdmin,
    collegeId: 'user_college',
  );
});

final activeCollegeIdProvider = StateProvider<String>((ref) {
  final user = ref.watch(currentProfileProvider);
  final useFirebase = ref.watch(useFirebaseBackendProvider);
  return user?.collegeId ?? (useFirebase ? '' : 'user_college');
});

class AuthController extends StateNotifier<AsyncValue<UserProfile?>> {
  final Ref _ref;

  AuthController(this._ref) : super(const AsyncValue.data(null));

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(authRepositoryProvider);
      final profile = await repo.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _ref.read(currentProfileProvider.notifier).state = profile;
      if (profile.collegeId != null) {
        _ref.read(activeCollegeIdProvider.notifier).state = profile.collegeId!;
      }
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? collegeId,
    String? departmentId,
    String? sectionId,
    String? collegeName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(authRepositoryProvider);
      final profile = await repo.registerWithEmailAndPassword(
        email: email,
        password: password,
        name: name,
        role: role,
        collegeId: collegeId,
        departmentId: departmentId,
        sectionId: sectionId,
        collegeName: collegeName,
      );
      _ref.read(currentProfileProvider.notifier).state = profile;
      if (profile.collegeId != null) {
        _ref.read(activeCollegeIdProvider.notifier).state = profile.collegeId!;
      }
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> completeStaffSignUp({
    required String email,
    required String password,
    required String name,
  }) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(authRepositoryProvider);
      final profile = await repo.completeStaffSignUp(
        email: email,
        password: password,
        name: name,
      );
      _ref.read(currentProfileProvider.notifier).state = profile;
      if (profile.collegeId != null) {
        _ref.read(activeCollegeIdProvider.notifier).state = profile.collegeId!;
      }
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(authRepositoryProvider);
      await repo.signOut();
      _ref.read(currentProfileProvider.notifier).state = null;
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final repo = _ref.read(authRepositoryProvider);
    await repo.sendPasswordResetEmail(email.trim());
  }

  /// Switch user role demo helper (for testing different dashboards easily)
  void switchDemoUser(UserProfile user) {
    _ref.read(currentProfileProvider.notifier).state = user;
    if (user.collegeId != null) {
      _ref.read(activeCollegeIdProvider.notifier).state = user.collegeId!;
    }
    state = AsyncValue.data(user);
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AsyncValue<UserProfile?>>((ref) {
  return AuthController(ref);
});
