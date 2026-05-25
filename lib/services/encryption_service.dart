import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/export.dart' as pc;

class EncryptionService {
  static const int _ivLength = 16;
  static const int _saltLength = 32;
  static const int _pbkdf2Iterations = 100000;
  static const int _keyLength = 32;

  /// Derives AES-256 key from password using PBKDF2-SHA256
  Uint8List deriveKey(String password, Uint8List salt) {
    final pbkdf2 = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64));
    pbkdf2.init(pc.Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLength));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Generates a cryptographically random salt
  Uint8List generateSalt() {
    final rng = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(_saltLength, (_) => rng.nextInt(256)));
  }

  /// Generates a random IV per encryption
  Uint8List _generateIV() {
    final rng = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(_ivLength, (_) => rng.nextInt(256)));
  }

  /// Hashes password with SHA-256 for storage/comparison
  String hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Encrypts text — returns "base64(iv):base64(ciphertext)"
  String encryptText(String plainText, String password, Uint8List salt) {
    final key = Key(deriveKey(password, salt));
    final ivBytes = _generateIV();
    final iv = IV(ivBytes);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${base64.encode(ivBytes)}:${encrypted.base64}';
  }

  /// Decrypts text encrypted by encryptText
  String decryptText(String payload, String password, Uint8List salt) {
    final parts = payload.split(':');
    if (parts.length != 2) throw const FormatException('Invalid format');
    final key = Key(deriveKey(password, salt));
    final iv = IV(base64.decode(parts[0]));
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    return encrypter.decrypt64(parts[1], iv: iv);
  }

  /// Encrypts file bytes — returns [16 bytes IV][encrypted data]
  Uint8List encryptFile(Uint8List fileBytes, String password, Uint8List salt) {
    final key = Key(deriveKey(password, salt));
    final ivBytes = _generateIV();
    final iv = IV(ivBytes);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encryptBytes(fileBytes, iv: iv);
    final result = Uint8List(_ivLength + encrypted.bytes.length);
    result.setRange(0, _ivLength, ivBytes);
    result.setRange(_ivLength, result.length, encrypted.bytes);
    return result;
  }

  /// Decrypts file bytes — reads IV from first 16 bytes
  Uint8List decryptFile(Uint8List encryptedBytes, String password, Uint8List salt) {
    if (encryptedBytes.length <= _ivLength) {
      throw const FormatException('File too short — corrupted?');
    }
    final ivBytes = encryptedBytes.sublist(0, _ivLength);
    final cipherBytes = encryptedBytes.sublist(_ivLength);
    final key = Key(deriveKey(password, salt));
    final iv = IV(ivBytes);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    return Uint8List.fromList(
        encrypter.decryptBytes(Encrypted(cipherBytes), iv: iv));
  }
}
