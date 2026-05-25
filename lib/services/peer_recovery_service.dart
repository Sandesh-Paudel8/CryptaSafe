import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'rsa_service.dart';

const _kTrustedPeers = 'cryptasafe_trusted_peers';

class PeerRecoveryService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _rsaService = RSAService();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  Future<void> addTrustedPeer({
    required String peerEmail,
    required String peerPublicKeyPem,
    required String masterPassword,
    required Uint8List salt,
  }) async {
    final payload = jsonEncode({
      'password': masterPassword,
      'salt': base64.encode(salt),
    });
    final encrypted = _rsaService.encryptWithPublicKey(
      Uint8List.fromList(utf8.encode(payload)),
      peerPublicKeyPem,
    );
    await _firestore
        .collection('peer_recovery')
        .doc(peerEmail)
        .collection('recoveries')
        .doc(_uid)
        .set({
      'fromUid': _uid,
      'fromEmail': _auth.currentUser!.email,
      'encryptedSecret': base64.encode(encrypted),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _savePeerLocally(peerEmail, peerPublicKeyPem);
  }

  Future<List<Map<String, String>>> getTrustedPeers() async {
    final raw = await _storage.read(key: _kTrustedPeers);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded.cast<Map<String, String>>();
  }

  Future<void> removeTrustedPeer(String peerEmail) async {
    final peers = await getTrustedPeers();
    peers.removeWhere((p) => p['email'] == peerEmail);
    await _storage.write(key: _kTrustedPeers, value: jsonEncode(peers));
    await _firestore
        .collection('peer_recovery')
        .doc(peerEmail)
        .collection('recoveries')
        .doc(_uid)
        .delete();
  }

  Future<Map<String, dynamic>?> checkForRecoveryData() async {
    final myEmail = _auth.currentUser?.email;
    if (myEmail == null) return null;
    final snapshot = await _firestore
        .collection('peer_recovery')
        .doc(myEmail)
        .collection('recoveries')
        .get();
    if (snapshot.docs.isEmpty) return null;
    for (final doc in snapshot.docs) {
      try {
        final encBytes = base64.decode(doc.data()['encryptedSecret'] as String);
        final decBytes = await _rsaService.decryptWithPrivateKey(encBytes);
        final decoded = jsonDecode(utf8.decode(decBytes));
        return {
          'password': decoded['password'],
          'salt': base64.decode(decoded['salt'] as String),
          'fromEmail': doc.data()['fromEmail'],
        };
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<void> _savePeerLocally(String email, String publicKeyPem) async {
    final peers = await getTrustedPeers();
    peers.removeWhere((p) => p['email'] == email);
    peers.add({'email': email, 'publicKey': publicKeyPem});
    await _storage.write(key: _kTrustedPeers, value: jsonEncode(peers));
  }
}
