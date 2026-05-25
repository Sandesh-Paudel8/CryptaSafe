import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'encryption_service.dart';

const _kNotesList = 'cryptasafe_notes_list';

class Note {
  final String id;
  final String title;
  final String encryptedContent;
  final DateTime createdAt;
  final DateTime updatedAt;

  Note({
    required this.id,
    required this.title,
    required this.encryptedContent,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'encryptedContent': encryptedContent,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'],
        title: json['title'],
        encryptedContent: json['encryptedContent'],
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: DateTime.parse(json['updatedAt']),
      );
}

class NotesService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final _enc = EncryptionService();

  Future<List<Note>> getAllNotes() async {
    final raw = await _storage.read(key: _kNotesList);
    if (raw == null) return [];
    final List decoded = jsonDecode(raw);
    return decoded.map((e) => Note.fromJson(e)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<Note> saveNote({
    String? id,
    required String title,
    required String plainContent,
    required String masterPassword,
    required Uint8List salt,
  }) async {
    final notes = await getAllNotes();
    final encrypted =
        _enc.encryptText(plainContent, masterPassword, salt);
    final now = DateTime.now();

    Note note;
    if (id != null) {
      // Update existing
      final idx = notes.indexWhere((n) => n.id == id);
      note = Note(
        id: id,
        title: title,
        encryptedContent: encrypted,
        createdAt: idx >= 0 ? notes[idx].createdAt : now,
        updatedAt: now,
      );
      if (idx >= 0) notes[idx] = note;
      else notes.add(note);
    } else {
      // Create new
      note = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        encryptedContent: encrypted,
        createdAt: now,
        updatedAt: now,
      );
      notes.add(note);
    }

    await _storage.write(
      key: _kNotesList,
      value: jsonEncode(notes.map((n) => n.toJson()).toList()),
    );
    return note;
  }

  Future<String> decryptNote(
      Note note, String masterPassword, Uint8List salt) async {
    return _enc.decryptText(note.encryptedContent, masterPassword, salt);
  }

  Future<void> deleteNote(String id) async {
    final notes = await getAllNotes();
    notes.removeWhere((n) => n.id == id);
    await _storage.write(
      key: _kNotesList,
      value: jsonEncode(notes.map((n) => n.toJson()).toList()),
    );
  }

  Future<void> wipeAllNotes() async {
    await _storage.delete(key: _kNotesList);
  }
}
