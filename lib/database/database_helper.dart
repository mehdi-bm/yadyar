import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// راه‌اندازی و مدیریت نسخه پایگاه‌داده محلی sqflite.
///
/// برای استفاده در برنامه از [DatabaseHelper.instance] استفاده کنید. برای
/// تست‌ها می‌توان با پاس دادن [path] (مثلاً [inMemoryDatabasePath]) یک نمونه
/// جدا و مستقل ساخت.
class DatabaseHelper {
  DatabaseHelper({String? path}) : _customPath = path;

  static final DatabaseHelper instance = DatabaseHelper();

  static const int databaseVersion = 2;
  static const String databaseName = 'yadyar.db';

  static const String tableNotes = 'notes';
  static const String tableReminders = 'reminders';
  static const String tableSubscriptions = 'subscriptions';
  static const String tableSubscriptionPayments = 'subscription_payments';
  static const String tableShoppingLists = 'shopping_lists';
  static const String tableShoppingItems = 'shopping_items';

  final String? _customPath;
  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = _customPath ?? join(await getDatabasesPath(), databaseName);
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
        lastPaidDate TEXT
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
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
