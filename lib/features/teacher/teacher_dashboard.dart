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
  final TextEditingController _messageController = TextEditingController();
  
  List<Map<String, dynamic>> _mySubjects = [];
  List<Map<String, dynamic>> _allStudents = [];
  String? _selectedSubjectId;
  String _targetType = "all";
  String? _targetStudentId;
  String? _targetSubjectId;

  bool _isLoading = true;
  bool _isActionProcessing = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final subjects = await _firestoreService.getSubjectsByTeacher(user.uid);
        final students = await _firestoreService.getAllStudents();
        setState(() {
          _mySubjects = subjects;
          _allStudents = students;
          if (_selectedSubjectId != null && !_mySubjects.any((s) => s['id'] == _selectedSubjectId)) {
            _selectedSubjectId = null;
          }
        });
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _sendMessage() async {
    if (_isActionProcessing) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_messageController.text.trim().isEmpty) {
      _showSnackBar("Please enter a message");
      return;
    }

    setState(() => _isActionProcessing = true);
    try {
      List<String> targetIds = [];
      if (_targetType == "student" && _targetStudentId != null) {
        targetIds = [_targetStudentId!];
      } else if (_targetType == "subject" && _targetSubjectId != null) {
        targetIds = [_targetSubjectId!];
      }

      await _firestoreService.sendMessage(
        senderId: user.uid,
        targetType: _targetType,
        targetIds: targetIds,
        message: _messageController.text.trim(),
      );

      _messageController.clear();
      _showSnackBar("Message Sent");
    } finally {
      if (mounted) setState(() => _isActionProcessing = false);
    }
  }

  Future<void> _createSubject() async {
    if (_isActionProcessing) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _subjectController.text.isEmpty) return;

    setState(() => _isActionProcessing = true);
    try {
      final teacherName = await _firestoreService.getUserName(user.uid);
      await _firestoreService.createSubject(
        _subjectController.text,
        user.uid,
        teacherName ?? 'Unknown Teacher',
      );
      _subjectController.clear();
      _showSnackBar("Subject Created");
      _refreshData();
    } finally {
      if (mounted) setState(() => _isActionProcessing = false);
    }
  }

  Future<void> _startSession() async {
    if (_isActionProcessing) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selectedSubjectId == null || _durationController.text.isEmpty) {
      _showSnackBar("Fill all session fields");
      return;
    }

    setState(() => _isActionProcessing = true);
    try {
      await _firestoreService.createSession(
        _selectedSubjectId!,
        user.uid,
        int.parse(_durationController.text),
      );
      _durationController.clear();
      _showSnackBar("Session Started");
      _refreshData();
    } catch (e) {
      _showSnackBar("Location required to start session");
    } finally {
      if (mounted) setState(() => _isActionProcessing = false);
    }
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
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        actions: [
          IconButton(onPressed: _refreshData, icon: const Icon(Icons.refresh))
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("Subjects", Icons.book),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _subjectController,
                          decoration: const InputDecoration(labelText: 'New Subject Name', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            onPressed: _isActionProcessing ? null : _createSubject,
                            label: Text(_isActionProcessing ? "Processing..." : "Create Subject"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                if (_mySubjects.isEmpty)
                  const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No subjects yet")))
                else
                  ..._mySubjects.map((subject) {
                    final String joinCode = subject['joinCode'] ?? 'No Code';
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.class_, color: Colors.blue),
                        title: Text("${subject['name']} ($joinCode)"),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _confirmAction(
                            "Delete Subject", 
                            "Are you sure?",
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
                      ),
                    );
                  }),

                const SizedBox(height: 24),
                _buildSectionHeader("Active Session", Icons.timer),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: "Select Subject", border: OutlineInputBorder()),
                          value: _selectedSubjectId,
                          items: _mySubjects.map((subject) {
                            return DropdownMenuItem(value: subject['id'] as String, child: Text(subject['name']));
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedSubjectId = value),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _durationController,
                          decoration: const InputDecoration(labelText: 'Duration (min)', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            onPressed: _isActionProcessing ? null : _startSession,
                            label: const Text("Start Session"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                _buildSectionHeader("Announcements", Icons.campaign),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _messageController,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Message Content', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _targetType,
                          decoration: const InputDecoration(labelText: "Target", border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: "all", child: Text("All Students")),
                            DropdownMenuItem(value: "subject", child: Text("Enrolled in Subject")),
                            DropdownMenuItem(value: "student", child: Text("Specific Student")),
                          ],
                          onChanged: (val) => setState(() => _targetType = val!),
                        ),
                        if (_targetType == "subject") ...[
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            hint: const Text("Select Subject"),
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            value: _targetSubjectId,
                            items: _mySubjects.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name']))).toList(),
                            onChanged: (val) => setState(() => _targetSubjectId = val),
                          ),
                        ],
                        if (_targetType == "student") ...[
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            hint: const Text("Select Student"),
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            value: _targetStudentId,
                            items: _allStudents.map((s) => DropdownMenuItem(value: s['id'] as String, child: Text(s['name']))).toList(),
                            onChanged: (val) => setState(() => _targetStudentId = val),
                          ),
                        ],
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.send),
                            onPressed: _isActionProcessing ? null : _sendMessage,
                            label: const Text("Send Announcement"),
                          ),
                        ),
                      ],
                    ),
                  ),
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
}
