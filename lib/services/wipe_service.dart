import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'storage_service.dart';
import 'cloud_backup_service.dart';
import 'firebase_auth_service.dart';

class WipeService {
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _storageService = StorageService();
  final _cloudBackupService = CloudBackupService();
  final _firebaseAuth = FirebaseAuthService();

  /// Wipes everything: local files, secure storage, cloud backups
  Future<void> wipeAll() async {
    // 1. Delete all local encrypted files (overwrite before delete)
    await _storageService.wipeAllFiles();

    // 2. Wipe cloud backups if signed in
    if (_firebaseAuth.isLoggedIn) {
      try {
        await _cloudBackupService.wipeAllCloudBackups();
      } catch (_) {
        // Best effort — don't block local wipe if cloud fails
      }
      await _firebaseAuth.signOut();
    }

    // 3. Clear all secure storage (passwords, keys, salt)
    await _secureStorage.deleteAll();
  }
}
