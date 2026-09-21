import 'package:flutter/foundation.dart';

/// پاسخ ثبت کلیک بنر؛ فقط clickId و destinationUrl برای باز کردن لینک لازم است.
@immutable
class AdClickReceipt {
  const AdClickReceipt({required this.clickId, required this.destinationUrl});

  final String clickId;
  final Uri destinationUrl;

  static AdClickReceipt? tryParse(
    Map<String, dynamic> json, {
    required Uri? Function(String value) resolveUrl,
  }) {
    final clickId = (json['clickId']?.toString() ?? '').trim();
    if (clickId.isEmpty) return null;
    final destinationUrl = resolveUrl(json['destinationUrl']?.toString() ?? '');
    if (destinationUrl == null) return null;
    return AdClickReceipt(clickId: clickId, destinationUrl: destinationUrl);
  }
}
