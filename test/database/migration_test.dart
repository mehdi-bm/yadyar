import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yadyar_app/database/database_helper.dart';
import 'package:yadyar_app/models/subscription_payment.dart';
import 'package:yadyar_app/repositories/subscription_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('upgrading an existing v1 database adds subscription_payments without data loss', () async {
    final dir = await Directory.systemTemp.createTemp('yadyar_migration_test');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 'test.db');

    // یک پایگاه‌داده نسخه ۱ (بدون جدول subscription_payments) شبیه‌سازی می‌شود،
    // دقیقاً همان چیزی که کاربران نصب‌شده قبل از این مرحله دارند.
    final v1Db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE subscriptions (
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
        },
      ),
    );
    final existingId = await v1Db.insert('subscriptions', {
      'title': 'اشتراک قدیمی',
      'amount': 50000.0,
      'dueDate': DateTime(2026, 8, 1).toIso8601String(),
      'repeatType': 'monthly',
      'category': 'اینترنت',
      'reminderDaysBefore': 3,
      'isPaid': 0,
      'lastPaidDate': null,
    });
    await v1Db.close();

    // اکنون همان فایل با DatabaseHelper واقعی (نسخه ۲) باز می‌شود؛ onUpgrade باید اجرا شود.
    final helper = DatabaseHelper(path: path);
    final repository = SubscriptionRepository(databaseHelper: helper);

    final subscriptions = await repository.getAll();
    expect(subscriptions, hasLength(1));
    expect(subscriptions.first.id, existingId);
    expect(subscriptions.first.title, 'اشتراک قدیمی');

    final paymentId = await repository.insertPayment(
      SubscriptionPayment(
        subscriptionId: subscriptions.first.id!,
        paidDate: DateTime.now(),
        amount: 50000,
      ),
    );
    expect(paymentId, greaterThan(0));

    final payments = await repository.getPaymentsBySubscriptionId(subscriptions.first.id!);
    expect(payments, hasLength(1));

    await helper.close();
  });
}
