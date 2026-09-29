import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../models/note.dart';
import '../models/reminder.dart';
import '../models/shopping_list.dart';
import '../models/subscription.dart';
import '../providers/backup_provider.dart';
import '../providers/shopping_provider.dart';
import '../repositories/note_repository.dart';
import '../repositories/reminder_repository.dart';
import '../repositories/shopping_list_repository.dart';
import '../repositories/subscription_repository.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import '../widgets/ads/ad_banner_widget.dart';
import 'backup/backup_screen.dart';
import 'bills/subscription_edit_screen.dart';
import 'bills/widgets/bill_status.dart';
import 'bills/widgets/subscription_actions.dart';
import 'bills/widgets/subscription_card.dart' show billCategoryIcon;
import 'notes/note_edit_screen.dart';
import 'notes/widgets/note_card.dart' show noteTintColor;
import 'shopping/shopping_list_detail_screen.dart';
import 'shopping/widgets/shopping_list_actions.dart';
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
  List<Note> _pinnedNotes = [];
  _Finance _finance = const _Finance();
  bool _isLoading = true;

  int get _todayReminderCount =>
      _reminders.where((entry) => entry.isToday).length;
  int get _overdueBillCount =>
      _bills.where((bill) => billStatusOf(bill) == BillStatus.overdue).length;
  int get _remainingShoppingCount => _shoppingLists.fold(
    0,
    (total, entry) => total + entry.summary.remainingCount,
  );

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
    if (mounted && _reminders.isEmpty && _bills.isEmpty) {
      setState(() => _isLoading = true);
    }
    unawaited(_adBannerKey.currentState?.refresh());

    // DatabaseHelper lazily opens one SQLite connection. Keep the first reads
    // sequential so multiple repositories cannot race while opening it.
    final notes = await _noteRepository.getAll();
    final reminders = await _reminderRepository.getAll();
    final subscriptions = await _subscriptionRepository.getAll();
    final payments = await _subscriptionRepository.getAllPayments();
    final shoppingLists = await _shoppingRepository.getAll();

    final activeNotes = notes.where((note) => !note.isDeleted).toList();
    final noteById = {for (final note in activeNotes) note.id: note};
    final now = DateTime.now();
    final today = _dateOnly(now);
    final tomorrow = today.add(const Duration(days: 1));
    final reminderEntries = <_ReminderEntry>[];
    for (final reminder in reminders.where((item) => item.isActive)) {
      // یادآور یادداشتی که به «حذف‌شده‌ها» رفته نمایش داده نمی‌شود.
      if (reminder.noteId != null && !noteById.containsKey(reminder.noteId)) {
        continue;
      }
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

    final endOfWindow = today.add(const Duration(days: dueSoonDays + 1));
    final nearbyBills =
        subscriptions
            .where(
              (bill) =>
                  !bill.isPaid && _dateOnly(bill.dueDate).isBefore(endOfWindow),
            )
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    // خلاصه مالی ماه شمسی جاری.
    final jalaliNow = Jalali.fromDateTime(now);
    final nextMonthStart =
        (jalaliNow.month == 12
                ? Jalali(jalaliNow.year + 1, 1, 1)
                : Jalali(jalaliNow.year, jalaliNow.month + 1, 1))
            .toDateTime();
    final paidThisMonth = payments
        .where((payment) {
          final paid = Jalali.fromDateTime(payment.paidDate);
          return paid.year == jalaliNow.year && paid.month == jalaliNow.month;
        })
        .fold<double>(0, (sum, payment) => sum + payment.amount);
    final dueThisMonth = subscriptions
        .where((bill) => !bill.isPaid && bill.dueDate.isBefore(nextMonthStart))
        .fold<double>(0, (sum, bill) => sum + bill.amount);

    final shoppingEntries = <_ShoppingEntry>[];
    var shoppingCost = 0.0;
    for (final list in shoppingLists) {
      final items = await _shoppingRepository.getItemsByListId(list.id!);
      final summary = ShoppingListSummary.fromItems(items);
      shoppingCost += summary.estimatedTotal - summary.spentTotal;
      if (summary.remainingCount > 0) {
        shoppingEntries.add(_ShoppingEntry(list: list, summary: summary));
      }
    }

    final pinned =
        activeNotes.where((note) => note.isPinned && !note.isArchived).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (!mounted) return;
    setState(() {
      _reminders = reminderEntries;
      _bills = nearbyBills;
      _shoppingLists = shoppingEntries;
      _pinnedNotes = pinned;
      _finance = _Finance(
        paidThisMonth: paidThisMonth,
        dueThisMonth: dueThisMonth,
        shoppingCost: shoppingCost,
      );
      _isLoading = false;
    });
  }

  bool _occursOn(Reminder reminder, DateTime target) {
    final start = _dateOnly(reminder.dateTime);
    if (target.isBefore(start)) return false;
    final days = DateTime.utc(
      target.year,
      target.month,
      target.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    return switch (reminder.repeatType) {
      ReminderRepeatType.none => days == 0,
      ReminderRepeatType.daily => true,
      ReminderRepeatType.weekly => days % 7 == 0,
      ReminderRepeatType.monthly => target.day == start.day,
    };
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// باز کردن یک صفحه و به‌روزرسانی داشبورد پس از بازگشت.
  Future<void> _push(Widget screen) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => screen));
    await refresh();
  }

  Future<void> _newShoppingList() async {
    final result = await showListFormDialog(context, title: 'لیست خرید جدید');
    if (result == null || !mounted) return;
    final provider = context.read<ShoppingProvider>();
    final id = await provider.addList(
      result.name,
      colorValue: result.colorValue,
    );
    final created = provider.listById(id);
    if (created != null && mounted) {
      await _push(ShoppingListDetailScreen(shoppingList: created));
    }
  }

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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _GreetingHeader(
                    reminderCount: _todayReminderCount,
                    overdueCount: _overdueBillCount,
                  ),
                  const SizedBox(height: 16),
                  AdBannerWidget(key: _adBannerKey),
                  _SummaryCard(
                    reminderCount: _todayReminderCount,
                    overdueCount: _overdueBillCount,
                    shoppingCount: _remainingShoppingCount,
                    onReminderTap: () => widget.onNavigateToTab(1),
                    onBillsTap: () => widget.onNavigateToTab(2),
                    onShoppingTap: () => widget.onNavigateToTab(3),
                  ),
                  const SizedBox(height: 16),
                  _QuickActions(
                    actions: [
                      _QuickAction(
                        icon: Icons.note_add_outlined,
                        label: 'یادداشت',
                        onTap: () => _push(const NoteEditScreen()),
                      ),
                      _QuickAction(
                        icon: Icons.alarm_add_outlined,
                        label: 'یادآور',
                        onTap: () => _push(
                          const NoteEditScreen(startWithReminder: true),
                        ),
                      ),
                      _QuickAction(
                        icon: Icons.post_add_outlined,
                        label: 'قبض',
                        onTap: () => _push(const SubscriptionEditScreen()),
                      ),
                      _QuickAction(
                        icon: Icons.add_shopping_cart_outlined,
                        label: 'لیست خرید',
                        onTap: _newShoppingList,
                      ),
                    ],
                  ),
                  if (_finance.hasData) ...[
                    const SizedBox(height: 16),
                    _FinanceCard(finance: _finance),
                  ],
                  if (_pinnedNotes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionHeader(
                      title: 'یادداشت‌های سنجاق‌شده',
                      onViewAll: () => widget.onNavigateToTab(1),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 128,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _pinnedNotes.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final note = _pinnedNotes[index];
                          return _PinnedNoteCard(
                            note: note,
                            onTap: () => _push(NoteEditScreen(note: note)),
                          );
                        },
                      ),
                    ),
                  ],
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
                      children: _reminders.take(5).map((entry) {
                        final note = entry.note;
                        final isFuture = entry.occurrence.isAfter(
                          DateTime.now(),
                        );
                        return ListTile(
                          leading: _SectionIcon(
                            icon: entry.isToday
                                ? Icons.notifications_active_outlined
                                : Icons.notifications_none_outlined,
                          ),
                          title: Text(
                            note?.title ?? entry.reminder.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${entry.isToday ? 'امروز' : 'فردا'}، '
                            '${TimeOfDay.fromDateTime(entry.occurrence).format(context)}'
                            '${entry.isToday && isFuture ? ' • ${relativeFutureLabel(entry.occurrence)}' : ''}',
                          ),
                          trailing: note == null
                              ? null
                              : const Icon(Icons.chevron_left),
                          onTap: note == null
                              ? null
                              : () => _push(NoteEditScreen(note: note)),
                        );
                      }).toList(),
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
                      children: _bills.take(5).map((bill) {
                        final status = billStatusOf(bill);
                        final color = billStatusColor(context, status);
                        return ListTile(
                          contentPadding: const EdgeInsetsDirectional.only(
                            start: 16,
                            end: 8,
                          ),
                          leading: _SectionIcon(
                            icon: billCategoryIcon(bill.category),
                            color: color,
                          ),
                          title: Text(
                            bill.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${formatTooman(bill.amount)} • ${dueCountdownLabel(bill) ?? ''}',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => payBillWithUndo(
                              context,
                              bill,
                              onChanged: refresh,
                            ),
                            child: const Text('پرداخت'),
                          ),
                          onTap: () =>
                              _push(SubscriptionEditScreen(subscription: bill)),
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
                        final accent = entry.list.colorValue != null
                            ? Color(entry.list.colorValue!)
                            : Theme.of(context).colorScheme.primary;
                        return ListTile(
                          leading: _SectionIcon(
                            icon: Icons.shopping_cart_outlined,
                            color: accent,
                          ),
                          title: Text(
                            entry.list.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${formatNumber(entry.summary.remainingCount)} آیتم باقی‌مانده'
                                '${entry.summary.hasPrices ? ' • ${formatTooman(entry.summary.estimatedTotal - entry.summary.spentTotal)}' : ''}',
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: entry.summary.progress,
                                  minHeight: 5,
                                  color: accent,
                                  backgroundColor: accent.withValues(
                                    alpha: 0.15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_left),
                          onTap: () => _push(
                            ShoppingListDetailScreen(shoppingList: entry.list),
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
    physics: const AlwaysScrollableScrollPhysics(),
    children: const [
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
    required this.onReminderTap,
    required this.onBillsTap,
    required this.onShoppingTap,
  });

  final int reminderCount;
  final int overdueCount;
  final int shoppingCount;
  final VoidCallback onReminderTap;
  final VoidCallback onBillsTap;
  final VoidCallback onShoppingTap;

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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            _SummaryItem(
              value: reminderCount,
              label: 'یادآور امروز',
              icon: Icons.notifications_active_outlined,
              highlighted: reminderCount > 0,
              onTap: onReminderTap,
            ),
            _SummaryItem(
              value: overdueCount,
              label: 'قبض معوق',
              icon: Icons.report_gmailerrorred_outlined,
              highlighted: overdueCount > 0,
              highlightColor: context.statusColors.error,
              onTap: onBillsTap,
            ),
            _SummaryItem(
              value: shoppingCount,
              label: 'خرید باقی‌مانده',
              icon: Icons.shopping_cart_outlined,
              highlighted: shoppingCount > 0,
              onTap: onShoppingTap,
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
    required this.onTap,
    this.highlighted = false,
    this.highlightColor,
  });

  final int value;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = highlighted
        ? (highlightColor ?? scheme.onPrimary)
        : scheme.onPrimaryContainer;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(height: 6),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value.toDouble()),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, animated, _) => Text(
                  formatNumber(animated.round()),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
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
        ),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// میان‌برهای ساخت سریع: یادداشت، یادآور، قبض و لیست خرید.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions});

  final List<_QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: actions[i].onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          actions[i].icon,
                          size: 20,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          actions[i].label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Finance {
  const _Finance({
    this.paidThisMonth = 0,
    this.dueThisMonth = 0,
    this.shoppingCost = 0,
  });

  final double paidThisMonth;
  final double dueThisMonth;
  final double shoppingCost;

  bool get hasData => paidThisMonth > 0 || dueThisMonth > 0 || shoppingCost > 0;
}

/// وضعیت مالی ماه شمسی جاری: پرداخت‌شده در برابر مانده قبض‌ها و هزینه خرید.
class _FinanceCard extends StatelessWidget {
  const _FinanceCard({required this.finance});

  final _Finance finance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = finance.paidThisMonth + finance.dueThisMonth;
    final progress = total == 0 ? 0.0 : finance.paidThisMonth / total;
    final monthName = Jalali.fromDateTime(DateTime.now()).formatter.mN;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'وضعیت مالی $monthName',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (total > 0) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 10,
                    color: context.statusColors.success,
                    backgroundColor: context.statusColors.warning.withValues(
                      alpha: 0.25,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _FinanceStat(
                    color: context.statusColors.success,
                    label: 'قبض‌های پرداخت‌شده',
                    value: finance.paidThisMonth,
                  ),
                  _FinanceStat(
                    color: context.statusColors.warning,
                    label: 'مانده تا پایان ماه',
                    value: finance.dueThisMonth,
                  ),
                ],
              ),
            ],
            if (finance.shoppingCost > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'هزینه تقریبی خریدهای باقی‌مانده: ${formatTooman(finance.shoppingCost)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FinanceStat extends StatelessWidget {
  const _FinanceStat({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    formatTooman(value),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedNoteCard extends StatelessWidget {
  const _PinnedNoteCard({required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = note.colorValue != null
        ? Color(note.colorValue!)
        : theme.colorScheme.primary;
    return SizedBox(
      width: 180,
      child: Card(
        margin: EdgeInsets.zero,
        color: noteTintColor(context, note),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.push_pin, size: 16, color: accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        note.title.isEmpty ? '(بدون عنوان)' : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    note.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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

/// سرآمد خوش‌آمدگویی داشبورد: تاریخ امروز به شمسی و یک جمع‌بندی کوتاه از روز.
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.reminderCount,
    required this.overdueCount,
  });

  final int reminderCount;
  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'صبح بخیر'
        : hour < 18
        ? 'ظهر بخیر'
        : 'عصر بخیر';
    final parts = [
      if (reminderCount > 0) '${formatNumber(reminderCount)} یادآور',
      if (overdueCount > 0) '${formatNumber(overdueCount)} قبض عقب‌افتاده',
    ];
    final digest = parts.isEmpty
        ? 'برای امروز کار عقب‌افتاده‌ای ندارید ✨'
        : 'امروز ${parts.join(' و ')} دارید';

    return Column(
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
        const SizedBox(height: 4),
        Text(
          digest,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
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
  const _ShoppingEntry({required this.list, required this.summary});

  final ShoppingList list;
  final ShoppingListSummary summary;
}
