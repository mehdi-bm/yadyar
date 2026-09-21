import '../models/support_receipt.dart';

/// قرارداد ارسال گزارش خطا و درخواست تبلیغ به همان API تبلیغات پارسیک.
abstract class AppSupportGateway {
  bool get isConfigured;

  Future<SupportReceipt> submitErrorReport({required String description});

  Future<SupportReceipt> submitAdvertisingRequest({
    required String fullName,
    required String phoneNumber,
    required String province,
    required String city,
    required String details,
  });

  void close();
}
