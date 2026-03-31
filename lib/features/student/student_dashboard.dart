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
  Map<String, Map<String, dynamic>> _analytics = {};

  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _loadAllData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final subjects = await _firestoreService.getAllSubjects();
    final activeSessions = await _firestoreService.getActiveSessions();
    final attendance = await _firestoreService.getAttendanceByStudent(user.uid);

    Map<String, Map<String, dynamic>> stats = {};
    for (var subject in subjects) {
      final subjectId = subject['id'];
      final sessions = await _firestoreService.getSessionsBySubject(subjectId);
      
      final totalValidSessions = sessions.length;
      final attendedCount = attendance.where((a) => a.subjectId == subjectId).length;
      final percentage = totalValidSessions == 0 ? 0.0 : (attendedCount / totalValidSessions) * 100;

      stats[subjectId] = {
        'attended': attendedCount,
        'total': totalValidSessions,
        'percentage': percentage.toStringAsFixed(1),
      };
    }

    setState(() {
      _subjects = subjects;
      _activeSessions = activeSessions;
      _analytics = stats;
    });
  }

  Future<void> _startVerification() async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final sessions = await _firestoreService.getActiveSessions();

      if (sessions.isEmpty) {
        _showSnackBar("No active session found");
        setState(() {
          isProcessing = false;
        });
        return;
      }

      if (sessions.length == 1) {
        await _processSession(sessions.first);
      } else {
        setState(() {
          isProcessing = false;
        });
        final selectedSession = await _showSessionSelectionDialog(sessions);
        if (selectedSession != null) {
          await _processSession(selectedSession);
        }
      }
    } catch (e) {
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
                title: Text("Subject ID: ${session.subjectId}"),
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
      final livenessResult = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LivenessScreen()),
      );

      if (livenessResult != true) {
        _showSnackBar("Liveness Failed");
        return;
      }

      final location = await _locationService.getCurrentLocation();
      if (location == null) {
        _showSnackBar("Location not available");
        return;
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final result = await _firestoreService.markAttendance(
        studentId: currentUser.uid,
        subjectId: session.subjectId,
        sessionId: session.id,
      );

      if (result == "SUCCESS") {
        _showSnackBar("Attendance Marked Successful");
        _loadAllData(); // Refresh analytics
      } else if (result == "ALREADY_MARKED") {
        _showSnackBar("Already Marked");
      } else {
        _showSnackBar("Attendance Failed");
      }

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
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(onPressed: _loadAllData, icon: const Icon(Icons.refresh))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, 
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: isProcessing ? null : _startVerification,
              child: isProcessing 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Start Verification'),
            ),

            const SizedBox(height: 20),
            const Text("Your Attendance Analytics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: _subjects.isEmpty
                  ? const Center(child: Text('No subjects available'))
                  : ListView.builder(
                      itemCount: _subjects.length,
                      itemBuilder: (context, index) {
                        final subject = _subjects[index];
                        final stats = _analytics[subject['id']];
                        final statsText = stats != null 
                            ? "${stats['attended']} / ${stats['total']} (${stats['percentage']}%)" 
                            : "Loading...";
                        return ListTile(
                          title: Text(subject['name'] ?? 'No Name'),
                          subtitle: Text('Teacher: ${subject['teacherName'] ?? 'Unknown'}'),
                          trailing: Text(statsText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
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
                          subtitle: Text("Start: ${session.startTime} | Duration: ${session.duration} min"),
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
