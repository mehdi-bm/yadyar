import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../models/subscription.dart';
import '../../providers/bills_provider.dart';
import '../../utils/date_formatter.dart';
import 'widgets/subscription_actions.dart';

const Map<SubscriptionRepeatType, String> subscriptionRepeatTypeLabels = {
  SubscriptionRepeatType.monthly: 'ماهانه',
  SubscriptionRepeatType.yearly: 'سالانه',
  SubscriptionRepeatType.once: 'یک‌بار',
};

const String _otherCategory = 'سایر';

class SubscriptionEditScreen extends StatefulWidget {
  const SubscriptionEditScreen({super.key, this.subscription});

  /// اگر null باشد، فرم در حالت «افزودن اشتراک/قبض جدید» است.
  final Subscription? subscription;

  @override
  State<SubscriptionEditScreen> createState() => _SubscriptionEditScreenState();
}

class _SubscriptionEditScreenState extends State<SubscriptionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _customCategoryController;
  late final TextEditingController _reminderDaysController;

  late String _selectedCategory;
  late DateTime _dueDate;
  late SubscriptionRepeatType _repeatType;

  bool get _isEditing => widget.subscription != null;

  @override
  void initState() {
    super.initState();
    final subscription = widget.subscription;

    _titleController = TextEditingController(text: subscription?.title ?? '');
    _amountController = TextEditingController(
      text: subscription != null ? subscription.amount.toStringAsFixed(0) : '',
    );
    _reminderDaysController = TextEditingController(
      text: (subscription?.reminderDaysBefore ?? 3).toString(),
    );
    _dueDate =
        subscription?.dueDate ?? DateTime.now().add(const Duration(days: 30));
    _repeatType = subscription?.repeatType ?? SubscriptionRepeatType.monthly;

    final currentCategory = subscription?.category;
    _selectedCategory =
        (currentCategory != null &&
            AppConstants.subscriptionCategories.contains(currentCategory))
        ? currentCategory
        : (currentCategory == null || currentCategory.isEmpty
              ? AppConstants.subscriptionCategories.first
              : _otherCategory);
    _customCategoryController = TextEditingController(
      text: _selectedCategory == _otherCategory ? (currentCategory ?? '') : '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _customCategoryController.dispose();
    _reminderDaysController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: Jalali.fromDateTime(_dueDate),
      firstDate: Jalali.fromDateTime(
        DateTime.now().subtract(const Duration(days: 365)),
      ),
      lastDate: Jalali.fromDateTime(
        DateTime.now().add(const Duration(days: 365 * 5)),
      ),
    );
    if (picked == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate),
    );
    if (time == null) return;

    final date = picked.toDateTime();
    setState(() {
      _dueDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final category = _selectedCategory == _otherCategory
        ? _customCategoryController.text.trim()
        : _selectedCategory;
    final provider = context.read<BillsProvider>();
    final subscription = Subscription(
      id: widget.subscription?.id,
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      dueDate: _dueDate,
      repeatType: _repeatType,
      category: category,
      reminderDaysBefore: int.parse(_reminderDaysController.text.trim()),
      isPaid: widget.subscription?.isPaid ?? false,
      lastPaidDate: widget.subscription?.lastPaidDate,
    );

    if (_isEditing) {
      await provider.updateSubscription(subscription);
    } else {
      await provider.addSubscription(subscription);
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDeleteSubscriptionConfirmation(context);
    if (!confirmed || !mounted) return;
    await context.read<BillsProvider>().deleteSubscription(
      widget.subscription!.id!,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'ویرایش اشتراک/قبض' : 'اشتراک/قبض جدید'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              tooltip: 'حذف',
              onPressed: _delete,
            ),
          IconButton.filled(
            icon: const Icon(Icons.check),
            tooltip: 'ذخیره',
            onPressed: _save,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'عنوان',
                        prefixIcon: Icon(Icons.receipt_long_outlined),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'عنوان نمی‌تواند خالی باشد'
                          : null,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'مبلغ (تومان)',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final parsed = double.tryParse((value ?? '').trim());
                        if (parsed == null || parsed <= 0) {
                          return 'مبلغ معتبر وارد کنید';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'دسته‌بندی',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: AppConstants.subscriptionCategories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedCategory = value!),
                    ),
                    if (_selectedCategory == _otherCategory) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _customCategoryController,
                        decoration: const InputDecoration(
                          labelText: 'عنوان دسته‌بندی',
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                        validator: (value) =>
                            _selectedCategory == _otherCategory &&
                                (value == null || value.trim().isEmpty)
                            ? 'عنوان دسته‌بندی را وارد کنید'
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      leading: const Icon(Icons.event_outlined),
                      title: const Text('تاریخ سررسید'),
                      subtitle: Text(formatJalaliDateTime(_dueDate)),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: _pickDueDate,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'نوع تکرار',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: SubscriptionRepeatType.values.map((type) {
                        return ChoiceChip(
                          label: Text(subscriptionRepeatTypeLabels[type]!),
                          selected: _repeatType == type,
                          onSelected: (_) => setState(() => _repeatType = type),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _reminderDaysController,
                      decoration: const InputDecoration(
                        labelText: 'یادآوری چند روز قبل از سررسید',
                        prefixIcon: Icon(Icons.notifications_active_outlined),
                        suffixText: 'روز',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final parsed = int.tryParse((value ?? '').trim());
                        if (parsed == null || parsed < 0) {
                          return 'عدد معتبر وارد کنید';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
