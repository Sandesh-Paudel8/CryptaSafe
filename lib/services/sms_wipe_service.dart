import 'package:flutter/services.dart';
import 'wipe_service.dart';

class SmsWipeService {
  // Method channel to communicate with Android native code
  static const _channel = MethodChannel('com.example.cryptasafe/sms_wipe');

  final _wipeService = WipeService();

  /// Check if a wipe was triggered by SMS while app was closed
  /// Call this in main.dart on app startup
  Future<bool> checkAndExecutePendingWipe() async {
    try {
      final bool wipeTriggered =
          await _channel.invokeMethod('checkWipeFlag') ?? false;
      if (wipeTriggered) {
        await _wipeService.wipeAll();
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      print('SmsWipeService error: ${e.message}');
      return false;
    }
  }

  /// Request SMS permission at runtime
  Future<bool> requestSmsPermission() async {
    try {
      final bool granted =
          await _channel.invokeMethod('requestSmsPermission') ?? false;
      return granted;
    } on PlatformException {
      return false;
    }
  }

  /// Check if SMS permission is granted
  Future<bool> hasSmsPermission() async {
    try {
      final bool granted =
          await _channel.invokeMethod('hasSmsPermission') ?? false;
      return granted;
    } on PlatformException {
      return false;
    }
  }
}
