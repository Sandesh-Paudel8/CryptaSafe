import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  /// Zips all encrypted files from the vault directory
  /// and shares the zip file using the system share sheet
  Future<void> exportVaultAsZip() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.enc'))
        .toList();

    if (files.isEmpty) {
      throw Exception('No encrypted files to export');
    }

    final encoder = ZipFileEncoder();
    final zipPath =
        '${directory.path}/cryptasafe_backup_${DateTime.now().millisecondsSinceEpoch}.zip';
    encoder.create(zipPath);

    for (final file in files) {
      encoder.addFile(file);
    }
    encoder.close();

    // Share the zip file
    await Share.shareXFiles(
      [XFile(zipPath)],
      subject: 'CryptaSafe Encrypted Backup',
      text:
          'CryptaSafe encrypted vault backup. Files are AES-256 encrypted and can only be decrypted with your master password.',
    );

    // Clean up zip after sharing
    await Future.delayed(const Duration(seconds: 5));
    final zipFile = File(zipPath);
    if (await zipFile.exists()) await zipFile.delete();
  }
}
