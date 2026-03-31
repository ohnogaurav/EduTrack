import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String id;
  final String studentId;
  final String subjectId;
  final String sessionId;
  final DateTime timestamp;

  AttendanceModel({
    required this.id,
    required this.studentId,
    required this.subjectId,
    required this.sessionId,
    required this.timestamp,
  });

  factory AttendanceModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AttendanceModel(
      id: documentId,
      studentId: map['studentId'] ?? '',
      subjectId: map['subjectId'] ?? '',
      sessionId: map['sessionId'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
