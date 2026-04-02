import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String id;
  final String subjectId;
  final String teacherId;
  final DateTime startTime;
  final int duration; // in minutes
  final bool isActive;
  final bool isCancelled;
  final double? latitude;
  final double? longitude;

  SessionModel({
    required this.id,
    required this.subjectId,
    required this.teacherId,
    required this.startTime,
    required this.duration,
    required this.isActive,
    required this.isCancelled,
    this.latitude,
    this.longitude,
  });

  bool get isExpired {
    final now = DateTime.now();
    final endTime = startTime.add(Duration(minutes: duration));
    return now.isAfter(endTime);
  }

  Map<String, dynamic> toMap() {
    return {
      'subjectId': subjectId,
      'teacherId': teacherId,
      'startTime': Timestamp.fromDate(startTime),
      'duration': duration,
      'isActive': isActive,
      'isCancelled': isCancelled,
      'latitude': latitude,
      'longitude': longitude,
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
      isCancelled: map['isCancelled'] ?? false,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
    );
  }
}
