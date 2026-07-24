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
