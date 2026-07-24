import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constants/app_constants.dart';
import '../../../providers/shopping_provider.dart';

const String _otherCategory = 'سایر';

Future<void> showAddItemSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _AddItemSheet(),
  );
}

class _AddItemSheet extends StatefulWidget {
  const _AddItemSheet();

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _customCategoryController = TextEditingController();
  String _selectedCategory = AppConstants.shoppingItemCategories.first;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final category = _selectedCategory == _otherCategory
        ? _customCategoryController.text.trim()
        : _selectedCategory;

    await context.read<ShoppingProvider>().addItem(
      name: _nameController.text.trim(),
      category: category,
      quantity: _quantityController.text.trim().isEmpty
          ? null
          : _quantityController.text.trim(),
    );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('افزودن آیتم', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'نام آیتم',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'نام نمی‌تواند خالی باشد'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'دسته‌بندی',
                border: OutlineInputBorder(),
              ),
              items: AppConstants.shoppingItemCategories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedCategory = value!),
            ),
            if (_selectedCategory == _otherCategory) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customCategoryController,
                decoration: const InputDecoration(
                  labelText: 'عنوان دسته‌بندی',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    _selectedCategory == _otherCategory &&
                        (value == null || value.trim().isEmpty)
                    ? 'عنوان دسته‌بندی را وارد کنید'
                    : null,
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: 'تعداد (اختیاری)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('افزودن'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
