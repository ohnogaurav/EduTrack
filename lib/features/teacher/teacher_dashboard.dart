import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../services/firestore_service.dart';
import '../../core/theme/theme_controller.dart';
import 'subject_detail_screen.dart';

class TeacherDashboard extends StatefulWidget {
  final int selectedIndex;
  const TeacherDashboard({super.key, required this.selectedIndex});

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

  @override
  void didUpdateWidget(TeacherDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _refreshData();
    }
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
          _buildSectionHeader("Create Subject", Icons.add_box),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add),
                      onPressed: _isActionProcessing ? null : _createSubject,
                      label: Text(_isActionProcessing ? "Processing..." : "Create Subject"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader("Your Subjects", Icons.book),
          if (_mySubjects.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No subjects yet"))))
          else
            ..._mySubjects.map((subject) {
              final String joinCode = subject['joinCode'] ?? 'No Code';
              return Card(
                child: ListTile(
                  leading: Icon(Icons.class_, color: Theme.of(context).colorScheme.primary),
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
        ],
      ),
    );
  }

  Widget _buildSessionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Start Session", Icons.timer),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.play_arrow),
                      onPressed: _isActionProcessing ? null : _startSession,
                      label: const Text("Start Session"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInboxTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader("Send Announcement", Icons.campaign),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
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
    );
  }

  Widget _buildProfileTab() {
    final user = FirebaseAuth.instance.currentUser;
    final themeController = context.watch<ThemeController>();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50, 
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.school, size: 50, color: Colors.white)
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text("Email"),
                  subtitle: Text(user?.email ?? "No Email"),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text("Role"),
                  subtitle: const Text("Teacher"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: SwitchListTile(
              title: const Text("Dark Mode"),
              secondary: const Icon(Icons.dark_mode_outlined),
              value: themeController.isDark,
              onChanged: (_) => themeController.toggleTheme(),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
              },
              label: const Text("Logout"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _durationController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
