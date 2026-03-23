import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
      await _db.collection('subjects').add({
        'name': name,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("FIRESTORE ERROR: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getAllSubjects() async {
    try {
      QuerySnapshot snapshot = await _db.collection('subjects').get();
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

  Future<void> createSession(String subjectId, String teacherId, int duration) async {
    try {
      await _db.collection('sessions').add({
        'subjectId': subjectId,
        'teacherId': teacherId,
        'duration': duration,
        'startTime': FieldValue.serverTimestamp(),
        'isActive': true,
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
}
