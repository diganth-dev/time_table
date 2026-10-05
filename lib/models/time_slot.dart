class TimeSlot {
  final String id;
  final String collegeId;
  final String? dayOfWeek; // null or 'ALL' applies to all working days, or specific day
  final int periodNumber; // 1, 2, 3, etc. (0 for break)
  final String startTime; // '09:00'
  final String endTime; // '10:00'
  final bool isBreak;
  final String? breakTitle;
  final int order;

  TimeSlot({
    required this.id,
    required this.collegeId,
    this.dayOfWeek,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    this.isBreak = false,
    this.breakTitle,
    required this.order,
  });

  String get label {
    if (isBreak) {
      return breakTitle ?? 'Break';
    }
    return 'Period $periodNumber';
  }

  String get timeRange => '$startTime - $endTime';

  factory TimeSlot.fromJson(Map<String, dynamic> json, {String? id}) {
    return TimeSlot(
      id: id ?? json['id'] as String? ?? '',
      collegeId: json['collegeId'] as String? ?? '',
      dayOfWeek: json['dayOfWeek'] as String?,
      periodNumber: json['periodNumber'] as int? ?? 1,
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      isBreak: json['isBreak'] as bool? ?? false,
      breakTitle: json['breakTitle'] as String?,
      order: json['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collegeId': collegeId,
      'dayOfWeek': dayOfWeek,
      'periodNumber': periodNumber,
      'startTime': startTime,
      'endTime': endTime,
      'isBreak': isBreak,
      'breakTitle': breakTitle,
      'order': order,
    };
  }

  TimeSlot copyWith({
    String? id,
    String? collegeId,
    String? dayOfWeek,
    int? periodNumber,
    String? startTime,
    String? endTime,
    bool? isBreak,
    String? breakTitle,
    int? order,
  }) {
    return TimeSlot(
      id: id ?? this.id,
      collegeId: collegeId ?? this.collegeId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      periodNumber: periodNumber ?? this.periodNumber,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isBreak: isBreak ?? this.isBreak,
      breakTitle: breakTitle ?? this.breakTitle,
      order: order ?? this.order,
    );
  }
}
