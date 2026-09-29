import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/shopping_category.dart';

/// راه‌اندازی و مدیریت نسخه پایگاه‌داده محلی sqflite.
///
/// برای استفاده در برنامه از [DatabaseHelper.instance] استفاده کنید. برای
/// تست‌ها می‌توان با پاس دادن [path] (مثلاً [inMemoryDatabasePath]) یک نمونه
/// جدا و مستقل ساخت.
class DatabaseHelper {
  DatabaseHelper({String? path}) : _customPath = path;

  static final DatabaseHelper instance = DatabaseHelper();

  static const int databaseVersion = 6;
  static const String databaseName = 'yadyar.db';

  static const String tableNotes = 'notes';
  static const String tableReminders = 'reminders';
  static const String tableSubscriptions = 'subscriptions';
  static const String tableSubscriptionPayments = 'subscription_payments';
  static const String tableShoppingLists = 'shopping_lists';
  static const String tableShoppingItems = 'shopping_items';
  static const String tableShoppingCategories = 'shopping_categories';

  final String? _customPath;
  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// مسیر واقعی فایل پایگاه‌داده روی دیسک؛ برای تهیه/بازیابی نسخه پشتیبان لازم است.
  Future<String> resolveDatabasePath() async {
    return _customPath ?? join(await getDatabasesPath(), databaseName);
  }

  Future<Database> _initDatabase() async {
    final path = await resolveDatabasePath();
    return openDatabase(
      path,
      version: databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableNotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        tag TEXT NOT NULL,
        isPinned INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // noteId با ON DELETE SET NULL پاک می‌شود، نه CASCADE: حذف یادداشت نباید
    // یادآور مرتبط را از بین ببرد، فقط آن را به یک یادآور مستقل تبدیل می‌کند.
    await db.execute('''
      CREATE TABLE $tableReminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        noteId INTEGER,
        title TEXT NOT NULL,
        dateTime TEXT NOT NULL,
        repeatType TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (noteId) REFERENCES $tableNotes (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSubscriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        dueDate TEXT NOT NULL,
        repeatType TEXT NOT NULL,
        category TEXT NOT NULL,
        reminderDaysBefore INTEGER NOT NULL DEFAULT 0,
        isPaid INTEGER NOT NULL DEFAULT 0,
        lastPaidDate TEXT,
        remainingOccurrences INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableShoppingLists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableShoppingItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shoppingListId INTEGER NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        isChecked INTEGER NOT NULL DEFAULT 0,
        quantity TEXT,
        FOREIGN KEY (shoppingListId) REFERENCES $tableShoppingLists (id) ON DELETE CASCADE
      )
    ''');

    await _createSubscriptionPaymentsTable(db);
    await _migrateShoppingToV4(db);
    await _migrateShoppingToV5(db);
    await _migrateNotesAndBillsToV6(db);
  }

  /// نسخه ۶: یادداشت‌ها (رنگ، بایگانی، «حذف‌شده‌ها») و قبض‌ها (شناسه قبض و
  /// توضیحات). فقط ستون اضافه می‌کند.
  Future<void> _migrateNotesAndBillsToV6(Database db) async {
    // در پایگاه‌داده‌های واقعی این جدول‌ها همیشه وجود دارند؛ IF NOT EXISTS فقط
    // مهاجرت را در برابر فایل ناقص (مثلاً پایگاه‌داده‌های ساختگی تست) مقاوم می‌کند.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableNotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        tag TEXT NOT NULL,
        isPinned INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSubscriptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        dueDate TEXT NOT NULL,
        repeatType TEXT NOT NULL,
        category TEXT NOT NULL,
        reminderDaysBefore INTEGER NOT NULL DEFAULT 0,
        isPaid INTEGER NOT NULL DEFAULT 0,
        lastPaidDate TEXT,
        remainingOccurrences INTEGER
      )
    ''');

    await db.execute('ALTER TABLE $tableNotes ADD COLUMN colorValue INTEGER');
    await db.execute(
      'ALTER TABLE $tableNotes '
      'ADD COLUMN isArchived INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute('ALTER TABLE $tableNotes ADD COLUMN deletedAt TEXT');
    await db.execute(
      'ALTER TABLE $tableSubscriptions ADD COLUMN billIdentifier TEXT',
    );
    await db.execute('ALTER TABLE $tableSubscriptions ADD COLUMN note TEXT');
  }

  /// نسخه ۵: «حذف‌شده‌ها» (سطل بازیافت). حذف قلم خرید به‌جای پاک کردن ردیف،
  /// زمان حذف را در deletedAt ثبت می‌کند تا قابل بازیابی باشد.
  Future<void> _migrateShoppingToV5(Database db) async {
    await db.execute(
      'ALTER TABLE $tableShoppingItems ADD COLUMN deletedAt TEXT',
    );
  }

  /// ارتقای بخش خرید به نسخه ۴: فیلدهای جدید قلم خرید، رنگ لیست و جدول
  /// دسته‌بندی‌های قابل مدیریت. هم برای نصب جدید و هم ارتقا اجرا می‌شود تا
  /// شِمای هر دو مسیر دقیقاً یکسان باشد. فقط ستون/جدول اضافه می‌کند و هیچ
  /// داده‌ای را حذف یا تغییر نمی‌دهد.
  Future<void> _migrateShoppingToV4(Database db) async {
    // در پایگاه‌داده‌های واقعی این دو جدول همیشه وجود دارند؛ IF NOT EXISTS فقط
    // مهاجرت را در برابر فایل ناقص (مثلاً پایگاه‌داده‌های ساختگی تست) مقاوم می‌کند.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableShoppingLists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableShoppingItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shoppingListId INTEGER NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        isChecked INTEGER NOT NULL DEFAULT 0,
        quantity TEXT,
        FOREIGN KEY (shoppingListId) REFERENCES $tableShoppingLists (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('ALTER TABLE $tableShoppingItems ADD COLUMN unit TEXT');
    await db.execute('ALTER TABLE $tableShoppingItems ADD COLUMN price REAL');
    await db.execute('ALTER TABLE $tableShoppingItems ADD COLUMN note TEXT');
    await db.execute(
      'ALTER TABLE $tableShoppingItems '
      'ADD COLUMN isImportant INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE $tableShoppingLists ADD COLUMN colorValue INTEGER',
    );

    await db.execute('''
      CREATE TABLE $tableShoppingCategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        iconKey TEXT NOT NULL,
        colorValue INTEGER NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0
      )
    ''');

    var order = 0;
    for (final category in ShoppingCategory.defaults) {
      await db.insert(
        tableShoppingCategories,
        category.copyWith(sortOrder: order++).toMap()..remove('id'),
      );
    }

    // دسته‌های دلخواهی که کاربر قبلاً (با گزینه «سایر» و نوشتن عنوان) ساخته،
    // به جدول دسته‌ها منتقل می‌شوند تا در مدیریت دسته‌بندی‌ها دیده شوند.
    final existing = await db.rawQuery(
      'SELECT DISTINCT category FROM $tableShoppingItems '
      'WHERE category NOT IN (SELECT name FROM $tableShoppingCategories)',
    );
    for (final row in existing) {
      final name = (row['category'] as String).trim();
      if (name.isEmpty) continue;
      await db.insert(
        tableShoppingCategories,
        ShoppingCategory(
          name: name,
          iconKey: ShoppingCategory.defaultIconKey,
          colorValue: ShoppingCategory.defaultColorValue,
          sortOrder: order++,
        ).toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _createSubscriptionPaymentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableSubscriptionPayments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subscriptionId INTEGER NOT NULL,
        paidDate TEXT NOT NULL,
        amount REAL NOT NULL,
        FOREIGN KEY (subscriptionId) REFERENCES $tableSubscriptions (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createSubscriptionPaymentsTable(db);
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE $tableSubscriptions ADD COLUMN remainingOccurrences INTEGER',
      );
    }
    if (oldVersion < 4) {
      await _migrateShoppingToV4(db);
    }
    if (oldVersion < 5) {
      await _migrateShoppingToV5(db);
    }
    if (oldVersion < 6) {
      await _migrateNotesAndBillsToV6(db);
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
