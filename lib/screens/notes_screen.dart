import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/notes_service.dart';

class NotesScreen extends StatefulWidget {
  final String masterPassword;
  final Uint8List salt;

  const NotesScreen({
    Key? key,
    required this.masterPassword,
    required this.salt,
  }) : super(key: key);

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _notesService = NotesService();
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await _notesService.getAllNotes();
    if (mounted) setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _openNote({Note? note}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _NoteEditorScreen(
        masterPassword: widget.masterPassword,
        salt: widget.salt,
        existingNote: note,
      ),
    ));
    _loadNotes();
  }

  Future<void> _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete note?',
            style: TextStyle(color: Colors.white)),
        content: Text('Delete "${note.title}"? This cannot be undone.',
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
    if (confirmed == true) {
      await _notesService.deleteNote(note.id);
      _loadNotes();
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Secure notes'),
        backgroundColor: Colors.grey[900],
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New note',
            onPressed: () => _openNote(),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueGrey))
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_outlined,
                          size: 64, color: Colors.grey[700]),
                      const SizedBox(height: 16),
                      Text('No secure notes yet',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Tap + to create your first note',
                          style: TextStyle(
                              color: Colors.grey[700], fontSize: 13)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notes.length,
                  itemBuilder: (_, i) {
                    final note = _notes[i];
                    return Card(
                      color: Colors.grey[900],
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blueGrey[800],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.lock_outline,
                              color: Colors.white, size: 20),
                        ),
                        title: Text(note.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500)),
                        subtitle: Text(
                          'Updated ${_formatDate(note.updatedAt)}',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () => _deleteNote(note),
                        ),
                        onTap: () => _openNote(note: note),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNote(),
        backgroundColor: Colors.blueGrey[700],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _NoteEditorScreen extends StatefulWidget {
  final String masterPassword;
  final Uint8List salt;
  final Note? existingNote;

  const _NoteEditorScreen({
    required this.masterPassword,
    required this.salt,
    this.existingNote,
  });

  @override
  State<_NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<_NoteEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _notesService = NotesService();
  bool _loading = false;
  bool _decrypting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingNote != null) {
      _titleCtrl.text = widget.existingNote!.title;
      _loadExistingContent();
    }
  }

  Future<void> _loadExistingContent() async {
    setState(() => _decrypting = true);
    try {
      final content = await _notesService.decryptNote(
        widget.existingNote!,
        widget.masterPassword,
        widget.salt,
      );
      _contentCtrl.text = content;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to decrypt note')),
        );
      }
    } finally {
      if (mounted) setState(() => _decrypting = false);
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await _notesService.saveNote(
        id: widget.existingNote?.id,
        title: _titleCtrl.text.trim(),
        plainContent: _contentCtrl.text,
        masterPassword: widget.masterPassword,
        salt: widget.salt,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  void _copyContent() {
    Clipboard.setData(ClipboardData(text: _contentCtrl.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note content copied')),
    );
    // Auto-clear clipboard after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      Clipboard.setData(const ClipboardData(text: ''));
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
            widget.existingNote == null ? 'New note' : 'Edit note'),
        backgroundColor: Colors.grey[900],
        actions: [
          if (widget.existingNote != null)
            IconButton(
              icon: const Icon(Icons.copy_outlined),
              tooltip: 'Copy content',
              onPressed: _decrypting ? null : _copyContent,
            ),
          IconButton(
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            tooltip: 'Save',
            onPressed: _loading ? null : _save,
          ),
        ],
      ),
      body: _decrypting
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blueGrey),
                  SizedBox(height: 16),
                  Text('Decrypting note...',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Note title',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      border: InputBorder.none,
                    ),
                  ),
                  Divider(color: Colors.grey[800]),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TextField(
                      controller: _contentCtrl,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, height: 1.6),
                      decoration: InputDecoration(
                        hintText: 'Write your secret note here...',
                        hintStyle: TextStyle(color: Colors.grey[600]),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
