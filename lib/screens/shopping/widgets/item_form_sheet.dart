import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constants/app_constants.dart';
import '../../../models/shopping_item.dart';
import '../../../providers/shopping_provider.dart';
import '../../../utils/currency_formatter.dart';
import '../../../utils/digit_converter.dart';
import 'category_form_dialog.dart';
import 'shopping_visuals.dart';

/// برگه افزودن یا ویرایش یک قلم خرید.
///
/// اگر کاربر در حالت ویرایش قلم را حذف کند، همان قلم حذف‌شده برگردانده
/// می‌شود تا صفحه والد بتواند دکمه «بازگردانی» نشان دهد.
Future<ShoppingItem?> showItemFormSheet(
  BuildContext context, {
  ShoppingItem? item,
}) {
  final provider = context.read<ShoppingProvider>();
  return showModalBottomSheet<ShoppingItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: provider,
      child: _ItemFormSheet(item: item),
    ),
  );
}

/// «۱٫۵»، «1,000» و مانند آن را به عدد تبدیل می‌کند؛ null اگر عدد نباشد.
double? _parseQuantity(String input) {
  final normalized = toWesternDigits(
    input.trim(),
  ).replaceAll('٬', '').replaceAll(',', '').replaceAll('٫', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

/// شکل ذخیره‌سازی مقدار: «2» یا «1.5» (بدون صفر اعشاری اضافه).
String _storeQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

class _ItemFormSheet extends StatefulWidget {
  const _ItemFormSheet({this.item});

  final ShoppingItem? item;

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  final _selectedChipKey = GlobalKey();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late final TextEditingController _noteController;
  late String _category;
  String? _unit;
  late bool _isImportant;
  bool _isSaving = false;
  String? _lastAddedName;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    final provider = context.read<ShoppingProvider>();
    _nameController = TextEditingController(text: item?.name ?? '');
    final numeric = item?.numericQuantity;
    _quantityController = TextEditingController(
      text: numeric != null ? formatNumber(numeric) : (item?.quantity ?? ''),
    );
    _priceController = TextEditingController(
      text: item?.price != null ? formatAmountInput(item!.price!) : '',
    );
    _noteController = TextEditingController(text: item?.note ?? '');
    _category = item?.category ?? provider.defaultCategoryName;
    _unit = item?.unit;
    _isImportant = item?.isImportant ?? false;
    _revealSelectedCategory();
  }

  @override
  void dispose() {
    _nameFocus.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _stepQuantity(int delta) {
    final current = _parseQuantity(_quantityController.text) ?? 0;
    final next = current + delta;
    setState(() {
      _quantityController.text = next <= 0 ? '' : formatNumber(next);
    });
  }

  void _applySuggestion(ShoppingItemSuggestion suggestion) {
    final provider = context.read<ShoppingProvider>();
    setState(() {
      _nameController.text = suggestion.name;
      if (provider.categoryByName(suggestion.category) != null) {
        _category = suggestion.category;
        _revealSelectedCategory();
      }
      _unit ??= suggestion.unit;
      if (_priceController.text.trim().isEmpty && suggestion.price != null) {
        _priceController.text = formatAmountInput(suggestion.price!);
      }
    });
  }

  void _selectCategory(String name) {
    setState(() => _category = name);
    _revealSelectedCategory();
  }

  /// ردیف دسته‌ها افقی است؛ دسته انتخاب‌شده (مثلاً پیش‌فرض یا دسته تازه‌ساخته)
  /// باید در دید باشد.
  void _revealSelectedCategory() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chipContext = _selectedChipKey.currentContext;
      if (chipContext != null && chipContext.mounted) {
        Scrollable.ensureVisible(
          chipContext,
          alignment: 0.5,
          duration: const Duration(milliseconds: 250),
        );
      }
    });
  }

  Future<void> _createCategory() async {
    final created = await showCategoryFormDialog(context);
    if (created != null && mounted) _selectCategory(created.name);
  }

  Future<void> _submit({bool keepOpen = false}) async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final provider = context.read<ShoppingProvider>();
    final name = _nameController.text.trim();
    final quantityValue = _parseQuantity(_quantityController.text);
    final quantity = quantityValue == null
        ? null
        : _storeQuantity(quantityValue);
    final price = parseFormattedAmount(_priceController.text)?.toDouble();
    final note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();

    if (_isEditing) {
      final original = widget.item!;
      await provider.updateItem(
        ShoppingItem(
          id: original.id,
          shoppingListId: original.shoppingListId,
          isChecked: original.isChecked,
          name: name,
          category: _category,
          quantity: quantity,
          unit: _unit,
          price: price,
          note: note,
          isImportant: _isImportant,
        ),
      );
    } else {
      await provider.addItem(
        name: name,
        category: _category,
        quantity: quantity,
        unit: _unit,
        price: price,
        note: note,
        isImportant: _isImportant,
      );
    }
    if (!mounted) return;

    if (keepOpen) {
      // برای ورود پشت‌سرهم اقلام: دسته و واحد حفظ می‌شوند، بقیه پاک.
      setState(() {
        _isSaving = false;
        _lastAddedName = name;
        _nameController.clear();
        _quantityController.clear();
        _priceController.clear();
        _noteController.clear();
        _isImportant = false;
      });
      _nameFocus.requestFocus();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final item = widget.item!;
    await context.read<ShoppingProvider>().deleteItem(item);
    if (mounted) Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ShoppingProvider>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final quantity = _parseQuantity(_quantityController.text);
    final price = parseFormattedAmount(_priceController.text);
    final showLineTotal = price != null && quantity != null && quantity != 1;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isEditing ? 'ویرایش آیتم' : 'افزودن آیتم',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_isEditing)
                          IconButton(
                            onPressed: _isSaving ? null : _delete,
                            tooltip: 'حذف آیتم',
                            icon: Icon(
                              Icons.delete_outline,
                              color: scheme.error,
                            ),
                          ),
                      ],
                    ),
                    if (_lastAddedName != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '«$_lastAddedName» اضافه شد. آیتم بعدی را وارد کنید.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    RawAutocomplete<ShoppingItemSuggestion>(
                      textEditingController: _nameController,
                      focusNode: _nameFocus,
                      displayStringForOption: (option) => option.name,
                      optionsBuilder: (value) =>
                          provider.suggestionsFor(value.text),
                      onSelected: _applySuggestion,
                      fieldViewBuilder:
                          (context, controller, focusNode, onSubmit) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              autofocus: !_isEditing,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'نام آیتم',
                                prefixIcon: Icon(Icons.shopping_bag_outlined),
                              ),
                              validator: (value) =>
                                  (value == null || value.trim().isEmpty)
                                  ? 'نام نمی‌تواند خالی باشد'
                                  : null,
                            );
                          },
                      optionsViewBuilder: (context, onSelected, options) =>
                          _SuggestionsView(
                            options: options.toList(),
                            onSelected: onSelected,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Text('دسته‌بندی', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    // یک ردیف افقی به‌جای Wrap: با ده‌ها دسته هم فرم کوتاه می‌ماند
                    // و مقدار/قیمت بالای کیبورد دیده می‌شوند.
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final category in provider.categories)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: ChoiceChip(
                                key: _category == category.name
                                    ? _selectedChipKey
                                    : null,
                                avatar: Icon(
                                  shoppingCategoryIcon(category.iconKey),
                                  size: 18,
                                  color: Color(category.colorValue),
                                ),
                                label: Text(category.name),
                                selected: _category == category.name,
                                onSelected: (_) =>
                                    _selectCategory(category.name),
                              ),
                            ),
                          // دسته‌ای که قلم دارد ولی در جدول نیست (داده قدیمی) هم انتخاب‌شده دیده شود.
                          if (provider.categoryByName(_category) == null)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: 8),
                              child: ChoiceChip(
                                key: _selectedChipKey,
                                label: Text(_category),
                                selected: true,
                                onSelected: (_) {},
                              ),
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 18),
                            label: const Text('دسته جدید'),
                            onPressed: _createCategory,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _quantityController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.center,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText: 'مقدار',
                              prefixIcon: IconButton(
                                icon: const Icon(Icons.remove),
                                tooltip: 'کم کردن',
                                onPressed: () => _stepQuantity(-1),
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.add),
                                tooltip: 'زیاد کردن',
                                onPressed: () => _stepQuantity(1),
                              ),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return null;
                              final parsed = _parseQuantity(text);
                              return parsed == null || parsed <= 0
                                  ? 'عدد معتبر وارد کنید'
                                  : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String?>(
                            initialValue: _unit,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'واحد',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('—'),
                              ),
                              // واحد قدیمی/غیراستاندارد هم در لیست باشد تا Dropdown خطا ندهد.
                              for (final unit in {
                                ...AppConstants.shoppingUnits,
                                ?_unit,
                              })
                                DropdownMenuItem<String?>(
                                  value: unit,
                                  child: Text(unit),
                                ),
                            ],
                            onChanged: (value) => setState(() => _unit = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'قیمت واحد (اختیاری)',
                        suffixText: 'تومان',
                        prefixIcon: const Icon(Icons.payments_outlined),
                        helperText: showLineTotal
                            ? 'جمع: ${formatTooman(price * quantity)}'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _noteController,
                      textInputAction: TextInputAction.done,
                      maxLines: null,
                      decoration: const InputDecoration(
                        labelText: 'توضیحات (مثلاً برند یا مدل)',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _isImportant,
                      onChanged: (value) =>
                          setState(() => _isImportant = value),
                      secondary: Icon(
                        _isImportant
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: _isImportant ? Colors.amber : null,
                      ),
                      title: const Text('مهم / ضروری'),
                      subtitle: const Text(
                        'در بالای دسته خودش نمایش داده می‌شود',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // دکمه‌ها بیرون از ناحیه اسکرول هستند تا با کیبورد باز هم همیشه دیده شوند.
          Padding(
            // paddingOf (نه viewPadding): وقتی کیبورد باز است صفر می‌شود و وقتی
            // بسته است، فضای نوار ناوبری سیستم را کنار می‌گذارد.
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: _isEditing
                ? SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _submit,
                      icon: const Icon(Icons.check),
                      label: const Text('ذخیره تغییرات'),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () => _submit(keepOpen: true),
                          child: const Text('افزودن و بعدی'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSaving ? null : _submit,
                          child: const Text('افزودن'),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionsView extends StatelessWidget {
  const _SuggestionsView({required this.options, required this.onSelected});

  final List<ShoppingItemSuggestion> options;
  final AutocompleteOnSelected<ShoppingItemSuggestion> onSelected;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ShoppingProvider>();
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
          child: ListView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            children: [
              for (final option in options)
                ListTile(
                  dense: true,
                  leading: CategoryAvatar(
                    category: provider.categoryByName(option.category),
                    size: 30,
                  ),
                  title: Text(option.name),
                  subtitle: Text(
                    option.price != null
                        ? '${option.category} • ${formatTooman(option.price!)}'
                        : option.category,
                  ),
                  onTap: () => onSelected(option),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
