import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/attendance_model.dart';
import '../../models/session_model.dart';

class SubjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  const SubjectDetailScreen({super.key, required this.subject});

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  
  List<UserModel> _enrolledStudents = [];
  List<SessionModel> _sessions = [];
  Map<String, int> _sessionAttendanceCount = {};
  
  int _totalAttendanceCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSubjectInsights();
  }

  Future<void> _loadSubjectInsights() async {
    try {
      final String subjectId = widget.subject['id'];
      
      // 1. Fetch Enrolled Students
      final studentIds = await _firestoreService.getEnrolledStudentIds(subjectId);
      _enrolledStudents = await _firestoreService.getStudentsByIds(studentIds);

      // 2. Fetch All Sessions for this subject
      _sessions = await _firestoreService.getSessionsBySubject(subjectId);
      _sessions.sort((a, b) => b.startTime.compareTo(a.startTime));

      // 3. Fetch All Attendance for this subject to calculate counts
      final allAttendance = await _firestoreService.getAttendanceBySubject(subjectId);
      _totalAttendanceCount = allAttendance.length;

      // Map session IDs to their attendance counts
      Map<String, int> counts = {};
      for (var session in _sessions) {
        counts[session.id] = allAttendance.where((a) => a.sessionId == session.id).length;
      }
      _sessionAttendanceCount = counts;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading subject insights: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String joinCode = widget.subject['joinCode'] ?? 'No Code';
    
    // Calculate Average Attendance %
    double avgAttendance = 0;
    if (_enrolledStudents.isNotEmpty && _sessions.isNotEmpty) {
      int totalPossible = _enrolledStudents.length * _sessions.length;
      avgAttendance = (_totalAttendanceCount / totalPossible) * 100;
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.subject['name'])),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SUMMARY SECTION
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Join Code:", style: TextStyle(fontWeight: FontWeight.bold)),
                            SelectableText(joinCode, style: const TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem("Students", _enrolledStudents.length.toString()),
                            _buildStatItem("Sessions", _sessions.length.toString()),
                            _buildStatItem("Avg. Attnd.", "${avgAttendance.toStringAsFixed(1)}%"),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const Text("Enrolled Students", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (_enrolledStudents.isEmpty)
                  const Text("No students joined yet")
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _enrolledStudents.length,
                      itemBuilder: (context, index) => ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(_enrolledStudents[index].name),
                        dense: true,
                      ),
                    ),
                  ),

                const Divider(height: 40),
                const Text("Session History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (_sessions.isEmpty)
                  const Text("No sessions conducted yet")
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final count = _sessionAttendanceCount[session.id] ?? 0;
                      return ListTile(
                        title: Text("Session on ${session.startTime.day}/${session.startTime.month}"),
                        subtitle: Text(session.isActive ? "Active" : "Completed"),
                        trailing: Text("Present: $count / ${_enrolledStudents.length}", 
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
              ],
            ),
          ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
