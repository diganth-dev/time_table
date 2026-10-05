import '../models/models.dart';

abstract class AuthRepository {
  Stream<UserProfile?> get authStateChanges;
  UserProfile? get currentUser;

  Future<UserProfile> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<UserProfile> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? collegeId,
    String? departmentId,
    String? sectionId,
    String? collegeName,
  });

  Future<UserProfile> completeStaffSignUp({
    required String email,
    required String password,
    required String name,
  });

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();

  Future<void> updateUserProfile(UserProfile profile);
}
