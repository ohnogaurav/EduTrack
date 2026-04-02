import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/session_model.dart';
import '../models/attendance_model.dart';
import '../models/subject_model.dart';
import '../models/user_model.dart';
import 'location_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();

  String generateJoinCode() {
    return (Random().nextInt(900000) + 100000).toString();
  }

  Future<void> createUser(String userId, String name, String email, String role) async {
    try {
      await _db.collection('users').doc(userId).set({
        'name': name,
        'email': email,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("FIRESTORE ERROR: $e");
    }
  }

  Future<String?> getUserRole(String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.get('role');
      }
      return null;
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return null;
    }
  }

  Future<String?> getUserName(String userId) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.get('name');
      }
      return null;
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return null;
    }
  }

  Future<void> createSubject(String name, String teacherId, String teacherName) async {
    try {
      final joinCode = generateJoinCode();
      await _db.collection('subjects').add({
        'name': name,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'createdAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
        'joinCode': joinCode,
      });
    } catch (e) {
      print("FIRESTORE ERROR: $e");
    }
  }

  Future<SubjectModel?> getSubjectByJoinCode(String code) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('subjects')
          .where('joinCode', isEqualTo: code)
          .where('isDeleted', isEqualTo: false)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return SubjectModel.fromMap(snapshot.docs.first.data() as Map<String, dynamic>, snapshot.docs.first.id);
      }
      return null;
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAllSubjects() async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('subjects')
          .where('isDeleted', isEqualTo: false)
          .get();
      return snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSubjectsByTeacher(String teacherId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('subjects')
          .where('teacherId', isEqualTo: teacherId)
          .where('isDeleted', isEqualTo: false)
          .get();
      return snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return [];
    }
  }

  Future<void> deleteSubject(String subjectId) async {
    try {
      await _db.collection('subjects').doc(subjectId).update({
        'isDeleted': true,
      });
    } catch (e) {
      print("FIRESTORE ERROR: $e");
    }
  }

  Future<void> createSession(String subjectId, String teacherId, int duration) async {
    try {
      final location = await _locationService.getCurrentLocation();
      if (location == null) {
        throw Exception("Location not available. Cannot start session.");
      }

      await _db.collection('sessions').add({
        'subjectId': subjectId,
        'teacherId': teacherId,
        'duration': duration,
        'startTime': FieldValue.serverTimestamp(),
        'isActive': true,
        'isCancelled': false,
        'latitude': location.latitude,
        'longitude': location.longitude,
      });
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      rethrow;
    }
  }

  Future<List<SessionModel>> getActiveSessions() async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('sessions')
          .where('isActive', isEqualTo: true)
          .where('isCancelled', isEqualTo: false)
          .get();

      List<SessionModel> sessions = snapshot.docs.map((doc) {
        return SessionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      // MODULE 15: Filter out expired sessions
      return sessions.where((session) => !session.isExpired).toList();
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSessionsByTeacher(String teacherId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('sessions')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      return snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return [];
    }
  }

  Future<void> cancelSession(String sessionId) async {
    try {
      await _db.collection('sessions').doc(sessionId).update({
        'isCancelled': true,
        'isActive': false,
      });
    } catch (e) {
      print("FIRESTORE ERROR: $e");
    }
  }

  Future<String> markAttendance({
    required String studentId,
    required String subjectId,
    required String sessionId,
  }) async {
    try {
      // 1. Check if enrollment exists
      final isEnrolled = await isStudentEnrolled(studentId, subjectId);
      if (!isEnrolled) {
        return "NOT_ENROLLED";
      }

      // 2. Fetch and verify session (MODULE 15 Backend Safety)
      DocumentSnapshot sessionDoc = await _db.collection('sessions').doc(sessionId).get();
      if (!sessionDoc.exists) return "SESSION_NOT_FOUND";
      
      final session = SessionModel.fromMap(sessionDoc.data() as Map<String, dynamic>, sessionDoc.id);
      if (session.isCancelled || !session.isActive || session.isExpired) {
        return "SESSION_EXPIRED";
      }

      // 3. Check for duplicate
      QuerySnapshot duplicate = await _db
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('sessionId', isEqualTo: sessionId)
          .get();

      if (duplicate.docs.isNotEmpty) {
        return "ALREADY_MARKED";
      }

      // 4. Create attendance
      await _db.collection('attendance').add({
        'studentId': studentId,
        'subjectId': subjectId,
        'sessionId': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return "SUCCESS";
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return "ERROR";
    }
  }

  Future<List<Map<String, dynamic>>> getAttendanceBySession(String sessionId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('attendance')
          .where('sessionId', isEqualTo: sessionId)
          .get();
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getAllStudents() async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();
      return snapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return [];
    }
  }

  Future<List<SessionModel>> getSessionsBySubject(String subjectId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('sessions')
          .where('subjectId', isEqualTo: subjectId)
          .where('isCancelled', isEqualTo: false)
          .get();
      return snapshot.docs.map((doc) {
        return SessionModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return [];
    }
  }

  Future<List<AttendanceModel>> getAttendanceByStudent(String studentId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .get();
      return snapshot.docs.map((doc) {
        return AttendanceModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return [];
    }
  }

  Future<List<AttendanceModel>> getAttendanceBySubject(String subjectId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('attendance')
          .where('subjectId', isEqualTo: subjectId)
          .get();
      return snapshot.docs.map((doc) {
        return AttendanceModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return [];
    }
  }

  Future<String> enrollStudent(String studentId, String subjectId) async {
    try {
      final exists = await isStudentEnrolled(studentId, subjectId);
      if (exists) return "ALREADY_ENROLLED";

      await _db.collection('enrollments').add({
        'studentId': studentId,
        'subjectId': subjectId,
        'enrolledAt': FieldValue.serverTimestamp(),
      });
      return "SUCCESS";
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return "ERROR";
    }
  }

  Future<List<String>> getStudentsBySubject(String subjectId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('enrollments')
          .where('subjectId', isEqualTo: subjectId)
          .get();
      return snapshot.docs.map((doc) => doc.get('studentId') as String).toList();
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return [];
    }
  }

  Future<List<String>> getSubjectsByStudent(String studentId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('enrollments')
          .where('studentId', isEqualTo: studentId)
          .get();
      return snapshot.docs.map((doc) => doc.get('subjectId') as String).toList();
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return [];
    }
  }

  Future<bool> isStudentEnrolled(String studentId, String subjectId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('enrollments')
          .where('studentId', isEqualTo: studentId)
          .where('subjectId', isEqualTo: subjectId)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> getEnrolledStudentIds(String subjectId) async {
    return getStudentsBySubject(subjectId);
  }

  Future<List<UserModel>> getStudentsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      List<UserModel> students = [];
      for (var id in ids) {
        DocumentSnapshot doc = await _db.collection('users').doc(id).get();
        if (doc.exists) {
          students.add(UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id));
        }
      }
      return students;
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return [];
    }
  }

  Future<void> sendMessage({
    required String senderId,
    required String targetType,
    required List<String> targetIds,
    required String message,
  }) async {
    try {
      List<String> finalTargetIds = targetIds;
      if (targetType == "all") {
        finalTargetIds = [];
      } else if (targetType == "subject" && targetIds.isNotEmpty) {
        finalTargetIds = await getStudentsBySubject(targetIds.first);
      }

      await _db.collection('messages').add({
        'senderId': senderId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'targetType': targetType,
        'targetIds': finalTargetIds,
      });
    } catch (e) {
      print("FIRESTORE ERROR: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getMessagesForStudent(String studentId) async {
    try {
      QuerySnapshot broadcastMessages = await _db
          .collection('messages')
          .where('targetType', isEqualTo: 'all')
          .get();

      QuerySnapshot targetedMessages = await _db
          .collection('messages')
          .where('targetIds', arrayContains: studentId)
          .get();

      List<Map<String, dynamic>> allMessages = [];
      
      for (var doc in broadcastMessages.docs) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        allMessages.add(data);
      }
      
      for (var doc in targetedMessages.docs) {
        var data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        allMessages.add(data);
      }

      allMessages.sort((a, b) {
        Timestamp tA = a['timestamp'] ?? Timestamp.now();
        Timestamp tB = b['timestamp'] ?? Timestamp.now();
        return tB.compareTo(tA);
      });

      return allMessages;
    } catch (e) {
      print("FIRESTORE ERROR: $e");
      return [];
    }
  }
}
