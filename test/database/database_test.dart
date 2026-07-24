import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:yadyar_app/database/database_helper.dart';
import 'package:yadyar_app/models/note.dart';
import 'package:yadyar_app/models/reminder.dart';
import 'package:yadyar_app/models/shopping_item.dart';
import 'package:yadyar_app/models/shopping_list.dart';
import 'package:yadyar_app/models/subscription.dart';
import 'package:yadyar_app/repositories/note_repository.dart';
import 'package:yadyar_app/repositories/reminder_repository.dart';
import 'package:yadyar_app/repositories/shopping_list_repository.dart';
import 'package:yadyar_app/repositories/subscription_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseHelper databaseHelper;

  setUp(() {
    // هر تست یک پایگاه‌داده درون‌حافظه‌ای جدا و مستقل می‌گیرد.
    databaseHelper = DatabaseHelper(path: inMemoryDatabasePath);
  });

  tearDown(() async {
    await databaseHelper.close();
  });

  test('insert and retrieve a Note', () async {
    final repo = NoteRepository(databaseHelper: databaseHelper);
    final now = DateTime.now();

    final id = await repo.insert(
      Note(
        title: 'یادداشت تست',
        content: 'این یک یادداشت نمونه است.',
        tag: 'شخصی',
        isPinned: true,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final saved = await repo.getById(id);

    expect(saved, isNotNull);
    expect(saved!.title, 'یادداشت تست');
    expect(saved.isPinned, isTrue);
    expect(await repo.getAll(), hasLength(1));
  });

  test('insert and retrieve a standalone Reminder', () async {
    final repo = ReminderRepository(databaseHelper: databaseHelper);

    final id = await repo.insert(
      Reminder(
        title: 'یادآوری تست',
        dateTime: DateTime.now().add(const Duration(days: 1)),
        repeatType: ReminderRepeatType.weekly,
      ),
    );

    final saved = await repo.getById(id);

    expect(saved, isNotNull);
    expect(saved!.noteId, isNull);
    expect(saved.repeatType, ReminderRepeatType.weekly);
    expect(saved.isActive, isTrue);
  });

  test('insert and retrieve a Subscription', () async {
    final repo = SubscriptionRepository(databaseHelper: databaseHelper);

    final id = await repo.insert(
      Subscription(
        title: 'اشتراک تست',
        amount: 150000,
        dueDate: DateTime.now().add(const Duration(days: 10)),
        repeatType: SubscriptionRepeatType.monthly,
        category: 'اشتراک ویدیو',
        reminderDaysBefore: 3,
      ),
    );

    final saved = await repo.getById(id);

    expect(saved, isNotNull);
    expect(saved!.amount, 150000);
    expect(saved.isPaid, isFalse);
    expect(saved.lastPaidDate, isNull);
  });

  test('insert and retrieve a ShoppingList with its ShoppingItem', () async {
    final repo = ShoppingListRepository(databaseHelper: databaseHelper);

    final listId = await repo.insert(
      ShoppingList(name: 'لیست تست', createdAt: DateTime.now()),
    );

    final itemId = await repo.insertItem(
      ShoppingItem(
        shoppingListId: listId,
        name: 'نان',
        category: 'نانوایی',
        quantity: '۲ عدد',
      ),
    );

    final savedList = await repo.getById(listId);
    final savedItem = await repo.getItemById(itemId);
    final items = await repo.getItemsByListId(listId);

    expect(savedList, isNotNull);
    expect(savedList!.name, 'لیست تست');
    expect(savedItem, isNotNull);
    expect(savedItem!.shoppingListId, listId);
    expect(items, hasLength(1));
  });

  test('deleting a ShoppingList cascades to its items', () async {
    final repo = ShoppingListRepository(databaseHelper: databaseHelper);
    final listId = await repo.insert(
      ShoppingList(name: 'لیست حذفی', createdAt: DateTime.now()),
    );
    await repo.insertItem(
      ShoppingItem(shoppingListId: listId, name: 'شیر', category: 'لبنیات'),
    );

    await repo.delete(listId);

    expect(await repo.getItemsByListId(listId), isEmpty);
  });

  test('deleting a Note sets its Reminder.noteId to null', () async {
    final noteRepo = NoteRepository(databaseHelper: databaseHelper);
    final reminderRepo = ReminderRepository(databaseHelper: databaseHelper);
    final now = DateTime.now();

    final noteId = await noteRepo.insert(
      Note(
        title: 'یادداشت با یادآور',
        content: 'محتوا',
        tag: 'کار',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final reminderId = await reminderRepo.insert(
      Reminder(noteId: noteId, title: 'یادآوری وابسته', dateTime: now),
    );

    await noteRepo.delete(noteId);

    final reminder = await reminderRepo.getById(reminderId);
    expect(reminder, isNotNull);
    expect(reminder!.noteId, isNull);
  });
}
