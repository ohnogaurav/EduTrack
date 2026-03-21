import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../student/student_dashboard.dart';
import '../teacher/teacher_dashboard.dart';

class LoginScreen extends StatefulWidget {
  final String role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login as ${widget.role}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final result = await _authService.login(
                  _emailController.text,
                  _passwordController.text,
                );
                
                if (result['error'] != null) {
                  _showSnackBar(result['error']);
                } else if (result['user'] != null) {
                  final String? role = await _firestoreService.getUserRole(result['user'].uid);
                  
                  if (role != widget.role.toLowerCase()) {
                    _showSnackBar("Unauthorized: You are not a ${widget.role}");
                  } else {
                    _showSnackBar("Login Successful");
                    
                    if (role == 'student') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const StudentDashboard()),
                      );
                    } else if (role == 'teacher') {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const TeacherDashboard()),
                      );
                    }
                  }
                }
              },
              child: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
