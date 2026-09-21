import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yadyar_app/database/database_helper.dart';
import 'package:yadyar_app/providers/backup_provider.dart';
import 'package:yadyar_app/screens/backup/backup_screen.dart';
import 'package:yadyar_app/services/backup_service.dart';
import 'package:yadyar_app/theme/app_theme.dart';

void main() {
  setUpAll(() {
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  // BackupProvider/BackupService از dart:io واقعی (File/Directory) استفاده
  // می‌کند که zone تست fake-async pumpAndSettle آن را جلو نمی‌برد. رفتار
  // واقعی بارگذاری/تهیه/بازیابی نسخه پشتیبان به‌طور کامل و مستقیم در
  // test/providers/backup_provider_test.dart پوشش داده شده؛ این تست فقط
  // سالم ساخته‌شدن صفحه (بدون خطا، بدون نیاز به تکمیل بارگذاری async) را
  // بررسی می‌کند.
  testWidgets('BackupScreen builds and shows its primary actions', (
    tester,
  ) async {
    final databaseHelper = DatabaseHelper(path: inMemoryDatabasePath);
    final backupService = BackupService(
      databaseHelper: databaseHelper,
      backupsDirectory: Directory.systemTemp.createTempSync(
        'yadyar_backup_smoke_test',
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => BackupProvider(backupService: backupService),
        child: MaterialApp(theme: AppTheme.light, home: const BackupScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('پشتیبان‌گیری و بازیابی'), findsOneWidget);
    expect(find.text('تهیه نسخه پشتیبان جدید'), findsOneWidget);
    expect(find.text('بازیابی از فایل دیگر...'), findsOneWidget);

    await databaseHelper.close();
  });
}
