import '../database/database_helper.dart';
import '../models/note.dart';

class NoteRepository {
  NoteRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  static const String _table = DatabaseHelper.tableNotes;

  Future<int> insert(Note note) async {
    final db = await _databaseHelper.database;
    return db.insert(_table, note.toMap());
  }

  Future<int> update(Note note) async {
    final db = await _databaseHelper.database;
    return db.update(_table, note.toMap(), where: 'id = ?', whereArgs: [note.id]);
  }

  Future<int> delete(int id) async {
    final db = await _databaseHelper.database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Note>> getAll() async {
    final db = await _databaseHelper.database;
    final maps = await db.query(_table, orderBy: 'isPinned DESC, updatedAt DESC');
    return maps.map(Note.fromMap).toList();
  }

  Future<Note?> getById(int id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Note.fromMap(maps.first);
  }
}
