import 'package:yadyar_app/models/support_receipt.dart';
import 'package:yadyar_app/services/app_support_gateway.dart';

/// Fake قابل کنترل برای تست صفحات گزارش خطا و درخواست تبلیغ.
class FakeAppSupportGateway implements AppSupportGateway {
  FakeAppSupportGateway({this.configured = true});

  bool configured;
  Object? errorToThrow;

  Map<String, String>? lastErrorReport;
  Map<String, String>? lastAdvertisingRequest;
  int submitCallCount = 0;

  @override
  bool get isConfigured => configured;

  @override
  Future<SupportReceipt> submitErrorReport({
    required String description,
  }) async {
    submitCallCount++;
    lastErrorReport = {'description': description};
    if (errorToThrow != null) throw errorToThrow!;
    return const SupportReceipt(id: 'r1', type: 'ErrorReport', status: 'New');
  }

  @override
  Future<SupportReceipt> submitAdvertisingRequest({
    required String fullName,
    required String phoneNumber,
    required String province,
    required String city,
    required String details,
  }) async {
    submitCallCount++;
    lastAdvertisingRequest = {
      'fullName': fullName,
      'phoneNumber': phoneNumber,
      'province': province,
      'city': city,
      'details': details,
    };
    if (errorToThrow != null) throw errorToThrow!;
    return const SupportReceipt(
      id: 'r2',
      type: 'AdvertisingRequest',
      status: 'New',
    );
  }

  @override
  void close() {}
}
