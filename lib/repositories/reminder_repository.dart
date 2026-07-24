import '../database/database_helper.dart';
import '../models/reminder.dart';

class ReminderRepository {
  ReminderRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  static const String _table = DatabaseHelper.tableReminders;

  Future<int> insert(Reminder reminder) async {
    final db = await _databaseHelper.database;
    return db.insert(_table, reminder.toMap());
  }

  Future<int> update(Reminder reminder) async {
    final db = await _databaseHelper.database;
    return db.update(
      _table,
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _databaseHelper.database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Reminder>> getAll() async {
    final db = await _databaseHelper.database;
    final maps = await db.query(_table, orderBy: 'dateTime ASC');
    return maps.map(Reminder.fromMap).toList();
  }

  Future<Reminder?> getById(int id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Reminder.fromMap(maps.first);
  }

  Future<List<Reminder>> getByNoteId(int noteId) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(_table, where: 'noteId = ?', whereArgs: [noteId]);
    return maps.map(Reminder.fromMap).toList();
  }
}
