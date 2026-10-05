import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/repositories.dart';

/// Flag to toggle between Cloud Firestore and Local Database.
/// Automatically defaults to true when Firebase is initialized on supported platforms.
final useFirebaseBackendProvider = StateProvider<bool>((ref) {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
});

final databaseRepositoryProvider = Provider<DatabaseRepository>((ref) {
  final useFirebase = ref.watch(useFirebaseBackendProvider);
  if (useFirebase) {
    try {
      return FirestoreRepository();
    } catch (_) {
      return LocalDatabaseRepository();
    }
  }
  return LocalDatabaseRepository();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final useFirebase = ref.watch(useFirebaseBackendProvider);
  if (useFirebase) {
    try {
      return FirebaseAuthRepository();
    } catch (_) {
      return LocalAuthRepository();
    }
  }
  return LocalAuthRepository();
});
