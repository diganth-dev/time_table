class ConflictItem {
  final String id;
  final String collegeId;
  final String type;
  final String severity; // 'hard', 'warning'
  final String title;
  final String description;
  final String? dayOfWeek;
  final int? periodNumber;
  final String? sectionId;
  final String? teacherId;
  final String? roomId;
  final String? subjectId;
  final String? suggestion;

  ConflictItem({
    required this.id,
    required this.collegeId,
    required this.type,
    this.severity = 'hard',
    required this.title,
    required this.description,
    this.dayOfWeek,
    this.periodNumber,
    this.sectionId,
    this.teacherId,
    this.roomId,
    this.subjectId,
    this.suggestion,
  });

  bool get isHard => severity == 'hard';

  factory ConflictItem.fromJson(Map<String, dynamic> json, {String? id}) {
    return ConflictItem(
      id: id ?? json['id'] as String? ?? '',
      collegeId: json['collegeId'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      severity: json['severity'] as String? ?? 'hard',
      title: json['title'] as String? ?? 'Conflict Detected',
      description: json['description'] as String? ?? '',
      dayOfWeek: json['dayOfWeek'] as String?,
      periodNumber: json['periodNumber'] as int?,
      sectionId: json['sectionId'] as String?,
      teacherId: json['teacherId'] as String?,
      roomId: json['roomId'] as String?,
      subjectId: json['subjectId'] as String?,
      suggestion: json['suggestion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collegeId': collegeId,
      'type': type,
      'severity': severity,
      'title': title,
      'description': description,
      'dayOfWeek': dayOfWeek,
      'periodNumber': periodNumber,
      'sectionId': sectionId,
      'teacherId': teacherId,
      'roomId': roomId,
      'subjectId': subjectId,
      'suggestion': suggestion,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConflictItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
