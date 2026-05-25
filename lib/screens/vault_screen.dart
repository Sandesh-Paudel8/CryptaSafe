import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/encryption_service.dart';
import '../services/storage_service.dart';
import '../services/cloud_backup_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/export_service.dart';
import 'auto_lock_wrapper.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'notes_screen.dart';

class VaultScreen extends StatefulWidget {
  final String masterPassword;
  final Uint8List salt;

  const VaultScreen({
    Key? key,
    required this.masterPassword,
    required this.salt,
  }) : super(key: key);

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final _searchController = TextEditingController();
  final _enc = EncryptionService();
  final _store = StorageService();
  final _cloud = CloudBackupService();
  final _fbAuth = FirebaseAuthService();
  final _exportService = ExportService();

  List<FileSystemEntity> _localFiles = [];
  List<FileSystemEntity> _filteredFiles = [];
  List<Map<String, dynamic>> _cloudFiles = [];
  bool _cloudLoading = false;
  bool _showCloud = false;
  bool _isSearching = false;

  // Loading overlay state
  bool _operationLoading = false;
  String _operationMessage = '';

  @override
  void initState() {
    super.initState();
    _blockScreenshots();
    _loadLocalFiles();
    if (_fbAuth.isLoggedIn) _loadCloudFiles();
    _searchController.addListener(_filterFiles);
  }

  // Screenshot prevention
  void _blockScreenshots() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    // FLAG_SECURE equivalent via method channel would go here
    // Flutter handles this via android:windowSecure in styles
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalFiles() async {
    final files = await _store.getEncryptedFiles();
    if (mounted) {
      setState(() {
        _localFiles = files;
        _filteredFiles = files;
      });
    }
  }

  void _filterFiles() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFiles = _localFiles.where((f) {
        final name = f.path.split('/').last.toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _loadCloudFiles() async {
    setState(() => _cloudLoading = true);
    try {
      final files = await _cloud.listBackedUpFiles();
      if (mounted) setState(() => _cloudFiles = files);
    } catch (e) {
      _snack('Could not load cloud files', success: false);
    } finally {
      if (mounted) setState(() => _cloudLoading = false);
    }
  }

  void _showOverlay(String message) {
    setState(() {
      _operationLoading = true;
      _operationMessage = message;
    });
  }

  void _hideOverlay() {
    if (mounted) setState(() => _operationLoading = false);
  }

Future<void> _pickAndEncrypt() async {
  // Pause auto-lock while file picker is open
  autoLockPaused = true;
  try {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null) return;
    final bytes = result.files.single.bytes;
    final name = result.files.single.name;
    if (bytes == null) return;

    _showOverlay('Encrypting $name...');
    try {
      final encrypted =
          _enc.encryptFile(bytes, widget.masterPassword, widget.salt);
      await _store.saveEncryptedFile(encrypted, name);
      await _loadLocalFiles();
      _snack('File encrypted and saved', success: true);
    } catch (e) {
      _snack('Encryption failed', success: false);
    } finally {
      _hideOverlay();
    }
  } finally {
    // Always resume auto-lock after file picker closes
    autoLockPaused = false;
  }
}

Future<void> _pickAndDecrypt() async {
  autoLockPaused = true;
  try {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null) return;
    final bytes = result.files.single.bytes;
    final name = result.files.single.name;
    if (!name.endsWith('.enc')) {
      _snack('Select an .enc file', success: false);
      return;
    }
    if (bytes == null) return;

    _showOverlay('Decrypting $name...');
    try {
      final decrypted =
          _enc.decryptFile(bytes, widget.masterPassword, widget.salt);
      await _store.saveDecryptedFile(decrypted, name);
      _snack('File decrypted and restored', success: true);
    } catch (e) {
      _snack('Decryption failed', success: false);
    } finally {
      _hideOverlay();
    }
  } finally {
    autoLockPaused = false;
  }
}

  Future<void> _decryptLocalFile(FileSystemEntity file) async {
    final name = file.path.split('/').last;
    if (!name.endsWith('.enc')) return;
    _showOverlay('Decrypting $name...');
    try {
      final bytes = await File(file.path).readAsBytes();
      final decrypted =
          _enc.decryptFile(bytes, widget.masterPassword, widget.salt);
      await _store.saveDecryptedFile(decrypted, name);
      _snack('File decrypted', success: true);
    } catch (e) {
      _snack('Decryption failed', success: false);
    } finally {
      _hideOverlay();
    }
  }

  Future<void> _backupToCloud(FileSystemEntity file) async {
    if (!_fbAuth.isLoggedIn) {
      _snack('Sign in to use cloud backup', success: false);
      return;
    }
    final name = file.path.split('/').last;
    _showOverlay('Uploading $name...');
    try {
      final bytes = await File(file.path).readAsBytes();
      await _cloud.uploadEncryptedFile(Uint8List.fromList(bytes), name);
      await _loadCloudFiles();
      _snack('Backed up: $name', success: true);
    } catch (e) {
      _snack('Backup failed: $e', success: false);
    } finally {
      _hideOverlay();
    }
  }

  Future<void> _restoreFromCloud(String fileName) async {
    _showOverlay('Downloading $fileName...');
    try {
      final encrypted = await _cloud.downloadEncryptedFile(fileName);
      final decrypted =
          _enc.decryptFile(encrypted, widget.masterPassword, widget.salt);
      await _store.saveDecryptedFile(decrypted, fileName);
      _snack('Restored from cloud', success: true);
    } catch (e) {
      _snack('Restore failed', success: false);
    } finally {
      _hideOverlay();
    }
  }

  Future<void> _deleteFile(FileSystemEntity file) async {
    final name = file.path.split('/').last;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete file?',
            style: TextStyle(color: Colors.white)),
        content: Text('Securely delete "$name"? This cannot be undone.',
            style: TextStyle(color: Colors.grey[400])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.blueGrey[300])),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _store.secureDelete(file.path);
    await _loadLocalFiles();
    _snack('File securely deleted', success: true);
  }

  Future<void> _renameFile(FileSystemEntity file) async {
    final oldName = file.path.split('/').last;
    final ctrl = TextEditingController(text: oldName.replaceAll('.enc', ''));
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Rename file',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'New name',
            hintStyle: TextStyle(color: Colors.grey[600]),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text('Cancel',
                style: TextStyle(color: Colors.blueGrey[300])),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Rename',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty) return;
    try {
      final dir = file.path.substring(0, file.path.lastIndexOf('/'));
      await File(file.path).rename('$dir/$newName.enc');
      await _loadLocalFiles();
      _snack('File renamed', success: true);
    } catch (e) {
      _snack('Rename failed', success: false);
    }
  }

  // Long press context menu
  void _showContextMenu(BuildContext context, FileSystemEntity file) {
    final name = file.path.split('/').last;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(name,
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 8),
            _contextTile(Icons.lock_open_outlined, 'Decrypt file',
                Colors.white, () {
              Navigator.of(context).pop();
              _decryptLocalFile(file);
            }),
            if (_fbAuth.isLoggedIn)
              _contextTile(Icons.cloud_upload_outlined, 'Backup to cloud',
                  Colors.blueGrey, () {
                Navigator.of(context).pop();
                _backupToCloud(file);
              }),
            _contextTile(Icons.drive_file_rename_outline, 'Rename',
                Colors.white, () {
              Navigator.of(context).pop();
              _renameFile(file);
            }),
            _contextTile(
                Icons.delete_outline, 'Delete securely', Colors.red, () {
              Navigator.of(context).pop();
              _deleteFile(file);
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _contextTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: TextStyle(color: color, fontSize: 15)),
      onTap: onTap,
    );
  }

  Future<void> _exportVault() async {
    _showOverlay('Creating encrypted backup zip...');
    try {
      await _exportService.exportVaultAsZip();
      _snack('Backup exported successfully', success: true);
    } catch (e) {
      _snack('Export failed: $e', success: false);
    } finally {
      _hideOverlay();
    }
  }

  void _snack(String msg, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.error_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ],
      ),
      backgroundColor: success ? Colors.green[800] : Colors.red[800],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  String _formatBytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // File type icon based on original extension
  IconData _fileIcon(String name) {
    final lower = name.toLowerCase().replaceAll('.enc', '');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') ||
        lower.endsWith('.png') || lower.endsWith('.gif') ||
        lower.endsWith('.webp')) return Icons.image_outlined;
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') ||
        lower.endsWith('.avi') || lower.endsWith('.mkv'))
      return Icons.videocam_outlined;
    if (lower.endsWith('.mp3') || lower.endsWith('.wav') ||
        lower.endsWith('.aac') || lower.endsWith('.m4a'))
      return Icons.audiotrack_outlined;
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_outlined;
    if (lower.endsWith('.doc') || lower.endsWith('.docx'))
      return Icons.description_outlined;
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx'))
      return Icons.table_chart_outlined;
    if (lower.endsWith('.zip') || lower.endsWith('.rar'))
      return Icons.folder_zip_outlined;
    if (lower.endsWith('.txt')) return Icons.text_snippet_outlined;
    return Icons.insert_drive_file_outlined;
  }

  // File type color
  Color _fileColor(String name) {
    final lower = name.toLowerCase().replaceAll('.enc', '');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') ||
        lower.endsWith('.png') || lower.endsWith('.gif'))
      return Colors.purple[300]!;
    if (lower.endsWith('.mp4') || lower.endsWith('.mov'))
      return Colors.red[300]!;
    if (lower.endsWith('.mp3') || lower.endsWith('.wav'))
      return Colors.orange[300]!;
    if (lower.endsWith('.pdf')) return Colors.red[400]!;
    if (lower.endsWith('.doc') || lower.endsWith('.docx'))
      return Colors.blue[300]!;
    if (lower.endsWith('.txt')) return Colors.grey[400]!;
    return Colors.blueGrey[300]!;
  }

  @override
  Widget build(BuildContext context) {
    return AutoLockWrapper(
      timeoutMinutes: 2,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              title: _isSearching
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search files...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: InputBorder.none,
                      ),
                    )
                  : const Text('CryptaSafe Vault'),
              backgroundColor: Colors.grey[900],
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: Icon(_isSearching ? Icons.close : Icons.search),
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) {
                        _searchController.clear();
                        _filteredFiles = _localFiles;
                      }
                    });
                  },
                ),
                if (_fbAuth.isLoggedIn)
                  IconButton(
                    icon: _cloudLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.cloud_sync_outlined),
                    onPressed: () {
                      setState(() => _showCloud = !_showCloud);
                      if (_showCloud) _loadCloudFiles();
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                      masterPassword: widget.masterPassword,
                      salt: widget.salt,
                    ),
                  )),
                ),
                IconButton(
                  icon: const Icon(Icons.lock_outline),
                  onPressed: () =>
                      Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => LoginScreen()),
                    (route) => false,
                  ),
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Quick actions ────────────────────────────
                  if (!_isSearching) ...[
                    Row(children: [
                      _quickAction(Icons.note_add_outlined, 'Notes',
                          Colors.blueGrey, () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => NotesScreen(
                            masterPassword: widget.masterPassword,
                            salt: widget.salt,
                          ),
                        ));
                      }),
                      const SizedBox(width: 10),
                      _quickAction(Icons.upload_file_outlined, 'Add file',
                          Colors.blueGrey, _pickAndEncrypt),
                      const SizedBox(width: 10),
                      _quickAction(Icons.ios_share_outlined, 'Export',
                          Colors.blueGrey, _exportVault),
                    ]),
                    const SizedBox(height: 24),
                  ],

                  // ── File vault ───────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionHeader(
                          'Files (${_filteredFiles.length})'),
                      if (!_isSearching)
                        TextButton.icon(
                          onPressed: _pickAndDecrypt,
                          icon: Icon(Icons.folder_open_outlined,
                              size: 16, color: Colors.blueGrey[300]),
                          label: Text('Decrypt external',
                              style: TextStyle(
                                  color: Colors.blueGrey[300],
                                  fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_filteredFiles.isEmpty)
                    _emptyState(_isSearching
                        ? 'No files match your search'
                        : 'No encrypted files yet\nTap "Add file" to get started')
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredFiles.length,
                      itemBuilder: (context, i) {
                        final file = _filteredFiles[i];
                        final name = file.path.split('/').last;
                        return Card(
                          color: Colors.grey[900],
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _decryptLocalFile(file),
                            onLongPress: () =>
                                _showContextMenu(context, file),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  // File type icon box
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: _fileColor(name)
                                          .withOpacity(0.15),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _fileIcon(name),
                                      color: _fileColor(name),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // File info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.replaceAll('.enc', ''),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.blueGrey[900],
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'encrypted',
                                                style: TextStyle(
                                                    color:
                                                        Colors.blueGrey[300],
                                                    fontSize: 10),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // More options
                                  IconButton(
                                    icon: Icon(Icons.more_vert,
                                        color: Colors.grey[600], size: 20),
                                    onPressed: () =>
                                        _showContextMenu(context, file),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // ── Cloud files ──────────────────────────────
                  if (_showCloud && _fbAuth.isLoggedIn && !_isSearching) ...[
                    const SizedBox(height: 28),
                    _sectionHeader(
                        'Cloud backup (${_cloudFiles.length})'),
                    const SizedBox(height: 10),
                    if (_cloudLoading)
                      const Center(
                          child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                  color: Colors.blueGrey)))
                    else if (_cloudFiles.isEmpty)
                      _emptyState('No cloud backups yet')
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _cloudFiles.length,
                        itemBuilder: (context, i) {
                          final file = _cloudFiles[i];
                          return Card(
                            color: Colors.grey[900],
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:
                                      Colors.blueGrey[800]!.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.cloud_outlined,
                                    color: Colors.blueGrey, size: 20),
                              ),
                              title: Text(file['fileName'],
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14)),
                              subtitle: Text(
                                  _formatBytes(file['sizeBytes'] as int),
                                  style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12)),
                              trailing: IconButton(
                                icon: Icon(Icons.cloud_download_outlined,
                                    color: Colors.blueGrey[300], size: 20),
                                onPressed: () =>
                                    _restoreFromCloud(file['fileName']),
                              ),
                            ),
                          );
                        },
                      ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ── Loading overlay ──────────────────────────────────
          if (_operationLoading)
            Container(
              color: Colors.black.withOpacity(0.75),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 28),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blueGrey[800]!),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                          color: Colors.blueGrey),
                      const SizedBox(height: 20),
                      Text(
                        _operationMessage,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _quickAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!),
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.blueGrey[300], size: 24),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) => Text(
        text.toUpperCase(),
        style: TextStyle(
            color: Colors.blueGrey[300],
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2),
      );

  Widget _emptyState(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.lock_outline, size: 48, color: Colors.grey[700]),
              const SizedBox(height: 12),
              Text(
                text,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
