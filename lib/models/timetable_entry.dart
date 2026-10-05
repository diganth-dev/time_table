class TimetableEntry {
  final String id;
  final String collegeId;
  final String versionId;
  final String dayOfWeek;
  final int periodNumber;
  final String? timeSlotId;
  final String sectionId;
  final String subjectId;
  final String teacherId;
  final String roomId;
  final String? batch; // e.g. 'B1', 'B2', or null for whole class
  final String status; // 'draft', 'published', 'cancelled'
  final String entryType; // 'class' or 'activity'
  final String? activityName;
  final String? description;
  final DateTime createdAt;
  final DateTime? updatedAt;

  TimetableEntry({
    required this.id,
    required this.collegeId,
    required this.versionId,
    required this.dayOfWeek,
    required this.periodNumber,
    this.timeSlotId,
    required this.sectionId,
    this.subjectId = '',
    this.teacherId = '',
    this.roomId = '',
    this.batch,
    this.status = 'draft',
    this.entryType = 'class',
    this.activityName,
    this.description,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get day => dayOfWeek;
  String get periodId => timeSlotId ?? 'period_$periodNumber';
  String get professorId => teacherId;
  bool get isActivity =>
      entryType.toLowerCase() == 'activity' ||
      (activityName != null &&
          activityName!.trim().isNotEmpty &&
          subjectId.isEmpty);

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

  factory TimetableEntry.fromJson(Map<String, dynamic> json, {String? id}) {
    final dayStr = json['day'] as String? ?? json['dayOfWeek'] as String? ?? 'Monday';
    final profStr = json['professorId'] as String? ?? json['teacherId'] as String? ?? '';
    final pId = json['periodId'] as String? ?? json['timeSlotId'] as String?;
    final pNum = json['periodNumber'] as int? ??
        (pId != null ? int.tryParse(pId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1 : 1);

    return TimetableEntry(
      id: id ?? json['id'] as String? ?? '',
      collegeId: json['collegeId'] as String? ?? '',
      versionId: json['versionId'] as String? ?? '',
      dayOfWeek: dayStr,
      periodNumber: pNum,
      timeSlotId: pId,
      sectionId: json['sectionId'] as String? ?? '',
      subjectId: json['subjectId'] as String? ?? '',
      teacherId: profStr,
      roomId: json['roomId'] as String? ?? '',
      batch: json['batch'] as String?,
      status: json['status'] as String? ?? 'draft',
      entryType: json['entryType'] as String? ?? 'class',
      activityName: json['activityName'] as String?,
      description: json['description'] as String?,
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'day': dayOfWeek,
      'dayOfWeek': dayOfWeek,
      'periodId': timeSlotId ?? 'period_$periodNumber',
      'periodNumber': periodNumber,
      'timeSlotId': timeSlotId,
      'sectionId': sectionId,
      'subjectId': subjectId,
      'professorId': teacherId,
      'teacherId': teacherId,
      'roomId': roomId,
      if (batch != null) 'batch': batch,
      'entryType': entryType,
      if (activityName != null) 'activityName': activityName,
      if (description != null) 'description': description,
      'collegeId': collegeId,
      'versionId': versionId,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  TimetableEntry copyWith({
    String? id,
    String? collegeId,
    String? versionId,
    String? dayOfWeek,
    int? periodNumber,
    String? timeSlotId,
    String? sectionId,
    String? subjectId,
    String? teacherId,
    String? roomId,
    String? batch,
    String? status,
    String? entryType,
    String? activityName,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimetableEntry(
      id: id ?? this.id,
      collegeId: collegeId ?? this.collegeId,
      versionId: versionId ?? this.versionId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      periodNumber: periodNumber ?? this.periodNumber,
      timeSlotId: timeSlotId ?? this.timeSlotId,
      sectionId: sectionId ?? this.sectionId,
      subjectId: subjectId ?? this.subjectId,
      teacherId: teacherId ?? this.teacherId,
      roomId: roomId ?? this.roomId,
      batch: batch ?? this.batch,
      status: status ?? this.status,
      entryType: entryType ?? this.entryType,
      activityName: activityName ?? this.activityName,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
