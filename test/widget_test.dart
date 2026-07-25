import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:yadyar_app/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDownAll(() async {
    // main.dart از DatabaseHelper.instance (سینگلتون واقعی، نه درون‌حافظه‌ای)
    // استفاده می‌کند؛ فایل تستی ساخته‌شده پاک می‌شود تا اثری باقی نماند.
    final dbPath = p.join(
      await databaseFactory.getDatabasesPath(),
      'yadyar.db',
    );
    final file = File(dbPath);
    if (await file.exists()) await file.delete();
  });

  testWidgets('Bottom navigation shows 4 tabs and switches between them', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const YadyarApp());
    await tester.pumpAndSettle();

    // برچسب‌های ناوبری پایین + محتوای تب فعلی (داشبورد).
    expect(find.text('داشبورد'), findsNWidgets(2));
    expect(find.text('یادداشت'), findsOneWidget);
    expect(find.text('قبض‌ها'), findsOneWidget);
    expect(find.text('خرید'), findsOneWidget);

    await tester.tap(find.text('خرید'));
    // فقط یک فریم پمپ می‌شود، نه pumpAndSettle: بارگذاری واقعی از دیتابیس
    // async است و جداگانه در تست‌های Provider پوشش داده شده؛ اینجا فقط
    // سالم ساخته‌شدن صفحه بعد از سوییچ تب بررسی می‌شود.
    await tester.pump();

    expect(find.byTooltip('لیست جدید'), findsOneWidget);
  });

  testWidgets('first launch shows onboarding after splash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const YadyarApp(onboardingComplete: false));
    await tester.pumpAndSettle();

    expect(find.text('یادداشت و یادآور'), findsOneWidget);
    expect(find.text('ادامه'), findsOneWidget);
    expect(find.text('رد کردن'), findsOneWidget);
  });
}
