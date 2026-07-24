import 'package:flutter/material.dart';

Future<bool> showDeleteSubscriptionConfirmation(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('حذف اشتراک/قبض'),
      content: const Text(
        'این مورد و تاریخچه پرداخت‌های آن برای همیشه حذف خواهد شد. آیا مطمئن هستید؟',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('انصراف'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            'حذف',
            style: TextStyle(color: Theme.of(ctx).colorScheme.error),
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
