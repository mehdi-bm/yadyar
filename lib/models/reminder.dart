enum ReminderRepeatType {
  none,
  daily,
  weekly,
  monthly;

  static ReminderRepeatType fromName(String name) =>
      ReminderRepeatType.values.byName(name);
}

class Reminder {
  const Reminder({
    this.id,
    this.noteId,
    required this.title,
    required this.dateTime,
    this.repeatType = ReminderRepeatType.none,
    this.isActive = true,
  });

  final int? id;

  /// یادآور می‌تواند به یک یادداشت وابسته باشد یا کاملاً مستقل باشد.
  final int? noteId;
  final String title;
  final DateTime dateTime;
  final ReminderRepeatType repeatType;
  final bool isActive;

  /// زمان رخداد بعدی از [now] به بعد (برای یادآور تکرارشونده، [dateTime] فقط
  /// اولین رخداد است). برای یادآور بدون تکرارِ گذشته، null. قواعد با
  /// زمان‌بندی اعلان در NotificationService یکی است (مثلاً ماه‌هایی که روز
  /// [dateTime] را ندارند رد می‌شوند).
  DateTime? nextOccurrence({DateTime? now}) {
    final reference = now ?? DateTime.now();
    var date = dateTime;
    if (date.isAfter(reference)) return date;
    DateTime at(int year, int month, int day) => DateTime(
      year,
      month,
      day,
      dateTime.hour,
      dateTime.minute,
      dateTime.second,
    );
    switch (repeatType) {
      case ReminderRepeatType.none:
        return null;
      case ReminderRepeatType.daily:
        do {
          date = at(date.year, date.month, date.day + 1);
        } while (!date.isAfter(reference));
      case ReminderRepeatType.weekly:
        do {
          date = at(date.year, date.month, date.day + 7);
        } while (!date.isAfter(reference));
      case ReminderRepeatType.monthly:
        do {
          var year = date.year;
          var month = date.month + 1;
          if (month > 12) {
            month = 1;
            year++;
          }
          while (dateTime.day > DateTime(year, month + 1, 0).day) {
            month++;
            if (month > 12) {
              month = 1;
              year++;
            }
          }
          date = at(year, month, dateTime.day);
        } while (!date.isAfter(reference));
    }
    return date;
  }

  Reminder copyWith({
    int? id,
    int? noteId,
    String? title,
    DateTime? dateTime,
    ReminderRepeatType? repeatType,
    bool? isActive,
  }) {
    return Reminder(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      dateTime: dateTime ?? this.dateTime,
      repeatType: repeatType ?? this.repeatType,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'noteId': noteId,
      'title': title,
      'dateTime': dateTime.toIso8601String(),
      'repeatType': repeatType.name,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory Reminder.fromMap(Map<String, Object?> map) {
    return Reminder(
      id: map['id'] as int?,
      noteId: map['noteId'] as int?,
      title: map['title'] as String,
      dateTime: DateTime.parse(map['dateTime'] as String),
      repeatType: ReminderRepeatType.fromName(map['repeatType'] as String),
      isActive: (map['isActive'] as int) == 1,
    );
  }
}
