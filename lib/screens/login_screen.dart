import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import 'vault_screen.dart';
import 'decoy_vault_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _biometricService = BiometricService();

  bool _loading = false;
  bool _obscureText = true;
  bool _biometricAvailable = false;
  String? _errorMessage;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final available = await _biometricService.isBiometricAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
    if (available) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _authenticateWithBiometrics();
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    final success = await _biometricService.authenticate();
    if (!mounted) return;
    if (success) {
      final salt = await _authService.getSalt();
      final password = await _authService.getStoredPassword();
      if (!mounted) return;
      if (password == null || salt == null) {
        setState(() {
          _loading = false;
          _errorMessage = 'Biometric login unavailable — enter password';
        });
        return;
      }
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => VaultScreen(masterPassword: password, salt: salt),
      ));
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _unlockWithPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password');
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final vaultType = await _authService.validatePassword(password);
      if (!mounted) return;
      switch (vaultType) {
        case VaultType.real:
          final salt = await _authService.getSalt();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) =>
                VaultScreen(masterPassword: password, salt: salt!),
          ));
          break;
        case VaultType.decoy:
          Navigator.of(context).pushReplacement(MaterialPageRoute(
            builder: (_) => const DecoyVaultScreen(),
          ));
          break;
        case VaultType.invalid:
          _failedAttempts++;
          setState(() {
            _loading = false;
            _errorMessage = _failedAttempts >= 5
                ? 'Too many attempts. Wait 30 seconds.'
                : 'Incorrect password ($_failedAttempts/5 attempts)';
          });
          _passwordController.clear();
          break;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 72, color: Colors.white),
                const SizedBox(height: 20),
                const Text('CryptaSafe Vault',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 8),
                Text('Enter your master password to unlock',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                const SizedBox(height: 40),

                TextField(
                  controller: _passwordController,
                  obscureText: _obscureText,
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _unlockWithPassword(),
                  decoration: InputDecoration(
                    hintText: 'Master password',
                    hintStyle: TextStyle(color: Colors.grey[600]),
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
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscureText
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey[500],
                          size: 20),
                      onPressed: () =>
                          setState(() => _obscureText = !_obscureText),
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[900]!.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[800]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_errorMessage!,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_loading || _failedAttempts >= 5)
                        ? null
                        : _unlockWithPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[700],
                      disabledBackgroundColor: Colors.grey[900],
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
                        : const Text('Unlock Vault',
                            style: TextStyle(
                                fontSize: 16, color: Colors.white)),
                  ),
                  
                ),

                if (_biometricAvailable) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _loading ? null : _authenticateWithBiometrics,
                    icon: const Icon(Icons.fingerprint,
                        color: Colors.blueGrey, size: 28),
                    label: Text('Use biometrics',
                        style: TextStyle(color: Colors.blueGrey[300])),
                  ),
                  const SizedBox(height: 8),
TextButton.icon(
  onPressed: () {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Peer Recovery',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'To recover your vault, ask your trusted peer to open CryptaSafe and share their recovery code with you. Then sign in to Firebase and try again.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(color: Colors.blueGrey[300]),
            ),
          ),
        ],
      ),
    );
  },
  icon: Icon(
    Icons.people_outline,
    color: Colors.grey[600],
    size: 18,
  ),
  label: Text(
    'Recover via trusted peer',
    style: TextStyle(color: Colors.grey[600], fontSize: 13),
  ),
),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
