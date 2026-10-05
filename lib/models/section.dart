class Section {
  final String id;
  final String collegeId;
  final String departmentId;
  final String courseId;
  final String academicYear;
  final int semester;
  final String sectionName;
  final int studentCount;

  /// Student groups used for parallel lab sessions (for example B1, B2).
  final List<String> batches;
  final List<String> eligibleClassroomIds;
  final bool active;

  Section({
    required this.id,
    required this.collegeId,
    required this.departmentId,
    required this.courseId,
    required this.academicYear,
    required this.semester,
    required this.sectionName,
    required this.studentCount,
    List<String>? batches,
    List<String>? eligibleClassroomIds,
    this.active = true,
  }) : batches = List.unmodifiable(
         (batches ?? const <String>[])
             .map((batch) => batch.trim())
             .where((batch) => batch.isNotEmpty)
             .toSet(),
       ),
       eligibleClassroomIds = List.unmodifiable(
         (eligibleClassroomIds ?? const <String>[])
             .map((id) => id.trim())
             .where((id) => id.isNotEmpty)
             .toSet(),
       );

  String get displayName =>
      'Sem $semester - Sec $sectionName ($studentCount students)';

  factory Section.fromJson(Map<String, dynamic> json, {String? id}) {
    return Section(
      id: id ?? json['id'] as String? ?? '',
      collegeId: json['collegeId'] as String? ?? '',
      departmentId: json['departmentId'] as String? ?? '',
      courseId: json['courseId'] as String? ?? '',
      academicYear: json['academicYear'] as String? ?? '2026-2027',
      semester: json['semester'] as int? ?? 1,
      sectionName: json['sectionName'] as String? ?? 'A',
      studentCount: json['studentCount'] as int? ?? 30,
      batches: json['batches'] == null
          ? const []
          : (json['batches'] as List)
                .map((value) => value.toString().trim())
                .where((value) => value.isNotEmpty)
                .toList(),
      eligibleClassroomIds: json['eligibleClassroomIds'] != null
          ? (json['eligibleClassroomIds'] as List)
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList()
          : (json['eligibleRoomIds'] != null
              ? (json['eligibleRoomIds'] as List)
                    .map((e) => e.toString().trim())
                    .where((e) => e.isNotEmpty)
                    .toList()
              : const []),
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collegeId': collegeId,
      'departmentId': departmentId,
      'courseId': courseId,
      'academicYear': academicYear,
      'semester': semester,
      'sectionName': sectionName,
      'studentCount': studentCount,
      'batches': batches,
      'eligibleClassroomIds': eligibleClassroomIds,
      'active': active,
    };
  }

  Section copyWith({
    String? id,
    String? collegeId,
    String? departmentId,
    String? courseId,
    String? academicYear,
    int? semester,
    String? sectionName,
    int? studentCount,
    List<String>? batches,
    List<String>? eligibleClassroomIds,
    bool? active,
  }) {
    return Section(
      id: id ?? this.id,
      collegeId: collegeId ?? this.collegeId,
      departmentId: departmentId ?? this.departmentId,
      courseId: courseId ?? this.courseId,
      academicYear: academicYear ?? this.academicYear,
      semester: semester ?? this.semester,
      sectionName: sectionName ?? this.sectionName,
      studentCount: studentCount ?? this.studentCount,
      batches: batches ?? this.batches,
      eligibleClassroomIds: eligibleClassroomIds ?? this.eligibleClassroomIds,
      active: active ?? this.active,
    );
  }
}
