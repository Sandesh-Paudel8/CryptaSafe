import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUp(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> signOut() async => await _auth.signOut();

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  String _handleError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password': return 'Password is too weak.';
      case 'email-already-in-use': return 'Account already exists with this email.';
      case 'user-not-found': return 'No account found with this email.';
      case 'wrong-password': return 'Incorrect password.';
      case 'invalid-email': return 'Invalid email address.';
      case 'too-many-requests': return 'Too many attempts. Try again later.';
      default: return e.message ?? 'Authentication failed.';
    }
  }
}
