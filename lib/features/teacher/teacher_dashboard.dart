import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import 'subject_detail_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  
  List<Map<String, dynamic>> _mySubjects = [];
  String? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final subjects = await _firestoreService.getSubjectsByTeacher(user.uid);
      setState(() {
        _mySubjects = subjects;
        if (_selectedSubjectId != null && !_mySubjects.any((s) => s['id'] == _selectedSubjectId)) {
          _selectedSubjectId = null;
        }
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _confirmAction(String title, String content, VoidCallback onConfirm) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            }, 
            child: const Text("Confirm")
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Dashboard')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create Subject', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextField(
              controller: _subjectController,
              decoration: const InputDecoration(labelText: 'Subject Name'),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null && _subjectController.text.isNotEmpty) {
                  final teacherName = await _firestoreService.getUserName(user.uid);
                  await _firestoreService.createSubject(
                    _subjectController.text,
                    user.uid,
                    teacherName ?? 'Unknown Teacher',
                  );
                  _subjectController.clear();
                  _showSnackBar("Subject Created");
                  _refreshData();
                }
              },
              child: const Text('Create Subject'),
            ),
            
            const Divider(height: 40),
            const Text('Your Subjects (Tap for details)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ..._mySubjects.map((subject) {
              final String joinCode = subject['joinCode'] ?? 'No Code';
              return ListTile(
                title: Text("${subject['name'] ?? 'No Name'} ($joinCode)"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmAction(
                    "Delete Subject", 
                    "Are you sure you want to delete this subject?",
                    () async {
                      await _firestoreService.deleteSubject(subject['id']);
                      _showSnackBar("Subject Deleted");
                      _refreshData();
                    }
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SubjectDetailScreen(subject: subject)),
                  );
                },
              );
            }),

            const Divider(height: 40),
            const Text('Start Attendance Session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Select Subject'),
              value: _selectedSubjectId,
              items: _mySubjects.map((subject) {
                return DropdownMenuItem<String>(
                  value: subject['id'],
                  child: Text(subject['name'] ?? 'No Name'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSubjectId = value;
                });
              },
            ),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(labelText: 'Duration (minutes)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null && _selectedSubjectId != null && _durationController.text.isNotEmpty) {
                  await _firestoreService.createSession(
                    _selectedSubjectId!,
                    user.uid,
                    int.parse(_durationController.text),
                  );
                  _durationController.clear();
                  _showSnackBar("Session Started");
                  _refreshData();
                } else {
                  _showSnackBar("Please select a subject and enter duration");
                }
              },
              child: const Text('Start Session'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _durationController.dispose();
    super.dispose();
  }
}
