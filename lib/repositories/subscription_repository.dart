import '../database/database_helper.dart';
import '../models/subscription.dart';
import '../models/subscription_payment.dart';

class SubscriptionRepository {
  SubscriptionRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  static const String _table = DatabaseHelper.tableSubscriptions;
  static const String _paymentsTable = DatabaseHelper.tableSubscriptionPayments;

  Future<int> insert(Subscription subscription) async {
    final db = await _databaseHelper.database;
    return db.insert(_table, subscription.toMap());
  }

  Future<int> update(Subscription subscription) async {
    final db = await _databaseHelper.database;
    return db.update(
      _table,
      subscription.toMap(),
      where: 'id = ?',
      whereArgs: [subscription.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _databaseHelper.database;
    return db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Subscription>> getAll() async {
    final db = await _databaseHelper.database;
    final maps = await db.query(_table, orderBy: 'dueDate ASC');
    return maps.map(Subscription.fromMap).toList();
  }

  Future<Subscription?> getById(int id) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Subscription.fromMap(maps.first);
  }

  // ---- تاریخچه پرداخت‌ها ----

  Future<int> insertPayment(SubscriptionPayment payment) async {
    final db = await _databaseHelper.database;
    return db.insert(_paymentsTable, payment.toMap());
  }

  Future<List<SubscriptionPayment>> getPaymentsBySubscriptionId(int subscriptionId) async {
    final db = await _databaseHelper.database;
    final maps = await db.query(
      _paymentsTable,
      where: 'subscriptionId = ?',
      whereArgs: [subscriptionId],
      orderBy: 'paidDate DESC',
    );
    return maps.map(SubscriptionPayment.fromMap).toList();
  }

  Future<List<SubscriptionPayment>> getAllPayments() async {
    final db = await _databaseHelper.database;
    final maps = await db.query(_paymentsTable, orderBy: 'paidDate DESC');
    return maps.map(SubscriptionPayment.fromMap).toList();
  }
}
