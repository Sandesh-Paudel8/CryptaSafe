import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/asymmetric/oaep.dart';
import 'package:pointycastle/key_generators/api.dart';
import 'package:pointycastle/key_generators/rsa_key_generator.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/random/fortuna_random.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:asn1lib/asn1lib.dart';

const _kRsaPublicKey = 'cryptasafe_rsa_public';
const _kRsaPrivateKey = 'cryptasafe_rsa_private';

class RSAService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> generateAndStoreKeyPair() async {
    final existing = await _storage.read(key: _kRsaPublicKey);
    if (existing != null) return;
    final keyPair = _generateKeyPair();
    await _storage.write(
        key: _kRsaPublicKey,
        value: _encodePublicKey(keyPair.publicKey as RSAPublicKey));
    await _storage.write(
        key: _kRsaPrivateKey,
        value: _encodePrivateKey(keyPair.privateKey as RSAPrivateKey));
  }

  Future<String?> getPublicKeyPem() async =>
      await _storage.read(key: _kRsaPublicKey);

  Uint8List encryptWithPublicKey(Uint8List data, String publicKeyPem) {
    final key = _decodePublicKey(publicKeyPem);
    final engine = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(key));
    return _processBlocks(engine, data);
  }

  Future<Uint8List> decryptWithPrivateKey(Uint8List data) async {
    final pem = await _storage.read(key: _kRsaPrivateKey);
    if (pem == null) throw Exception('No private key found');
    final key = _decodePrivateKey(pem);
    final engine = OAEPEncoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(key));
    return _processBlocks(engine, data);
  }

  // ── Internal helpers ──────────────────────────────────────────

  AsymmetricKeyPair<PublicKey, PrivateKey> _generateKeyPair() {
    final secureRandom = FortunaRandom();
    final seed = List<int>.generate(32, (_) => Random.secure().nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seed)));
    final keyGen = RSAKeyGenerator()
      ..init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        secureRandom,
      ));
    return keyGen.generateKeyPair();
  }

  Uint8List _processBlocks(AsymmetricBlockCipher engine, Uint8List input) {
    final output = <int>[];
    var offset = 0;
    while (offset < input.length) {
      final end = (offset + engine.inputBlockSize).clamp(0, input.length);
      output.addAll(engine.process(input.sublist(offset, end)));
      offset = end;
    }
    return Uint8List.fromList(output);
  }

  String _encodePublicKey(RSAPublicKey key) {
    final seq = ASN1Sequence()
      ..add(ASN1Integer(key.modulus!))
      ..add(ASN1Integer(key.exponent!));
    final b64 = base64.encode(seq.encodedBytes);
    return '-----BEGIN PUBLIC KEY-----\n$b64\n-----END PUBLIC KEY-----';
  }

  String _encodePrivateKey(RSAPrivateKey key) {
    final seq = ASN1Sequence()
      ..add(ASN1Integer(BigInt.zero))
      ..add(ASN1Integer(key.modulus!))
      ..add(ASN1Integer(key.publicExponent!))
      ..add(ASN1Integer(key.privateExponent!))
      ..add(ASN1Integer(key.p!))
      ..add(ASN1Integer(key.q!))
      ..add(ASN1Integer(key.privateExponent! % (key.p! - BigInt.one)))
      ..add(ASN1Integer(key.privateExponent! % (key.q! - BigInt.one)))
      ..add(ASN1Integer(key.q!.modInverse(key.p!)));
    final b64 = base64.encode(seq.encodedBytes);
    return '-----BEGIN RSA PRIVATE KEY-----\n$b64\n-----END RSA PRIVATE KEY-----';
  }

  RSAPublicKey _decodePublicKey(String pem) {
    final b64 = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll('\n', '')
        .trim();
    final bytes = base64.decode(b64);
    final parser = ASN1Parser(bytes);
    final seq = parser.nextObject() as ASN1Sequence;
    final modulus = (seq.elements[0] as ASN1Integer).valueAsBigInteger;
    final exponent = (seq.elements[1] as ASN1Integer).valueAsBigInteger;
    return RSAPublicKey(modulus, exponent);
  }

  RSAPrivateKey _decodePrivateKey(String pem) {
    final b64 = pem
        .replaceAll('-----BEGIN RSA PRIVATE KEY-----', '')
        .replaceAll('-----END RSA PRIVATE KEY-----', '')
        .replaceAll('\n', '')
        .trim();
    final bytes = base64.decode(b64);
    final parser = ASN1Parser(bytes);
    final seq = parser.nextObject() as ASN1Sequence;
    final modulus = (seq.elements[1] as ASN1Integer).valueAsBigInteger;
    final publicExponent = (seq.elements[2] as ASN1Integer).valueAsBigInteger;
    final privateExponent = (seq.elements[3] as ASN1Integer).valueAsBigInteger;
    final p = (seq.elements[4] as ASN1Integer).valueAsBigInteger;
    final q = (seq.elements[5] as ASN1Integer).valueAsBigInteger;
    return RSAPrivateKey(modulus, privateExponent, p, q);
  }
}
