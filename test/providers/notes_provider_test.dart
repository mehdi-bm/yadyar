import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yadyar_app/database/database_helper.dart';
import 'package:yadyar_app/models/note.dart';
import 'package:yadyar_app/models/reminder.dart';
import 'package:yadyar_app/providers/notes_provider.dart';
import 'package:yadyar_app/repositories/note_repository.dart';
import 'package:yadyar_app/repositories/reminder_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper databaseHelper;
  late NoteRepository noteRepository;
  late ReminderRepository reminderRepository;
  late NotesProvider provider;

  setUp(() {
    databaseHelper = DatabaseHelper(path: inMemoryDatabasePath);
    noteRepository = NoteRepository(databaseHelper: databaseHelper);
    reminderRepository = ReminderRepository(databaseHelper: databaseHelper);
    provider = NotesProvider(
      noteRepository: noteRepository,
      reminderRepository: reminderRepository,
    );
  });

  tearDown(() async {
    await databaseHelper.close();
  });

  test(
    'defaults to sorting by nearest reminder, notes without a reminder sink to the bottom',
    () async {
      final now = DateTime.now();
      final farId = await noteRepository.insert(
        Note(
          title: 'دور',
          content: '',
          tag: '',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final nearId = await noteRepository.insert(
        Note(
          title: 'نزدیک',
          content: '',
          tag: '',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final noReminderId = await noteRepository.insert(
        Note(
          title: 'بدون یادآور',
          content: '',
          tag: '',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await reminderRepository.insert(
        Reminder(
          noteId: farId,
          title: 'دور',
          dateTime: now.add(const Duration(days: 10)),
        ),
      );
      await reminderRepository.insert(
        Reminder(
          noteId: nearId,
          title: 'نزدیک',
          dateTime: now.add(const Duration(hours: 1)),
        ),
      );

      await provider.loadNotes();

      expect(provider.sortOption, NoteSortOption.nearestReminder);
      final order = provider.filteredNotes.map((n) => n.id).toList();
      expect(order, [nearId, farId, noReminderId]);
    },
  );

  test(
    'an inactive reminder is treated the same as having no reminder for sorting',
    () async {
      final now = DateTime.now();
      final noteId = await noteRepository.insert(
        Note(
          title: 'یادداشت',
          content: '',
          tag: '',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await reminderRepository.insert(
        Reminder(
          noteId: noteId,
          title: 'یادآور غیرفعال',
          dateTime: now.add(const Duration(hours: 1)),
          isActive: false,
        ),
      );

      await provider.loadNotes();

      expect(provider.reminderForNote(noteId), isNotNull);
      // برای مرتب‌سازی نادیده گرفته می‌شود چون فعال نیست: نباید خطا بدهد و باید در لیست باشد.
      expect(provider.filteredNotes.map((n) => n.id), contains(noteId));
    },
  );

  test('setTagFilter(null) ("همه") clears any active tag filter', () async {
    final now = DateTime.now();
    await noteRepository.insert(
      Note(
        title: 'کاری',
        content: '',
        tag: 'کار',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await noteRepository.insert(
      Note(
        title: 'شخصی',
        content: '',
        tag: 'شخصی',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await provider.loadNotes();

    provider.setTagFilter('کار');
    expect(provider.filteredNotes, hasLength(1));

    provider.setTagFilter(null);
    expect(provider.selectedTag, isNull);
    expect(provider.filteredNotes, hasLength(2));
  });

  test('alphabetical sort option orders notes by title', () async {
    final now = DateTime.now();
    await noteRepository.insert(
      Note(title: 'ب', content: '', tag: '', createdAt: now, updatedAt: now),
    );
    await noteRepository.insert(
      Note(title: 'الف', content: '', tag: '', createdAt: now, updatedAt: now),
    );
    await provider.loadNotes();

    provider.setSortOption(NoteSortOption.alphabetical);

    expect(provider.filteredNotes.map((n) => n.title).toList(), ['الف', 'ب']);
  });

  test('pinned notes always sort first regardless of sort option', () async {
    final now = DateTime.now();
    final pinnedId = await noteRepository.insert(
      Note(
        title: 'ب',
        content: '',
        tag: '',
        isPinned: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await noteRepository.insert(
      Note(title: 'الف', content: '', tag: '', createdAt: now, updatedAt: now),
    );
    await provider.loadNotes();

    provider.setSortOption(NoteSortOption.alphabetical);

    expect(provider.filteredNotes.first.id, pinnedId);
  });
}
