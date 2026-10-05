class Course {
  final String id;
  final String collegeId;
  final String departmentId;
  final String name;
  final String code;
  final int durationYears;
  final int totalSemesters;
  final bool active;

  Course({
    required this.id,
    required this.collegeId,
    required this.departmentId,
    required this.name,
    required this.code,
    this.durationYears = 4,
    this.totalSemesters = 8,
    this.active = true,
  });

  factory Course.fromJson(Map<String, dynamic> json, {String? id}) {
    return Course(
      id: id ?? json['id'] as String? ?? '',
      collegeId: json['collegeId'] as String? ?? '',
      departmentId: json['departmentId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      durationYears: json['durationYears'] as int? ?? 4,
      totalSemesters: json['totalSemesters'] as int? ?? 8,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collegeId': collegeId,
      'departmentId': departmentId,
      'name': name,
      'code': code,
      'durationYears': durationYears,
      'totalSemesters': totalSemesters,
      'active': active,
    };
  }

  Course copyWith({
    String? id,
    String? collegeId,
    String? departmentId,
    String? name,
    String? code,
    int? durationYears,
    int? totalSemesters,
    bool? active,
  }) {
    return Course(
      id: id ?? this.id,
      collegeId: collegeId ?? this.collegeId,
      departmentId: departmentId ?? this.departmentId,
      name: name ?? this.name,
      code: code ?? this.code,
      durationYears: durationYears ?? this.durationYears,
      totalSemesters: totalSemesters ?? this.totalSemesters,
      active: active ?? this.active,
    );
  }
}
