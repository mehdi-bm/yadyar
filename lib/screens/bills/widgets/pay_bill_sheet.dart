import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

import '../../../models/subscription.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/date_formatter.dart';

/// مبلغ و تاریخ یک پرداخت (از برگه «ثبت پرداخت»).
class PaymentInput {
  const PaymentInput({required this.amount, required this.paidDate});

  final double amount;
  final DateTime paidDate;
}

/// برگه ثبت پرداخت با مبلغ/تاریخ دلخواه؛ برای قبض‌های متغیر (برق، گاز...) یا
/// ثبت پرداختی که روز دیگری انجام شده.
Future<PaymentInput?> showPayBillSheet(
  BuildContext context,
  Subscription subscription,
) {
  return showModalBottomSheet<PaymentInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _PayBillSheet(subscription: subscription),
  );
}

class _PayBillSheet extends StatefulWidget {
  const _PayBillSheet({required this.subscription});

  final Subscription subscription;

  @override
  State<_PayBillSheet> createState() => _PayBillSheetState();
}

class _PayBillSheetState extends State<_PayBillSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(
    text: formatAmountInput(widget.subscription.amount),
  );
  DateTime _paidDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: Jalali.fromDateTime(_paidDate),
      firstDate: Jalali.fromDateTime(
        DateTime.now().subtract(const Duration(days: 365 * 2)),
      ),
      lastDate: Jalali.fromDateTime(DateTime.now()),
    );
    if (picked == null || !mounted) return;
    final date = picked.toDateTime();
    final now = DateTime.now();
    setState(
      () => _paidDate = DateTime(
        date.year,
        date.month,
        date.day,
        now.hour,
        now.minute,
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      PaymentInput(
        amount: parseFormattedAmount(_amountController.text)!.toDouble(),
        paidDate: _paidDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isToday =
        formatJalaliDate(_paidDate) == formatJalaliDate(DateTime.now());

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ثبت پرداخت',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.subscription.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'مبلغ پرداختی',
                suffixText: 'تومان',
                prefixIcon: Icon(Icons.payments_outlined),
                helperText:
                    'برای قبض‌های متغیر، مبلغ واقعی این دوره را وارد کنید',
              ),
              validator: (value) {
                final parsed = parseFormattedAmount(value ?? '');
                return parsed == null || parsed <= 0
                    ? 'مبلغ معتبر وارد کنید'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              leading: const Icon(Icons.event_available_outlined),
              title: const Text('تاریخ پرداخت'),
              subtitle: Text(
                isToday
                    ? 'امروز — ${formatJalaliDate(_paidDate)}'
                    : formatJalaliDate(_paidDate),
              ),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: const Text('ثبت پرداخت'),
            ),
          ],
        ),
      ),
    );
  }
}
