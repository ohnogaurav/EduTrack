import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../models/session_model.dart';
import 'liveness_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  List<Map<String, dynamic>> _subjects = [];
  List<SessionModel> _activeSessions = [];

  bool isProcessing = false;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _startVerification() async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      // 1. LIVENESS
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LivenessScreen()),
      );

      print("DEBUG: Liveness result = $result");

      if (result != true) {
        print("DEBUG: Liveness failed or not completed");
        _showSnackBar("Liveness Failed");
        return;
      }

      // 2. GPS
      print("DEBUG: Calling GPS");
      final location = await _locationService.getCurrentLocation();
      
      if (location == null) {
        print("DEBUG: Location not available");
        _showSnackBar("Location not available");
        return;
      }

      print("DEBUG: Location = ${location.latitude}, ${location.longitude}");

      // 3. SUCCESS
      _showSnackBar("Verification Complete");
    } catch (e) {
      print("DEBUG: Error during verification: $e");
      _showSnackBar("Verification Error");
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

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

            const SizedBox(height: 10),

            // 🔹 Start Verification Button (Module 8 Integrated Production Flow)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, 
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: isProcessing ? null : _startVerification,
              child: isProcessing 
                ? const SizedBox(
                    height: 20, 
                    width: 20, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                : const Text('Start Verification'),
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
