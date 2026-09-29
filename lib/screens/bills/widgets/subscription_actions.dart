import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/subscription.dart';
import '../../../providers/bills_provider.dart';
import '../../../widgets/confirm_dialog.dart';
import '../payment_history_screen.dart';
import '../subscription_edit_screen.dart';
import 'pay_bill_sheet.dart';

Future<bool> showDeleteSubscriptionConfirmation(BuildContext context) {
  return showConfirmDialog(
    context,
    title: 'حذف اشتراک/قبض',
    message:
        'این مورد و تاریخچه پرداخت‌های آن برای همیشه حذف خواهد شد. آیا مطمئن هستید؟',
  );
}

enum BillAction { pay, payCustom, edit, history, copyIdentifier, delete }

/// ثبت پرداخت و نمایش پیام همراه با «بازگردانی». اگر [custom] باشد، ابتدا
/// برگه مبلغ/تاریخ باز می‌شود.
Future<void> payBillWithUndo(
  BuildContext context,
  Subscription subscription, {
  bool custom = false,
  VoidCallback? onChanged,
}) async {
  final provider = context.read<BillsProvider>();
  final messenger = ScaffoldMessenger.of(context);
  PaymentInput? input;
  if (custom) {
    input = await showPayBillSheet(context, subscription);
    if (input == null) return;
  }
  final undo = await provider.markAsPaid(
    subscription,
    amount: input?.amount,
    paidDate: input?.paidDate,
  );
  onChanged?.call();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('پرداخت «${subscription.title}» ثبت شد'),
        // اسنک‌بار دارای action به‌طور پیش‌فرض خودکار بسته نمی‌شود (persist).
        persist: false,
        duration: const Duration(seconds: 4),
        showCloseIcon: true,
        action: SnackBarAction(
          label: 'بازگردانی',
          onPressed: () async {
            await provider.undoPayment(undo);
            onChanged?.call();
          },
        ),
      ),
    );
}

Future<void> openSubscriptionEditor(
  BuildContext context, {
  Subscription? subscription,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => SubscriptionEditScreen(subscription: subscription),
    ),
  );
}

/// اجرای یک عمل روی قبض (مشترک بین لیست قبض‌ها و داشبورد).
Future<void> runBillAction(
  BuildContext context,
  Subscription subscription,
  BillAction action,
) async {
  switch (action) {
    case BillAction.pay:
      await payBillWithUndo(context, subscription);
    case BillAction.payCustom:
      await payBillWithUndo(context, subscription, custom: true);
    case BillAction.edit:
      await openSubscriptionEditor(context, subscription: subscription);
    case BillAction.history:
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => PaymentHistoryScreen(subscription: subscription),
        ),
      );
    case BillAction.copyIdentifier:
      final identifier = subscription.billIdentifier;
      if (identifier == null || identifier.isEmpty) return;
      final messenger = ScaffoldMessenger.of(context);
      await Clipboard.setData(ClipboardData(text: identifier));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('شناسه قبض کپی شد'),
            showCloseIcon: true,
          ),
        );
    case BillAction.delete:
      final provider = context.read<BillsProvider>();
      final confirmed = await showDeleteSubscriptionConfirmation(context);
      if (confirmed) await provider.deleteSubscription(subscription.id!);
  }
}
