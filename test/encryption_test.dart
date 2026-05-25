import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptasafe/services/encryption_service.dart';

void main() {
  final enc = EncryptionService();
  late Uint8List salt;

  setUp(() {
    salt = enc.generateSalt();
  });

  group('EncryptionService — Text', () {
    test('encrypt then decrypt returns original text', () {
      const original = 'Hello CryptaSafe!';
      const password = 'TestPassword123';

      final encrypted = enc.encryptText(original, password, salt);
      final decrypted = enc.decryptText(encrypted, password, salt);

      expect(decrypted, equals(original));
    });

    test('encrypted text is different from original', () {
      const original = 'Secret message';
      const password = 'TestPassword123';

      final encrypted = enc.encryptText(original, password, salt);

      expect(encrypted, isNot(equals(original)));
    });

    test('same text encrypted twice produces different ciphertext (random IV)', () {
      const original = 'Same message';
      const password = 'TestPassword123';

      final encrypted1 = enc.encryptText(original, password, salt);
      final encrypted2 = enc.encryptText(original, password, salt);

      expect(encrypted1, isNot(equals(encrypted2)));
    });

    test('decrypt with wrong password throws exception', () {
      const original = 'Secret message';
      const password = 'CorrectPassword';
      const wrongPassword = 'WrongPassword';

      final encrypted = enc.encryptText(original, password, salt);

      expect(
        () => enc.decryptText(encrypted, wrongPassword, salt),
        throwsException,
      );
    });

    test('decrypt with wrong salt throws exception', () {
      const original = 'Secret message';
      const password = 'TestPassword123';
      final wrongSalt = enc.generateSalt();

      final encrypted = enc.encryptText(original, password, salt);

      expect(
        () => enc.decryptText(encrypted, password, wrongSalt),
        throwsException,
      );
    });
  });

  group('EncryptionService — Files', () {
    test('encrypt then decrypt file returns original bytes', () {
      final originalBytes =
          Uint8List.fromList([1, 2, 3, 4, 5, 100, 200, 255]);
      const password = 'TestPassword123';

      final encrypted = enc.encryptFile(originalBytes, password, salt);
      final decrypted = enc.decryptFile(encrypted, password, salt);

      expect(decrypted, equals(originalBytes));
    });

    test('encrypted file is longer than original (IV prepended)', () {
      final originalBytes =
          Uint8List.fromList(List.generate(100, (i) => i));
      const password = 'TestPassword123';

      final encrypted = enc.encryptFile(originalBytes, password, salt);

      expect(encrypted.length, greaterThan(originalBytes.length));
    });

    test('encrypted file with wrong password throws exception', () {
      final originalBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      const password = 'CorrectPassword';
      const wrongPassword = 'WrongPassword';

      final encrypted = enc.encryptFile(originalBytes, password, salt);

      expect(
        () => enc.decryptFile(encrypted, wrongPassword, salt),
        throwsException,
      );
    });

    test('corrupted file throws exception', () {
      final tooShort = Uint8List.fromList([1, 2, 3]);

      expect(
        () => enc.decryptFile(tooShort, 'password', salt),
        throwsException,
      );
    });
  });

  group('EncryptionService — Password hashing', () {
    test('same password produces same hash', () {
      const password = 'MyPassword123';
      expect(
        enc.hashPassword(password),
        equals(enc.hashPassword(password)),
      );
    });

    test('different passwords produce different hashes', () {
      expect(
        enc.hashPassword('Password1'),
        isNot(equals(enc.hashPassword('Password2'))),
      );
    });

    test('hash is not the original password', () {
      const password = 'MyPassword123';
      expect(enc.hashPassword(password), isNot(equals(password)));
    });

    test('hash is 64 characters (SHA-256 hex)', () {
      expect(enc.hashPassword('anything').length, equals(64));
    });
  });

  group('EncryptionService — Salt and Key derivation', () {
    test('generateSalt returns 32 bytes', () {
      expect(enc.generateSalt().length, equals(32));
    });

    test('two salts are different (random)', () {
      final salt1 = enc.generateSalt();
      final salt2 = enc.generateSalt();
      expect(salt1, isNot(equals(salt2)));
    });

    test('deriveKey returns 32 bytes', () {
      final key = enc.deriveKey('password', salt);
      expect(key.length, equals(32));
    });

    test('same password and salt always derives same key', () {
      final key1 = enc.deriveKey('password', salt);
      final key2 = enc.deriveKey('password', salt);
      expect(key1, equals(key2));
    });

    test('different passwords derive different keys', () {
      final key1 = enc.deriveKey('password1', salt);
      final key2 = enc.deriveKey('password2', salt);
      expect(key1, isNot(equals(key2)));
    });
  });
}
