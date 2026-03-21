import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      print("Signup Success: ${result.user?.email}");
      return result.user;
    } on FirebaseAuthException catch (e) {
      print("SIGNUP ERROR CODE: ${e.code}");
      print("SIGNUP ERROR MESSAGE: ${e.message}");
      return null;
    } catch (e, stack) {
      print("UNKNOWN SIGNUP ERROR: $e");
      print("STACK TRACE: $stack");
      return null;
    }
  }

  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      print("Login Success: ${result.user?.email}");
      return result.user;
    } on FirebaseAuthException catch (e) {
      print("LOGIN ERROR CODE: ${e.code}");
      print("LOGIN ERROR MESSAGE: ${e.message}");
      return null;
    } catch (e, stack) {
      print("UNKNOWN LOGIN ERROR: $e");
      print("STACK TRACE: $stack");
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _auth.signOut();
      print("Logout Success");
    } catch (e, stack) {
      print("LOGOUT ERROR: $e");
      print("STACK TRACE: $stack");
    }
  }
}