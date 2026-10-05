import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  UserProfile? _cachedUser;

  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  UserProfile? get currentUser => _cachedUser;

  @override
  Stream<UserProfile?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) {
        _cachedUser = null;
        return null;
      }
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final profile = UserProfile.fromJson(userDoc.data() as Map<String, dynamic>, id: userDoc.id);
          _cachedUser = profile;
          return profile;
        }
      } catch (_) {}
      return null;
    });
  }

  @override
  Future<UserProfile> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw Exception('Sign in failed: no user returned');

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      final profile = UserProfile.fromJson(userDoc.data() as Map<String, dynamic>, id: userDoc.id);
      _cachedUser = profile;
      return profile;
    }

    // Existing user profile was missing in /users/{uid}.
    // Check if this user is explicitly the administrator of the legacy college
    String effectiveCollegeId = 'col_${user.uid}';
    try {
      final legacyCol = await _firestore.collection('colleges').doc('user_college').get();
      if (legacyCol.exists && legacyCol.data() != null) {
        final data = legacyCol.data() as Map<String, dynamic>;
        if (data['adminId'] == user.uid) {
          effectiveCollegeId = 'user_college';
        }
      }
    } catch (_) {}

    final profile = UserProfile(
      id: user.uid,
      email: user.email ?? email.trim(),
      name: user.displayName ?? (user.email?.split('@').first ?? 'College Admin'),
      role: UserRole.collegeAdmin,
      collegeId: effectiveCollegeId,
    );

    await _firestore.collection('users').doc(user.uid).set(profile.toJson());
    _cachedUser = profile;
    return profile;
  }

  @override
  Future<UserProfile> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required UserRole role,
    String? collegeId,
    String? departmentId,
    String? sectionId,
    String? collegeName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;
    if (user == null) throw Exception('Registration failed: no user returned');

    // Each new College Admin receives their own unique isolated collegeId (col_<uid>)
    final effectiveCollegeId = (collegeId != null && collegeId.trim().isNotEmpty)
        ? collegeId.trim()
        : 'col_${user.uid}';

    final profile = UserProfile(
      id: user.uid,
      email: email.trim(),
      name: name.trim(),
      role: UserRole.collegeAdmin,
      collegeId: effectiveCollegeId,
    );

    // 1. Create user document
    await _firestore.collection('users').doc(user.uid).set(profile.toJson());

    // 2. Create isolated college document for this new administrator
    try {
      final college = College(
        id: effectiveCollegeId,
        name: (collegeName != null && collegeName.trim().isNotEmpty)
            ? collegeName.trim()
            : '${name.trim()}\'s College',
        code: 'COL',
        adminId: user.uid,
        workingDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      );
      await _firestore.collection('colleges').doc(effectiveCollegeId).set(college.toJson());
    } catch (_) {}

    _cachedUser = profile;
    return profile;
  }

  @override
  Future<UserProfile> completeStaffSignUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final cleanEmail = email.toLowerCase().trim();

    // 1. Query staff document by email
    final staffQuery = await _firestore
        .collection('staff')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    if (staffQuery.docs.isEmpty) {
      throw Exception('No pending staff invitation found for $email. Contact your college admin.');
    }

    final staffDoc = staffQuery.docs.first;
    final staff = Staff.fromJson(staffDoc.data(), id: staffDoc.id);

    // 2. Create Firebase Auth account
    final credential = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );
    final user = credential.user;
    if (user == null) throw Exception('Registration failed: no user returned');

    // 3. Create user profile
    final profile = UserProfile(
      id: user.uid,
      email: cleanEmail,
      name: name.isNotEmpty ? name.trim() : staff.name,
      role: UserRole.teacher,
      collegeId: staff.collegeId,
      departmentId: staff.departmentId,
      staffId: staff.id,
    );

    // 4. Update staff document with linked UID and status active
    final batch = _firestore.batch();
    batch.set(_firestore.collection('users').doc(user.uid), profile.toJson());
    batch.update(staffDoc.reference, {
      'userId': user.uid,
      'status': 'active',
    });
    await batch.commit();

    _cachedUser = profile;
    return profile;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    _cachedUser = null;
  }

  @override
  Future<void> updateUserProfile(UserProfile profile) async {
    await _firestore.collection('users').doc(profile.id).update(profile.toJson());
    _cachedUser = profile;
  }
}
