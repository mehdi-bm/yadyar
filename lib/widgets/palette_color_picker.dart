import 'package:flutter/material.dart';

/// پالت رنگ مشترک اپ (دسته‌ها و لیست‌های خرید، یادداشت‌ها) به‌صورت ARGB.
const List<int> appColorPalette = [
  0xFF43A047,
  0xFF00897B,
  0xFF26C6DA,
  0xFF42A5F5,
  0xFF5C6BC0,
  0xFF7E57C2,
  0xFFEC407A,
  0xFFE53935,
  0xFFFFA726,
  0xFFFDD835,
  0xFF8D6E63,
  0xFF78909C,
];

/// انتخاب رنگ از [appColorPalette]؛ [allowNone] گزینه «رنگ پیش‌فرض تم» را اضافه می‌کند.
class PaletteColorPicker extends StatelessWidget {
  const PaletteColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.allowNone = false,
  });

  final int? selected;
  final ValueChanged<int?> onChanged;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (allowNone)
          _Swatch(
            color: scheme.primary,
            isSelected: selected == null,
            label: 'رنگ پیش‌فرض',
            onTap: () => onChanged(null),
          ),
        for (final value in appColorPalette)
          _Swatch(
            color: Color(value),
            isSelected: selected == value,
            label: 'رنگ',
            onTap: () => onChanged(value),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.isSelected,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: isSelected
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : null,
        ),
      ),
    );
  }
}
