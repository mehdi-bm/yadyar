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
import 'package:shared_preferences/shared_preferences.dart';

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
    SharedPreferences.setMockInitialValues({});
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

  testWidgets('pinning shows the pin icon; deleting moves to trash with undo', (
    tester,
  ) async {
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

    // حذف قابل بازیابی است: تأیید نمی‌خواهد و دکمه «بازگردانی» نشان می‌دهد.
    expect(find.text('یادداشت تست'), findsNothing);
    expect(provider.trashCount, 1);

    await tester.tap(find.text('بازگردانی'));
    await tester.pumpAndSettle();

    expect(find.text('یادداشت تست'), findsOneWidget);
    expect(provider.trashCount, 0);
  });

  testWidgets('swiping a note archives it and it shows in the archive', (
    tester,
  ) async {
    await provider.addNote(
      title: 'برای بایگانی',
      content: 'متن',
      tag: '',
      isPinned: false,
    );
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    // در چینش LTR تست، کشیدن به راست = startToEnd = بایگانی.
    await tester.drag(find.text('برای بایگانی'), const Offset(700, 0));
    await tester.pumpAndSettle();

    expect(find.text('برای بایگانی'), findsNothing);
    expect(find.text('«برای بایگانی» بایگانی شد'), findsOneWidget);
    expect(provider.archivedNotes.single.title, 'برای بایگانی');

    await tester.tap(find.byTooltip('گزینه‌های بیشتر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('بایگانی (۱)'));
    await tester.pumpAndSettle();

    expect(find.text('برای بایگانی'), findsOneWidget);
    await tester.tap(find.byTooltip('خروج از بایگانی'));
    await tester.pumpAndSettle();

    expect(provider.archivedNotes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('trash screen restores and permanently deletes notes', (
    tester,
  ) async {
    await provider.addNote(title: 'الف', content: '', tag: '', isPinned: false);
    await provider.addNote(title: 'ب', content: '', tag: '', isPinned: false);
    for (final note in provider.filteredNotes.toList()) {
      await provider.moveToTrash(note);
    }
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('گزینه‌های بیشتر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف‌شده‌ها (۲)'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('بازگردانی').first);
    await tester.pumpAndSettle();
    expect(provider.trashCount, 1);

    await tester.tap(find.byTooltip('حذف برای همیشه'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف دائمی'));
    await tester.pumpAndSettle();

    expect(provider.trashCount, 0);
    expect(find.textContaining('بخش حذف‌شده‌ها خالی است'), findsOneWidget);
    expect(provider.filteredNotes, hasLength(1));
  });

  testWidgets('grid view toggle and pinned/other sections', (tester) async {
    await provider.addNote(
      title: 'سنجاق‌شده من',
      content: '',
      tag: 'کار',
      isPinned: true,
    );
    await provider.addNote(
      title: 'معمولی',
      content: '',
      tag: '',
      isPinned: false,
    );
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();

    expect(find.text('سنجاق‌شده'), findsOneWidget);
    expect(find.text('سایر یادداشت‌ها'), findsOneWidget);

    await tester.tap(find.byTooltip('نمای شبکه‌ای'));
    await tester.pumpAndSettle();

    expect(provider.isGridView, isTrue);
    expect(find.byTooltip('نمای لیستی'), findsOneWidget);
    expect(find.text('معمولی'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
