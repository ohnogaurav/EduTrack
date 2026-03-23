import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';

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
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final subjects = await _firestoreService.getSubjectsByTeacher(user.uid);
      setState(() {
        _mySubjects = subjects;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
                  _loadSubjects(); // Refresh list
                }
              },
              child: const Text('Create Subject'),
            ),
            const Divider(height: 40),
            const Text('Start Attendance Session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              isExpanded: true,
              hint: const Text('Select Subject'),
              value: _selectedSubjectId,
              items: _mySubjects.map((subject) {
                return DropdownMenuItem<String>(
                  value: subject['id'],
                  child: Text(subject['name']),
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
