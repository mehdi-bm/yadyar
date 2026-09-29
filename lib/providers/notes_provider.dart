import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';
import '../models/reminder.dart';
import '../repositories/note_repository.dart';
import '../repositories/reminder_repository.dart';
import '../services/notification_service.dart';

enum NoteSortOption {
  nearestReminder,
  updatedNewest,
  createdNewest,
  alphabetical,
}

const Map<NoteSortOption, String> noteSortOptionLabels = {
  NoteSortOption.nearestReminder: 'نزدیک‌ترین یادآور',
  NoteSortOption.updatedNewest: 'آخرین ویرایش',
  NoteSortOption.createdNewest: 'تاریخ ایجاد',
  NoteSortOption.alphabetical: 'الفبایی',
};

class NotesProvider extends ChangeNotifier {
  NotesProvider({
    NoteRepository? noteRepository,
    ReminderRepository? reminderRepository,
    NotificationService? notificationService,
  }) : _noteRepository = noteRepository ?? NoteRepository(),
       _reminderRepository = reminderRepository ?? ReminderRepository(),
       _notificationService =
           notificationService ?? NotificationService.instance;

  static const String _gridViewPreferenceKey = 'notes_grid_view';

  /// مدت نگهداری یادداشت‌ها در «حذف‌شده‌ها» پیش از پاک شدن خودکار.
  static const Duration trashRetention = Duration(days: 30);

  final NoteRepository _noteRepository;
  final ReminderRepository _reminderRepository;
  final NotificationService _notificationService;

  List<Note> _notes = [];
  Map<int, Reminder> _remindersByNoteId = {};
  bool _isLoading = false;
  String _searchQuery = '';
  String? _selectedTag;
  bool _onlyWithReminder = false;
  bool _isGridView = false;
  NoteSortOption _sortOption = NoteSortOption.nearestReminder;

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get selectedTag => _selectedTag;
  bool get onlyWithReminder => _onlyWithReminder;
  bool get isGridView => _isGridView;
  NoteSortOption get sortOption => _sortOption;

  /// یادآور فعال یک یادداشت (برای نمایش تاریخ/ساعت روی کارت)، در صورت وجود.
  Reminder? reminderForNote(int noteId) => _remindersByNoteId[noteId];

  /// زمان رخداد بعدی یادآور فعال یک یادداشت (با در نظر گرفتن تکرار).
  DateTime? nextReminderFor(int? noteId) {
    if (noteId == null) return null;
    final reminder = _remindersByNoteId[noteId];
    if (reminder == null || !reminder.isActive) return null;
    return reminder.nextOccurrence();
  }

  /// یادداشت‌های فعال: نه بایگانی‌شده و نه حذف‌شده.
  List<Note> get _activeNotes =>
      _notes.where((note) => !note.isArchived && !note.isDeleted).toList();

  List<Note> get archivedNotes =>
      _notes.where((note) => note.isArchived && !note.isDeleted).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  /// «حذف‌شده‌ها»، جدیدترین حذف اول.
  List<Note> get trashedNotes =>
      _notes.where((note) => note.isDeleted).toList()
        ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));

  int get activeCount => _activeNotes.length;
  int get archivedCount => archivedNotes.length;
  int get trashCount => _notes.where((note) => note.isDeleted).length;
  int get withReminderCount =>
      _activeNotes.where((note) => nextReminderFor(note.id) != null).length;

  List<Note> get pinnedNotes =>
      _activeNotes.where((note) => note.isPinned).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  List<String> get allTags {
    final tags = _activeNotes
        .map((note) => note.tag)
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
    tags.sort();
    return tags;
  }

  List<Note> get filteredNotes {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _activeNotes.where((note) {
      final matchesQuery =
          query.isEmpty ||
          note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query) ||
          note.tag.toLowerCase().contains(query);
      final matchesTag = _selectedTag == null || note.tag == _selectedTag;
      final matchesReminder =
          !_onlyWithReminder || nextReminderFor(note.id) != null;
      return matchesQuery && matchesTag && matchesReminder;
    }).toList();

    filtered.sort((a, b) {
      // سنجاق‌شده‌ها همیشه بالای لیست می‌مانند، صرف‌نظر از نوع مرتب‌سازی انتخابی.
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      switch (_sortOption) {
        case NoteSortOption.nearestReminder:
          final reminderA = nextReminderFor(a.id);
          final reminderB = nextReminderFor(b.id);
          if (reminderA == null && reminderB == null) {
            return b.updatedAt.compareTo(a.updatedAt);
          }
          if (reminderA == null) return 1;
          if (reminderB == null) return -1;
          return reminderA.compareTo(reminderB);
        case NoteSortOption.updatedNewest:
          return b.updatedAt.compareTo(a.updatedAt);
        case NoteSortOption.createdNewest:
          return b.createdAt.compareTo(a.createdAt);
        case NoteSortOption.alphabetical:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
    });
    return filtered;
  }

  Future<void> loadNotes() async {
    _isLoading = true;
    notifyListeners();
    await _purgeExpiredTrash();
    await _reload();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _reload() async {
    _notes = await _noteRepository.getAll();
    final allReminders = await _reminderRepository.getAll();
    _remindersByNoteId = {
      for (final reminder in allReminders)
        if (reminder.noteId != null) reminder.noteId!: reminder,
    };
    notifyListeners();
  }

  /// حالت نمایش شبکه‌ای/لیستی ذخیره‌شده را می‌خواند (جدا از loadNotes تا
  /// تست‌ها بدون SharedPreferences کار کنند).
  Future<void> loadPreferences() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      _isGridView = preferences.getBool(_gridViewPreferenceKey) ?? false;
      notifyListeners();
    } on Object {
      // نبود تنظیمات ذخیره‌شده مانع کار نیست؛ حالت پیش‌فرض (لیستی) می‌ماند.
    }
  }

  Future<void> toggleGridView() async {
    _isGridView = !_isGridView;
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_gridViewPreferenceKey, _isGridView);
    } on Object {
      // ذخیره نشدن تنظیم فقط یعنی در اجرای بعدی حالت پیش‌فرض نمایش داده شود.
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setTagFilter(String? tag) {
    _onlyWithReminder = false;
    _selectedTag = _selectedTag == tag ? null : tag;
    notifyListeners();
  }

  /// فیلتر «فقط یادداشت‌های دارای یادآور» (هم‌زمان با تگ انتخاب نمی‌شود).
  void toggleReminderFilter() {
    _onlyWithReminder = !_onlyWithReminder;
    if (_onlyWithReminder) _selectedTag = null;
    notifyListeners();
  }

  void setSortOption(NoteSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  Future<Reminder?> getReminderForNote(int noteId) async {
    final reminders = await _reminderRepository.getByNoteId(noteId);
    return reminders.isEmpty ? null : reminders.first;
  }

  Future<int> addNote({
    required String title,
    required String content,
    required String tag,
    required bool isPinned,
    Reminder? reminder,
    int? colorValue,
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
        colorValue: colorValue,
      ),
    );
    if (reminder != null) {
      final savedReminder = reminder.copyWith(noteId: noteId);
      final reminderId = await _reminderRepository.insert(savedReminder);
      await _notificationService.scheduleReminderNotification(
        savedReminder.copyWith(id: reminderId),
      );
    }
    await _reload();
    return noteId;
  }

  Future<void> updateNote(Note note, {Reminder? reminder}) async {
    await _noteRepository.update(note.copyWith(updatedAt: DateTime.now()));

    // در این فرم هر یادداشت حداکثر یک یادآور دارد: قدیمی پاک و در صورت نیاز جدید درج می‌شود.
    final existingReminders = await _reminderRepository.getByNoteId(note.id!);
    for (final existing in existingReminders) {
      await _notificationService.cancelReminder(existing.id!);
      await _reminderRepository.delete(existing.id!);
    }
    if (reminder != null) {
      final savedReminder = reminder.copyWith(id: null, noteId: note.id);
      final reminderId = await _reminderRepository.insert(savedReminder);
      await _notificationService.scheduleReminderNotification(
        savedReminder.copyWith(id: reminderId),
      );
    }
    await _reload();
  }

  /// حذف دائمی یادداشت و یادآورهای آن.
  Future<void> deleteNote(int noteId) async {
    final reminders = await _reminderRepository.getByNoteId(noteId);
    for (final reminder in reminders) {
      await _notificationService.cancelReminder(reminder.id!);
      await _reminderRepository.delete(reminder.id!);
    }
    await _noteRepository.delete(noteId);
    await _reload();
  }

  /// انتقال به «حذف‌شده‌ها» (قابل بازیابی). اعلان یادآور لغو می‌شود ولی خود
  /// یادآور می‌ماند تا با بازیابی دوباره زمان‌بندی شود.
  Future<void> moveToTrash(Note note) async {
    final trashed = note.copyWith(deletedAt: DateTime.now());
    _replaceLocal(trashed);
    await _setNotificationsFor(note.id!, enabled: false);
    await _noteRepository.update(trashed);
    await _reload();
  }

  Future<void> restoreFromTrash(Note note) async {
    await _noteRepository.update(note.copyWith(clearDeletedAt: true));
    await _setNotificationsFor(note.id!, enabled: true);
    await _reload();
  }

  Future<void> emptyTrash() async {
    for (final note in trashedNotes) {
      await deleteNote(note.id!);
    }
  }

  Future<void> _purgeExpiredTrash() async {
    final cutoff = DateTime.now().subtract(trashRetention);
    final notes = await _noteRepository.getAll();
    for (final note in notes) {
      if (note.deletedAt != null && note.deletedAt!.isBefore(cutoff)) {
        final reminders = await _reminderRepository.getByNoteId(note.id!);
        for (final reminder in reminders) {
          await _reminderRepository.delete(reminder.id!);
        }
        await _noteRepository.delete(note.id!);
      }
    }
  }

  Future<void> _setNotificationsFor(int noteId, {required bool enabled}) async {
    final reminders = await _reminderRepository.getByNoteId(noteId);
    for (final reminder in reminders) {
      if (enabled) {
        await _notificationService.scheduleReminderNotification(reminder);
      } else {
        await _notificationService.cancelReminder(reminder.id!);
      }
    }
  }

  /// بایگانی یادداشت را از لیست اصلی خارج می‌کند (یادآورش فعال می‌ماند).
  Future<void> setArchived(Note note, bool archived) async {
    final updated = note.copyWith(
      isArchived: archived,
      isPinned: archived ? false : null,
    );
    _replaceLocal(updated);
    await _noteRepository.update(updated);
    await _reload();
  }

  Future<void> setColor(Note note, int? colorValue) async {
    await _noteRepository.update(
      note.copyWith(colorValue: colorValue, clearColor: colorValue == null),
    );
    await _reload();
  }

  /// یک کپی از یادداشت (بدون یادآور) می‌سازد و شناسه آن را برمی‌گرداند.
  Future<int> duplicateNote(Note note) async {
    final now = DateTime.now();
    final id = await _noteRepository.insert(
      Note(
        title: '${note.title} (کپی)',
        content: note.content,
        tag: note.tag,
        createdAt: now,
        updatedAt: now,
        colorValue: note.colorValue,
      ),
    );
    await _reload();
    return id;
  }

  Future<void> togglePin(Note note) async {
    await _noteRepository.update(
      note.copyWith(isPinned: !note.isPinned, updatedAt: DateTime.now()),
    );
    await _reload();
  }

  /// به‌روزرسانی فوری حالت محلی پیش از پایگاه‌داده: Dismissible انتظار دارد
  /// کارتِ کشیده‌شده در همان فریم از لیست حذف شود.
  void _replaceLocal(Note updated) {
    _notes = [
      for (final note in _notes) note.id == updated.id ? updated : note,
    ];
    notifyListeners();
  }

  /// متن قابل اشتراک یادداشت.
  String shareText(Note note) {
    final buffer = StringBuffer(note.title.trim());
    if (note.content.trim().isNotEmpty) {
      buffer.write('\n\n${note.content.trim()}');
    }
    if (note.tag.isNotEmpty)
      buffer.write('\n\n#${note.tag.replaceAll(' ', '_')}');
    return buffer.toString();
  }
}
