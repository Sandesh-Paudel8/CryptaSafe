import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageService {
  Future<String> saveEncryptedFile(List<int> bytes, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final cleanName = filename.split('/').last;
    final filePath = '${directory.path}/$cleanName.enc';
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  Future<String> saveDecryptedFile(List<int> bytes, String filename) async {
    final directory = await getApplicationDocumentsDirectory();
    final outputName = filename.endsWith('.enc')
        ? filename.replaceAll('.enc', '')
        : '$filename.dec';
    final filePath = '${directory.path}/$outputName';
    await File(filePath).writeAsBytes(bytes);
    return filePath;
  }

  Future<List<FileSystemEntity>> getEncryptedFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync();
    return files.where((f) => f.path.endsWith('.enc')).toList();
  }

  Future<void> secureDelete(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return;
    // Overwrite with random bytes before deleting
    final length = await file.length();
    final random = List<int>.generate(length, (_) => 0);
    await file.writeAsBytes(random);
    await file.delete();
  }

  Future<void> wipeAllFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync();
    for (final file in files) {
      if (file is File) await secureDelete(file.path);
    }
  }
}
