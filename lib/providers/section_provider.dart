import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'auth_provider.dart';
import 'repository_provider.dart';

import 'conflict_provider.dart';
import 'subject_provider.dart';
import 'timetable_provider.dart';

final sectionListProvider = FutureProvider<List<Section>>((ref) async {
  final db = ref.watch(databaseRepositoryProvider);
  final collegeId = ref.watch(activeCollegeIdProvider);
  return db.getSections(collegeId);
});

class SectionController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  SectionController(this._ref) : super(const AsyncValue.data(null));

  Future<void> addSection(Section section) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.createSection(section);
      _ref.invalidate(sectionListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateSection(Section section) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.updateSection(section);
      _ref.invalidate(sectionListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> deleteSection(String id) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseRepositoryProvider);
      await db.deleteSection(id);
      _ref.invalidate(sectionListProvider);
      _ref.invalidate(subjectListProvider);
      _ref.invalidate(timetableEntriesProvider);
      _ref.invalidate(timetableVersionsProvider);
      _ref.invalidate(conflictsListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final sectionControllerProvider = StateNotifierProvider<SectionController, AsyncValue<void>>((ref) {
  return SectionController(ref);
});
