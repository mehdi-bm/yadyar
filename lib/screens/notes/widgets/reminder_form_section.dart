import 'package:flutter/material.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';

import '../../../models/reminder.dart';
import '../../../utils/date_formatter.dart';

const Map<ReminderRepeatType, String> reminderRepeatTypeLabels = {
  ReminderRepeatType.none: 'بدون تکرار',
  ReminderRepeatType.daily: 'روزانه',
  ReminderRepeatType.weekly: 'هفتگی',
  ReminderRepeatType.monthly: 'ماهانه',
};

/// بخش یادآور در فرم افزودن/ویرایش یادداشت: کلید فعال‌سازی + انتخاب زمان و نوع تکرار.
class ReminderFormSection extends StatelessWidget {
  const ReminderFormSection({
    super.key,
    required this.enabled,
    required this.dateTime,
    required this.repeatType,
    required this.onEnabledChanged,
    required this.onDateTimeChanged,
    required this.onRepeatTypeChanged,
  });

  final bool enabled;
  final DateTime dateTime;
  final ReminderRepeatType repeatType;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<DateTime> onDateTimeChanged;
  final ValueChanged<ReminderRepeatType> onRepeatTypeChanged;

  Future<void> _pickDateTime(BuildContext context) async {
    final pickedDate = await showPersianDatePicker(
      context: context,
      initialDate: Jalali.fromDateTime(dateTime),
      firstDate: Jalali.fromDateTime(
        DateTime.now().subtract(const Duration(days: 1)),
      ),
      lastDate: Jalali.fromDateTime(
        DateTime.now().add(const Duration(days: 365 * 5)),
      ),
    );
    if (pickedDate == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(dateTime),
    );
    if (time == null) return;

    final date = pickedDate.toDateTime();
    onDateTimeChanged(
      DateTime(date.year, date.month, date.day, time.hour, time.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('افزودن یادآور'),
              value: enabled,
              onChanged: onEnabledChanged,
            ),
            if (enabled) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(formatJalaliDateTime(dateTime)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () => _pickDateTime(context),
              ),
              const SizedBox(height: 4),
              Text('نوع تکرار', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: ReminderRepeatType.values.map((type) {
                  return ChoiceChip(
                    label: Text(reminderRepeatTypeLabels[type]!),
                    selected: repeatType == type,
                    onSelected: (_) => onRepeatTypeChanged(type),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
