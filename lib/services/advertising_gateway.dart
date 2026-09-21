import '../models/ad_banner_model.dart';
import '../models/ad_click_receipt.dart';

/// قرارداد سرویس تبلیغات؛ UI/Controller فقط با این interface کار می‌کند تا
/// در تست بتوان یک fake ساده جایگزین کرد.
abstract class AdvertisingGateway {
  bool get isConfigured;

  Uri? resolvePublicUrl(String value);

  Future<List<AdBannerModel>> fetchBanners();

  Future<AdClickReceipt> registerClick({
    required String bannerId,
    required String externalUserId,
  });

  void close();
}
