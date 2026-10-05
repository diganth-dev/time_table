class Department {
  final String id;
  final String collegeId;
  final String name;
  final String code;
  final String? hodId;
  final String? hodName;
  final bool active;

  Department({
    required this.id,
    required this.collegeId,
    required this.name,
    required this.code,
    this.hodId,
    this.hodName,
    this.active = true,
  });

  factory Department.fromJson(Map<String, dynamic> json, {String? id}) {
    return Department(
      id: id ?? json['id'] as String? ?? '',
      collegeId: json['collegeId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      hodId: json['hodId'] as String?,
      hodName: json['hodName'] as String?,
      active: json['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collegeId': collegeId,
      'name': name,
      'code': code,
      'hodId': hodId,
      'hodName': hodName,
      'active': active,
    };
  }

  Department copyWith({
    String? id,
    String? collegeId,
    String? name,
    String? code,
    String? hodId,
    String? hodName,
    bool? active,
  }) {
    return Department(
      id: id ?? this.id,
      collegeId: collegeId ?? this.collegeId,
      name: name ?? this.name,
      code: code ?? this.code,
      hodId: hodId ?? this.hodId,
      hodName: hodName ?? this.hodName,
      active: active ?? this.active,
    );
  }
}
