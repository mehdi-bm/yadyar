import 'package:yadyar_app/models/ad_banner_model.dart';
import 'package:yadyar_app/models/ad_click_receipt.dart';
import 'package:yadyar_app/services/advertising_gateway.dart';

/// Fake قابل کنترل برای تست AdBannerController و AdBannerWidget بدون شبکه واقعی.
class FakeAdvertisingGateway implements AdvertisingGateway {
  FakeAdvertisingGateway({this.configured = true});

  bool configured;
  List<AdBannerModel> bannersToReturn = const [];
  Object? fetchError;
  Duration? fetchDelay;
  int fetchCallCount = 0;

  Object? registerClickError;
  Duration? registerClickDelay;
  int registerClickCallCount = 0;
  final List<String> registeredClickBannerIds = [];

  @override
  bool get isConfigured => configured;

  @override
  Uri? resolvePublicUrl(String value) => Uri.tryParse(value);

  @override
  Future<List<AdBannerModel>> fetchBanners() async {
    fetchCallCount++;
    if (fetchDelay != null) await Future<void>.delayed(fetchDelay!);
    if (fetchError != null) throw fetchError!;
    return bannersToReturn;
  }

  @override
  Future<AdClickReceipt> registerClick({
    required String bannerId,
    required String externalUserId,
  }) async {
    registerClickCallCount++;
    registeredClickBannerIds.add(bannerId);
    if (registerClickDelay != null) await Future<void>.delayed(registerClickDelay!);
    if (registerClickError != null) throw registerClickError!;
    return AdClickReceipt(
      clickId: 'click-$bannerId',
      destinationUrl: Uri.parse('https://example.com/$bannerId'),
    );
  }

  @override
  void close() {}
}
