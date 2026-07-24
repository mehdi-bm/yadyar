import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../models/reminder.dart';
import '../repositories/note_repository.dart';
import '../repositories/reminder_repository.dart';

class NotesProvider extends ChangeNotifier {
  NotesProvider({NoteRepository? noteRepository, ReminderRepository? reminderRepository})
    : _noteRepository = noteRepository ?? NoteRepository(),
      _reminderRepository = reminderRepository ?? ReminderRepository();

  final NoteRepository _noteRepository;
  final ReminderRepository _reminderRepository;

  List<Note> _notes = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _selectedTag;

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get selectedTag => _selectedTag;

  List<String> get allTags {
    final tags = _notes.map((note) => note.tag).where((tag) => tag.isNotEmpty).toSet().toList();
    tags.sort();
    return tags;
  }

  List<Note> get filteredNotes {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _notes.where((note) {
      final matchesQuery =
          query.isEmpty ||
          note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query);
      final matchesTag = _selectedTag == null || note.tag == _selectedTag;
      return matchesQuery && matchesTag;
    }).toList();

    filtered.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return filtered;
  }

  Future<void> loadNotes() async {
    _isLoading = true;
    notifyListeners();
    _notes = await _noteRepository.getAll();
    _isLoading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setTagFilter(String? tag) {
    _selectedTag = _selectedTag == tag ? null : tag;
    notifyListeners();
  }

  Future<Reminder?> getReminderForNote(int noteId) async {
    final reminders = await _reminderRepository.getByNoteId(noteId);
    return reminders.isEmpty ? null : reminders.first;
  }

  Future<void> addNote({
    required String title,
    required String content,
    required String tag,
    required bool isPinned,
    Reminder? reminder,
  }) async {
    final now = DateTime.now();
    final noteId = await _noteRepository.insert(
      Note(
        title: title,
        content: content,
        tag: tag,
        isPinned: isPinned,
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (reminder != null) {
      await _reminderRepository.insert(reminder.copyWith(noteId: noteId));
    }
    await loadNotes();
  }

  Future<void> updateNote(Note note, {Reminder? reminder}) async {
    await _noteRepository.update(note.copyWith(updatedAt: DateTime.now()));

    // در این فرم هر یادداشت حداکثر یک یادآور دارد: قدیمی پاک و در صورت نیاز جدید درج می‌شود.
    final existingReminders = await _reminderRepository.getByNoteId(note.id!);
    for (final existing in existingReminders) {
      await _reminderRepository.delete(existing.id!);
    }
    if (reminder != null) {
      await _reminderRepository.insert(reminder.copyWith(id: null, noteId: note.id));
    }
    await loadNotes();
  }

  Future<void> deleteNote(int noteId) async {
    final reminders = await _reminderRepository.getByNoteId(noteId);
    for (final reminder in reminders) {
      await _reminderRepository.delete(reminder.id!);
    }
    await _noteRepository.delete(noteId);
    await loadNotes();
  }

  Future<void> togglePin(Note note) async {
    await _noteRepository.update(note.copyWith(isPinned: !note.isPinned, updatedAt: DateTime.now()));
    await loadNotes();
  }
}
