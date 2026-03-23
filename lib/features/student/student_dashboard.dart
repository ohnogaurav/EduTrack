import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/session_model.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _subjects = [];
  List<SessionModel> _activeSessions = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 🔹 Load Subjects Button
            ElevatedButton(
              onPressed: () async {
                final subjects = await _firestoreService.getAllSubjects();
                setState(() {
                  _subjects = subjects;
                });
              },
              child: const Text('Load Subjects'),
            ),

            const SizedBox(height: 10),

            // 🔹 Load Active Sessions Button
            ElevatedButton(
              onPressed: () async {
                final sessions = await _firestoreService.getActiveSessions();
                setState(() {
                  _activeSessions = sessions;
                });
              },
              child: const Text('Load Active Sessions'),
            ),

            const SizedBox(height: 20),

            const Text("Available Subjects", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: _subjects.isEmpty
                  ? const Center(child: Text('No subjects loaded'))
                  : ListView.builder(
                      itemCount: _subjects.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          title: Text(_subjects[index]['name'] ?? 'No Name'),
                          subtitle: Text(
                            'Teacher: ${_subjects[index]['teacherName'] ?? 'Unknown'}',
                          ),
                        );
                      },
                    ),
            ),

            const Divider(),

            const Text("Active Sessions", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: _activeSessions.isEmpty
                  ? const Center(child: Text('No active sessions'))
                  : ListView.builder(
                      itemCount: _activeSessions.length,
                      itemBuilder: (context, index) {
                        final session = _activeSessions[index];
                        return ListTile(
                          title: Text("Subject ID: ${session.subjectId}"),
                          subtitle: Text(
                            "Start: ${session.startTime} | Duration: ${session.duration} min",
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
