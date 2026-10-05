enum UserRole {
  superAdmin,
  collegeAdmin,
  teacher,
  student;

  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.collegeAdmin:
        return 'College Admin';
      case UserRole.teacher:
        return 'Teacher / Staff';
      case UserRole.student:
        return 'Student';
    }
  }

  static UserRole fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'superadmin':
      case 'super_admin':
        return UserRole.superAdmin;
      case 'collegeadmin':
      case 'college_admin':
      case 'admin':
        return UserRole.collegeAdmin;
      case 'teacher':
      case 'staff':
        return UserRole.teacher;
      case 'student':
        return UserRole.student;
      default:
        return UserRole.student;
    }
  }

  String toDbString() {
    switch (this) {
      case UserRole.superAdmin:
        return 'super_admin';
      case UserRole.collegeAdmin:
        return 'college_admin';
      case UserRole.teacher:
        return 'teacher';
      case UserRole.student:
        return 'student';
    }
  }
}
