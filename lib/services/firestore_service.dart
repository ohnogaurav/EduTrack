import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/session_model.dart';
import '../models/attendance_model.dart';
import '../models/subject_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
      await _db.collection('sessions').add({
        'subjectId': subjectId,
        'teacherId': teacherId,
        'duration': duration,
        'startTime': FieldValue.serverTimestamp(),
        'isActive': true,
        'isCancelled': false,
      });
    } catch (e) {
      print("FIRESTORE ERROR: $e");
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

      DateTime now = DateTime.now();

      // Filter sessions that have not expired
      return sessions.where((session) {
        DateTime endTime = session.startTime.add(Duration(minutes: session.duration));
        return now.isBefore(endTime);
      }).toList();
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
      final isEnrolled = await isStudentEnrolled(studentId, subjectId);
      if (!isEnrolled) {
        return "NOT_ENROLLED";
      }

      QuerySnapshot duplicate = await _db
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .where('sessionId', isEqualTo: sessionId)
          .get();

      if (duplicate.docs.isNotEmpty) {
        return "ALREADY_MARKED";
      }

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
}
