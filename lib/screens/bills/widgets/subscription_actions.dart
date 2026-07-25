import 'package:flutter/material.dart';

import '../../../widgets/confirm_dialog.dart';

Future<bool> showDeleteSubscriptionConfirmation(BuildContext context) {
  return showConfirmDialog(
    context,
    title: 'حذف اشتراک/قبض',
    message:
        'این مورد و تاریخچه پرداخت‌های آن برای همیشه حذف خواهد شد. آیا مطمئن هستید؟',
  );
}
