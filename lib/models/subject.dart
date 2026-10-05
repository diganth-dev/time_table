class Subject {
  final String id;
  final String collegeId;
  final String? sectionId; // Optional link to specific class Section
  final String departmentId;
  final String courseId;
  final int semester;
  final String subjectCode;
  final String? courseShortName;
  final String subjectName;
  final String subjectType; // 'Theory', 'Lab', 'Tutorial', 'Seminar'
  final int hoursPerWeek;
  final String requiredRoomType; // 'Classroom', 'Computer Lab', 'Physics Lab', etc.
  final List<String> assignedTeacherIds;
  final int consecutivePeriods;
  final List<String> eligibleLabIds; // References to global Room/Lab records
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Subject({
    required this.id,
    required this.collegeId,
    this.sectionId,
    required this.departmentId,
    required this.courseId,
    required this.semester,
    required this.subjectCode,
    this.courseShortName,
    required this.subjectName,
    this.subjectType = 'Theory',
    this.hoursPerWeek = 4,
    this.requiredRoomType = 'Classroom',
    List<String>? assignedTeacherIds,
    this.consecutivePeriods = 1,
    List<String>? eligibleLabIds,
    this.active = true,
    this.createdAt,
    this.updatedAt,
  }) : assignedTeacherIds = assignedTeacherIds ?? [],
       eligibleLabIds = eligibleLabIds ?? [];

  bool get isLab {
    final facility = requiredRoomType.trim().toLowerCase();
    return subjectType.trim().toLowerCase() == 'lab' ||
        facility.contains('lab');
  }

  static const String classVenueId = 'class';

  /// Returns true if this lab subject allows being conducted in a normal classroom.
  bool get allowsClassroom =>
      eligibleLabIds.any((id) => id.toLowerCase() == 'class' || id.toLowerCase() == 'classroom');

  /// Returns true if this lab subject allows physical laboratories.
  bool get allowsPhysicalLabs =>
      !allowsClassroom ||
      eligibleLabIds.any((id) => id.toLowerCase() != 'class' && id.toLowerCase() != 'classroom');

  /// Returns true if this lab subject only allows normal classrooms.
  bool get allowsOnlyClassroom =>
      allowsClassroom &&
      !eligibleLabIds.any((id) => id.toLowerCase() != 'class' && id.toLowerCase() != 'classroom');

  String get name => subjectName;
  String get requiredFacility => requiredRoomType;
  String? get assignedProfessorId =>
      assignedTeacherIds.isNotEmpty ? assignedTeacherIds.first : null;

  String get shortName {
    if (courseShortName != null && courseShortName!.trim().isNotEmpty) {
      return courseShortName!.trim();
    }
    if (subjectCode.trim().isNotEmpty) {
      return subjectCode.trim();
    }
    return subjectName.trim().isNotEmpty ? subjectName.trim() : 'SUB';
  }

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is DateTime) return val;
    try {
      if (val.runtimeType.toString().contains('Timestamp')) {
        return (val as dynamic).toDate();
      }
    } catch (_) {}
    return DateTime.tryParse(val.toString());
  }

  factory Subject.fromJson(Map<String, dynamic> json, {String? id}) {
    final profId = json['assignedProfessorId'] as String?;
    final teachers = json['assignedTeacherIds'] != null
        ? List<String>.from(json['assignedTeacherIds'] as List)
        : (profId != null && profId.isNotEmpty ? [profId] : <String>[]);

    final subName =
        json['name'] as String? ?? json['subjectName'] as String? ?? '';
    final roomType =
        json['requiredFacility'] as String? ??
        json['requiredRoomType'] as String? ??
        'Classroom';

    return Subject(
      id: id ?? json['id'] as String? ?? '',
      collegeId: json['collegeId'] as String? ?? '',
      sectionId: json['sectionId'] as String?,
      departmentId: json['departmentId'] as String? ?? '',
      courseId: json['courseId'] as String? ?? '',
      semester: json['semester'] as int? ?? 1,
      subjectCode: json['subjectCode'] as String? ?? '',
      courseShortName:
          json['courseShortName'] as String? ?? json['shortName'] as String?,
      subjectName: subName,
      subjectType: json['subjectType'] as String? ?? 'Theory',
      hoursPerWeek: json['hoursPerWeek'] as int? ?? 4,
      requiredRoomType: roomType,
      assignedTeacherIds: teachers,
      consecutivePeriods: json['consecutivePeriods'] as int? ?? 1,
      eligibleLabIds: json['eligibleLabIds'] != null
          ? List<String>.from(json['eligibleLabIds'] as List)
          : (json['compatibleLabIds'] != null
              ? List<String>.from(json['compatibleLabIds'] as List)
              : <String>[]),
      active: json['active'] as bool? ?? true,
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': subjectName,
      'subjectName': subjectName,
      'subjectCode': subjectCode,
      'courseShortName': courseShortName,
      'shortName': courseShortName,
      'requiredFacility': requiredRoomType,
      'requiredRoomType': requiredRoomType,
      'assignedProfessorId': assignedProfessorId,
      'assignedTeacherIds': assignedTeacherIds,
      'sectionId': sectionId,
      'collegeId': collegeId,
      'departmentId': departmentId,
      'courseId': courseId,
      'semester': semester,
      'subjectType': subjectType,
      'hoursPerWeek': hoursPerWeek,
      'consecutivePeriods': consecutivePeriods,
      'eligibleLabIds': eligibleLabIds,
      'active': active,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  Subject copyWith({
    String? id,
    String? collegeId,
    String? sectionId,
    String? departmentId,
    String? courseId,
    int? semester,
    String? subjectCode,
    String? courseShortName,
    String? subjectName,
    String? subjectType,
    int? hoursPerWeek,
    String? requiredRoomType,
    List<String>? assignedTeacherIds,
    String? assignedProfessorId,
    int? consecutivePeriods,
    List<String>? eligibleLabIds,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    List<String>? teachers = assignedTeacherIds ?? this.assignedTeacherIds;
    if (assignedProfessorId != null) {
      teachers = assignedProfessorId.isNotEmpty ? [assignedProfessorId] : [];
    }
    return Subject(
      id: id ?? this.id,
      collegeId: collegeId ?? this.collegeId,
      sectionId: sectionId ?? this.sectionId,
      departmentId: departmentId ?? this.departmentId,
      courseId: courseId ?? this.courseId,
      semester: semester ?? this.semester,
      subjectCode: subjectCode ?? this.subjectCode,
      courseShortName: courseShortName ?? this.courseShortName,
      subjectName: subjectName ?? this.subjectName,
      subjectType: subjectType ?? this.subjectType,
      hoursPerWeek: hoursPerWeek ?? this.hoursPerWeek,
      requiredRoomType: requiredRoomType ?? this.requiredRoomType,
      assignedTeacherIds: teachers,
      consecutivePeriods: consecutivePeriods ?? this.consecutivePeriods,
      eligibleLabIds: eligibleLabIds ?? this.eligibleLabIds,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
