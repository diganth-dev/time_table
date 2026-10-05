import '../core/utils/subject_matcher.dart';
import 'time_slot.dart';

class UnavailableTime {
  final String dayOfWeek;
  final String startTime;
  final String endTime;

  const UnavailableTime({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory UnavailableTime.fromJson(Map<String, dynamic> json) {
    return UnavailableTime(
      dayOfWeek: json['dayOfWeek'] as String? ?? 'Monday',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  String get label => '$dayOfWeek $startTime - $endTime';

  /// Parses time string formats into minutes from midnight (0..1439).
  static int? parseTimeToMinutes(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) return null;

    final isPm = trimmed.contains('pm');
    final isAm = trimmed.contains('am');
    final cleaned = trimmed.replaceAll(RegExp(r'[^\d:]'), '');
    if (cleaned.isEmpty) return null;

    int hours = 0;
    int minutes = 0;

    if (cleaned.contains(':')) {
      final parts = cleaned.split(':');
      hours = int.tryParse(parts[0]) ?? 0;
      if (parts.length > 1) {
        minutes = int.tryParse(parts[1]) ?? 0;
      }
    } else {
      hours = int.tryParse(cleaned) ?? 0;
    }

    if (isPm) {
      if (hours < 12) hours += 12;
    } else if (isAm) {
      if (hours == 12) hours = 0;
    } else {
      // Intuitive college hour heuristic: 1-6 are PM (13:00 - 18:00), 7-12 are AM (07:00 - 12:00)
      if (hours >= 1 && hours <= 6) {
        hours += 12;
      }
    }

    if (hours < 0 || hours > 24 || minutes < 0 || minutes >= 60) return null;
    return hours * 60 + minutes;
  }

  /// Validates that From and To represent a valid non-empty time range where From < To.
  static String? validateTimeRange(String from, String to) {
    if (from.trim().isEmpty) return 'Please enter a "From" time.';
    if (to.trim().isEmpty) return 'Please enter a "To" time.';
    final start = parseTimeToMinutes(from);
    final end = parseTimeToMinutes(to);
    if (start == null) return 'Invalid "From" time format (e.g. 09:00 or 9:00 AM).';
    if (end == null) return 'Invalid "To" time format (e.g. 10:00 or 10:00 AM).';
    if (start >= end) return '"From" time must be earlier than "To" time.';
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnavailableTime &&
          runtimeType == other.runtimeType &&
          dayOfWeek == other.dayOfWeek &&
          startTime == other.startTime &&
          endTime == other.endTime;

  @override
  int get hashCode => dayOfWeek.hashCode ^ startTime.hashCode ^ endTime.hashCode;
}

class Staff {
  final String id;
  final String collegeId;
  final String? userId; // Linked Firebase Auth UID once registered
  final String employeeId;
  final String name;
  final String email;
  final String phone;
  final String departmentId;
  final String designation;
  final String role; // 'teacher', 'hod', 'lab_instructor'
  final String status; // 'invited', 'pending', 'active', 'inactive'
  final List<String> subjectsCanTeach; // Subject IDs
  final int maxClassesPerDay;
  final int maxClassesPerWeek;
  final List<int> preferredPeriodNumbers;
  final List<UnavailableTime> unavailableTimes;
  final bool active;

  Staff({
    required this.id,
    required this.collegeId,
    this.userId,
    this.employeeId = '',
    required this.name,
    this.email = '',
    this.phone = '',
    required this.departmentId,
    this.designation = 'Assistant Professor',
    this.role = 'teacher',
    this.status = 'invited',
    List<String>? subjectsCanTeach,
    this.maxClassesPerDay = 4,
    this.maxClassesPerWeek = 20,
    List<int>? preferredPeriodNumbers,
    List<UnavailableTime>? unavailableTimes,
    this.active = true,
  })  : subjectsCanTeach = subjectsCanTeach ?? [],
        preferredPeriodNumbers = preferredPeriodNumbers ?? [],
        unavailableTimes = unavailableTimes ?? [];

  bool get isLinkedWithAuth => userId != null && userId!.isNotEmpty && status == 'active';

  /// Determines whether this staff member is eligible to teach a given subject.
  /// Rule 1: If subjectsCanTeach is empty, the professor can teach any subject.
  /// Rule 2: If subjectsCanTeach is non-empty, the professor is eligible if ANY
  /// meaningful professor-entered token matches a token in the subject name, or
  /// matches code, ID, abbreviation, or fuzzy spelling mistake under the 5-tier
  /// matching hierarchy.
  bool isEligibleForSubject({
    required String subjectName,
    required String subjectCode,
    String? courseShortName,
    String? subjectId,
  }) {
    return SubjectMatcher.isStaffEligible(
      subjectsCanTeach: subjectsCanTeach,
      subjectName: subjectName,
      subjectCode: subjectCode,
      courseShortName: courseShortName,
      subjectId: subjectId,
    );
  }

  /// Checks if this professor is unavailable on the given day and time slot.
  /// If [unavailableTimes] is empty, the professor remains available for all slots.
  bool isUnavailableDuring({
    required String day,
    required TimeSlot slot,
  }) {
    if (unavailableTimes.isEmpty) return false;

    for (final u in unavailableTimes) {
      final uDay = u.dayOfWeek.trim().toLowerCase();
      final targetDay = day.trim().toLowerCase();
      if (uDay != 'all' && uDay != targetDay) {
        continue;
      }

      final uStart = UnavailableTime.parseTimeToMinutes(u.startTime);
      final uEnd = UnavailableTime.parseTimeToMinutes(u.endTime);
      final slotStart = UnavailableTime.parseTimeToMinutes(slot.startTime);
      final slotEnd = UnavailableTime.parseTimeToMinutes(slot.endTime);

      if (uStart != null && uEnd != null && slotStart != null && slotEnd != null) {
        // Overlap if (uStart < slotEnd) && (slotStart < uEnd)
        if (uStart < slotEnd && slotStart < uEnd) {
          return true;
        }
      } else {
        // Fallback check against periodNumber
        final uPeriod = int.tryParse(u.startTime.trim());
        if (uPeriod != null && uPeriod == slot.periodNumber) {
          return true;
        }
      }
    }

    return false;
  }

  factory Staff.fromJson(Map<String, dynamic> json, {String? id}) {
    return Staff(
      id: id ?? json['id'] as String? ?? '',
      collegeId: json['collegeId'] as String? ?? '',
      userId: json['userId'] as String?,
      employeeId: json['employeeId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      departmentId: json['departmentId'] as String? ?? '',
      designation: json['designation'] as String? ?? 'Assistant Professor',
      role: json['role'] as String? ?? 'teacher',
      status: json['status'] as String? ?? 'invited',
      subjectsCanTeach: () {
        final raw = json['subjectsCanTeach'];
        if (raw == null) return <String>[];
        if (raw is List) {
          return List<String>.from(raw.map((e) => e.toString()));
        }
        if (raw is String) {
          return raw
              .split(RegExp(r'[,;\n]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
        return <String>[];
      }(),
      maxClassesPerDay: json['maxClassesPerDay'] as int? ?? 4,
      maxClassesPerWeek: json['maxClassesPerWeek'] as int? ?? 20,
      preferredPeriodNumbers: json['preferredPeriodNumbers'] != null
          ? List<int>.from(json['preferredPeriodNumbers'] as List)
          : [],
      unavailableTimes: json['unavailableTimes'] != null
          ? (json['unavailableTimes'] as List)
              .map((u) => UnavailableTime.fromJson(Map<String, dynamic>.from(u as Map)))
              .toList()
          : [],
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collegeId': collegeId,
      'userId': userId,
      'employeeId': employeeId,
      'name': name,
      'email': email,
      'phone': phone,
      'departmentId': departmentId,
      'designation': designation,
      'role': role,
      'status': status,
      'subjectsCanTeach': subjectsCanTeach,
      'maxClassesPerDay': maxClassesPerDay,
      'maxClassesPerWeek': maxClassesPerWeek,
      'preferredPeriodNumbers': preferredPeriodNumbers,
      'unavailableTimes': unavailableTimes.map((u) => u.toJson()).toList(),
      'active': active,
    };
  }

  Staff copyWith({
    String? id,
    String? collegeId,
    String? userId,
    String? employeeId,
    String? name,
    String? email,
    String? phone,
    String? departmentId,
    String? designation,
    String? role,
    String? status,
    List<String>? subjectsCanTeach,
    int? maxClassesPerDay,
    int? maxClassesPerWeek,
    List<int>? preferredPeriodNumbers,
    List<UnavailableTime>? unavailableTimes,
    bool? active,
  }) {
    return Staff(
      id: id ?? this.id,
      collegeId: collegeId ?? this.collegeId,
      userId: userId ?? this.userId,
      employeeId: employeeId ?? this.employeeId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      departmentId: departmentId ?? this.departmentId,
      designation: designation ?? this.designation,
      role: role ?? this.role,
      status: status ?? this.status,
      subjectsCanTeach: subjectsCanTeach ?? this.subjectsCanTeach,
      maxClassesPerDay: maxClassesPerDay ?? this.maxClassesPerDay,
      maxClassesPerWeek: maxClassesPerWeek ?? this.maxClassesPerWeek,
      preferredPeriodNumbers:
          preferredPeriodNumbers ?? this.preferredPeriodNumbers,
      unavailableTimes: unavailableTimes ?? this.unavailableTimes,
      active: active ?? this.active,
    );
  }
}
