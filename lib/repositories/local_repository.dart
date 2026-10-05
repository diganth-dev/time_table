import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'auth_repository.dart';
import 'database_repository.dart';

class LocalDatabaseRepository implements DatabaseRepository {
  static final LocalDatabaseRepository _instance = LocalDatabaseRepository._internal();
  factory LocalDatabaseRepository() => _instance;

  LocalDatabaseRepository._internal();

  final _uuid = const Uuid();

  final List<College> _colleges = [];
  final List<Department> _departments = [];
  final List<Course> _courses = [];
  final List<Section> _sections = [];
  final List<Staff> _staff = [];
  final List<Subject> _subjects = [];
  final List<Room> _rooms = [];
  final List<TimeSlot> _timeSlots = [];
  final List<TeacherAvailability> _availabilities = [];
  final List<TimetableVersion> _timetableVersions = [];
  final List<TimetableEntry> _timetableEntries = [];
  final List<ConflictItem> _conflicts = [];
  final List<NotificationItem> _notifications = [];
  Map<String, dynamic>? _collegeSettingsDoc;

  final _entriesController = StreamController<List<TimetableEntry>>.broadcast();
  final _notificationsController = StreamController<List<NotificationItem>>.broadcast();

  void _notifyEntries() {
    _entriesController.add(List.unmodifiable(_timetableEntries));
  }

  void _notifyNotifications() {
    _notificationsController.add(List.unmodifiable(_notifications));
  }

  // ==================== Colleges ====================
  @override
  Future<List<College>> getColleges() async => List.unmodifiable(_colleges);

  @override
  Future<College?> getCollege(String id) async {
    final idx = _colleges.indexWhere((c) => c.id == id);
    if (idx != -1) {
      if (_collegeSettingsDoc != null && _collegeSettingsDoc!['workingDays'] != null) {
        final settingsDays = List<String>.from(_collegeSettingsDoc!['workingDays'] as List);
        return _colleges[idx].copyWith(workingDays: settingsDays);
      }
      return _colleges[idx];
    }
    // Return default college so the active college is never null
    final defaultDays = _collegeSettingsDoc?['workingDays'] != null
        ? List<String>.from(_collegeSettingsDoc!['workingDays'] as List)
        : ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
    final defaultCol = College(
      id: id,
      name: 'University College',
      code: 'UC',
      workingDays: defaultDays,
    );
    _colleges.add(defaultCol);
    return defaultCol;
  }

  @override
  Future<void> createCollege(College college) async {
    final idx = _colleges.indexWhere((c) => c.id == college.id);
    if (idx != -1) {
      _colleges[idx] = college;
    } else {
      _colleges.add(college);
    }
  }

  @override
  Future<void> updateCollege(College college) async {
    final idx = _colleges.indexWhere((c) => c.id == college.id);
    if (idx != -1) {
      _colleges[idx] = college;
    } else {
      _colleges.add(college);
    }
    if (_collegeSettingsDoc != null) {
      _collegeSettingsDoc!['workingDays'] = college.workingDays;
    } else {
      _collegeSettingsDoc = {
        'workingDays': college.workingDays,
        'periodsPerDay': 0,
        'periods': [],
        'breaks': [],
        'updatedAt': DateTime.now(),
      };
    }
  }

  @override
  Future<void> deleteCollege(String id) async {
    _colleges.removeWhere((c) => c.id == id);
  }

  // ==================== Departments ====================
  @override
  Future<List<Department>> getDepartments(String collegeId) async {
    return _departments.where((d) => d.collegeId == collegeId).toList();
  }

  @override
  Future<void> createDepartment(Department department) async {
    _departments.add(department);
  }

  @override
  Future<void> updateDepartment(Department department) async {
    final idx = _departments.indexWhere((d) => d.id == department.id);
    if (idx != -1) _departments[idx] = department;
  }

  @override
  Future<void> deleteDepartment(String id) async {
    _departments.removeWhere((d) => d.id == id);
  }

  // ==================== Courses ====================
  @override
  Future<List<Course>> getCourses(String collegeId) async {
    return _courses.where((c) => c.collegeId == collegeId).toList();
  }

  @override
  Future<void> createCourse(Course course) async {
    _courses.add(course);
  }

  @override
  Future<void> updateCourse(Course course) async {
    final idx = _courses.indexWhere((c) => c.id == course.id);
    if (idx != -1) _courses[idx] = course;
  }

  @override
  Future<void> deleteCourse(String id) async {
    _courses.removeWhere((c) => c.id == id);
  }

  // ==================== Sections ====================
  @override
  Future<List<Section>> getSections(String collegeId) async {
    return _sections.where((s) => s.collegeId == collegeId).toList();
  }

  @override
  Future<Section?> getSection(String id) async {
    final idx = _sections.indexWhere((s) => s.id == id);
    return idx != -1 ? _sections[idx] : null;
  }

  @override
  Future<void> createSection(Section section) async {
    _sections.add(section);
  }

  @override
  Future<void> updateSection(Section section) async {
    final idx = _sections.indexWhere((s) => s.id == section.id);
    if (idx != -1) _sections[idx] = section;
  }

  @override
  Future<void> deleteSection(String id) async {
    _sections.removeWhere((s) => s.id == id);
    _subjects.removeWhere((s) => s.sectionId == id);
    _timetableEntries.removeWhere((e) => e.sectionId == id);
    _notifyEntries();
  }

  // ==================== Staff ====================
  @override
  Future<List<Staff>> getStaffList(String collegeId) async {
    return _staff.where((s) => s.collegeId == collegeId).toList();
  }

  @override
  Future<Staff?> getStaff(String id) async {
    final idx = _staff.indexWhere((s) => s.id == id);
    return idx != -1 ? _staff[idx] : null;
  }

  @override
  Future<Staff?> getStaffByEmail(String email) async {
    final idx = _staff.indexWhere((s) => s.email.toLowerCase().trim() == email.toLowerCase().trim());
    return idx != -1 ? _staff[idx] : null;
  }

  @override
  Future<Staff?> getStaffByUserId(String userId) async {
    final idx = _staff.indexWhere((s) => s.userId == userId);
    return idx != -1 ? _staff[idx] : null;
  }

  @override
  Future<void> createStaff(Staff staff) async {
    _staff.add(staff);
  }

  @override
  Future<void> updateStaff(Staff staff) async {
    final idx = _staff.indexWhere((s) => s.id == staff.id);
    if (idx != -1) _staff[idx] = staff;
  }

  @override
  Future<void> deleteStaff(String id) async {
    _staff.removeWhere((s) => s.id == id);
  }

  @override
  Future<void> linkStaffToAuth(String staffId, String userId) async {
    final idx = _staff.indexWhere((s) => s.id == staffId);
    if (idx != -1) {
      _staff[idx] = _staff[idx].copyWith(
        userId: userId,
        status: 'active',
      );
    }
  }

  // ==================== Subjects ====================
  @override
  Future<List<Subject>> getSubjects(String collegeId) async {
    return _subjects.where((s) => s.collegeId == collegeId).toList();
  }

  @override
  Future<Subject?> getSubject(String id) async {
    final idx = _subjects.indexWhere((s) => s.id == id);
    return idx != -1 ? _subjects[idx] : null;
  }

  @override
  Future<void> createSubject(Subject subject) async {
    _subjects.add(subject);
  }

  @override
  Future<void> updateSubject(Subject subject) async {
    final idx = _subjects.indexWhere((s) => s.id == subject.id);
    if (idx != -1) _subjects[idx] = subject;
  }

  @override
  Future<void> deleteSubject(String id) async {
    _subjects.removeWhere((s) => s.id == id);
  }

  // ==================== Rooms ====================
  @override
  Future<List<Room>> getRooms(String collegeId) async {
    return _rooms.where((r) => r.collegeId == collegeId).toList();
  }

  @override
  Future<Room?> getRoom(String id) async {
    final idx = _rooms.indexWhere((r) => r.id == id);
    return idx != -1 ? _rooms[idx] : null;
  }

  @override
  Future<void> createRoom(Room room) async {
    _rooms.add(room);
  }

  @override
  Future<void> updateRoom(Room room) async {
    final idx = _rooms.indexWhere((r) => r.id == room.id);
    if (idx != -1) _rooms[idx] = room;
  }

  @override
  Future<void> deleteRoom(String id) async {
    _rooms.removeWhere((r) => r.id == id);
  }

  // ==================== TimeSlots ====================
  @override
  Future<List<TimeSlot>> getTimeSlots(String collegeId) async {
    final existing = _timeSlots.where((t) => t.collegeId == collegeId).toList();
    if (existing.isNotEmpty) {
      existing.sort((a, b) => a.order.compareTo(b.order));
      return existing;
    }

    if (_collegeSettingsDoc != null) {
      final data = _collegeSettingsDoc!;
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
    _timeSlots.removeWhere((t) => t.collegeId == collegeId);
    _timeSlots.addAll(slots);

    final academic = slots.where((s) => !s.isBreak).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final breaks = slots.where((s) => s.isBreak).toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    final col = await getCollege(collegeId);
    final workingDays = col?.workingDays ?? ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

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
    _timeSlots.add(slot);
  }

  @override
  Future<void> updateTimeSlot(TimeSlot slot) async {
    final idx = _timeSlots.indexWhere((t) => t.id == slot.id);
    if (idx != -1) _timeSlots[idx] = slot;
  }

  @override
  Future<void> deleteTimeSlot(String id) async {
    _timeSlots.removeWhere((t) => t.id == id);
  }

  // ==================== College Schedule Settings ====================
  @override
  Future<Map<String, dynamic>?> getCollegeScheduleSettings({String? collegeId}) async {
    return _collegeSettingsDoc;
  }

  @override
  Future<void> saveCollegeScheduleSettings({
    required List<String> workingDays,
    required int periodsPerDay,
    required List<Map<String, dynamic>> periods,
    required List<Map<String, dynamic>> breaks,
    String? collegeId,
  }) async {
    _collegeSettingsDoc = {
      'workingDays': workingDays,
      'periodsPerDay': periodsPerDay,
      'periods': periods,
      'breaks': breaks,
      'updatedAt': DateTime.now(),
    };
    if (collegeId != null) {
      final idx = _colleges.indexWhere((c) => c.id == collegeId);
      if (idx != -1) {
        _colleges[idx] = _colleges[idx].copyWith(workingDays: workingDays);
      } else {
        _colleges.add(College(
          id: collegeId,
          name: 'University College',
          code: 'UC',
          workingDays: workingDays,
        ));
      }
    }
  }

  // ==================== Teacher Availability ====================
  @override
  Future<List<TeacherAvailability>> getTeacherAvailability(String collegeId, {String? teacherId}) async {
    return _availabilities.where((a) {
      if (a.collegeId != collegeId) return false;
      if (teacherId != null && a.teacherId != teacherId) return false;
      return true;
    }).toList();
  }

  @override
  Future<void> setTeacherAvailability(TeacherAvailability availability) async {
    final idx = _availabilities.indexWhere((a) =>
        a.collegeId == availability.collegeId &&
        a.teacherId == availability.teacherId &&
        a.dayOfWeek == availability.dayOfWeek &&
        a.periodNumber == availability.periodNumber);
    if (idx != -1) {
      _availabilities[idx] = availability;
    } else {
      _availabilities.add(availability);
    }
  }

  @override
  Future<void> saveBulkAvailability(List<TeacherAvailability> availabilities) async {
    for (final a in availabilities) {
      await setTeacherAvailability(a);
    }
  }

  @override
  Future<void> markTeacherLeave(TeacherAvailability leave) async {
    _availabilities.add(leave);
  }

  // ==================== Timetable Versions ====================
  @override
  Future<List<TimetableVersion>> getTimetableVersions(String collegeId) async {
    return _timetableVersions.where((v) => v.collegeId == collegeId).toList()
      ..sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
  }

  @override
  Future<TimetableVersion?> getActivePublishedVersion(String collegeId) async {
    final published = _timetableVersions
        .where((v) => v.collegeId == collegeId && v.isPublished)
        .toList();
    if (published.isEmpty) return null;
    published.sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return published.first;
  }

  @override
  Future<void> createTimetableVersion(TimetableVersion version) async {
    _timetableVersions.add(version);
  }

  @override
  Future<void> updateTimetableVersion(TimetableVersion version) async {
    final idx = _timetableVersions.indexWhere((v) => v.id == version.id);
    if (idx != -1) _timetableVersions[idx] = version;
  }

  @override
  Future<void> publishTimetableVersion(
    String collegeId,
    String versionId,
    String publishedBy, {
    String? changeLog,
  }) async {
    // Unmark any currently published version for this college
    for (var i = 0; i < _timetableVersions.length; i++) {
      if (_timetableVersions[i].collegeId == collegeId &&
          _timetableVersions[i].isCurrentPublished) {
        _timetableVersions[i] = _timetableVersions[i].copyWith(
          isCurrentPublished: false,
          status: 'archived',
        );
      }
    }

    // Mark the selected version as published
    final idx = _timetableVersions.indexWhere((v) => v.id == versionId);
    if (idx != -1) {
      _timetableVersions[idx] = _timetableVersions[idx].copyWith(
        isCurrentPublished: true,
        status: 'published',
        publishedAt: DateTime.now(),
        publishedBy: publishedBy,
        changeLog: changeLog,
      );
    }

    // Mark all entries for this version as published
    for (var i = 0; i < _timetableEntries.length; i++) {
      if (_timetableEntries[i].versionId == versionId) {
        _timetableEntries[i] = _timetableEntries[i].copyWith(status: 'published');
      }
    }

    // Send broadcast notification to students and teachers
    final notif = NotificationItem(
      id: _uuid.v4(),
      collegeId: collegeId,
      recipientRole: 'all',
      title: 'Timetable Published: ${_timetableVersions[idx].name}',
      message: 'A new timetable version has been officially published and is now in effect.',
      relatedType: 'timetable_published',
      relatedId: versionId,
      timestamp: DateTime.now(),
    );
    await createNotification(notif);
    _notifyEntries();
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
    return _timetableEntries.where((e) {
      if (e.collegeId != collegeId) return false;
      if (versionId != null && e.versionId != versionId) return false;
      if (sectionId != null && e.sectionId != sectionId) return false;
      if (teacherId != null && e.teacherId != teacherId) return false;
      if (roomId != null && e.roomId != roomId) return false;
      if (status != null && e.status != status) return false;
      return true;
    }).toList();
  }

  @override
  Future<void> saveTimetableEntries(String collegeId, String versionId, List<TimetableEntry> entries) async {
    _timetableEntries.removeWhere((e) => e.collegeId == collegeId && e.versionId == versionId);
    _timetableEntries.addAll(entries);
    _notifyEntries();
  }

  @override
  Future<void> createTimetableEntry(TimetableEntry entry) async {
    final idx = _timetableEntries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) {
      _timetableEntries[idx] = entry;
    } else {
      _timetableEntries.add(entry);
    }
    _notifyEntries();
  }

  @override
  Future<void> updateTimetableEntry(TimetableEntry entry) async {
    final idx = _timetableEntries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) {
      _timetableEntries[idx] = entry;
    } else {
      _timetableEntries.add(entry);
    }
    _notifyEntries();
  }

  @override
  Future<void> deleteTimetableEntry(String id) async {
    _timetableEntries.removeWhere((e) => e.id == id);
    _notifyEntries();
  }

  @override
  Future<void> deleteTimetable(String collegeId, {String? versionId}) async {
    _timetableEntries.removeWhere((e) =>
        e.collegeId == collegeId && (versionId == null || e.versionId == versionId));
    _timetableVersions.removeWhere((v) =>
        v.collegeId == collegeId && (versionId == null || v.id == versionId));
    _conflicts.removeWhere((c) => c.collegeId == collegeId);
    _notifyEntries();
  }

  // ==================== Conflicts ====================
  @override
  Future<List<ConflictItem>> getConflicts(String collegeId) async {
    return _conflicts.where((c) => c.collegeId == collegeId).toList();
  }

  @override
  Future<void> saveConflicts(String collegeId, List<ConflictItem> conflicts) async {
    _conflicts.removeWhere((c) => c.collegeId == collegeId);
    _conflicts.addAll(conflicts);
  }

  @override
  Future<void> clearConflicts(String collegeId) async {
    _conflicts.removeWhere((c) => c.collegeId == collegeId);
  }

  // ==================== Notifications ====================
  @override
  Future<List<NotificationItem>> getNotifications(String collegeId, {String? userId, String? role}) async {
    return _notifications.where((n) {
      if (n.collegeId != collegeId) return false;
      if (n.recipientRole == 'all') return true;
      if (role != null && n.recipientRole == role) return true;
      if (userId != null && n.recipientUserId == userId) return true;
      return false;
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  @override
  Future<void> createNotification(NotificationItem notification) async {
    _notifications.add(notification);
    _notifyNotifications();
  }

  @override
  Future<void> markNotificationRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      _notifyNotifications();
    }
  }

  @override
  Stream<List<TimetableEntry>> watchTimetableEntries(String collegeId, {String? versionId}) {
    return _entriesController.stream.map((entries) {
      return entries.where((e) {
        if (e.collegeId != collegeId) return false;
        if (versionId != null && e.versionId != versionId) return false;
        return true;
      }).toList();
    });
  }

  @override
  Stream<List<NotificationItem>> watchNotifications(String collegeId, {String? userId, String? role}) {
    return _notificationsController.stream.map((notifs) {
      return notifs.where((n) {
        if (n.collegeId != collegeId) return false;
        if (n.recipientRole == 'all') return true;
        if (role != null && n.recipientRole == role) return true;
        if (userId != null && n.recipientUserId == userId) return true;
        return false;
      }).toList();
    });
  }

  /// Bulk seed helper for the large production scenario:
  /// 5 departments, 20 sections, 100 teachers, 80 rooms, 10 laboratories, 500 subjects/classes
  Future<void> seedLargeScenario(String collegeId) async {
    // Clear existing for this college
    _departments.removeWhere((d) => d.collegeId == collegeId);
    _courses.removeWhere((c) => c.collegeId == collegeId);
    _sections.removeWhere((s) => s.collegeId == collegeId);
    _staff.removeWhere((s) => s.collegeId == collegeId);
    _rooms.removeWhere((r) => r.collegeId == collegeId);
    _subjects.removeWhere((s) => s.collegeId == collegeId);
    _timeSlots.removeWhere((t) => t.collegeId == collegeId);

    // Seed academic periods for this college
    final standardSlots = [
      TimeSlot(id: 'ts_${collegeId}_1', collegeId: collegeId, periodNumber: 1, startTime: '09:00', endTime: '10:00', order: 1),
      TimeSlot(id: 'ts_${collegeId}_2', collegeId: collegeId, periodNumber: 2, startTime: '10:00', endTime: '11:00', order: 2),
      TimeSlot(id: 'ts_${collegeId}_b1', collegeId: collegeId, periodNumber: 0, breakTitle: 'Short Break', startTime: '11:00', endTime: '11:15', isBreak: true, order: 3),
      TimeSlot(id: 'ts_${collegeId}_3', collegeId: collegeId, periodNumber: 3, startTime: '11:15', endTime: '12:15', order: 4),
      TimeSlot(id: 'ts_${collegeId}_4', collegeId: collegeId, periodNumber: 4, startTime: '12:15', endTime: '13:15', order: 5),
      TimeSlot(id: 'ts_${collegeId}_b2', collegeId: collegeId, periodNumber: 0, breakTitle: 'Lunch Break', startTime: '13:15', endTime: '14:00', isBreak: true, order: 6),
      TimeSlot(id: 'ts_${collegeId}_5', collegeId: collegeId, periodNumber: 5, startTime: '14:00', endTime: '15:00', order: 7),
      TimeSlot(id: 'ts_${collegeId}_6', collegeId: collegeId, periodNumber: 6, startTime: '15:00', endTime: '16:00', order: 8),
    ];
    _timeSlots.addAll(standardSlots);

    // 5 Departments
    final deptNames = [
      {'code': 'CSE', 'name': 'Computer Science & Engineering'},
      {'code': 'ECE', 'name': 'Electronics & Communication Engineering'},
      {'code': 'ME', 'name': 'Mechanical Engineering'},
      {'code': 'CE', 'name': 'Civil Engineering'},
      {'code': 'ISE', 'name': 'Information Science & Engineering'},
    ];

    for (var i = 0; i < deptNames.length; i++) {
      final code = deptNames[i]['code']!;
      final name = deptNames[i]['name']!;
      final deptId = 'dept_${collegeId}_${code.toLowerCase()}';
      _departments.add(Department(id: deptId, collegeId: collegeId, name: name, code: code));

      final courseId = 'course_${collegeId}_${code.toLowerCase()}';
      _courses.add(Course(id: courseId, collegeId: collegeId, departmentId: deptId, name: 'B.Tech in $name', code: 'BT-$code'));

      // 4 sections per department (4 * 5 = 20 sections)
      for (var sem in [3, 5]) {
        for (var secName in ['A', 'B']) {
          final secId = 'sec_${collegeId}_${code.toLowerCase()}_${sem}_$secName';
          _sections.add(Section(
            id: secId,
            collegeId: collegeId,
            departmentId: deptId,
            courseId: courseId,
            academicYear: '2026-2027',
            semester: sem,
            sectionName: secName,
            studentCount: 50 + (i * 2),
          ));
        }
      }
    }

    // 100 Teachers (20 per department)
    var teacherCounter = 1;
    for (var dept in _departments.where((d) => d.collegeId == collegeId)) {
      for (var t = 1; t <= 20; t++) {
        final staffId = 'staff_${collegeId}_${dept.code.toLowerCase()}_$t';
        final empId = 'EMP${teacherCounter.toString().padLeft(3, '0')}';
        _staff.add(Staff(
          id: staffId,
          collegeId: collegeId,
          employeeId: empId,
          name: 'Prof. ${dept.code} Faculty $t',
          email: 'faculty_${dept.code.toLowerCase()}_${t}_$collegeId@college.edu',
          departmentId: dept.id,
          designation: t <= 3 ? 'Professor' : (t <= 8 ? 'Associate Professor' : 'Assistant Professor'),
          role: t == 1 ? 'hod' : 'teacher',
          status: 'active',
          maxClassesPerDay: 4,
          maxClassesPerWeek: 20,
        ));
        teacherCounter++;
      }
    }

    // 80 Classrooms + 10 Laboratories = 90 rooms total
    for (var r = 1; r <= 80; r++) {
      _rooms.add(Room(
        id: 'room_${collegeId}_c_$r',
        collegeId: collegeId,
        roomNumber: 'CR-${100 + r}',
        building: r <= 40 ? 'Main Block' : 'Science Block',
        floor: ((r - 1) ~/ 20) + 1,
        capacity: 65,
        roomType: 'Classroom',
        facilities: ['Projector', 'Audio System'],
      ));
    }

    final labTypes = [
      'Computer Lab', 'Computer Lab', 'Computer Lab', 'Computer Lab',
      'Electronics Lab', 'Electronics Lab',
      'Mechanical Lab', 'Mechanical Lab',
      'Civil CAD Lab', 'Civil CAD Lab'
    ];
    for (var l = 0; l < labTypes.length; l++) {
      _rooms.add(Room(
        id: 'room_${collegeId}_lab_${l + 1}',
        collegeId: collegeId,
        roomNumber: 'LAB-${l + 1}',
        building: 'Tech Block',
        floor: ((l ~/ 4) + 1),
        capacity: 60,
        roomType: labTypes[l],
        facilities: ['Workstations', 'Specialized Hardware', 'AC'],
      ));
    }

    // Subjects and teacher assignments
    // For each department and semester, create subjects and assign qualified teachers
    for (var dept in _departments.where((d) => d.collegeId == collegeId)) {
      final deptStaff = _staff.where((s) => s.collegeId == collegeId && s.departmentId == dept.id).toList();

      for (var sem in [3, 5]) {
        final semOffset = sem == 3 ? 0 : 10;

        // 4 Theory subjects per semester
        for (var s = 1; s <= 4; s++) {
          final subjId = 'subj_${collegeId}_${dept.code.toLowerCase()}_${sem}_$s';
          final t1 = deptStaff[semOffset + (s - 1) * 2];
          final t2 = deptStaff[semOffset + (s - 1) * 2 + 1];

          final subj = Subject(
            id: subjId,
            collegeId: collegeId,
            departmentId: dept.id,
            courseId: 'course_${collegeId}_${dept.code.toLowerCase()}',
            semester: sem,
            subjectCode: '${dept.code}$sem${s}0',
            subjectName: '${dept.code} Course Subject $s',
            subjectType: 'Theory',
            hoursPerWeek: 4,
            requiredRoomType: 'Classroom',
            assignedTeacherIds: [t1.id, t2.id],
          );
          _subjects.add(subj);

          // Update both teachers' subjectsCanTeach
          for (final t in [t1, t2]) {
            final sIdx = _staff.indexWhere((st) => st.id == t.id);
            if (sIdx != -1) {
              _staff[sIdx] = _staff[sIdx].copyWith(
                subjectsCanTeach: [..._staff[sIdx].subjectsCanTeach, subjId],
              );
            }
          }
        }

        // 1 Lab subject per semester
        final labSubjId = 'subj_${collegeId}_${dept.code.toLowerCase()}_${sem}_lab';
        final labT1 = deptStaff[semOffset + 8];
        final labT2 = deptStaff[semOffset + 9];

        final reqRoom = dept.code == 'CSE' || dept.code == 'ISE'
            ? 'Computer Lab'
            : (dept.code == 'ECE'
                ? 'Electronics Lab'
                : (dept.code == 'ME'
                    ? 'Mechanical Lab'
                    : (dept.code == 'CE' ? 'Civil CAD Lab' : 'Classroom')));

        final labSubj = Subject(
          id: labSubjId,
          collegeId: collegeId,
          departmentId: dept.id,
          courseId: 'course_${collegeId}_${dept.code.toLowerCase()}',
          semester: sem,
          subjectCode: '${dept.code}$sem${9}L',
          subjectName: '${dept.code} Practical Lab',
          subjectType: 'Lab',
          hoursPerWeek: 2,
          consecutivePeriods: 2,
          requiredRoomType: reqRoom,
          assignedTeacherIds: [labT1.id, labT2.id],
        );
        _subjects.add(labSubj);

        for (final t in [labT1, labT2]) {
          final lIdx = _staff.indexWhere((st) => st.id == t.id);
          if (lIdx != -1) {
            _staff[lIdx] = _staff[lIdx].copyWith(
              subjectsCanTeach: [..._staff[lIdx].subjectsCanTeach, labSubjId],
            );
          }
        }
      }
    }
  }
}

class LocalAuthRepository implements AuthRepository {
  static final LocalAuthRepository _instance = LocalAuthRepository._internal();
  factory LocalAuthRepository() => _instance;
  LocalAuthRepository._internal();

  final _authStreamController = StreamController<UserProfile?>.broadcast();
  UserProfile? _currentUser;

  // Empty user list by default - no hardcoded users
  final List<UserProfile> _registeredUsers = [];

  @override
  Stream<UserProfile?> get authStateChanges => _authStreamController.stream;

  @override
  UserProfile? get currentUser => _currentUser;

  @override
  Future<UserProfile> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.toLowerCase().trim();
    final user = _registeredUsers.firstWhere(
      (u) => u.email.toLowerCase().trim() == cleanEmail,
      orElse: () {
        // If not found, create a sensible default user with unique collegeId
        final uid = 'usr_${DateTime.now().millisecondsSinceEpoch}';
        final newUser = UserProfile(
          id: uid,
          email: cleanEmail,
          name: cleanEmail.split('@').first,
          role: UserRole.collegeAdmin,
          collegeId: 'col_$uid',
        );
        _registeredUsers.add(newUser);
        return newUser;
      },
    );

    _currentUser = user;
    _authStreamController.add(user);
    return user;
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
    final cleanEmail = email.toLowerCase().trim();
    final uid = 'usr_${DateTime.now().microsecondsSinceEpoch}_${_registeredUsers.length}';
    final effectiveCollegeId = (collegeId != null && collegeId.trim().isNotEmpty)
        ? collegeId.trim()
        : 'col_$uid';
    final newUser = UserProfile(
      id: uid,
      email: cleanEmail,
      name: name,
      role: UserRole.collegeAdmin, // Admin-only application
      collegeId: effectiveCollegeId,
      departmentId: departmentId,
      sectionId: sectionId,
    );

    _registeredUsers.removeWhere((u) => u.email.toLowerCase().trim() == cleanEmail);
    _registeredUsers.add(newUser);

    _currentUser = newUser;
    _authStreamController.add(newUser);
    return newUser;
  }

  @override
  Future<UserProfile> completeStaffSignUp({
    required String email,
    required String password,
    required String name,
  }) async {
    final cleanEmail = email.toLowerCase().trim();
    final db = LocalDatabaseRepository();
    final staff = await db.getStaffByEmail(cleanEmail);

    if (staff == null) {
      throw Exception('No pending staff invitation found for $email. Contact college admin.');
    }

    final userId = 'usr_staff_${DateTime.now().millisecondsSinceEpoch}';
    final userProfile = UserProfile(
      id: userId,
      email: cleanEmail,
      name: name.isNotEmpty ? name : staff.name,
      role: UserRole.teacher,
      collegeId: staff.collegeId,
      departmentId: staff.departmentId,
      staffId: staff.id,
    );

    _registeredUsers.add(userProfile);
    await db.linkStaffToAuth(staff.id, userId);

    _currentUser = userProfile;
    _authStreamController.add(userProfile);
    return userProfile;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    // Simulated reset email
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authStreamController.add(null);
  }

  @override
  Future<void> updateUserProfile(UserProfile profile) async {
    final idx = _registeredUsers.indexWhere((u) => u.id == profile.id);
    if (idx != -1) {
      _registeredUsers[idx] = profile;
    } else {
      _registeredUsers.add(profile);
    }
    if (_currentUser?.id == profile.id) {
      _currentUser = profile;
      _authStreamController.add(profile);
    }
  }
}
