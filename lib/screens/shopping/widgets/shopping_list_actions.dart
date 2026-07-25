import 'package:flutter/material.dart';

import '../../../widgets/confirm_dialog.dart';

Future<bool> showDeleteShoppingListConfirmation(BuildContext context) {
  return showConfirmDialog(
    context,
    title: 'حذف لیست خرید',
    message: 'این لیست و همه آیتم‌های آن برای همیشه حذف خواهد شد. آیا مطمئن هستید؟',
  );
}

/// دیالوگ ساده برای گرفتن نام لیست خرید (هم برای افزودن و هم ویرایش نام).
Future<String?> showListNameDialog(
  BuildContext context, {
  required String title,
  String initialName = '',
}) async {
  final controller = TextEditingController(text: initialName);
  final formKey = GlobalKey<FormState>();

  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'نام لیست'),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'نام نمی‌تواند خالی باشد'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('انصراف'),
        ),
        TextButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(ctx).pop(controller.text.trim());
            }
          },
          child: const Text('ذخیره'),
        ),
      ],
    ),
  );
  controller.dispose();
  return name;
}
