import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String id;
  final String subjectId;
  final String teacherId;
  final DateTime startTime;
  final int duration; // in minutes
  final bool isActive;

  SessionModel({
    required this.id,
    required this.subjectId,
    required this.teacherId,
    required this.startTime,
    required this.duration,
    required this.isActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'subjectId': subjectId,
      'teacherId': teacherId,
      'startTime': Timestamp.fromDate(startTime),
      'duration': duration,
      'isActive': isActive,
    };
  }

  factory SessionModel.fromMap(Map<String, dynamic> map, String documentId) {
    return SessionModel(
      id: documentId,
      subjectId: map['subjectId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      startTime: (map['startTime'] as Timestamp).toDate(),
      duration: map['duration'] ?? 0,
      isActive: map['isActive'] ?? false,
    );
  }
}
