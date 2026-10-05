import '../models/models.dart';

abstract class DatabaseRepository {
  // Colleges
  Future<List<College>> getColleges();
  Future<College?> getCollege(String id);
  Future<void> createCollege(College college);
  Future<void> updateCollege(College college);
  Future<void> deleteCollege(String id);

  // Departments
  Future<List<Department>> getDepartments(String collegeId);
  Future<void> createDepartment(Department department);
  Future<void> updateDepartment(Department department);
  Future<void> deleteDepartment(String id);

  // Courses
  Future<List<Course>> getCourses(String collegeId);
  Future<void> createCourse(Course course);
  Future<void> updateCourse(Course course);
  Future<void> deleteCourse(String id);

  // Sections
  Future<List<Section>> getSections(String collegeId);
  Future<Section?> getSection(String id);
  Future<void> createSection(Section section);
  Future<void> updateSection(Section section);
  Future<void> deleteSection(String id);

  // Staff
  Future<List<Staff>> getStaffList(String collegeId);
  Future<Staff?> getStaff(String id);
  Future<Staff?> getStaffByEmail(String email);
  Future<Staff?> getStaffByUserId(String userId);
  Future<void> createStaff(Staff staff);
  Future<void> updateStaff(Staff staff);
  Future<void> deleteStaff(String id);
  Future<void> linkStaffToAuth(String staffId, String userId);

  // Subjects
  Future<List<Subject>> getSubjects(String collegeId);
  Future<Subject?> getSubject(String id);
  Future<void> createSubject(Subject subject);
  Future<void> updateSubject(Subject subject);
  Future<void> deleteSubject(String id);

  // Rooms
  Future<List<Room>> getRooms(String collegeId);
  Future<Room?> getRoom(String id);
  Future<void> createRoom(Room room);
  Future<void> updateRoom(Room room);
  Future<void> deleteRoom(String id);

  // TimeSlots & College Schedule Settings
  Future<List<TimeSlot>> getTimeSlots(String collegeId);
  Future<void> saveTimeSlots(String collegeId, List<TimeSlot> slots);
  Future<void> createTimeSlot(TimeSlot slot);
  Future<void> updateTimeSlot(TimeSlot slot);
  Future<void> deleteTimeSlot(String id);

  // College Schedule Settings (collection: collegeSettings, stable doc: settings)
  Future<Map<String, dynamic>?> getCollegeScheduleSettings({String? collegeId});
  Future<void> saveCollegeScheduleSettings({
    required List<String> workingDays,
    required int periodsPerDay,
    required List<Map<String, dynamic>> periods,
    required List<Map<String, dynamic>> breaks,
    String? collegeId,
  });

  // Teacher Availability
  Future<List<TeacherAvailability>> getTeacherAvailability(String collegeId, {String? teacherId});
  Future<void> setTeacherAvailability(TeacherAvailability availability);
  Future<void> saveBulkAvailability(List<TeacherAvailability> availabilities);
  Future<void> markTeacherLeave(TeacherAvailability leave);

  // Timetable Versions
  Future<List<TimetableVersion>> getTimetableVersions(String collegeId);
  Future<TimetableVersion?> getActivePublishedVersion(String collegeId);
  Future<void> createTimetableVersion(TimetableVersion version);
  Future<void> updateTimetableVersion(TimetableVersion version);
  Future<void> publishTimetableVersion(String collegeId, String versionId, String publishedBy, {String? changeLog});

  // Timetable Entries
  Future<List<TimetableEntry>> getTimetableEntries(
    String collegeId, {
    String? versionId,
    String? sectionId,
    String? teacherId,
    String? roomId,
    String? status,
  });
  Future<void> saveTimetableEntries(String collegeId, String versionId, List<TimetableEntry> entries);
  Future<void> createTimetableEntry(TimetableEntry entry);
  Future<void> updateTimetableEntry(TimetableEntry entry);
  Future<void> deleteTimetableEntry(String id);
  Future<void> deleteTimetable(String collegeId, {String? versionId});

  // Conflicts
  Future<List<ConflictItem>> getConflicts(String collegeId);
  Future<void> saveConflicts(String collegeId, List<ConflictItem> conflicts);
  Future<void> clearConflicts(String collegeId);

  // Notifications
  Future<List<NotificationItem>> getNotifications(String collegeId, {String? userId, String? role});
  Future<void> createNotification(NotificationItem notification);
  Future<void> markNotificationRead(String id);

  // Stream triggers / listeners
  Stream<List<TimetableEntry>> watchTimetableEntries(String collegeId, {String? versionId});
  Stream<List<NotificationItem>> watchNotifications(String collegeId, {String? userId, String? role});
}
