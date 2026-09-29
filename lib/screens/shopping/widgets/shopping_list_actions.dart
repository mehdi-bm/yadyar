import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/shopping_list.dart';
import '../../../providers/shopping_provider.dart';
import '../../../widgets/confirm_dialog.dart';
import 'shopping_list_card.dart';
import 'shopping_visuals.dart';

/// اجرای یک عمل روی لیست خرید (مشترک بین صفحه لیست‌ها و صفحه جزئیات).
///
/// برای حذف، true برمی‌گرداند اگر لیست واقعاً حذف شد (تا صفحه جزئیات بسته شود).
Future<bool> runShoppingListAction(
  BuildContext context,
  ShoppingList list,
  ShoppingListAction action,
) async {
  final provider = context.read<ShoppingProvider>();
  final messenger = ScaffoldMessenger.of(context);
  switch (action) {
    case ShoppingListAction.edit:
      final result = await showListFormDialog(
        context,
        title: 'ویرایش لیست',
        initialName: list.name,
        initialColorValue: list.colorValue,
      );
      if (result != null) {
        // copyWith نمی‌تواند رنگ را به null (پیش‌فرض) برگرداند؛ لیست از نو ساخته می‌شود.
        await provider.updateList(
          ShoppingList(
            id: list.id,
            name: result.name,
            createdAt: list.createdAt,
            colorValue: result.colorValue,
          ),
        );
      }
      return false;
    case ShoppingListAction.duplicate:
      await provider.duplicateList(list);
      messenger.showSnackBar(
        SnackBar(content: Text('کپی «${list.name}» ساخته شد')),
      );
      return false;
    case ShoppingListAction.share:
      final text = await provider.buildShareText(list);
      await Share.share(text, subject: list.name);
      return false;
    case ShoppingListAction.delete:
      final confirmed = await showDeleteShoppingListConfirmation(context);
      if (!confirmed) return false;
      await provider.deleteList(list.id!);
      messenger.showSnackBar(
        SnackBar(content: Text('لیست «${list.name}» حذف شد')),
      );
      return true;
  }
}

Future<bool> showDeleteShoppingListConfirmation(BuildContext context) {
  return showConfirmDialog(
    context,
    title: 'حذف لیست خرید',
    message:
        'این لیست و همه آیتم‌های آن برای همیشه حذف خواهد شد. آیا مطمئن هستید؟',
  );
}

/// نتیجه فرم لیست خرید.
class ListFormResult {
  const ListFormResult({required this.name, this.colorValue});

  final String name;

  /// null یعنی رنگ پیش‌فرض تم.
  final int? colorValue;
}

/// دیالوگ ساخت/ویرایش لیست خرید (نام و رنگ).
Future<ListFormResult?> showListFormDialog(
  BuildContext context, {
  required String title,
  String initialName = '',
  int? initialColorValue,
}) {
  return showDialog<ListFormResult>(
    context: context,
    builder: (_) => _ListFormDialog(
      title: title,
      initialName: initialName,
      initialColorValue: initialColorValue,
    ),
  );
}

// کنترلر متن باید مال State خود دیالوگ باشد، نه تابع showListFormDialog:
// بعد از pop، دیالوگ هنوز در حال انیمیشن خروج (و بسته شدن کیبورد) است و
// TextField دوباره build می‌شود؛ dispose زودهنگام کنترلر باعث خطای
// `_dependents.isEmpty` می‌شد.
class _ListFormDialog extends StatefulWidget {
  const _ListFormDialog({
    required this.title,
    required this.initialName,
    required this.initialColorValue,
  });

  final String title;
  final String initialName;
  final int? initialColorValue;

  @override
  State<_ListFormDialog> createState() => _ListFormDialogState();
}

class _ListFormDialogState extends State<_ListFormDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  final _formKey = GlobalKey<FormState>();
  late int? _colorValue = widget.initialColorValue;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      ListFormResult(name: _controller.text.trim(), colorValue: _colorValue),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        // فاصله بالا تا برچسب شناور فیلد نام بریده نشود.
        padding: const EdgeInsets.only(top: 8),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: 'نام لیست'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'نام نمی‌تواند خالی باشد'
                    : null,
              ),
              const SizedBox(height: 16),
              Text('رنگ لیست', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              PaletteColorPicker(
                selected: _colorValue,
                allowNone: true,
                onChanged: (value) => setState(() => _colorValue = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('انصراف'),
        ),
        TextButton(onPressed: _submit, child: const Text('ذخیره')),
      ],
    );
  }
}
