/// یک رکورد پرداخت واقعی برای یک اشتراک/قبض (برای تاریخچه پرداخت‌ها و نمودار هزینه ماهانه).
class SubscriptionPayment {
  const SubscriptionPayment({
    this.id,
    required this.subscriptionId,
    required this.paidDate,
    required this.amount,
  });

  final int? id;
  final int subscriptionId;
  final DateTime paidDate;
  final double amount;

  SubscriptionPayment copyWith({
    int? id,
    int? subscriptionId,
    DateTime? paidDate,
    double? amount,
  }) {
    return SubscriptionPayment(
      id: id ?? this.id,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      paidDate: paidDate ?? this.paidDate,
      amount: amount ?? this.amount,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'subscriptionId': subscriptionId,
      'paidDate': paidDate.toIso8601String(),
      'amount': amount,
    };
  }

  factory SubscriptionPayment.fromMap(Map<String, Object?> map) {
    return SubscriptionPayment(
      id: map['id'] as int?,
      subscriptionId: map['subscriptionId'] as int,
      paidDate: DateTime.parse(map['paidDate'] as String),
      amount: (map['amount'] as num).toDouble(),
    );
  }
}
