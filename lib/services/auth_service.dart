import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'encryption_service.dart';

const _kPasswordHash = 'cryptasafe_password_hash';
const _kPasswordRaw = 'cryptasafe_password_raw';
const _kSalt = 'cryptasafe_salt';
const _kIsSetup = 'cryptasafe_is_setup';
const _kDecoyHash = 'cryptasafe_decoy_hash';

class AuthService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _enc = EncryptionService();

  Future<bool> isVaultSetup() async {
    final val = await _storage.read(key: _kIsSetup);
    return val == 'true';
  }

  Future<void> setupVault(String password, {String? decoyPassword}) async {
    final salt = _enc.generateSalt();
    await _storage.write(key: _kSalt, value: base64.encode(salt));
    await _storage.write(key: _kPasswordHash, value: _enc.hashPassword(password));
    await _storage.write(key: _kPasswordRaw, value: password);
    await _storage.write(key: _kIsSetup, value: 'true');
    if (decoyPassword != null && decoyPassword.isNotEmpty) {
      await _storage.write(
          key: _kDecoyHash, value: _enc.hashPassword(decoyPassword));
    }
  }

  Future<VaultType> validatePassword(String password) async {
    final storedHash = await _storage.read(key: _kPasswordHash);
    final decoyHash = await _storage.read(key: _kDecoyHash);
    final inputHash = _enc.hashPassword(password);
    if (storedHash != null && inputHash == storedHash) return VaultType.real;
    if (decoyHash != null && inputHash == decoyHash) return VaultType.decoy;
    return VaultType.invalid;
  }

  Future<Uint8List?> getSalt() async {
    final saltB64 = await _storage.read(key: _kSalt);
    if (saltB64 == null) return null;
    return base64.decode(saltB64);
  }

  Future<String?> getStoredPassword() async {
    return await _storage.read(key: _kPasswordRaw);
  }

  Future<void> changePassword(String newPassword) async {
    final salt = _enc.generateSalt();
    await _storage.write(key: _kSalt, value: base64.encode(salt));
    await _storage.write(key: _kPasswordHash, value: _enc.hashPassword(newPassword));
    await _storage.write(key: _kPasswordRaw, value: newPassword);
  }

  Future<void> wipeVault() async {
    await _storage.deleteAll();
  }
}

enum VaultType { real, decoy, invalid }
