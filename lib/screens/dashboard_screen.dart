import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../models/reminder.dart';
import '../models/shopping_list.dart';
import '../models/subscription.dart';
import '../providers/backup_provider.dart';
import '../repositories/note_repository.dart';
import '../repositories/reminder_repository.dart';
import '../repositories/shopping_list_repository.dart';
import '../repositories/subscription_repository.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import '../widgets/ads/ad_banner_widget.dart';
import 'backup/backup_screen.dart';
import 'bills/widgets/bill_status.dart';
import 'shopping/shopping_list_detail_screen.dart';
import 'support/support_screen.dart';

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

  final _adBannerKey = GlobalKey<AdBannerWidgetState>();

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
    unawaited(_adBannerKey.currentState?.refresh());

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
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'پشتیبانی',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const SupportScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.backup_outlined),
            tooltip: 'پشتیبان‌گیری و بازیابی',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider(
                  create: (_) => BackupProvider(),
                  child: const BackupScreen(),
                ),
              ),
            ),
          ),
          const ThemeModeButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: _isLoading
            ? const _LoadingBody()
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  const _GreetingHeader(),
                  const SizedBox(height: 16),
                  AdBannerWidget(key: _adBannerKey),
                  _SummaryCard(
                    reminderCount: _todayReminderCount,
                    overdueCount: _overdueBillCount,
                    shoppingCount: _remainingShoppingCount,
                  ),
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: 'یادآورهای امروز و فردا',
                    onViewAll: () => widget.onNavigateToTab(1),
                  ),
                  const SizedBox(height: 8),
                  if (_reminders.isEmpty)
                    const _EmptyMessage(
                      icon: Icons.notifications_none_outlined,
                      message: 'یادآوری برای امروز یا فردا ندارید.',
                    )
                  else
                    _SectionCard(
                      children: _reminders
                          .take(4)
                          .map(
                            (entry) => ListTile(
                              leading: _SectionIcon(
                                icon: entry.isToday
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
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: 'قبض‌های نزدیک به سررسید',
                    onViewAll: () => widget.onNavigateToTab(2),
                  ),
                  const SizedBox(height: 8),
                  if (_bills.isEmpty)
                    const _EmptyMessage(
                      icon: Icons.receipt_long_outlined,
                      message: 'قبض معوق یا نزدیک به سررسیدی ندارید.',
                    )
                  else
                    _SectionCard(
                      children: _bills.take(4).map((bill) {
                        final status = billStatusOf(bill);
                        final color = billStatusColor(context, status);
                        return ListTile(
                          leading: _SectionIcon(
                            icon: Icons.receipt_long_outlined,
                            color: color,
                          ),
                          title: Text(bill.title),
                          subtitle: Text(
                            '${formatJalaliDate(bill.dueDate)} • '
                            '${billStatusLabel(status)}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),
                  _SectionHeader(
                    title: 'لیست‌های خرید فعال',
                    onViewAll: () => widget.onNavigateToTab(3),
                  ),
                  const SizedBox(height: 8),
                  if (_shoppingLists.isEmpty)
                    const _EmptyMessage(
                      icon: Icons.shopping_cart_outlined,
                      message: 'آیتم خرید باقی‌مانده‌ای ندارید.',
                    )
                  else
                    _SectionCard(
                      children: _shoppingLists.take(4).map((entry) {
                        return ListTile(
                          leading: const _SectionIcon(
                            icon: Icons.shopping_cart_outlined,
                          ),
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
                        );
                      }).toList(),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            scheme.primaryContainer,
            scheme.primary.withValues(alpha: 0.75),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Row(
          children: [
            _SummaryItem(
              value: reminderCount,
              label: 'یادآور امروز',
              icon: Icons.notifications_active_outlined,
              highlighted: reminderCount > 0,
            ),
            _SummaryItem(
              value: overdueCount,
              label: 'قبض معوق',
              icon: Icons.report_gmailerrorred_outlined,
              highlighted: overdueCount > 0,
              highlightColor: context.statusColors.error,
            ),
            _SummaryItem(
              value: shoppingCount,
              label: 'خرید باقی‌مانده',
              icon: Icons.shopping_cart_outlined,
              highlighted: shoppingCount > 0,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.value,
    required this.label,
    required this.icon,
    this.highlighted = false,
    this.highlightColor,
  });

  final int value;
  final String label;
  final IconData icon;
  final bool highlighted;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = highlighted
        ? (highlightColor ?? scheme.onPrimary)
        : scheme.onPrimaryContainer;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
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
  const _EmptyMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        child: Column(
          children: [
            Icon(icon, size: 28, color: scheme.outline),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// کارت ظرف مشترک برای گروه‌بندی ردیف‌های یک بخش داشبورد با یک جداکننده
/// بین هر ردیف، به‌جای یک Card جدا برای هر مورد.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon({required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: accent, size: 20),
    );
  }
}

/// سرآمد خوش‌آمدگویی داشبورد: تاریخ امروز به شمسی، برای حس زنده و به‌روز بودن اپ.
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'صبح بخیر'
        : hour < 18
        ? 'ظهر بخیر'
        : 'عصر بخیر';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatJalaliLong(DateTime.now()),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
