import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final _auth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authenticate to unlock CryptaSafe Vault',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          sensitiveTransaction: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}
