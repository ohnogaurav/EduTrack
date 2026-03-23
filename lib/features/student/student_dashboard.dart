import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _subjects = [];

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

            // 🔥 Debug Button for Active Sessions
            ElevatedButton(
              onPressed: () async {
                final sessions = await _firestoreService.getActiveSessions();

                print("===== ACTIVE SESSIONS TEST =====");
                print("COUNT: ${sessions.length}");

                for (var s in sessions) {
                  print("Session -> Subject: ${s.subjectId}");
                  print("Start: ${s.startTime}");
                  print("Duration: ${s.duration}");
                  print("------------------------------");
                }
              },
              child: const Text('Check Active Sessions'),
            ),

            const SizedBox(height: 20),

            // 🔹 Subject List
            Expanded(
              child: _subjects.isEmpty
                  ? const Center(child: Text('No subjects loaded'))
                  : ListView.builder(
                itemCount: _subjects.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title:
                    Text(_subjects[index]['name'] ?? 'No Name'),
                    subtitle: Text(
                      'Teacher: ${_subjects[index]['teacherName'] ?? 'Unknown'}',
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