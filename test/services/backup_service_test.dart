import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yadyar_app/database/database_helper.dart';
import 'package:yadyar_app/models/note.dart';
import 'package:yadyar_app/repositories/note_repository.dart';
import 'package:yadyar_app/services/backup_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory workDir;
  late DatabaseHelper databaseHelper;
  late BackupService backupService;

  setUp(() async {
    workDir = await Directory.systemTemp.createTemp('yadyar_backup_test');
    final dbPath = p.join(workDir.path, 'yadyar.db');
    databaseHelper = DatabaseHelper(path: dbPath);
    backupService = BackupService(
      databaseHelper: databaseHelper,
      backupsDirectory: Directory(p.join(workDir.path, 'backups')),
    );
  });

  tearDown(() async {
    await databaseHelper.close();
    await workDir.delete(recursive: true);
  });

  test(
    'createBackup copies the live database into the backups directory',
    () async {
      final repo = NoteRepository(databaseHelper: databaseHelper);
      final now = DateTime.now();
      await repo.insert(
        Note(
          title: 'یادداشت اصلی',
          content: '',
          tag: '',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final backup = await backupService.createBackup();

      expect(await backup.exists(), isTrue);
      expect(backup.path, endsWith('.db'));
      expect(await backupService.looksLikeValidBackup(backup), isTrue);
    },
  );

  test('listBackups returns backups newest-first', () async {
    final repo = NoteRepository(databaseHelper: databaseHelper);
    final now = DateTime.now();
    await repo.insert(
      Note(
        title: 'یادداشت',
        content: '',
        tag: '',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final first = await backupService.createBackup();
    // نام فایل با دقت ثانیه ساخته می‌شود؛ برای نام یکتای دومی باید از مرز
    // یک ثانیه واقعی عبور کنیم.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final second = await backupService.createBackup();

    final list = await backupService.listBackups();

    expect(list, hasLength(2));
    expect(list.first.path, second.path);
    expect(list.last.path, first.path);
  });

  test(
    'looksLikeValidBackup rejects a non-sqlite file and a missing file',
    () async {
      final junk = File(p.join(workDir.path, 'junk.txt'));
      await junk.writeAsString('این یک فایل پشتیبان معتبر نیست');

      expect(await backupService.looksLikeValidBackup(junk), isFalse);
      expect(
        await backupService.looksLikeValidBackup(
          File(p.join(workDir.path, 'missing.db')),
        ),
        isFalse,
      );
    },
  );

  test(
    'restoreFromFile replaces current data and keeps an automatic pre-restore safety backup',
    () async {
      final repo = NoteRepository(databaseHelper: databaseHelper);
      final now = DateTime.now();
      await repo.insert(
        Note(
          title: 'یادداشت قدیمی',
          content: '',
          tag: '',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final oldBackup = await backupService.createBackup();

      // شبیه‌سازی وضعیت فعلی گوشی: یک یادداشت جدید که در نسخه پشتیبان قدیمی نیست.
      await repo.insert(
        Note(
          title: 'یادداشت فعلی گوشی',
          content: '',
          tag: '',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await backupService.restoreFromFile(oldBackup);

      final restoredNotes = await repo.getAll();
      expect(restoredNotes.map((n) => n.title), ['یادداشت قدیمی']);

      // نسخه پشتیبان ایمنیِ خودکار قبل از بازیابی باید ساخته شده باشد و شامل
      // وضعیت «فعلی گوشی» (هر دو یادداشت) باشد تا در صورت اشتباه قابل بازگشت باشد.
      final backups = await backupService.listBackups();
      final safetyBackupPath = backups
          .firstWhere((f) => f.path.contains('pre-restore'))
          .path;
      final safetyHelper = DatabaseHelper(path: safetyBackupPath);
      final safetyRepo = NoteRepository(databaseHelper: safetyHelper);
      final safetyNotes = await safetyRepo.getAll();
      expect(
        safetyNotes.map((n) => n.title),
        containsAll(['یادداشت قدیمی', 'یادداشت فعلی گوشی']),
      );
      await safetyHelper.close();
    },
  );

  test(
    'restoreFromFile rejects an invalid backup file without touching current data',
    () async {
      final repo = NoteRepository(databaseHelper: databaseHelper);
      final now = DateTime.now();
      await repo.insert(
        Note(
          title: 'یادداشت فعلی',
          content: '',
          tag: '',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final junk = File(p.join(workDir.path, 'junk.db'));
      await junk.writeAsString('نه یک فایل sqlite واقعی');

      await expectLater(
        backupService.restoreFromFile(junk),
        throwsFormatException,
      );

      final notes = await repo.getAll();
      expect(notes.map((n) => n.title), ['یادداشت فعلی']);
    },
  );

  test('deleteBackup removes the file', () async {
    final repo = NoteRepository(databaseHelper: databaseHelper);
    final now = DateTime.now();
    await repo.insert(
      Note(
        title: 'یادداشت',
        content: '',
        tag: '',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final backup = await backupService.createBackup();

    await backupService.deleteBackup(backup);

    expect(await backup.exists(), isFalse);
  });
}
