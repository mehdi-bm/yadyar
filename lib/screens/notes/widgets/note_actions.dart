import 'package:flutter/material.dart';

import '../../../widgets/confirm_dialog.dart';

Future<bool> showDeleteNoteConfirmation(BuildContext context) {
  return showConfirmDialog(
    context,
    title: 'حذف یادداشت',
    message:
        'این یادداشت و یادآور مرتبط با آن (در صورت وجود) برای همیشه حذف خواهد شد. آیا مطمئن هستید؟',
  );
}
