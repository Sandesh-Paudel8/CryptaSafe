import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';
import 'login_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _firebaseAuth = FirebaseAuthService();

  // Sign in controllers
  final _signInEmailCtrl = TextEditingController();
  final _signInPassCtrl = TextEditingController();

  // Sign up controllers
  final _signUpEmailCtrl = TextEditingController();
  final _signUpPassCtrl = TextEditingController();
  final _signUpConfirmCtrl = TextEditingController();

  bool _loading = false;
  bool _obscureSignIn = true;
  bool _obscureSignUp = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _errorMessage = null;
          _successMessage = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInEmailCtrl.dispose();
    _signInPassCtrl.dispose();
    _signUpEmailCtrl.dispose();
    _signUpPassCtrl.dispose();
    _signUpConfirmCtrl.dispose();
    super.dispose();
  }

  // Navigate to vault after successful auth
  void _navigateToVault() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _signIn() async {
    final email = _signInEmailCtrl.text.trim();
    final password = _signInPassCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await _firebaseAuth.signIn(email, password);
      if (!mounted) return;
      _navigateToVault();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _signUp() async {
    final email = _signUpEmailCtrl.text.trim();
    final password = _signUpPassCtrl.text;
    final confirm = _signUpConfirmCtrl.text;

    // Validation
    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }
    if (password.length < 6) {
      setState(() =>
          _errorMessage = 'Password must be at least 6 characters');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Sign up creates account AND signs in automatically
      await _firebaseAuth.signUp(email, password);
      if (!mounted) return;

      // Show brief success then navigate
      setState(() {
        _loading = false;
        _successMessage = 'Account created successfully!';
      });

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      // Navigate directly to vault — no need to sign in again
      _navigateToVault();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    final email = _signInEmailCtrl.text.trim();
    if (email.isEmpty) {
      setState(
          () => _errorMessage = 'Enter your email above first');
      return;
    }
    try {
      await _firebaseAuth.sendPasswordReset(email);
      setState(() => _successMessage =
          'Password reset email sent to $email');
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Header
              const Icon(Icons.cloud_outlined,
                  size: 52, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                'CryptaSafe Cloud',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Sign in or create an account to enable cloud backup',
                style:
                    TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
              const SizedBox(height: 28),

              // Tab bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.blueGrey[700],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[500],
                  tabs: const [
                    Tab(text: 'Sign In'),
                    Tab(text: 'Sign Up'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // ── Sign In ──────────────────────────────
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _field(
                            controller: _signInEmailCtrl,
                            hint: 'Email address',
                            icon: Icons.email_outlined,
                            type: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          _field(
                            controller: _signInPassCtrl,
                            hint: 'Password',
                            icon: Icons.lock_outline,
                            obscure: _obscureSignIn,
                            toggle: () => setState(() =>
                                _obscureSignIn = !_obscureSignIn),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _resetPassword,
                              child: Text('Forgot password?',
                                  style: TextStyle(
                                      color: Colors.blueGrey[300],
                                      fontSize: 12)),
                            ),
                          ),
                          _submitBtn('Sign In', _signIn),
                          const SizedBox(height: 12),
                          _skipBtn(),
                        ],
                      ),
                    ),

                    // ── Sign Up ──────────────────────────────
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          _field(
                            controller: _signUpEmailCtrl,
                            hint: 'Email address',
                            icon: Icons.email_outlined,
                            type: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          _field(
                            controller: _signUpPassCtrl,
                            hint: 'Password (min 6 characters)',
                            icon: Icons.lock_outline,
                            obscure: _obscureSignUp,
                            toggle: () => setState(() =>
                                _obscureSignUp = !_obscureSignUp),
                          ),
                          const SizedBox(height: 14),
                          _field(
                            controller: _signUpConfirmCtrl,
                            hint: 'Confirm password',
                            icon: Icons.lock_outline,
                            obscure: _obscureSignUp,
                          ),
                          const SizedBox(height: 20),
                          _submitBtn('Create Account', _signUp),
                          const SizedBox(height: 12),
                          _skipBtn(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Messages
              if (_errorMessage != null) _msgCard(_errorMessage!, true),
              if (_successMessage != null)
                _msgCard(_successMessage!, false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? toggle,
    TextInputType? type,
  }) =>
      TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[600]),
          prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
          filled: true,
          fillColor: Colors.grey[900],
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[800]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.blueGrey[400]!),
          ),
          suffixIcon: toggle != null
              ? IconButton(
                  icon: Icon(
                      obscure
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey[600],
                      size: 18),
                  onPressed: toggle,
                )
              : null,
        ),
      );

  Widget _submitBtn(String label, VoidCallback onPressed) =>
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[700],
            disabledBackgroundColor: Colors.grey[800],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 16, color: Colors.white)),
        ),
      );

  Widget _skipBtn() => SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (_) => const LoginScreen()),
            (route) => false,
          ),
          child: Text(
            'Skip — use offline only',
            style:
                TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
      );

  Widget _msgCard(String msg, bool isError) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError
              ? Colors.red[900]!.withOpacity(0.25)
              : Colors.green[900]!.withOpacity(0.25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color:
                  isError ? Colors.red[800]! : Colors.green[800]!),
        ),
        child: Row(
          children: [
            Icon(
                isError
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                color: isError ? Colors.red : Colors.green,
                size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg,
                  style: TextStyle(
                      color: isError ? Colors.red : Colors.green,
                      fontSize: 13)),
            ),
          ],
        ),
      );
}
