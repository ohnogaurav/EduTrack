import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      print("DEBUG: Fetching active sessions");
      final sessions = await _firestoreService.getActiveSessions();

      if (sessions.isEmpty) {
        print("DEBUG: No active session found");
        _showSnackBar("No active session found");
        setState(() {
          isProcessing = false;
        });
        return;
      }

      if (sessions.length == 1) {
        print("DEBUG: Single session auto-selected");
        await _processSession(sessions.first);
      } else {
        print("DEBUG: Multiple sessions found");
        setState(() {
          isProcessing = false;
        });
        final selectedSession = await _showSessionSelectionDialog(sessions);
        if (selectedSession != null) {
          await _processSession(selectedSession);
        }
      }
    } catch (e) {
      print("DEBUG: Error in verification start: $e");
      _showSnackBar("Verification Error");
      setState(() {
        isProcessing = false;
      });
    }
  }

  Future<SessionModel?> _showSessionSelectionDialog(List<SessionModel> sessions) async {
    return showDialog<SessionModel>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Select Session"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return ListTile(
                title: Text("Subject: ${session.subjectId}"),
                subtitle: Text("ID: ${session.id}"),
                onTap: () => Navigator.pop(context, session),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  Future<void> _processSession(SessionModel session) async {
    setState(() {
      isProcessing = true;
    });

    try {
      print("DEBUG: Processing session ${session.id}");

      // 1. LIVENESS
      final livenessResult = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LivenessScreen()),
      );

      print("DEBUG: Liveness result = $livenessResult");

      if (livenessResult != true) {
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

      // 3. ATTENDANCE
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showSnackBar("User not logged in");
        return;
      }

      print("DEBUG: Marking attendance for session ${session.id}");
      final result = await _firestoreService.markAttendance(
        studentId: currentUser.uid,
        subjectId: session.subjectId,
        sessionId: session.id,
      );

      print("DEBUG: Attendance result = $result");

      if (result == "SUCCESS") {
        _showSnackBar("Attendance Marked Successful");
      } else if (result == "ALREADY_MARKED") {
        _showSnackBar("Already Marked");
      } else {
        _showSnackBar("Attendance Failed");
      }

    } catch (e) {
      print("DEBUG: Error processing session: $e");
      _showSnackBar("Processing Error");
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

            // 🔹 Start Verification Button (Module 9.5 Session Selection)
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
