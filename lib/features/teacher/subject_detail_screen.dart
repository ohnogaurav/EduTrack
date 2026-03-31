import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  const SubjectDetailScreen({super.key, required this.subject});

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = true;
  Map<String, dynamic>? _latestSession;
  List<String> _presentStudentNames = [];
  int _totalStudents = 0;

  @override
  void initState() {
    super.initState();
    _loadSubjectData();
  }

  Future<void> _loadSubjectData() async {
    try {
      final sessions = await _firestoreService.getSessionsByTeacher(widget.subject['teacherId']);
      
      // Filter sessions for THIS subject and sort by startTime
      final subjectSessions = sessions.where((s) => s['subjectId'] == widget.subject['id']).toList();
      
      if (subjectSessions.isNotEmpty) {
        subjectSessions.sort((a, b) {
          Timestamp tA = a['startTime'];
          Timestamp tB = b['startTime'];
          return tB.compareTo(tA);
        });

        _latestSession = subjectSessions.first;
        
        final attendanceList = await _firestoreService.getAttendanceBySession(_latestSession!['id']);
        final allStudents = await _firestoreService.getAllStudents();
        _totalStudents = allStudents.length;

        final Map<String, String> studentNameMap = {
          for (var student in allStudents) student['id']: student['name'] ?? 'Unknown Student'
        };

        _presentStudentNames = attendanceList.map((att) {
          return studentNameMap[att['studentId']] ?? "Unknown Student";
        }).toList();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading subject details: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.subject['name'])),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Recent Session", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (_latestSession == null)
                  const Text("No sessions yet")
                else ...[
                  Text("Status: ${_latestSession!['isCancelled'] ? 'Cancelled' : (_latestSession!['isActive'] ? 'Active' : 'Completed')}",
                    style: TextStyle(
                      color: _latestSession!['isCancelled'] ? Colors.red : (_latestSession!['isActive'] ? Colors.green : Colors.grey),
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text("Attendance: ${_presentStudentNames.length} / $_totalStudents", style: const TextStyle(fontSize: 18)),
                  const Divider(),
                  const Text("Present Students:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(
                    child: _presentStudentNames.isEmpty
                      ? const Center(child: Text("No attendance yet"))
                      : ListView.builder(
                          itemCount: _presentStudentNames.length,
                          itemBuilder: (context, index) => ListTile(
                            leading: const Icon(Icons.check_circle, color: Colors.green),
                            title: Text(_presentStudentNames[index]),
                          ),
                        ),
                  ),
                ]
              ],
            ),
          ),
    );
  }
}
