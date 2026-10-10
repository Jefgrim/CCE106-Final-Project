// =============================================================================
// FILE: lib/models/user.dart
// OOP CONCEPTS DEMONSTRATED:
// 1. ABSTRACTION: Abstract class 'User' defines a common template with toJson / fromJson.
// 2. INHERITANCE: 'Student', 'FacultyMember', and 'Coordinator' inherit from 'User'.
// 3. POLYMORPHISM: Each child class overrides 'getRoleDescription()' and 'toJson()'.
// 4. ENCAPSULATION: Attributes and serializations are bundled cleanly.
// =============================================================================

/// Enum representing the possible roles in the CapSync system.
enum UserRole {
  student,
  faculty,
  coordinator,
}

/// [OOP - ABSTRACTION & ENCAPSULATION]
abstract class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String department;
  final String avatarInitials;
  final String? photoUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.department = 'IT College - University of Mindanao',
    required this.avatarInitials,
    this.photoUrl,
  });

  /// [OOP - POLYMORPHISM]
  String getRoleDescription();

  /// Formatted display title
  String get displayName => name;

  /// Serialization for database storage (Firebase / Local Storage)
  Map<String, dynamic> toJson();

  /// [OOP - FACTORY POLYMORPHISM]: Parses appropriate subclass from database map
  static User fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String? ?? 'student';
    if (roleStr == 'faculty') {
      return FacultyMember.fromJson(json);
    } else if (roleStr == 'coordinator') {
      return Coordinator.fromJson(json);
    } else {
      return Student.fromJson(json);
    }
  }

  @override
  String toString() => '$name (${getRoleDescription()})';
}

/// [OOP - INHERITANCE]
class Student extends User {
  final String studentIdNumber; // e.g. "UM-2022-8492"
  final String groupId;         // ID of their Capstone group
  final String capstoneTitle;   // Their approved capstone project title
  final String yearLevel;       // e.g. "4th Year BSIT"

  Student({
    required super.id,
    required super.name,
    required super.email,
    required super.avatarInitials,
    super.department,
    super.photoUrl,
    required this.studentIdNumber,
    required this.groupId,
    required this.capstoneTitle,
    this.yearLevel = '4th Year BSIT',
  }) : super(role: UserRole.student);

  @override
  String getRoleDescription() {
    return 'Capstone Student ($yearLevel)';
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': 'student',
      'department': department,
      'avatarInitials': avatarInitials,
      'photoUrl': photoUrl,
      'studentIdNumber': studentIdNumber,
      'groupId': groupId,
      'capstoneTitle': capstoneTitle,
      'yearLevel': yearLevel,
    };
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatarInitials: json['avatarInitials'] ?? 'ST',
      photoUrl: json['photoUrl'] as String?,
      department: json['department'] ?? 'IT College - University of Mindanao',
      studentIdNumber: json['studentIdNumber'] ?? '',
      groupId: json['groupId'] ?? '',
      capstoneTitle: json['capstoneTitle'] ?? '',
      yearLevel: json['yearLevel'] ?? '4th Year BSIT',
    );
  }

  Student copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarInitials,
    String? photoUrl,
    String? department,
    String? studentIdNumber,
    String? groupId,
    String? capstoneTitle,
    String? yearLevel,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      photoUrl: photoUrl ?? this.photoUrl,
      department: department ?? this.department,
      studentIdNumber: studentIdNumber ?? this.studentIdNumber,
      groupId: groupId ?? this.groupId,
      capstoneTitle: capstoneTitle ?? this.capstoneTitle,
      yearLevel: yearLevel ?? this.yearLevel,
    );
  }
}

/// [OOP - INHERITANCE]
class FacultyMember extends User {
  final String facultyIdNumber;     // e.g. "FAC-0142"
  final String academicRank;        // e.g. "Associate Professor"
  final String consultationRoom;    // e.g. "Faculty Lounge Room 304"
  final List<String> expertiseTags; // e.g. ["Mobile Dev", "Cloud"]
  final bool isAdviser;
  final bool isPanelist;

  FacultyMember({
    required super.id,
    required super.name,
    required super.email,
    required super.avatarInitials,
    super.department,
    super.photoUrl,
    required this.facultyIdNumber,
    this.academicRank = '',
    this.consultationRoom = '',
    this.expertiseTags = const [],
    this.isAdviser = true,
    this.isPanelist = true,
  }) : super(role: UserRole.faculty);

  @override
  String getRoleDescription() {
    return 'Faculty Adviser & Panelist';
  }

  String get formattedExpertise => expertiseTags.join(', ');

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': 'faculty',
      'department': department,
      'avatarInitials': avatarInitials,
      'photoUrl': photoUrl,
      'facultyIdNumber': facultyIdNumber,
      'academicRank': academicRank,
      'consultationRoom': consultationRoom,
      'expertiseTags': expertiseTags,
      'isAdviser': isAdviser,
      'isPanelist': isPanelist,
    };
  }

  factory FacultyMember.fromJson(Map<String, dynamic> json) {
    return FacultyMember(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatarInitials: json['avatarInitials'] ?? 'FC',
      photoUrl: json['photoUrl'] as String?,
      department: json['department'] ?? 'IT College - University of Mindanao',
      facultyIdNumber: json['facultyIdNumber'] ?? '',
      academicRank: json['academicRank'] ?? '',
      consultationRoom: json['consultationRoom'] ?? '',
      expertiseTags: List<String>.from(json['expertiseTags'] ?? []),
      isAdviser: json['isAdviser'] ?? true,
      isPanelist: json['isPanelist'] ?? true,
    );
  }

  FacultyMember copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarInitials,
    String? photoUrl,
    String? department,
    String? facultyIdNumber,
    String? academicRank,
    String? consultationRoom,
    List<String>? expertiseTags,
    bool? isAdviser,
    bool? isPanelist,
  }) {
    return FacultyMember(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      photoUrl: photoUrl ?? this.photoUrl,
      department: department ?? this.department,
      facultyIdNumber: facultyIdNumber ?? this.facultyIdNumber,
      academicRank: academicRank ?? this.academicRank,
      consultationRoom: consultationRoom ?? this.consultationRoom,
      expertiseTags: expertiseTags ?? this.expertiseTags,
      isAdviser: isAdviser ?? this.isAdviser,
      isPanelist: isPanelist ?? this.isPanelist,
    );
  }
}

/// [OOP - INHERITANCE]
class Coordinator extends User {
  final String officeLocation;
  final String academicYear;

  Coordinator({
    required super.id,
    required super.name,
    required super.email,
    required super.avatarInitials,
    super.department,
    super.photoUrl,
    required this.officeLocation,
    this.academicYear = 'A.Y. 2026-2027',
  }) : super(role: UserRole.coordinator);

  @override
  String getRoleDescription() {
    return 'Capstone Coordinator ($academicYear)';
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': 'coordinator',
      'department': department,
      'avatarInitials': avatarInitials,
      'photoUrl': photoUrl,
      'officeLocation': officeLocation,
      'academicYear': academicYear,
    };
  }

  factory Coordinator.fromJson(Map<String, dynamic> json) {
    return Coordinator(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatarInitials: json['avatarInitials'] ?? 'CR',
      photoUrl: json['photoUrl'] as String?,
      department: json['department'] ?? 'IT College - University of Mindanao',
      officeLocation: json['officeLocation'] ?? 'IT Dean\'s Office',
      academicYear: json['academicYear'] ?? 'A.Y. 2026-2027',
    );
  }

  Coordinator copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarInitials,
    String? photoUrl,
    String? department,
    String? officeLocation,
    String? academicYear,
  }) {
    return Coordinator(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      photoUrl: photoUrl ?? this.photoUrl,
      department: department ?? this.department,
      officeLocation: officeLocation ?? this.officeLocation,
      academicYear: academicYear ?? this.academicYear,
    );
  }
}
