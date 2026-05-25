import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({Key? key}) : super(key: key);

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _decoyController = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _showDecoy = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _decoyController.dispose();
    super.dispose();
  }

  Future<void> _setupVault() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (password.isEmpty) {
      setState(() => _errorMessage = 'Password cannot be empty');
      return;
    }
    if (password.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await _authService.setupVault(
        password,
        decoyPassword: _showDecoy ? _decoyController.text.trim() : null,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Setup failed. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.shield_outlined, size: 56, color: Colors.white),
              const SizedBox(height: 20),
              const Text('Set up your vault',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                'Create a strong master password. This cannot be recovered if lost.',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
              const SizedBox(height: 36),

              _label('Master password'),
              const SizedBox(height: 8),
              _passwordField(
                controller: _passwordController,
                hint: 'At least 8 characters',
                obscure: _obscurePassword,
                toggle: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              const SizedBox(height: 16),

              _label('Confirm password'),
              const SizedBox(height: 8),
              _passwordField(
                controller: _confirmController,
                hint: 'Re-enter your password',
                obscure: _obscureConfirm,
                toggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Switch(
                    value: _showDecoy,
                    onChanged: (v) => setState(() => _showDecoy = v),
                    activeColor: Colors.blueGrey[300],
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Enable decoy vault (optional)',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ),
                ],
              ),

              if (_showDecoy) ...[
                const SizedBox(height: 8),
                Text(
                  'Decoy password opens a fake vault with dummy files.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 10),
                _label('Decoy password'),
                const SizedBox(height: 8),
                TextField(
                  controller: _decoyController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecor('Enter decoy password'),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                _errorCard(_errorMessage!),
              ],

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _setupVault,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey[700],
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
                      : const Text('Create Vault',
                          style:
                              TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: TextStyle(color: Colors.grey[400], fontSize: 13));

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback toggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecor(hint).copyWith(
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey[500], size: 20),
          onPressed: toggle,
        ),
      ),
    );
  }

  Widget _errorCard(String message) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red[900]!.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red[700]!),
        ),
        child: Text(message,
            style: const TextStyle(color: Colors.red, fontSize: 13)),
      );

  InputDecoration _inputDecor(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[900],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[800]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.blueGrey[400]!),
        ),
      );
}
