import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CloudBackupService {
  final _storage = FirebaseStorage.instance;
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;
  CollectionReference get _meta =>
      _firestore.collection('vaults').doc(_uid).collection('files');

  Future<void> uploadEncryptedFile(Uint8List bytes, String fileName) async {
    final ref = _storage.ref('vaults/$_uid/$fileName');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/octet-stream'),
    );
    final url = await task.ref.getDownloadURL();
    await _meta.doc(fileName).set({
      'fileName': fileName,
      'sizeBytes': bytes.length,
      'uploadedAt': FieldValue.serverTimestamp(),
      'downloadUrl': url,
    });
  }

  Future<Uint8List> downloadEncryptedFile(String fileName) async {
    final ref = _storage.ref('vaults/$_uid/$fileName');
    final bytes = await ref.getData(50 * 1024 * 1024);
    if (bytes == null) throw Exception('Empty download');
    return bytes;
  }

  Future<List<Map<String, dynamic>>> listBackedUpFiles() async {
    final snapshot =
        await _meta.orderBy('uploadedAt', descending: true).get();
    return snapshot.docs.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      return {
        'fileName': d['fileName'] ?? doc.id,
        'sizeBytes': d['sizeBytes'] ?? 0,
        'uploadedAt': d['uploadedAt'],
        'downloadUrl': d['downloadUrl'] ?? '',
      };
    }).toList();
  }

  Future<void> deleteBackedUpFile(String fileName) async {
    await _storage.ref('vaults/$_uid/$fileName').delete();
    await _meta.doc(fileName).delete();
  }

  Future<void> wipeAllCloudBackups() async {
    final files = await listBackedUpFiles();
    for (final f in files) {
      await deleteBackedUpFile(f['fileName']);
    }
  }
}
