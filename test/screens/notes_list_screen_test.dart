import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yadyar_app/database/database_helper.dart';
import 'package:yadyar_app/providers/notes_provider.dart';
import 'package:yadyar_app/repositories/note_repository.dart';
import 'package:yadyar_app/repositories/reminder_repository.dart';
import 'package:yadyar_app/screens/notes/notes_list_screen.dart';
import 'package:yadyar_app/theme/app_theme.dart';

void main() {
  setUpAll(() {
    // نسخه بدون ایزوله: چون بارگذاری از initState/postFrameCallback در
    // صفحات واقعی صدا زده می‌شود، ارتباط مبتنی بر ایزوله در zone تست ویجت
    // (fake-async) هرگز پاسخ نمی‌گیرد و pumpAndSettle برای همیشه گیر می‌کند.
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late DatabaseHelper databaseHelper;
  late NotesProvider provider;

  setUp(() {
    databaseHelper = DatabaseHelper(path: inMemoryDatabasePath);
    provider = NotesProvider(
      noteRepository: NoteRepository(databaseHelper: databaseHelper),
      reminderRepository: ReminderRepository(databaseHelper: databaseHelper),
    );
  });

  tearDown(() async {
    await databaseHelper.close();
  });

  Widget buildApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: const MaterialApp(home: NotesListScreen()),
    );
  }

  testWidgets('shows empty state when there are no notes', (tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('هنوز یادداشتی ثبت نشده'), findsOneWidget);
  });

  testWidgets('creating a note through the editor adds it to the list', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('یادداشت جدید'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'عنوان'),
      'خرید نان',
    );
    await tester.tap(find.byTooltip('ذخیره'));
    await tester.pumpAndSettle();

    expect(find.text('خرید نان'), findsOneWidget);
  });

  testWidgets(
    'pinning a note shows the pin icon, deleting asks for confirmation',
    (tester) async {
      await provider.addNote(
        title: 'یادداشت تست',
        content: '',
        tag: '',
        isPinned: false,
      );
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('یادداشت تست'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('سنجاق کردن'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.push_pin), findsOneWidget);

      await tester.longPress(find.text('یادداشت تست'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();

      // دیالوگ تایید حذف باید ظاهر شود؛ با انصراف، یادداشت هنوز باید موجود باشد.
      expect(find.text('حذف یادداشت'), findsOneWidget);
      await tester.tap(find.text('انصراف'));
      await tester.pumpAndSettle();
      expect(find.text('یادداشت تست'), findsOneWidget);

      await tester.longPress(find.text('یادداشت تست'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();

      expect(find.text('یادداشت تست'), findsNothing);
    },
  );

  testWidgets('theme mode button cycles through system, light and dark', (
    tester,
  ) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('تم سیستم؛ تغییر تم'), findsOneWidget);

    await tester.tap(find.byTooltip('تم سیستم؛ تغییر تم'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('تم روشن؛ تغییر تم'), findsOneWidget);

    await tester.tap(find.byTooltip('تم روشن؛ تغییر تم'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('تم تیره؛ تغییر تم'), findsOneWidget);
  });
}
