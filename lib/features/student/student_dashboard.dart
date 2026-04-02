import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../models/session_model.dart';
import 'liveness_screen.dart';

class StudentDashboard extends StatefulWidget {
  final int selectedIndex;
  const StudentDashboard({super.key, required this.selectedIndex});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();
  final TextEditingController _joinCodeController = TextEditingController();
  
  List<Map<String, dynamic>> _subjects = [];
  List<SessionModel> _activeSessions = [];
  List<Map<String, dynamic>> _messages = [];
  Map<String, Map<String, dynamic>> _analytics = {};

  bool _isLoading = true;
  bool _isActionProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void didUpdateWidget(StudentDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _loadAllData();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (widget.selectedIndex == 0 || widget.selectedIndex == 1) {
        final enrolledSubjectIds = await _firestoreService.getSubjectsByStudent(user.uid);
        final allSubjects = await _firestoreService.getAllSubjects();
        final subjects = allSubjects.where((s) => enrolledSubjectIds.contains(s['id'])).toList();
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
          _activeSessions = activeSessions.where((s) => enrolledSubjectIds.contains(s.subjectId)).toList();
          _analytics = stats;
        });
      } else if (widget.selectedIndex == 2) {
        final messages = await _firestoreService.getMessagesForStudent(user.uid);
        setState(() => _messages = messages);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinSubject() async {
    if (_isActionProcessing) return;
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) {
      _showSnackBar("Please enter a join code");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isActionProcessing = true);
    try {
      final subject = await _firestoreService.getSubjectByJoinCode(code);
      if (subject == null) {
        _showSnackBar("Invalid Join Code");
      } else {
        final result = await _firestoreService.enrollStudent(user.uid, subject.id);
        if (result == "SUCCESS") {
          _showSnackBar("Joined ${subject.name} successfully");
          _joinCodeController.clear();
          _loadAllData();
        } else if (result == "ALREADY_ENROLLED") {
          _showSnackBar("You are already joined");
        }
      }
    } finally {
      if (mounted) setState(() => _isActionProcessing = false);
    }
  }

  Future<void> _startVerification() async {
    if (_isActionProcessing) return;
    setState(() => _isActionProcessing = true);

    try {
      final activeSessions = await _firestoreService.getActiveSessions();
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final enrolledSubjectIds = await _firestoreService.getSubjectsByStudent(user.uid);
      final sessions = activeSessions.where((s) => enrolledSubjectIds.contains(s.subjectId)).toList();

      if (sessions.isEmpty) {
        _showSnackBar("No active session found");
        return;
      }

      if (sessions.length == 1) {
        await _processSession(sessions.first);
      } else {
        final selectedSession = await _showSessionSelectionDialog(sessions);
        if (selectedSession != null) {
          await _processSession(selectedSession);
        }
      }
    } finally {
      if (mounted) setState(() => _isActionProcessing = false);
    }
  }

  Future<SessionModel?> _showSessionSelectionDialog(List<SessionModel> sessions) async {
    return showDialog<SessionModel>(
      context: context,
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
      ),
    );
  }

  Future<void> _processSession(SessionModel session) async {
    try {
      if (session.isExpired) {
        _showSnackBar("Session expired");
        return;
      }

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
        _showSnackBar("Location required");
        return;
      }

      final distance = Geolocator.distanceBetween(
        location.latitude, location.longitude,
        session.latitude ?? 0, session.longitude ?? 0,
      );

      if (distance > 20.0) {
        _showSnackBar("Not in range ($distance m)");
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final result = await _firestoreService.markAttendance(
        studentId: user.uid,
        subjectId: session.subjectId,
        sessionId: session.id,
      );

      _showSnackBar(result == "SUCCESS" ? "Attendance Marked!" : "Failed: $result");
      if (result == "SUCCESS") _loadAllData();
    } catch (e) {
      _showSnackBar("Error during verification");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    switch (widget.selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildSessionsTab();
      case 2:
        return _buildInboxTab();
      case 3:
        return _buildProfileTab();
      default:
        return const Center(child: Text("Page Not Found"));
    }
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Join Subject", Icons.add_link),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _joinCodeController,
                      decoration: const InputDecoration(labelText: 'Join Code', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isActionProcessing ? null : _joinSubject,
                    child: const Text("Join"),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader("Verification", Icons.verified_user),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.all(16)),
              icon: const Icon(Icons.camera_alt),
              onPressed: _isActionProcessing ? null : _startVerification,
              label: Text(_isActionProcessing ? "Processing..." : "Start Verification"),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader("Analytics", Icons.analytics),
          if (_subjects.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text("Join a subject to see analytics"))))
          else
            ..._subjects.map((subject) {
              final stats = _analytics[subject['id']];
              final statsText = stats != null ? "${stats['attended']} / ${stats['total']} (${stats['percentage']}%)" : "...";
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.book, color: Colors.blue),
                  title: Text(subject['name'] ?? 'No Name'),
                  subtitle: Text("Teacher: ${subject['teacherName'] ?? 'Unknown'}"),
                  trailing: Text(statsText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildSessionsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _activeSessions.isEmpty
          ? const Center(child: Text("No active sessions available"))
          : ListView.builder(
              itemCount: _activeSessions.length,
              itemBuilder: (context, index) {
                final session = _activeSessions[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.sensors, color: Colors.green),
                    title: Text("Subject: ${session.subjectId}"),
                    subtitle: Text("Expires at: ${session.startTime.add(Duration(minutes: session.duration)).hour}:${session.startTime.add(Duration(minutes: session.duration)).minute.toString().padLeft(2, '0')}"),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInboxTab() {
    return _messages.isEmpty
        ? const Center(child: Text("No messages"))
        : ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              final timestamp = msg['timestamp'] as Timestamp?;
              final date = timestamp?.toDate() ?? DateTime.now();
              return Card(
                child: ListTile(
                  title: Text(msg['message'] ?? ''),
                  subtitle: Text("From: ${msg['senderId']}\n${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}"),
                  isThreeLine: true,
                ),
              );
            },
          );
  }

  Widget _buildProfileTab() {
    final user = FirebaseAuth.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          children: [
            const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
            const SizedBox(height: 16),
            Text(user?.email ?? "No Email", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Role: Student", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text("Logout"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }
}
