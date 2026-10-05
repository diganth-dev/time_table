class Room {
  final String id;
  final String collegeId;
  final String roomNumber;
  final String building;
  final int floor;
  final int capacity;
  final String roomType; // 'Classroom', 'Computer Lab', 'Physics Lab', etc.
  final List<String> facilities;
  final List<String> compatibleSubjects;
  final bool active;
  final bool isUnderMaintenance;
  final String? maintenanceReason;
  final DateTime? maintenanceFrom;
  final DateTime? maintenanceTo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Room({
    required this.id,
    required this.collegeId,
    required this.roomNumber,
    this.building = 'Main Block',
    this.floor = 1,
    this.capacity = 60,
    this.roomType = 'Classroom',
    List<String>? facilities,
    List<String>? compatibleSubjects,
    this.active = true,
    this.isUnderMaintenance = false,
    this.maintenanceReason,
    this.maintenanceFrom,
    this.maintenanceTo,
    this.createdAt,
    this.updatedAt,
  }) : facilities = facilities ?? [],
       compatibleSubjects = compatibleSubjects ?? [];

  static const List<String> roomTypes = [
    'Classroom',
    'Computer Lab',
    'Physics Lab',
    'Chemistry Lab',
    'Electronics Lab',
    'Seminar Hall',
    'Auditorium',
    'Other',
  ];

  String get facilityType => roomType;
  bool get isAvailable => active && !isUnderMaintenance;
  String get displayName => '$roomNumber ($roomType - Cap: $capacity)';
  bool get isLab =>
      roomType.trim().toLowerCase().contains('lab') ||
      facilities.any((f) => f.trim().toLowerCase().contains('lab')) ||
      compatibleSubjects.isNotEmpty;
  bool isLabRoom() => isLab;

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

  factory Room.fromJson(Map<String, dynamic> json, {String? id}) {
    final facilityType = json['facilityType'] as String? ?? json['roomType'] as String? ?? 'Classroom';
    final isAvail = json['isAvailable'] as bool?;
    final isUnderMaint = isAvail != null ? !isAvail : (json['isUnderMaintenance'] as bool? ?? false);
    final active = isAvail ?? (json['active'] as bool? ?? true);
    final compSubjs = json['compatibleSubjects'] != null
        ? List<String>.from(json['compatibleSubjects'] as List)
        : (json['compatible_subjects'] != null
            ? List<String>.from(json['compatible_subjects'] as List)
            : <String>[]);

    return Room(
      id: id ?? json['id'] as String? ?? '',
      collegeId: json['collegeId'] as String? ?? '',
      roomNumber: json['roomNumber'] as String? ?? json['name'] as String? ?? '',
      building: json['building'] as String? ?? 'Main Block',
      floor: json['floor'] as int? ?? 1,
      capacity: json['capacity'] as int? ?? 60,
      roomType: facilityType,
      facilities: json['facilities'] != null
          ? List<String>.from(json['facilities'] as List)
          : [],
      compatibleSubjects: compSubjs,
      active: active,
      isUnderMaintenance: isUnderMaint,
      maintenanceReason: json['maintenanceReason'] as String?,
      maintenanceFrom: _parseDateTime(json['maintenanceFrom']),
      maintenanceTo: _parseDateTime(json['maintenanceTo']),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collegeId': collegeId,
      'roomNumber': roomNumber,
      'name': roomNumber,
      'building': building,
      'floor': floor,
      'capacity': capacity,
      'facilityType': roomType,
      'roomType': roomType,
      'isAvailable': active && !isUnderMaintenance,
      'active': active,
      'isUnderMaintenance': isUnderMaintenance,
      'facilities': facilities,
      'compatibleSubjects': compatibleSubjects,
      'maintenanceReason': maintenanceReason,
      'maintenanceFrom': maintenanceFrom?.toIso8601String(),
      'maintenanceTo': maintenanceTo?.toIso8601String(),
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  Room copyWith({
    String? id,
    String? collegeId,
    String? roomNumber,
    String? building,
    int? floor,
    int? capacity,
    String? roomType,
    List<String>? facilities,
    List<String>? compatibleSubjects,
    bool? active,
    bool? isUnderMaintenance,
    String? maintenanceReason,
    DateTime? maintenanceFrom,
    DateTime? maintenanceTo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Room(
      id: id ?? this.id,
      collegeId: collegeId ?? this.collegeId,
      roomNumber: roomNumber ?? this.roomNumber,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      capacity: capacity ?? this.capacity,
      roomType: roomType ?? this.roomType,
      facilities: facilities ?? this.facilities,
      compatibleSubjects: compatibleSubjects ?? this.compatibleSubjects,
      active: active ?? this.active,
      isUnderMaintenance: isUnderMaintenance ?? this.isUnderMaintenance,
      maintenanceReason: maintenanceReason ?? this.maintenanceReason,
      maintenanceFrom: maintenanceFrom ?? this.maintenanceFrom,
      maintenanceTo: maintenanceTo ?? this.maintenanceTo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
