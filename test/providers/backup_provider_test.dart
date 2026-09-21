import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yadyar_app/database/database_helper.dart';
import 'package:yadyar_app/models/note.dart';
import 'package:yadyar_app/providers/backup_provider.dart';
import 'package:yadyar_app/repositories/note_repository.dart';
import 'package:yadyar_app/services/backup_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory workDir;
  late DatabaseHelper databaseHelper;
  late NoteRepository noteRepository;
  late BackupService backupService;
  late BackupProvider provider;

  setUp(() async {
    workDir = await Directory.systemTemp.createTemp(
      'yadyar_backup_provider_test',
    );
    final dbPath = p.join(workDir.path, 'yadyar.db');
    databaseHelper = DatabaseHelper(path: dbPath);
    noteRepository = NoteRepository(databaseHelper: databaseHelper);
    backupService = BackupService(
      databaseHelper: databaseHelper,
      backupsDirectory: Directory(p.join(workDir.path, 'backups')),
    );
    provider = BackupProvider(backupService: backupService);

    final now = DateTime.now();
    await noteRepository.insert(
      Note(
        title: 'یادداشت اولیه',
        content: '',
        tag: '',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await databaseHelper.close();
    if (await workDir.exists()) await workDir.delete(recursive: true);
  });

  test('starts empty, loadBackups populates the list', () async {
    expect(provider.backups, isEmpty);

    await provider.loadBackups();

    expect(provider.isLoading, isFalse);
    expect(provider.backups, isEmpty);
  });

  test('createBackup adds a backup and toggles isBusy while running', () async {
    final states = <bool>[];
    provider.addListener(() => states.add(provider.isBusy));

    await provider.createBackup();

    expect(provider.backups, hasLength(1));
    expect(states, contains(true));
    expect(provider.isBusy, isFalse);
  });

  test(
    'restoreFromFile replaces data, keeps a safety backup, and refreshes the list',
    () async {
      await provider.createBackup();
      final oldBackupPath = provider.backups.single.path;

      await noteRepository.insert(
        Note(
          title: 'یادداشت جدید روی گوشی',
          content: '',
          tag: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await provider.restoreFromFile(File(oldBackupPath));

      final notes = await noteRepository.getAll();
      expect(notes.map((n) => n.title), ['یادداشت اولیه']);
      // نسخه اصلی + نسخه ایمنیِ خودکار پیش از بازیابی.
      expect(provider.backups, hasLength(2));
      expect(
        provider.backups.any((f) => f.path.contains('pre-restore')),
        isTrue,
      );
    },
  );

  test(
    'restoreFromFile throws and leaves data untouched for an invalid file',
    () async {
      final junk = File(p.join(workDir.path, 'junk.db'));
      await junk.writeAsString('نه یک فایل sqlite واقعی');

      await expectLater(provider.restoreFromFile(junk), throwsFormatException);

      final notes = await noteRepository.getAll();
      expect(notes.map((n) => n.title), ['یادداشت اولیه']);
    },
  );

  test('deleteBackup removes it from the list', () async {
    await provider.createBackup();
    final file = provider.backups.single;

    await provider.deleteBackup(file);

    expect(provider.backups, isEmpty);
    expect(await file.exists(), isFalse);
  });
}
