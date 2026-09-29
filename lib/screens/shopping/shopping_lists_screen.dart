import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/shopping_list.dart';
import '../../providers/shopping_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../widgets/empty_state.dart';
import 'shopping_categories_screen.dart';
import 'shopping_list_detail_screen.dart';
import 'shopping_trash_screen.dart';
import 'widgets/shopping_list_actions.dart';
import 'widgets/shopping_list_card.dart';

class ShoppingListsScreen extends StatefulWidget {
  const ShoppingListsScreen({super.key});

  @override
  State<ShoppingListsScreen> createState() => _ShoppingListsScreenState();
}

class _ShoppingListsScreenState extends State<ShoppingListsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ShoppingProvider>().loadLists();
    });
  }

  Future<void> _addList(BuildContext context) async {
    final result = await showListFormDialog(context, title: 'لیست خرید جدید');
    if (result == null || !context.mounted) return;
    final provider = context.read<ShoppingProvider>();
    final id = await provider.addList(
      result.name,
      colorValue: result.colorValue,
    );
    final created = provider.listById(id);
    if (created != null && context.mounted) _openDetail(context, created);
  }

  void _openDetail(BuildContext context, ShoppingList list) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ShoppingListDetailScreen(shoppingList: list),
      ),
    );
  }

  void _openCategories(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const ShoppingCategoriesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShoppingProvider>();
    final lists = provider.lists;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'دسته‌بندی‌ها',
            onPressed: () => _openCategories(context),
          ),
          IconButton(
            icon: Badge.count(
              count: provider.trashCount,
              isLabelVisible: provider.trashCount > 0,
              child: const Icon(Icons.restore_from_trash_outlined),
            ),
            tooltip: 'حذف‌شده‌ها',
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const ShoppingTrashScreen()),
            ),
          ),
          const ThemeModeButton(),
        ],
      ),
      body: provider.isLoadingLists && lists.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : lists.isEmpty
          ? EmptyStateView(
              icon: Icons.shopping_cart_outlined,
              message:
                  'هنوز لیست خریدی ثبت نشده است.\nبرای شروع، دکمه + را بزنید.',
              actionLabel: 'ساخت اولین لیست خرید',
              onAction: () => _addList(context),
            )
          : RefreshIndicator(
              onRefresh: provider.loadLists,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 88),
                itemCount: lists.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _OverviewCard(
                      listCount: lists.length,
                      summary: provider.overallSummary,
                    );
                  }
                  final list = lists[index - 1];
                  return ShoppingListCard(
                    shoppingList: list,
                    summary: provider.summaryFor(list.id!),
                    onTap: () => _openDetail(context, list),
                    onAction: (action) =>
                        runShoppingListAction(context, list, action),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addList(context),
        tooltip: 'لیست جدید',
        icon: const Icon(Icons.add),
        label: const Text('لیست جدید'),
      ),
    );
  }
}

/// خلاصه کلی همه لیست‌ها: تعداد لیست، اقلام باقی‌مانده و هزینه تقریبی باقی‌مانده.
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.listCount, required this.summary});

  final int listCount;
  final ShoppingListSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final remainingCost = summary.estimatedTotal - summary.spentTotal;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            scheme.primaryContainer,
            scheme.primary.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Row(
        children: [
          _OverviewStat(
            icon: Icons.list_alt_outlined,
            value: formatNumber(listCount),
            label: 'لیست خرید',
          ),
          _OverviewStat(
            icon: Icons.pending_actions_outlined,
            value: formatNumber(summary.remainingCount),
            label: 'مورد باقی‌مانده',
          ),
          _OverviewStat(
            icon: Icons.payments_outlined,
            value: remainingCost > 0 ? formatNumber(remainingCost) : '—',
            label: 'هزینه باقی‌مانده (تومان)',
          ),
        ],
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
