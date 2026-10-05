class TimetableVersion {
  final String id;
  final String collegeId;
  final int versionNumber;
  final String name;
  final String status; // 'draft', 'published', 'archived'
  final String academicYear;
  final String semester;
  final bool isCurrentPublished;
  final DateTime? publishedAt;
  final String? publishedBy;
  final String? changeLog;
  final DateTime createdAt;

  TimetableVersion({
    required this.id,
    required this.collegeId,
    required this.versionNumber,
    required this.name,
    this.status = 'draft',
    required this.academicYear,
    required this.semester,
    this.isCurrentPublished = false,
    this.publishedAt,
    this.publishedBy,
    this.changeLog,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isPublished => status == 'published' || isCurrentPublished;

  factory TimetableVersion.fromJson(Map<String, dynamic> json, {String? id}) {
    return TimetableVersion(
      id: id ?? json['id'] as String? ?? '',
      collegeId: json['collegeId'] as String? ?? '',
      versionNumber: json['versionNumber'] as int? ?? 1,
      name: json['name'] as String? ?? 'Version 1',
      status: json['status'] as String? ?? 'draft',
      academicYear: json['academicYear'] as String? ?? '2026-2027',
      semester: json['semester'] as String? ?? 'Odd 2026',
      isCurrentPublished: json['isCurrentPublished'] as bool? ?? false,
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'].toString())
          : null,
      publishedBy: json['publishedBy'] as String?,
      changeLog: json['changeLog'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collegeId': collegeId,
      'versionNumber': versionNumber,
      'name': name,
      'status': status,
      'academicYear': academicYear,
      'semester': semester,
      'isCurrentPublished': isCurrentPublished,
      'publishedAt': publishedAt?.toIso8601String(),
      'publishedBy': publishedBy,
      'changeLog': changeLog,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  TimetableVersion copyWith({
    String? id,
    String? collegeId,
    int? versionNumber,
    String? name,
    String? status,
    String? academicYear,
    String? semester,
    bool? isCurrentPublished,
    DateTime? publishedAt,
    String? publishedBy,
    String? changeLog,
    DateTime? createdAt,
  }) {
    return TimetableVersion(
      id: id ?? this.id,
      collegeId: collegeId ?? this.collegeId,
      versionNumber: versionNumber ?? this.versionNumber,
      name: name ?? this.name,
      status: status ?? this.status,
      academicYear: academicYear ?? this.academicYear,
      semester: semester ?? this.semester,
      isCurrentPublished: isCurrentPublished ?? this.isCurrentPublished,
      publishedAt: publishedAt ?? this.publishedAt,
      publishedBy: publishedBy ?? this.publishedBy,
      changeLog: changeLog ?? this.changeLog,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
