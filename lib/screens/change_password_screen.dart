import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final current = _currentCtrl.text;
    final newPass = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }
    if (newPass.length < 8) {
      setState(() => _error = 'New password must be at least 8 characters');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'New passwords do not match');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      // Validate current password first
      final vaultType = await _authService.validatePassword(current);
      if (vaultType == VaultType.invalid) {
        setState(() {
          _error = 'Current password is incorrect';
          _loading = false;
        });
        return;
      }

      await _authService.changePassword(newPass);

      if (!mounted) return;
      setState(() {
        _success = 'Password changed successfully! Please log in again.';
        _loading = false;
      });

      // Navigate back to login after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to change password. Try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: Colors.grey[900],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              'Enter your current password then choose a new one.',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 28),

            _label('Current password'),
            const SizedBox(height: 8),
            _passField(
              controller: _currentCtrl,
              hint: 'Your current master password',
              obscure: _obscureCurrent,
              toggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
            ),

            const SizedBox(height: 16),
            _label('New password'),
            const SizedBox(height: 8),
            _passField(
              controller: _newCtrl,
              hint: 'At least 8 characters',
              obscure: _obscureNew,
              toggle: () => setState(() => _obscureNew = !_obscureNew),
            ),

            const SizedBox(height: 16),
            _label('Confirm new password'),
            const SizedBox(height: 8),
            _passField(
              controller: _confirmCtrl,
              hint: 'Re-enter new password',
              obscure: _obscureNew,
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              _msgCard(_error!, isError: true),
            ],
            if (_success != null) ...[
              const SizedBox(height: 16),
              _msgCard(_success!, isError: false),
            ],

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _changePassword,
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
                    : const Text('Change Password',
                        style:
                            TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) =>
      Text(text, style: TextStyle(color: Colors.grey[400], fontSize: 13));

  Widget _passField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    VoidCallback? toggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600]),
        filled: true,
        fillColor: Colors.grey[900],
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                    obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[500],
                    size: 20),
                onPressed: toggle,
              )
            : null,
      ),
    );
  }

  Widget _msgCard(String msg, {required bool isError}) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError
              ? Colors.red[900]!.withOpacity(0.25)
              : Colors.green[900]!.withOpacity(0.25),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isError ? Colors.red[800]! : Colors.green[800]!),
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
