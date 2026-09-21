import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';

/// "SQLite format 3\0" — سرآمد استاندارد هر فایل پایگاه‌داده sqlite.
const List<int> _sqliteMagicHeader = [
  0x53,
  0x51,
  0x4c,
  0x69,
  0x74,
  0x65,
  0x20,
  0x66,
  0x6f,
  0x72,
  0x6d,
  0x61,
  0x74,
  0x20,
  0x33,
  0x00,
];

/// تهیه، فهرست‌گیری، اعتبارسنجی و بازیابی نسخه‌های پشتیبان محلی از پایگاه‌داده اپ.
///
/// نسخه‌های پشتیبان به‌صورت کپی خام فایل sqlite در پوشه اختصاصی
/// `<app documents>/backups` نگه‌داری می‌شوند تا هم در دسترس اپ (برای بازیابی
/// سریع) و هم از طریق اشتراک‌گذاری قابل انتقال به بیرون (گوگل‌درایو، تلگرام و...) باشند.
class BackupService {
  /// [backupsDirectory] برای تست‌ها قابل تزریق است تا نیازی به کانال پلتفرم
  /// واقعی path_provider نباشد؛ در برنامه واقعی همیشه null می‌ماند و مسیر از
  /// پوشه اسناد اپ محاسبه می‌شود.
  BackupService({DatabaseHelper? databaseHelper, Directory? backupsDirectory})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance,
      _backupsDirectoryOverride = backupsDirectory;

  final DatabaseHelper _databaseHelper;
  final Directory? _backupsDirectoryOverride;

  static const String _backupPrefix = 'yadyar_backup_';
  static const String _preRestorePrefix = 'yadyar_backup_pre-restore_';

  Future<Directory> _backupsDirectory() async {
    final override = _backupsDirectoryOverride;
    if (override != null) {
      if (!await override.exists()) await override.create(recursive: true);
      return override;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'backups'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// یک نسخه پشتیبان جدید از پایگاه‌داده فعلی می‌سازد. برای یکپارچگی کامل
  /// (بدون رکوردهای نیمه‌نوشته)، پیش از کپی، اتصال باز فعلی بسته می‌شود؛ بعد
  /// از این متد به‌صورت خودکار در اولین استفاده دوباره باز خواهد شد.
  Future<File> createBackup({bool isPreRestoreSafety = false}) async {
    final dbPath = await _databaseHelper.resolveDatabasePath();
    final sourceFile = File(dbPath);
    if (!await sourceFile.exists()) {
      throw StateError('پایگاه‌داده‌ای برای تهیه نسخه پشتیبان یافت نشد.');
    }

    final backupsDir = await _backupsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final prefix = isPreRestoreSafety ? _preRestorePrefix : _backupPrefix;
    final backupFile = File(p.join(backupsDir.path, '$prefix$timestamp.db'));

    await _databaseHelper.close();
    await sourceFile.copy(backupFile.path);
    return backupFile;
  }

  /// نسخه‌های پشتیبان محلی ذخیره‌شده در پوشه اپ، جدیدترین اول.
  ///
  /// مرتب‌سازی بر اساس timestamp استخراج‌شده از نام فایل انجام می‌شود، نه زمان
  /// تغییر فایل‌سیستم (چون `File.copy` همیشه زمان تغییر مقصد را به‌صورت
  /// قابل‌اتکا «اکنون» تنظیم نمی‌کند) و نه رشته کامل نام فایل (چون پیشوند
  /// طولانی‌تر `pre-restore` لغوی همیشه بالاتر از پیشوند معمولی می‌نشیند،
  /// صرف‌نظر از اینکه واقعاً جدیدتر باشد یا نه).
  Future<List<File>> listBackups() async {
    final dir = await _backupsDirectory();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.db'))
        .toList();
    files.sort(
      (a, b) => _timestampOf(b.path).compareTo(_timestampOf(a.path)),
    );
    return files;
  }

  /// بخش timestamp با طول ثابت (`yyyyMMdd_HHmmss`، ۱۵ کاراکتر) را از انتهای
  /// نام فایل جدا می‌کند تا مرتب‌سازی مستقل از طول پیشوند (`yadyar_backup_`
  /// یا `yadyar_backup_pre-restore_`) باشد.
  static const int _timestampLength = 15;

  String _timestampOf(String path) {
    final name = p.basenameWithoutExtension(path);
    if (name.length <= _timestampLength) return name;
    return name.substring(name.length - _timestampLength);
  }

  Future<void> deleteBackup(File file) async {
    if (await file.exists()) await file.delete();
  }

  /// بررسی می‌کند فایل انتخاب‌شده هم یک فایل sqlite معتبر است و هم جدول‌های
  /// اصلی یادیار را دارد — پیش از جایگزینی پایگاه‌داده فعلی با آن.
  Future<bool> looksLikeValidBackup(File file) async {
    if (!await file.exists()) return false;
    if (!await _hasSqliteHeader(file)) return false;
    return _hasExpectedTables(file);
  }

  Future<bool> _hasSqliteHeader(File file) async {
    final handle = await file.open();
    try {
      final header = await handle.read(_sqliteMagicHeader.length);
      if (header.length < _sqliteMagicHeader.length) return false;
      for (var i = 0; i < _sqliteMagicHeader.length; i++) {
        if (header[i] != _sqliteMagicHeader[i]) return false;
      }
      return true;
    } finally {
      await handle.close();
    }
  }

  Future<bool> _hasExpectedTables(File file) async {
    Database? db;
    try {
      db = await databaseFactory.openDatabase(
        file.path,
        options: OpenDatabaseOptions(readOnly: true),
      );
      final tables = await db.query(
        'sqlite_master',
        columns: ['name'],
        where: 'type = ? AND name IN (?, ?, ?)',
        whereArgs: [
          'table',
          DatabaseHelper.tableNotes,
          DatabaseHelper.tableSubscriptions,
          DatabaseHelper.tableShoppingLists,
        ],
      );
      return tables.length == 3;
    } on Object {
      return false;
    } finally {
      await db?.close();
    }
  }

  /// پایگاه‌داده فعلی را با محتوای [backupFile] جایگزین می‌کند.
  ///
  /// پیش از جایگزینی، به‌صورت خودکار یک نسخه پشتیبان ایمنی از وضعیت فعلی
  /// گرفته می‌شود (پیشوند pre-restore) تا اگر فایل اشتباهی انتخاب شده باشد،
  /// اطلاعات فعلی از بین نرود و قابل بازگشت باشد.
  Future<void> restoreFromFile(File backupFile) async {
    if (!await looksLikeValidBackup(backupFile)) {
      throw const FormatException(
        'فایل انتخاب‌شده یک نسخه پشتیبان معتبر یادیار نیست.',
      );
    }

    await createBackup(isPreRestoreSafety: true);

    final dbPath = await _databaseHelper.resolveDatabasePath();
    await _databaseHelper.close();
    await backupFile.copy(dbPath);
  }
}
