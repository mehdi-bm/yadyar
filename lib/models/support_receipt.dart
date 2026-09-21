import 'package:flutter/foundation.dart';

/// رسید موفقیت ثبت گزارش خطا یا درخواست تبلیغ.
@immutable
class SupportReceipt {
  const SupportReceipt({
    required this.id,
    required this.type,
    required this.status,
  });

  final String id;
  final String type;
  final String status;

  static SupportReceipt? tryParse(Map<String, dynamic> json) {
    final id = (json['id']?.toString() ?? '').trim();
    if (id.isEmpty) return null;
    return SupportReceipt(
      id: id,
      type: json['type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}
