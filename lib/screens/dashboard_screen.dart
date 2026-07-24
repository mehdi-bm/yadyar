import 'package:flutter/material.dart';

import '../models/note.dart';
import '../models/reminder.dart';
import '../models/shopping_list.dart';
import '../models/subscription.dart';
import '../repositories/note_repository.dart';
import '../repositories/reminder_repository.dart';
import '../repositories/shopping_list_repository.dart';
import '../repositories/subscription_repository.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import 'bills/widgets/bill_status.dart';
import 'shopping/shopping_list_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.onNavigateToTab,
    this.noteRepository,
    this.reminderRepository,
    this.subscriptionRepository,
    this.shoppingRepository,
  });

  final ValueChanged<int> onNavigateToTab;
  final NoteRepository? noteRepository;
  final ReminderRepository? reminderRepository;
  final SubscriptionRepository? subscriptionRepository;
  final ShoppingListRepository? shoppingRepository;

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  late final NoteRepository _noteRepository;
  late final ReminderRepository _reminderRepository;
  late final SubscriptionRepository _subscriptionRepository;
  late final ShoppingListRepository _shoppingRepository;

  List<_ReminderEntry> _reminders = [];
  List<Subscription> _bills = [];
  List<_ShoppingEntry> _shoppingLists = [];
  bool _isLoading = true;

  int get _todayReminderCount =>
      _reminders.where((entry) => entry.isToday).length;
  int get _overdueBillCount =>
      _bills.where((bill) => billStatusOf(bill) == BillStatus.overdue).length;
  int get _remainingShoppingCount =>
      _shoppingLists.fold(0, (total, entry) => total + entry.remainingCount);

  @override
  void initState() {
    super.initState();
    _noteRepository = widget.noteRepository ?? NoteRepository();
    _reminderRepository = widget.reminderRepository ?? ReminderRepository();
    _subscriptionRepository =
        widget.subscriptionRepository ?? SubscriptionRepository();
    _shoppingRepository = widget.shoppingRepository ?? ShoppingListRepository();
    refresh();
  }

  Future<void> refresh() async {
    if (mounted) setState(() => _isLoading = true);

    // DatabaseHelper lazily opens one SQLite connection. Keep the first reads
    // sequential so multiple repositories cannot race while opening it.
    final notes = await _noteRepository.getAll();
    final reminders = await _reminderRepository.getAll();
    final subscriptions = await _subscriptionRepository.getAll();
    final shoppingLists = await _shoppingRepository.getAll();

    final noteById = {for (final note in notes) note.id: note};
    final today = _dateOnly(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));
    final reminderEntries = <_ReminderEntry>[];
    for (final reminder in reminders.where((item) => item.isActive)) {
      for (final date in [today, tomorrow]) {
        if (_occursOn(reminder, date)) {
          reminderEntries.add(
            _ReminderEntry(
              reminder: reminder,
              note: noteById[reminder.noteId],
              occurrence: DateTime(
                date.year,
                date.month,
                date.day,
                reminder.dateTime.hour,
                reminder.dateTime.minute,
              ),
              isToday: date == today,
            ),
          );
        }
      }
    }
    reminderEntries.sort((a, b) => a.occurrence.compareTo(b.occurrence));

    final endOfWindow = today.add(const Duration(days: 8));
    final nearbyBills =
        subscriptions
            .where(
              (bill) =>
                  !bill.isPaid && _dateOnly(bill.dueDate).isBefore(endOfWindow),
            )
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final shoppingEntries = <_ShoppingEntry>[];
    for (final list in shoppingLists) {
      final items = await _shoppingRepository.getItemsByListId(list.id!);
      final remaining = items.where((item) => !item.isChecked).length;
      if (remaining > 0) {
        shoppingEntries.add(
          _ShoppingEntry(list: list, remainingCount: remaining),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _reminders = reminderEntries;
      _bills = nearbyBills;
      _shoppingLists = shoppingEntries;
      _isLoading = false;
    });
  }

  bool _occursOn(Reminder reminder, DateTime target) {
    final start = _dateOnly(reminder.dateTime);
    if (target.isBefore(start)) return false;
    final days = target.difference(start).inDays;
    return switch (reminder.repeatType) {
      ReminderRepeatType.none => days == 0,
      ReminderRepeatType.daily => true,
      ReminderRepeatType.weekly => days % 7 == 0,
      ReminderRepeatType.monthly => target.day == start.day,
    };
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('داشبورد'),
        actions: const [ThemeModeButton()],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: _isLoading
            ? const _LoadingBody()
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                children: [
                  _SummaryCard(
                    reminderCount: _todayReminderCount,
                    overdueCount: _overdueBillCount,
                    shoppingCount: _remainingShoppingCount,
                  ),
                  const SizedBox(height: 16),
                  _SectionHeader(
                    title: 'یادآورهای امروز و فردا',
                    onViewAll: () => widget.onNavigateToTab(1),
                  ),
                  if (_reminders.isEmpty)
                    const _EmptyMessage('یادآوری برای امروز یا فردا ندارید.')
                  else
                    ..._reminders
                        .take(4)
                        .map(
                          (entry) => Card(
                            child: ListTile(
                              leading: Icon(
                                entry.isToday
                                    ? Icons.notifications_active_outlined
                                    : Icons.notifications_none_outlined,
                              ),
                              title: Text(
                                entry.note?.title ?? entry.reminder.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${entry.isToday ? 'امروز' : 'فردا'}، '
                                '${TimeOfDay.fromDateTime(entry.occurrence).format(context)}',
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(height: 12),
                  _SectionHeader(
                    title: 'قبض‌های نزدیک به سررسید',
                    onViewAll: () => widget.onNavigateToTab(2),
                  ),
                  if (_bills.isEmpty)
                    const _EmptyMessage('قبض معوق یا نزدیک به سررسیدی ندارید.')
                  else
                    ..._bills.take(4).map((bill) {
                      final status = billStatusOf(bill);
                      final color = billStatusColor(context, status);
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.12),
                            child: Icon(
                              Icons.receipt_long_outlined,
                              color: color,
                            ),
                          ),
                          title: Text(bill.title),
                          subtitle: Text(
                            '${formatJalaliDate(bill.dueDate)} • '
                            '${billStatusLabel(status)}',
                            style: TextStyle(color: color),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 12),
                  _SectionHeader(
                    title: 'لیست‌های خرید فعال',
                    onViewAll: () => widget.onNavigateToTab(3),
                  ),
                  if (_shoppingLists.isEmpty)
                    const _EmptyMessage('آیتم خرید باقی‌مانده‌ای ندارید.')
                  else
                    ..._shoppingLists
                        .take(4)
                        .map(
                          (entry) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.shopping_cart_outlined),
                              title: Text(entry.list.name),
                              subtitle: Text(
                                '${entry.remainingCount} آیتم باقی‌مانده',
                              ),
                              trailing: const Icon(Icons.chevron_left),
                              onTap: () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => ShoppingListDetailScreen(
                                    shoppingList: entry.list,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ],
              ),
      ),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) => ListView(
    physics: AlwaysScrollableScrollPhysics(),
    children: [
      SizedBox(
        height: 400,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dashboard_outlined, size: 48),
              SizedBox(height: 12),
              Text('در حال بروزرسانی داشبورد…'),
            ],
          ),
        ),
      ),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.reminderCount,
    required this.overdueCount,
    required this.shoppingCount,
  });

  final int reminderCount;
  final int overdueCount;
  final int shoppingCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Row(
          children: [
            _SummaryItem(value: reminderCount, label: 'یادآور امروز'),
            _SummaryItem(value: overdueCount, label: 'قبض معوق'),
            _SummaryItem(value: shoppingCount, label: 'خرید باقی‌مانده'),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          '$value',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.onViewAll});

  final String title;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      TextButton(onPressed: onViewAll, child: const Text('مشاهده همه')),
    ],
  );
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).colorScheme.outline),
    ),
  );
}

class _ReminderEntry {
  const _ReminderEntry({
    required this.reminder,
    required this.note,
    required this.occurrence,
    required this.isToday,
  });

  final Reminder reminder;
  final Note? note;
  final DateTime occurrence;
  final bool isToday;
}

class _ShoppingEntry {
  const _ShoppingEntry({required this.list, required this.remainingCount});

  final ShoppingList list;
  final int remainingCount;
}
