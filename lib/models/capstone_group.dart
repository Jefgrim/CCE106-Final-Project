// =============================================================================
// FILE: lib/models/capstone_group.dart
// OOP PRINCIPLE DEMONSTRATED: ENCAPSULATION & AGGREGATION
// Groups encapsulate relationships between student groups and assigned faculty.
// =============================================================================

class CapstoneGroup {
  final String id;
  final String groupNumber;
  final String title;
  final List<String> studentMembers;
  final String academicYear;

  // Encapsulated assignment IDs
  String _adviserId;
  String _leadPanelistId;
  List<String> _panelistIds;

  CapstoneGroup({
    required this.id,
    required this.groupNumber,
    required this.title,
    required this.studentMembers,
    this.academicYear = '',
    required String adviserId,
    required String leadPanelistId,
    required List<String> panelistIds,
  })  : _adviserId = adviserId,
        _leadPanelistId = leadPanelistId,
        _panelistIds = List.from(panelistIds);

  String get adviserId => _adviserId;
  String get leadPanelistId => _leadPanelistId;
  List<String> get panelistIds => List.unmodifiable(_panelistIds);

  List<String> get allAssignedFacultyIds {
    final ids = <String>{_adviserId, _leadPanelistId, ..._panelistIds};
    return ids.toList();
  }

  void setAdviser(String newAdviserId) {
    _adviserId = newAdviserId;
  }

  void setLeadPanelist(String newLeadId) {
    _leadPanelistId = newLeadId;
  }

  void setPanelists(List<String> newPanelistIds) {
    _panelistIds = List.from(newPanelistIds);
  }

  /// Serialization for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'groupNumber': groupNumber,
      'title': title,
      'studentMembers': studentMembers,
      'academicYear': academicYear,
      'adviserId': _adviserId,
      'leadPanelistId': _leadPanelistId,
      'panelistIds': _panelistIds,
    };
  }

  factory CapstoneGroup.fromJson(Map<String, dynamic> json) {
    return CapstoneGroup(
      id: json['id'] ?? '',
      groupNumber: json['groupNumber'] ?? '',
      title: json['title'] ?? '',
      studentMembers: List<String>.from(json['studentMembers'] ?? []),
      academicYear: json['academicYear'] ?? '',
      adviserId: json['adviserId'] ?? '',
      leadPanelistId: json['leadPanelistId'] ?? '',
      panelistIds: List<String>.from(json['panelistIds'] ?? []),
    );
  }
}
