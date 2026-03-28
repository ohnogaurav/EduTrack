import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectModel {
  final String id;
  final String name;
  final String teacherId;
  final String teacherName;
  final bool isDeleted;

  SubjectModel({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.teacherName,
    required this.isDeleted,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'isDeleted': isDeleted,
    };
  }

  factory SubjectModel.fromMap(Map<String, dynamic> map, String documentId) {
    return SubjectModel(
      id: documentId,
      name: map['name'] ?? '',
      teacherId: map['teacherId'] ?? '',
      teacherName: map['teacherName'] ?? '',
      isDeleted: map['isDeleted'] ?? false,
    );
  }
}
