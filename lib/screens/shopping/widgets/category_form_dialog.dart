import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/shopping_category.dart';
import '../../../providers/shopping_provider.dart';
import 'shopping_visuals.dart';

/// دیالوگ ساخت یا ویرایش دسته خرید. ذخیره در پایگاه‌داده هم همین‌جا انجام
/// می‌شود و دسته ذخیره‌شده برگردانده می‌شود (یا null اگر لغو شود).
Future<ShoppingCategory?> showCategoryFormDialog(
  BuildContext context, {
  ShoppingCategory? category,
}) {
  final provider = context.read<ShoppingProvider>();
  return showDialog<ShoppingCategory>(
    context: context,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: _CategoryFormDialog(category: category),
    ),
  );
}

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({this.category});

  final ShoppingCategory? category;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final _nameController = TextEditingController(
    text: widget.category?.name ?? '',
  );
  final _formKey = GlobalKey<FormState>();
  late String _iconKey =
      widget.category?.iconKey ?? ShoppingCategory.defaultIconKey;
  late int _colorValue = widget.category?.colorValue ?? shoppingPalette.first;
  bool _isSaving = false;

  bool get _isEditing => widget.category != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final provider = context.read<ShoppingProvider>();
    final name = _nameController.text.trim();
    final ShoppingCategory saved;
    if (_isEditing) {
      saved = widget.category!.copyWith(
        name: name,
        iconKey: _iconKey,
        colorValue: _colorValue,
      );
      await provider.updateCategory(saved);
    } else {
      saved = await provider.addCategory(
        ShoppingCategory(
          name: name,
          iconKey: _iconKey,
          colorValue: _colorValue,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ShoppingProvider>();
    final theme = Theme.of(context);
    final isFallback = widget.category?.isFallback ?? false;
    final preview = ShoppingCategory(
      name: '',
      iconKey: _iconKey,
      colorValue: _colorValue,
    );

    return AlertDialog(
      title: Row(
        children: [
          CategoryAvatar(category: preview, size: 34),
          const SizedBox(width: 12),
          Expanded(child: Text(_isEditing ? 'ویرایش دسته' : 'دسته جدید')),
        ],
      ),
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
                controller: _nameController,
                autofocus: !_isEditing,
                // نام دسته «سایر» ثابت است، چون مقصد اقلام دسته‌های حذف‌شده است.
                enabled: !isFallback,
                decoration: InputDecoration(
                  labelText: 'نام دسته',
                  helperText: isFallback
                      ? 'نام این دسته قابل تغییر نیست'
                      : null,
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'نام نمی‌تواند خالی باشد';
                  if (provider.isCategoryNameTaken(
                    name,
                    exceptId: widget.category?.id,
                  )) {
                    return 'این دسته از قبل وجود دارد';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('آیکون', style: theme.textTheme.labelLarge),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in shoppingCategoryIcons.entries)
                    _IconOption(
                      icon: entry.value,
                      color: Color(_colorValue),
                      isSelected: entry.key == _iconKey,
                      onTap: () => setState(() => _iconKey = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('رنگ', style: theme.textTheme.labelLarge),
              const SizedBox(height: 10),
              PaletteColorPicker(
                selected: _colorValue,
                onChanged: (value) => setState(() => _colorValue = value!),
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
        TextButton(
          onPressed: _isSaving ? null : _submit,
          child: const Text('ذخیره'),
        ),
      ],
    );
  }
}

class _IconOption extends StatelessWidget {
  const _IconOption({
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.2)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: isSelected ? color : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
