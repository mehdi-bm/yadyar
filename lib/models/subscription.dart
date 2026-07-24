enum SubscriptionRepeatType {
  monthly,
  yearly,
  once;

  static SubscriptionRepeatType fromName(String name) =>
      SubscriptionRepeatType.values.byName(name);
}

class Subscription {
  const Subscription({
    this.id,
    required this.title,
    required this.amount,
    required this.dueDate,
    this.repeatType = SubscriptionRepeatType.monthly,
    required this.category,
    this.reminderDaysBefore = 0,
    this.isPaid = false,
    this.lastPaidDate,
  });

  final int? id;
  final String title;
  final double amount;
  final DateTime dueDate;
  final SubscriptionRepeatType repeatType;
  final String category;
  final int reminderDaysBefore;
  final bool isPaid;

  /// تا پیش از اولین پرداخت مقدار ندارد.
  final DateTime? lastPaidDate;

  Subscription copyWith({
    int? id,
    String? title,
    double? amount,
    DateTime? dueDate,
    SubscriptionRepeatType? repeatType,
    String? category,
    int? reminderDaysBefore,
    bool? isPaid,
    DateTime? lastPaidDate,
  }) {
    return Subscription(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      repeatType: repeatType ?? this.repeatType,
      category: category ?? this.category,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      isPaid: isPaid ?? this.isPaid,
      lastPaidDate: lastPaidDate ?? this.lastPaidDate,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'repeatType': repeatType.name,
      'category': category,
      'reminderDaysBefore': reminderDaysBefore,
      'isPaid': isPaid ? 1 : 0,
      'lastPaidDate': lastPaidDate?.toIso8601String(),
    };
  }

  factory Subscription.fromMap(Map<String, Object?> map) {
    return Subscription(
      id: map['id'] as int?,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      dueDate: DateTime.parse(map['dueDate'] as String),
      repeatType: SubscriptionRepeatType.fromName(map['repeatType'] as String),
      category: map['category'] as String,
      reminderDaysBefore: map['reminderDaysBefore'] as int,
      isPaid: (map['isPaid'] as int) == 1,
      lastPaidDate: map['lastPaidDate'] != null
          ? DateTime.parse(map['lastPaidDate'] as String)
          : null,
    );
  }
}
