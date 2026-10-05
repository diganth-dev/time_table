class College {
  final String id;
  final String name;
  final String code;
  final String? adminId;
  final String address;
  final String academicYear;
  final String currentSemester;
  final List<String> workingDays;
  final int periodsPerDay;
  final int periodDurationMinutes;
  final String startTime;
  final String endTime;
  final String? lunchStartTime;
  final String? lunchEndTime;
  final String? morningBreakStartTime;
  final String? morningBreakEndTime;
  final DateTime createdAt;
  final bool active;

  College({
    required this.id,
    required this.name,
    required this.code,
    this.adminId,
    this.address = '',
    this.academicYear = '2026-2027',
    this.currentSemester = 'Odd 2026',
    List<String>? workingDays,
    this.periodsPerDay = 6,
    this.periodDurationMinutes = 60,
    this.startTime = '09:00',
    this.endTime = '16:00',
    this.lunchStartTime = '13:15',
    this.lunchEndTime = '14:00',
    this.morningBreakStartTime = '11:00',
    this.morningBreakEndTime = '11:15',
    DateTime? createdAt,
    this.active = true,
  })  : workingDays = workingDays ??
            ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
        createdAt = createdAt ?? DateTime.now();

  factory College.fromJson(Map<String, dynamic> json, {String? id}) {
    return College(
      id: id ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      adminId: json['adminId'] as String?,
      address: json['address'] as String? ?? '',
      academicYear: json['academicYear'] as String? ?? '2026-2027',
      currentSemester: json['currentSemester'] as String? ?? 'Odd 2026',
      workingDays: json['workingDays'] != null
          ? List<String>.from(json['workingDays'] as List)
          : ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'],
      periodsPerDay: json['periodsPerDay'] as int? ?? 6,
      periodDurationMinutes: json['periodDurationMinutes'] as int? ?? 60,
      startTime: json['startTime'] as String? ?? '09:00',
      endTime: json['endTime'] as String? ?? '16:00',
      lunchStartTime: json['lunchStartTime'] as String? ?? '13:15',
      lunchEndTime: json['lunchEndTime'] as String? ?? '14:00',
      morningBreakStartTime: json['morningBreakStartTime'] as String? ?? '11:00',
      morningBreakEndTime: json['morningBreakEndTime'] as String? ?? '11:15',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      if (adminId != null) 'adminId': adminId,
      'address': address,
      'academicYear': academicYear,
      'currentSemester': currentSemester,
      'workingDays': workingDays,
      'periodsPerDay': periodsPerDay,
      'periodDurationMinutes': periodDurationMinutes,
      'startTime': startTime,
      'endTime': endTime,
      'lunchStartTime': lunchStartTime,
      'lunchEndTime': lunchEndTime,
      'morningBreakStartTime': morningBreakStartTime,
      'morningBreakEndTime': morningBreakEndTime,
      'createdAt': createdAt.toIso8601String(),
      'active': active,
    };
  }

  College copyWith({
    String? id,
    String? name,
    String? code,
    String? adminId,
    String? address,
    String? academicYear,
    String? currentSemester,
    List<String>? workingDays,
    int? periodsPerDay,
    int? periodDurationMinutes,
    String? startTime,
    String? endTime,
    String? lunchStartTime,
    String? lunchEndTime,
    String? morningBreakStartTime,
    String? morningBreakEndTime,
    DateTime? createdAt,
    bool? active,
  }) {
    return College(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      adminId: adminId ?? this.adminId,
      address: address ?? this.address,
      academicYear: academicYear ?? this.academicYear,
      currentSemester: currentSemester ?? this.currentSemester,
      workingDays: workingDays ?? this.workingDays,
      periodsPerDay: periodsPerDay ?? this.periodsPerDay,
      periodDurationMinutes:
          periodDurationMinutes ?? this.periodDurationMinutes,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      lunchStartTime: lunchStartTime ?? this.lunchStartTime,
      lunchEndTime: lunchEndTime ?? this.lunchEndTime,
      morningBreakStartTime:
          morningBreakStartTime ?? this.morningBreakStartTime,
      morningBreakEndTime: morningBreakEndTime ?? this.morningBreakEndTime,
      createdAt: createdAt ?? this.createdAt,
      active: active ?? this.active,
    );
  }
}
