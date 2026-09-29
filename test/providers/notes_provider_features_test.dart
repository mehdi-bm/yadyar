import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yadyar_app/database/database_helper.dart';
import 'package:yadyar_app/models/reminder.dart';
import 'package:yadyar_app/providers/notes_provider.dart';
import 'package:yadyar_app/repositories/note_repository.dart';
import 'package:yadyar_app/repositories/reminder_repository.dart';
import 'package:yadyar_app/utils/date_formatter.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Reminder.nextOccurrence', () {
    final now = DateTime(2026, 9, 29, 12);

    test('one-off reminder: future as-is, past is null', () {
      final future = Reminder(title: 'x', dateTime: DateTime(2026, 9, 30, 9));
      final past = Reminder(title: 'x', dateTime: DateTime(2026, 9, 1, 9));
      expect(future.nextOccurrence(now: now), DateTime(2026, 9, 30, 9));
      expect(past.nextOccurrence(now: now), isNull);
    });

    test('daily, weekly and monthly advance past now', () {
      final start = DateTime(2026, 9, 1, 9);
      expect(
        Reminder(
          title: 'x',
          dateTime: start,
          repeatType: ReminderRepeatType.daily,
        ).nextOccurrence(now: now),
        DateTime(2026, 9, 30, 9),
      );
      expect(
        Reminder(
          title: 'x',
          dateTime: start,
          repeatType: ReminderRepeatType.weekly,
        ).nextOccurrence(now: now),
        DateTime(2026, 10, 6, 9),
      );
      expect(
        Reminder(
          title: 'x',
          dateTime: start,
          repeatType: ReminderRepeatType.monthly,
        ).nextOccurrence(now: now),
        DateTime(2026, 10, 1, 9),
      );
    });

    test('monthly on the 31st skips months without that day', () {
      final reminder = Reminder(
        title: 'x',
        dateTime: DateTime(2026, 8, 31, 9),
        repeatType: ReminderRepeatType.monthly,
      );
      expect(reminder.nextOccurrence(now: now), DateTime(2026, 10, 31, 9));
    });
  });

  test('relativeFutureLabel', () {
    final now = DateTime(2026, 9, 29, 12);
    expect(relativeFutureLabel(DateTime(2026, 9, 29, 11), now: now), 'گذشته');
    expect(
      relativeFutureLabel(DateTime(2026, 9, 29, 12, 20), now: now),
      '۲۰ دقیقه دیگر',
    );
    expect(
      relativeFutureLabel(DateTime(2026, 9, 29, 15), now: now),
      '۳ ساعت دیگر',
    );
    expect(
      relativeFutureLabel(DateTime(2026, 9, 30, 9, 5), now: now),
      'فردا ۰۹:۰۵',
    );
    expect(
      relativeFutureLabel(DateTime(2026, 10, 3, 9), now: now),
      '۴ روز دیگر',
    );
  });

  group('NotesProvider features', () {
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

    Future<int> add(String title, {bool pinned = false, Reminder? reminder}) =>
        provider.addNote(
          title: title,
          content: 'متن $title',
          tag: '',
          isPinned: pinned,
          reminder: reminder,
        );

    test('trash hides the note and keeps its reminder for restore', () async {
      final id = await add(
        'با یادآور',
        reminder: Reminder(
          title: 'با یادآور',
          dateTime: DateTime.now().add(const Duration(days: 1)),
        ),
      );
      await add('دیگری');
      final note = provider.filteredNotes.firstWhere((n) => n.id == id);

      await provider.moveToTrash(note);

      expect(provider.filteredNotes.map((n) => n.title), ['دیگری']);
      expect(provider.trashedNotes.single.id, id);
      expect(await reminderRepository.getByNoteId(id), hasLength(1));

      await provider.restoreFromTrash(provider.trashedNotes.single);

      expect(provider.trashCount, 0);
      expect(provider.filteredNotes, hasLength(2));
      expect(provider.nextReminderFor(id), isNotNull);
    });

    test('archived notes leave the main list and lose their pin', () async {
      final id = await add('سنجاق‌شده', pinned: true);
      final note = provider.filteredNotes.single;

      await provider.setArchived(note, true);

      expect(provider.filteredNotes, isEmpty);
      expect(provider.archivedNotes.single.id, id);
      expect(provider.archivedNotes.single.isPinned, isFalse);
      expect(provider.pinnedNotes, isEmpty);

      await provider.setArchived(provider.archivedNotes.single, false);
      expect(provider.filteredNotes.single.id, id);
    });

    test('emptyTrash deletes notes and their reminders permanently', () async {
      final id = await add(
        'حذفی',
        reminder: Reminder(
          title: 'حذفی',
          dateTime: DateTime.now().add(const Duration(hours: 2)),
        ),
      );
      await provider.moveToTrash(provider.filteredNotes.single);

      await provider.emptyTrash();

      expect(provider.trashCount, 0);
      expect(await noteRepository.getById(id), isNull);
      expect(await reminderRepository.getByNoteId(id), isEmpty);
    });

    test('notes past the retention period are purged on load', () async {
      final oldId = await add('قدیمی');
      final recentId = await add('تازه');
      final old = provider.filteredNotes.firstWhere((n) => n.id == oldId);
      await noteRepository.update(
        old.copyWith(
          deletedAt: DateTime.now().subtract(
            NotesProvider.trashRetention + const Duration(days: 1),
          ),
        ),
      );
      await provider.moveToTrash(
        provider.filteredNotes.firstWhere((n) => n.id == recentId),
      );

      await provider.loadNotes();

      expect(await noteRepository.getById(oldId), isNull);
      expect(provider.trashedNotes.single.id, recentId);
    });

    test('color can be set and cleared', () async {
      await add('رنگی');
      await provider.setColor(provider.filteredNotes.single, 0xFF42A5F5);
      expect(provider.filteredNotes.single.colorValue, 0xFF42A5F5);

      await provider.setColor(provider.filteredNotes.single, null);
      expect(provider.filteredNotes.single.colorValue, isNull);
    });

    test('duplicate copies content and color without reminder', () async {
      await provider.addNote(
        title: 'اصلی',
        content: 'متن',
        tag: 'کار',
        isPinned: true,
        colorValue: 0xFFEC407A,
        reminder: Reminder(
          title: 'اصلی',
          dateTime: DateTime.now().add(const Duration(days: 1)),
        ),
      );

      final copyId = await provider.duplicateNote(
        provider.filteredNotes.single,
      );

      final copy = provider.filteredNotes.firstWhere((n) => n.id == copyId);
      expect(copy.title, 'اصلی (کپی)');
      expect(copy.content, 'متن');
      expect(copy.tag, 'کار');
      expect(copy.colorValue, 0xFFEC407A);
      expect(copy.isPinned, isFalse);
      expect(provider.nextReminderFor(copyId), isNull);
    });

    test(
      'reminder filter keeps only notes with an upcoming reminder',
      () async {
        await add(
          'با یادآور',
          reminder: Reminder(
            title: 'با یادآور',
            dateTime: DateTime.now().add(const Duration(days: 2)),
          ),
        );
        await add(
          'یادآور گذشته',
          reminder: Reminder(
            title: 'یادآور گذشته',
            dateTime: DateTime.now().subtract(const Duration(days: 2)),
          ),
        );
        await add('بدون یادآور');

        expect(provider.withReminderCount, 1);
        provider.toggleReminderFilter();
        expect(provider.filteredNotes.single.title, 'با یادآور');

        provider.setTagFilter(null);
        expect(provider.onlyWithReminder, isFalse);
        expect(provider.filteredNotes, hasLength(3));
      },
    );

    test('shareText includes title, content and tag', () async {
      await provider.addNote(
        title: 'خرید',
        content: 'نان و شیر',
        tag: 'خانه تکانی',
        isPinned: false,
      );
      expect(
        provider.shareText(provider.filteredNotes.single),
        'خرید\n\nنان و شیر\n\n#خانه_تکانی',
      );
    });
  });
}
