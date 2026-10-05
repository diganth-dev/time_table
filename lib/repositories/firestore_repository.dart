import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'database_repository.dart';

class FirestoreRepository implements DatabaseRepository {
  final FirebaseFirestore _firestore;

  FirestoreRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  void _logGenerationFirestore({
    required String operation,
    required String path,
    required String tenantId,
    required String purpose,
  }) {
    String uid = 'unauthenticated';
    try {
      uid = FirebaseAuth.instance.currentUser?.uid ?? 'null';
    } catch (_) {}
    debugPrint(
      '[GENERATION FIRESTORE]\n'
      'operation: $operation\n'
      'path: $path\n'
      'uid: $uid\n'
      'tenantId: $tenantId\n'
      'purpose: $purpose',
    );
  }

  // Collection references
  CollectionReference get _colleges => _firestore.collection('colleges');
  CollectionReference get _departments => _firestore.collection('departments');
  CollectionReference get _courses => _firestore.collection('courses');
  CollectionReference get _sections => _firestore.collection('sections');
  CollectionReference get _staff => _firestore.collection('staff');
  CollectionReference get _subjects => _firestore.collection('subjects');
  CollectionReference get _rooms => _firestore.collection('rooms');
  CollectionReference get _timeSlots => _firestore.collection('timeSlots');
  CollectionReference get _teacherAvailability => _firestore.collection('teacherAvailability');
  CollectionReference get _timetableVersions => _firestore.collection('timetableVersions');
  CollectionReference get _timetableEntries => _firestore.collection('timetableEntries');
  CollectionReference get _collegeSettings => _firestore.collection('collegeSettings');
  CollectionReference get _conflicts => _firestore.collection('conflicts');
  CollectionReference get _notifications => _firestore.collection('notifications');

  // ==================== Colleges ====================
  @override
  Future<List<College>> getColleges() async {
    final snap = await _colleges.get();
    return snap.docs
        .map((doc) => College.fromJson(doc.data() as Map<String, dynamic>, id: doc.id))
        .toList();
  }

  @override
  Future<College?> getCollege(String id) async {
    if (id.isEmpty) return null;
    _logGenerationFirestore(
      operation: 'get',
      path: '/colleges/$id',
      tenantId: id,
      purpose: 'loading college configuration',
    );
    final doc = await _colleges.doc(id).get();
    if (!doc.exists) {
      final settingsDoc = await _collegeSettings.doc('settings').get();
      List<String> defaultDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
      if (settingsDoc.exists && settingsDoc.data() != null) {
        final data = settingsDoc.data() as Map<String, dynamic>;
        if (data['workingDays'] != null) {
          defaultDays = List<String>.from(data['workingDays'] as List);
        }
      }
      final defaultCol = College(
        id: id,
        name: 'University College',
        code: 'UC',
        workingDays: defaultDays,
      );
      try {
        await _colleges.doc(id).set(defaultCol.toJson());
      } catch (_) {}
      return defaultCol;
    }
    var college = College.fromJson(doc.data() as Map<String, dynamic>, id: doc.id);
    try {
      final settingsDoc = await _collegeSettings.doc('settings').get();
      if (settingsDoc.exists && settingsDoc.data() != null) {
        final data = settingsDoc.data() as Map<String, dynamic>;
        if (data['workingDays'] != null) {
          final settingsDays = List<String>.from(data['workingDays'] as List);
          college = college.copyWith(workingDays: settingsDays);
        }
      }
    } catch (_) {}
    return college;
  }

  @override
  Future<void> createCollege(College college) async {
    await _colleges.doc(college.id).set(college.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> updateCollege(College college) async {
    await _colleges.doc(college.id).set(college.toJson(), SetOptions(merge: true));
    try {
      await _collegeSettings.doc('settings').set({
        'workingDays': college.workingDays,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Future<void> deleteCollege(String id) async {
    await _colleges.doc(id).delete();
  }

  // ==================== Departments ====================
  @override
  Future<List<Department>> getDepartments(String collegeId) async {
    if (collegeId.isEmpty) return [];
    final snap = await _departments.where('collegeId', isEqualTo: collegeId).get();
    return snap.docs
        .map((d) => Department.fromJson(d.data() as Map<String, dynamic>, id: d.id))
        .toList();
  }

  @override
  Future<void> createDepartment(Department department) async {
    await _departments.doc(department.id).set(department.toJson());
  }

  @override
  Future<void> updateDepartment(Department department) async {
    await _departments.doc(department.id).update(department.toJson());
  }

  @override
  Future<void> deleteDepartment(String id) async {
    await _departments.doc(id).delete();
  }

  // ==================== Courses ====================
  @override
  Future<List<Course>> getCourses(String collegeId) async {
    if (collegeId.isEmpty) return [];
    final snap = await _courses.where('collegeId', isEqualTo: collegeId).get();
    return snap.docs
        .map((d) => Course.fromJson(d.data() as Map<String, dynamic>, id: d.id))
        .toList();
  }

  @override
  Future<void> createCourse(Course course) async {
    await _courses.doc(course.id).set(course.toJson());
  }

  @override
  Future<void> updateCourse(Course course) async {
    await _courses.doc(course.id).update(course.toJson());
  }

  @override
  Future<void> deleteCourse(String id) async {
    await _courses.doc(id).delete();
  }

  // ==================== Sections ====================
  @override
  Future<List<Section>> getSections(String collegeId) async {
    if (collegeId.isEmpty) return [];
    _logGenerationFirestore(
      operation: 'query',
      path: '/sections',
      tenantId: collegeId,
      purpose: 'loading sections',
    );
    final snap = await _sections.where('collegeId', isEqualTo: collegeId).get();
    return snap.docs
        .map((d) => Section.fromJson(d.data() as Map<String, dynamic>, id: d.id))
        .toList();
  }

  @override
  Future<Section?> getSection(String id) async {
    final doc = await _sections.doc(id).get();
    if (!doc.exists) return null;
    return Section.fromJson(doc.data() as Map<String, dynamic>, id: doc.id);
  }

  @override
  Future<void> createSection(Section section) async {
    await _sections.doc(section.id).set(section.toJson());
  }

  @override
  Future<void> updateSection(Section section) async {
    await _sections.doc(section.id).set(section.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteSection(String id) async {
    final section = await getSection(id);
    final batch = _firestore.batch();
    batch.delete(_sections.doc(id));

    // Delete associated subjects scoped to the section's college
    Query subjectsQuery = _subjects.where('sectionId', isEqualTo: id);
    if (section != null && section.collegeId.isNotEmpty) {
      subjectsQuery = subjectsQuery.where('collegeId', isEqualTo: section.collegeId);
    }
    final subjectsSnap = await subjectsQuery.get();
    for (final doc in subjectsSnap.docs) {
      batch.delete(doc.reference);
    }

    // Delete associated timetable entries scoped to the section's college
    Query entriesQuery = _timetableEntries.where('sectionId', isEqualTo: id);
    if (section != null && section.collegeId.isNotEmpty) {
      entriesQuery = entriesQuery.where('collegeId', isEqualTo: section.collegeId);
    }
    final entriesSnap = await entriesQuery.get();
    for (final doc in entriesSnap.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // ==================== Staff ====================
  @override
  Future<List<Staff>> getStaffList(String collegeId) async {
    if (collegeId.isEmpty) return [];
    _logGenerationFirestore(
      operation: 'query',
      path: '/staff',
      tenantId: collegeId,
      purpose: 'loading faculty/professors',
    );
    final snap = await _staff.where('collegeId', isEqualTo: collegeId).get();
    return snap.docs
        .map((d) => Staff.fromJson(d.data() as Map<String, dynamic>, id: d.id))
        .toList();
  }

  @override
  Future<Staff?> getStaff(String id) async {
    final doc = await _staff.doc(id).get();
    if (!doc.exists) return null;
    return Staff.fromJson(doc.data() as Map<String, dynamic>, id: doc.id);
  }

  @override
  Future<Staff?> getStaffByEmail(String email) async {
    final snap = await _staff
        .where('email', isEqualTo: email.toLowerCase().trim())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Staff.fromJson(snap.docs.first.data() as Map<String, dynamic>, id: snap.docs.first.id);
  }

  @override
  Future<Staff?> getStaffByUserId(String userId) async {
    final snap = await _staff.where('userId', isEqualTo: userId).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return Staff.fromJson(snap.docs.first.data() as Map<String, dynamic>, id: snap.docs.first.id);
  }

  @override
  Future<void> createStaff(Staff staff) async {
    await _staff.doc(staff.id).set(staff.toJson());
  }

  @override
  Future<void> updateStaff(Staff staff) async {
    await _staff.doc(staff.id).set(staff.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteStaff(String id) async {
    await _staff.doc(id).delete();
  }

  @override
  Future<void> linkStaffToAuth(String staffId, String userId) async {
    await _staff.doc(staffId).update({
      'userId': userId,
      'status': 'active',
    });
  }

  // ==================== Subjects ====================
  @override
  Future<List<Subject>> getSubjects(String collegeId) async {
    if (collegeId.isEmpty) return [];
    _logGenerationFirestore(
      operation: 'query',
      path: '/subjects',
      tenantId: collegeId,
      purpose: 'loading subjects',
    );
    final snap = await _subjects.where('collegeId', isEqualTo: collegeId).get();
    return snap.docs
        .map((d) => Subject.fromJson(d.data() as Map<String, dynamic>, id: d.id))
        .toList();
  }

  @override
  Future<Subject?> getSubject(String id) async {
    final doc = await _subjects.doc(id).get();
    if (!doc.exists) return null;
    return Subject.fromJson(doc.data() as Map<String, dynamic>, id: doc.id);
  }

  @override
  Future<void> createSubject(Subject subject) async {
    final data = subject.toJson();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _subjects.doc(subject.id).set(data);
  }

  @override
  Future<void> updateSubject(Subject subject) async {
    final data = subject.toJson();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _subjects.doc(subject.id).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> deleteSubject(String id) async {
    await _subjects.doc(id).delete();
  }

  // ==================== Rooms ====================
  @override
  Future<List<Room>> getRooms(String collegeId) async {
    if (collegeId.isEmpty) return [];
    _logGenerationFirestore(
      operation: 'query',
      path: '/rooms',
      tenantId: collegeId,
      purpose: 'loading classrooms and laboratories',
    );
    final snap = await _rooms.where('collegeId', isEqualTo: collegeId).get();
    return snap.docs
        .map((d) => Room.fromJson(d.data() as Map<String, dynamic>, id: docId(d)))
        .toList();
  }

  static String docId(DocumentSnapshot d) => d.id;

  @override
  Future<Room?> getRoom(String id) async {
    final doc = await _rooms.doc(id).get();
    if (!doc.exists) return null;
    return Room.fromJson(doc.data() as Map<String, dynamic>, id: doc.id);
  }

  @override
  Future<void> createRoom(Room room) async {
    final data = room.toJson();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _rooms.doc(room.id).set(data);
  }

  @override
  Future<void> updateRoom(Room room) async {
    final data = room.toJson();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _rooms.doc(room.id).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> deleteRoom(String id) async {
    await _rooms.doc(id).delete();
  }

  // ==================== TimeSlots ====================
  @override
  Future<List<TimeSlot>> getTimeSlots(String collegeId) async {
    if (collegeId.isEmpty) return [];
    _logGenerationFirestore(
      operation: 'query',
      path: '/timeSlots',
      tenantId: collegeId,
      purpose: 'loading time slots',
    );
    final snap = await _timeSlots.where('collegeId', isEqualTo: collegeId).get();
    if (snap.docs.isNotEmpty) {
      final slots = snap.docs
          .map((d) => TimeSlot.fromJson(d.data() as Map<String, dynamic>, id: d.id))
          .toList();
      slots.sort((a, b) => a.order.compareTo(b.order));
      return slots;
    }

    // Check collegeSettings/settings document
    final settingsDoc = await _collegeSettings.doc('settings').get();
    if (settingsDoc.exists && settingsDoc.data() != null) {
      final data = settingsDoc.data() as Map<String, dynamic>;
      final result = <TimeSlot>[];
      final periods = data['periods'] as List? ?? [];
      for (final p in periods) {
        if (p is Map<String, dynamic>) {
          result.add(TimeSlot(
            id: p['id'] as String? ?? 'p_${p['periodNumber']}',
            collegeId: collegeId,
            periodNumber: p['periodNumber'] as int? ?? 1,
            startTime: p['startTime'] as String? ?? '09:00',
            endTime: p['endTime'] as String? ?? '10:00',
            order: p['order'] as int? ?? (p['periodNumber'] as int? ?? 1),
            isBreak: false,
          ));
        }
      }
      final breaks = data['breaks'] as List? ?? [];
      for (final b in breaks) {
        if (b is Map<String, dynamic>) {
          result.add(TimeSlot(
            id: b['id'] as String? ?? 'break_${b['order'] ?? 1}',
            collegeId: collegeId,
            periodNumber: 0,
            startTime: b['startTime'] as String? ?? '11:00',
            endTime: b['endTime'] as String? ?? '11:15',
            order: b['order'] as int? ?? 3,
            isBreak: true,
            breakTitle: b['name'] as String? ?? b['title'] as String? ?? 'Break',
          ));
        }
      }
      result.sort((a, b) => a.order.compareTo(b.order));
      return result;
    }

    return [];
  }

  @override
  Future<void> saveTimeSlots(String collegeId, List<TimeSlot> slots) async {
    final batch = _firestore.batch();
    final existing = await _timeSlots.where('collegeId', isEqualTo: collegeId).get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final slot in slots) {
      batch.set(_timeSlots.doc(slot.id), slot.toJson());
    }
    await batch.commit();

    // Also sync to collection collegeSettings, document settings
    final academic = slots.where((s) => !s.isBreak).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final breaks = slots.where((s) => s.isBreak).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    List<String> workingDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    try {
      final colSnap = await _colleges.doc(collegeId).get();
      if (colSnap.exists && colSnap.data() != null) {
        final cData = colSnap.data() as Map<String, dynamic>;
        if (cData['workingDays'] != null) {
          workingDays = List<String>.from(cData['workingDays'] as List);
        }
      }
    } catch (_) {}

    await saveCollegeScheduleSettings(
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
  }

  @override
  Future<void> createTimeSlot(TimeSlot slot) async {
    await _timeSlots.doc(slot.id).set(slot.toJson());
  }

  @override
  Future<void> updateTimeSlot(TimeSlot slot) async {
    await _timeSlots.doc(slot.id).update(slot.toJson());
  }

  @override
  Future<void> deleteTimeSlot(String id) async {
    await _timeSlots.doc(id).delete();
  }

  // ==================== College Schedule Settings ====================
  @override
  Future<Map<String, dynamic>?> getCollegeScheduleSettings({String? collegeId}) async {
    _logGenerationFirestore(
      operation: 'get',
      path: '/collegeSettings/settings',
      tenantId: collegeId ?? '',
      purpose: 'loading college schedule settings',
    );
    final doc = await _collegeSettings.doc('settings').get();
    if (doc.exists && doc.data() != null) {
      return doc.data() as Map<String, dynamic>;
    }
    return null;
  }

  @override
  Future<void> saveCollegeScheduleSettings({
    required List<String> workingDays,
    required int periodsPerDay,
    required List<Map<String, dynamic>> periods,
    required List<Map<String, dynamic>> breaks,
    String? collegeId,
  }) async {
    final data = {
      'workingDays': workingDays,
      'periodsPerDay': periodsPerDay,
      'periods': periods,
      'breaks': breaks,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _collegeSettings.doc('settings').set(data, SetOptions(merge: true));
    if (collegeId != null) {
      try {
        await _colleges.doc(collegeId).set({'workingDays': workingDays}, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  // ==================== Teacher Availability ====================
  @override
  Future<List<TeacherAvailability>> getTeacherAvailability(String collegeId, {String? teacherId}) async {
    if (collegeId.isEmpty) return [];
    _logGenerationFirestore(
      operation: 'query',
      path: '/teacherAvailability',
      tenantId: collegeId,
      purpose: 'loading teacher availability',
    );
    Query q = _teacherAvailability.where('collegeId', isEqualTo: collegeId);
    if (teacherId != null) {
      q = q.where('teacherId', isEqualTo: teacherId);
    }
    final snap = await q.get();
    return snap.docs
        .map((d) => TeacherAvailability.fromJson(d.data() as Map<String, dynamic>, id: d.id))
        .toList();
  }

  @override
  Future<void> setTeacherAvailability(TeacherAvailability availability) async {
    await _teacherAvailability.doc(availability.id).set(availability.toJson());
  }

  @override
  Future<void> saveBulkAvailability(List<TeacherAvailability> availabilities) async {
    final batch = _firestore.batch();
    for (final a in availabilities) {
      batch.set(_teacherAvailability.doc(a.id), a.toJson());
    }
    await batch.commit();
  }

  @override
  Future<void> markTeacherLeave(TeacherAvailability leave) async {
    await _teacherAvailability.doc(leave.id).set(leave.toJson());
  }

  // ==================== Timetable Versions ====================
  @override
  Future<List<TimetableVersion>> getTimetableVersions(String collegeId) async {
    if (collegeId.isEmpty) return [];
    _logGenerationFirestore(
      operation: 'query',
      path: '/timetableVersions',
      tenantId: collegeId,
      purpose: 'loading existing timetable versions',
    );
    final snap = await _timetableVersions.where('collegeId', isEqualTo: collegeId).get();
    final list = snap.docs
        .map((d) => TimetableVersion.fromJson(d.data() as Map<String, dynamic>, id: d.id))
        .toList();
    list.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return list;
  }

  @override
  Future<TimetableVersion?> getActivePublishedVersion(String collegeId) async {
    if (collegeId.isEmpty) return null;
    final snap = await _timetableVersions
        .where('collegeId', isEqualTo: collegeId)
        .where('isCurrentPublished', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return TimetableVersion.fromJson(snap.docs.first.data() as Map<String, dynamic>, id: snap.docs.first.id);
  }

  @override
  Future<void> createTimetableVersion(TimetableVersion version) async {
    _logGenerationFirestore(
      operation: 'set',
      path: '/timetableVersions/${version.id}',
      tenantId: version.collegeId,
      purpose: 'saving generated timetable version metadata',
    );
    await _timetableVersions.doc(version.id).set(version.toJson());
  }

  @override
  Future<void> updateTimetableVersion(TimetableVersion version) async {
    await _timetableVersions.doc(version.id).update(version.toJson());
  }

  @override
  Future<void> publishTimetableVersion(
    String collegeId,
    String versionId,
    String publishedBy, {
    String? changeLog,
  }) async {
    final batch = _firestore.batch();

    // 1. Unpublish any previous published versions
    final prevPublished = await _timetableVersions
        .where('collegeId', isEqualTo: collegeId)
        .where('isCurrentPublished', isEqualTo: true)
        .get();
    for (final doc in prevPublished.docs) {
      batch.update(doc.reference, {'isCurrentPublished': false, 'status': 'archived'});
    }

    // 2. Mark this version as published
    batch.update(_timetableVersions.doc(versionId), {
      'isCurrentPublished': true,
      'status': 'published',
      'publishedAt': DateTime.now().toIso8601String(),
      'publishedBy': publishedBy,
      'changeLog': changeLog,
    });

    // 3. Mark all its entries as published
    final entries = await _timetableEntries
        .where('collegeId', isEqualTo: collegeId)
        .where('versionId', isEqualTo: versionId)
        .get();
    for (final doc in entries.docs) {
      batch.update(doc.reference, {'status': 'published'});
    }

    // 4. Create notification
    final notifDoc = _notifications.doc();
    batch.set(notifDoc, {
      'id': notifDoc.id,
      'collegeId': collegeId,
      'recipientRole': 'all',
      'title': 'Timetable Published',
      'message': 'Official college timetable has been published and is active.',
      'relatedType': 'timetable_published',
      'relatedId': versionId,
      'timestamp': DateTime.now().toIso8601String(),
      'isRead': false,
    });

    await batch.commit();
  }

  // ==================== Timetable Entries ====================
  @override
  Future<List<TimetableEntry>> getTimetableEntries(
    String collegeId, {
    String? versionId,
    String? sectionId,
    String? teacherId,
    String? roomId,
    String? status,
  }) async {
    if (collegeId.isEmpty) return [];
    _logGenerationFirestore(
      operation: 'query',
      path: '/timetableEntries',
      tenantId: collegeId,
      purpose: 'loading timetable entries${versionId != null ? ' for version $versionId' : ''}',
    );
    Query q = _timetableEntries.where('collegeId', isEqualTo: collegeId);
    if (versionId != null) q = q.where('versionId', isEqualTo: versionId);
    if (sectionId != null) q = q.where('sectionId', isEqualTo: sectionId);
    if (teacherId != null) q = q.where('teacherId', isEqualTo: teacherId);
    if (roomId != null) q = q.where('roomId', isEqualTo: roomId);
    if (status != null) q = q.where('status', isEqualTo: status);

    final snap = await q.get();
    return snap.docs
        .map((d) => TimetableEntry.fromJson(d.data() as Map<String, dynamic>, id: d.id))
        .toList();
  }

  @override
  Future<void> saveTimetableEntries(String collegeId, String versionId, List<TimetableEntry> entries) async {
    _logGenerationFirestore(
      operation: 'query',
      path: '/timetableEntries',
      tenantId: collegeId,
      purpose: 'querying existing entries for version $versionId before overwrite',
    );
    final existing = await _timetableEntries
        .where('collegeId', isEqualTo: collegeId)
        .where('versionId', isEqualTo: versionId)
        .get();

    final batch = _firestore.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final entry in entries) {
      final data = entry.toJson();
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      batch.set(_timetableEntries.doc(entry.id), data);
    }
    _logGenerationFirestore(
      operation: 'batch (delete ${existing.docs.length} / set ${entries.length})',
      path: '/timetableEntries',
      tenantId: collegeId,
      purpose: 'saving generated timetable entries',
    );
    await batch.commit();
  }

  @override
  Future<void> createTimetableEntry(TimetableEntry entry) async {
    final data = entry.toJson();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _timetableEntries.doc(entry.id).set(data);
  }

  @override
  Future<void> updateTimetableEntry(TimetableEntry entry) async {
    final data = entry.toJson();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _timetableEntries.doc(entry.id).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> deleteTimetableEntry(String id) async {
    await _timetableEntries.doc(id).delete();
  }

  @override
  Future<void> deleteTimetable(String collegeId, {String? versionId}) async {
    final batch = _firestore.batch();

    // 1. Delete timetable entries
    Query entriesQuery = _timetableEntries;
    if (collegeId.isNotEmpty) {
      entriesQuery = entriesQuery.where('collegeId', isEqualTo: collegeId);
    }
    if (versionId != null) {
      entriesQuery = entriesQuery.where('versionId', isEqualTo: versionId);
    }
    final entriesSnap = await entriesQuery.get();
    for (final doc in entriesSnap.docs) {
      batch.delete(doc.reference);
    }

    // 2. Delete timetable version(s)
    Query versionsQuery = _timetableVersions;
    if (collegeId.isNotEmpty) {
      versionsQuery = versionsQuery.where('collegeId', isEqualTo: collegeId);
    }
    if (versionId != null) {
      versionsQuery = versionsQuery.where('id', isEqualTo: versionId);
    }
    final versionsSnap = await versionsQuery.get();
    for (final doc in versionsSnap.docs) {
      batch.delete(doc.reference);
    }

    // 3. Clear conflicts
    if (collegeId.isNotEmpty) {
      final conflictsSnap = await _conflicts.where('collegeId', isEqualTo: collegeId).get();
      for (final doc in conflictsSnap.docs) {
        batch.delete(doc.reference);
      }
    }

    await batch.commit();
  }

  // ==================== Conflicts ====================
  @override
  Future<List<ConflictItem>> getConflicts(String collegeId) async {
    if (collegeId.isEmpty) return [];
    _logGenerationFirestore(
      operation: 'query',
      path: '/conflicts',
      tenantId: collegeId,
      purpose: 'loading conflicts from conflict center',
    );
    final snap = await _conflicts.where('collegeId', isEqualTo: collegeId).get();
    return snap.docs
        .map((d) => ConflictItem.fromJson(d.data() as Map<String, dynamic>, id: d.id))
        .toList();
  }

  @override
  Future<void> saveConflicts(String collegeId, List<ConflictItem> conflicts) async {
    if (collegeId.isEmpty) return;
    _logGenerationFirestore(
      operation: 'query',
      path: '/conflicts',
      tenantId: collegeId,
      purpose: 'querying existing conflicts before overwrite',
    );
    final existing = await _conflicts.where('collegeId', isEqualTo: collegeId).get();
    final batch = _firestore.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final c in conflicts) {
      batch.set(_conflicts.doc(c.id), c.toJson());
    }
    _logGenerationFirestore(
      operation: 'batch (delete ${existing.docs.length} / set ${conflicts.length})',
      path: '/conflicts',
      tenantId: collegeId,
      purpose: 'saving timetable conflicts to conflict center',
    );
    await batch.commit();
  }

  @override
  Future<void> clearConflicts(String collegeId) async {
    if (collegeId.isEmpty) return;
    final existing = await _conflicts.where('collegeId', isEqualTo: collegeId).get();
    final batch = _firestore.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ==================== Notifications ====================
  @override
  Future<List<NotificationItem>> getNotifications(String collegeId, {String? userId, String? role}) async {
    if (collegeId.isEmpty) return [];
    final snap = await _notifications.where('collegeId', isEqualTo: collegeId).get();
    final list = snap.docs
        .map((d) => NotificationItem.fromJson(d.data() as Map<String, dynamic>, id: d.id))
        .where((n) {
          if (n.recipientRole == 'all') return true;
          if (role != null && n.recipientRole == role) return true;
          if (userId != null && n.recipientUserId == userId) return true;
          return false;
        })
        .toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  @override
  Future<void> createNotification(NotificationItem notification) async {
    await _notifications.doc(notification.id).set(notification.toJson());
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await _notifications.doc(id).update({'isRead': true});
  }

  @override
  Stream<List<TimetableEntry>> watchTimetableEntries(String collegeId, {String? versionId}) {
    if (collegeId.isEmpty) return Stream.value([]);
    Query q = _timetableEntries.where('collegeId', isEqualTo: collegeId);
    if (versionId != null) {
      q = q.where('versionId', isEqualTo: versionId);
    }
    return q.snapshots().map((snap) => snap.docs
        .map((d) => TimetableEntry.fromJson(d.data() as Map<String, dynamic>, id: d.id))
        .toList());
  }

  @override
  Stream<List<NotificationItem>> watchNotifications(String collegeId, {String? userId, String? role}) {
    if (collegeId.isEmpty) return Stream.value([]);
    return _notifications
        .where('collegeId', isEqualTo: collegeId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => NotificationItem.fromJson(d.data() as Map<String, dynamic>, id: d.id))
          .where((n) {
            if (n.recipientRole == 'all') return true;
            if (role != null && n.recipientRole == role) return true;
            if (userId != null && n.recipientUserId == userId) return true;
            return false;
          })
          .toList();
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list;
    });
  }
}
