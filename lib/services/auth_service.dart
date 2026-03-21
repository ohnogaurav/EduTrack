import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _mapErrorCode(String errorCode) {
    switch (errorCode) {
      case 'invalid-email':
        return 'Invalid email format';
      case 'user-not-found':
        return 'User not found';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'Email already registered';
      case 'weak-password':
        return 'Password should be at least 6 characters';
      case 'user-disabled':
        return 'This user has been disabled';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled';
      default:
        return 'An error occurred. Please try again';
    }
  }

  Future<Map<String, dynamic>> signUp(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return {'user': result.user, 'error': null};
    } on FirebaseAuthException catch (e) {
      return {'user': null, 'error': _mapErrorCode(e.code)};
    } catch (e) {
      return {'user': null, 'error': 'An unexpected error occurred'};
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return {'user': result.user, 'error': null};
    } on FirebaseAuthException catch (e) {
      return {'user': null, 'error': _mapErrorCode(e.code)};
    } catch (e) {
      return {'user': null, 'error': 'An unexpected error occurred'};
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print("LOGOUT ERROR: $e");
    }
  }
}
