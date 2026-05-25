import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/firebase_auth_service.dart';
import '../services/wipe_service.dart';
import '../services/sms_wipe_service.dart';
import 'peer_recovery_screen.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';
import 'setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String masterPassword;
  final Uint8List salt;

  const SettingsScreen({
    Key? key,
    required this.masterPassword,
    required this.salt,
  }) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _firebaseAuth = FirebaseAuthService();
  final _smsWipeService = SmsWipeService();
  bool _hasSmsPermission = false;
  bool _checkingPermission = true;

  @override
  void initState() {
    super.initState();
    _checkSmsPermission();
  }

  Future<void> _checkSmsPermission() async {
    final granted = await _smsWipeService.hasSmsPermission();
    if (mounted) {
      setState(() {
        _hasSmsPermission = granted;
        _checkingPermission = false;
      });
    }
  }

  Future<void> _requestSmsPermission() async {
    await _smsWipeService.requestSmsPermission();
    await _checkSmsPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.grey[900],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Account ────────────────────────────────────────
          if (_firebaseAuth.isLoggedIn) ...[
            _sectionLabel('Account'),
            _tile(
              icon: Icons.email_outlined,
              title: _firebaseAuth.currentUser?.email ?? 'Signed in',
              subtitle: 'Firebase cloud account',
              onTap: null,
            ),
            _tile(
              icon: Icons.logout,
              title: 'Sign out of cloud',
              subtitle: 'Your vault stays on device',
              onTap: () async {
                await _firebaseAuth.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                  (route) => false,
                );
              },
            ),
            const SizedBox(height: 20),
          ],

          // ── Security ────────────────────────────────────────
          _sectionLabel('Security'),
          _tile(
            icon: Icons.lock_reset_outlined,
            title: 'Change master password',
            subtitle: 'Update your vault password',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ChangePasswordScreen(),
            )),
          ),
          _tile(
            icon: Icons.people_outline,
            title: 'Trusted peer recovery',
            subtitle: 'Add contacts who can restore your vault',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PeerRecoveryScreen(
                masterPassword: widget.masterPassword,
                salt: widget.salt,
              ),
            )),
          ),
          _tile(
            icon: Icons.lock_clock_outlined,
            title: 'Auto-lock timeout',
            subtitle: '2 minutes of inactivity',
            onTap: null,
          ),
          _tile(
            icon: Icons.calculate_outlined,
            title: 'Disguise mode',
            subtitle: 'App appears as calculator — enter 1337. to unlock',
            onTap: null,
          ),
          const SizedBox(height: 20),

          // ── SMS Remote Wipe ─────────────────────────────────
          _sectionLabel('SMS Remote Wipe'),

          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blueGrey[800]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sms_outlined,
                        color: Colors.blueGrey[300], size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Secret wipe command',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(const ClipboardData(
                            text: 'CRYPTASAFE_WIPE_NOW'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Wipe command copied')),
                        );
                      },
                      child: Icon(Icons.copy_outlined,
                          color: Colors.blueGrey[400], size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: const Text(
                    'CRYPTASAFE_WIPE_NOW',
                    style: TextStyle(
                      color: Colors.orange,
                      fontFamily: 'monospace',
                      fontSize: 13,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Send this SMS to your own number from another device to remotely wipe the vault.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),

          _checkingPermission
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                        color: Colors.blueGrey, strokeWidth: 2),
                  ))
              : _hasSmsPermission
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[900]!.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green[800]!),
                      ),
                      child: const Row(children: [
                        Icon(Icons.check_circle_outline,
                            color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'SMS permission granted — remote wipe active',
                            style: TextStyle(
                                color: Colors.green, fontSize: 13),
                          ),
                        ),
                      ]),
                    )
                  : _tile(
                      icon: Icons.sms_failed_outlined,
                      title: 'Enable SMS wipe',
                      subtitle: 'Grant permission to activate remote wipe',
                      onTap: _requestSmsPermission,
                      isWarning: true,
                    ),

          const SizedBox(height: 20),

          // ── Danger zone ─────────────────────────────────────
          _sectionLabel('Danger zone'),
          _tile(
            icon: Icons.delete_forever_outlined,
            title: 'Wipe entire vault',
            subtitle: 'Delete all local and cloud data permanently',
            onTap: () => _confirmWipe(context),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  void _confirmWipe(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Wipe vault?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This permanently deletes all local files, keys, and cloud backups. There is no recovery.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: TextStyle(color: Colors.blueGrey[300])),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await WipeService().wipeAll();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SetupScreen()),
                (route) => false,
              );
            },
            child: const Text('Wipe everything',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
              color: Colors.blueGrey[300],
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2),
        ),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool isDestructive = false,
    bool isWarning = false,
  }) =>
      Card(
        color: Colors.grey[900],
        margin: const EdgeInsets.only(bottom: 8),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: ListTile(
          leading: Icon(icon,
              color: isDestructive
                  ? Colors.red
                  : isWarning
                      ? Colors.orange
                      : Colors.blueGrey),
          title: Text(title,
              style: TextStyle(
                  color: isDestructive
                      ? Colors.red
                      : isWarning
                          ? Colors.orange
                          : Colors.white,
                  fontSize: 14)),
          subtitle: Text(subtitle,
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          trailing: onTap != null
              ? const Icon(Icons.arrow_forward_ios,
                  size: 14, color: Colors.grey)
              : null,
          onTap: onTap,
        ),
      );
}
