class TeacherAvailability {
  final String id;
  final String collegeId;
  final String teacherId;
  final String dayOfWeek;
  final int periodNumber;
  final bool isAvailable;
  final bool isLeave;
  final String? leaveReason;
  final DateTime? leaveDate;

  TeacherAvailability({
    required this.id,
    required this.collegeId,
    required this.teacherId,
    required this.dayOfWeek,
    required this.periodNumber,
    this.isAvailable = true,
    this.isLeave = false,
    this.leaveReason,
    this.leaveDate,
  });

  factory TeacherAvailability.fromJson(Map<String, dynamic> json, {String? id}) {
    return TeacherAvailability(
      id: id ?? json['id'] as String? ?? '',
      collegeId: json['collegeId'] as String? ?? '',
      teacherId: json['teacherId'] as String? ?? '',
      dayOfWeek: json['dayOfWeek'] as String? ?? 'Monday',
      periodNumber: json['periodNumber'] as int? ?? 1,
      isAvailable: json['isAvailable'] as bool? ?? true,
      isLeave: json['isLeave'] as bool? ?? false,
      leaveReason: json['leaveReason'] as String?,
      leaveDate: json['leaveDate'] != null
          ? DateTime.tryParse(json['leaveDate'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collegeId': collegeId,
      'teacherId': teacherId,
      'dayOfWeek': dayOfWeek,
      'periodNumber': periodNumber,
      'isAvailable': isAvailable,
      'isLeave': isLeave,
      'leaveReason': leaveReason,
      'leaveDate': leaveDate?.toIso8601String(),
    };
  }

  TeacherAvailability copyWith({
    String? id,
    String? collegeId,
    String? teacherId,
    String? dayOfWeek,
    int? periodNumber,
    bool? isAvailable,
    bool? isLeave,
    String? leaveReason,
    DateTime? leaveDate,
  }) {
    return TeacherAvailability(
      id: id ?? this.id,
      collegeId: collegeId ?? this.collegeId,
      teacherId: teacherId ?? this.teacherId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      periodNumber: periodNumber ?? this.periodNumber,
      isAvailable: isAvailable ?? this.isAvailable,
      isLeave: isLeave ?? this.isLeave,
      leaveReason: leaveReason ?? this.leaveReason,
      leaveDate: leaveDate ?? this.leaveDate,
    );
  }
}
