import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yadyar_app/models/ad_banner_model.dart';
import 'package:yadyar_app/providers/ad_banner_controller.dart';
import 'package:yadyar_app/repositories/install_id_repository.dart';
import 'package:yadyar_app/services/ads_api_exception.dart';

import '../support/fake_advertising_gateway.dart';

AdBannerModel _banner(String id) => AdBannerModel(
  bannerId: id,
  imageUrl: Uri.parse('https://example.com/$id.webp'),
  destinationUrl: Uri.parse('https://example.com/$id'),
  bannerTitle: 'بنر $id',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('not configured: fetch resolves without calling the gateway', () async {
    final gateway = FakeAdvertisingGateway(configured: false);
    final controller = AdBannerController(
      gateway: gateway,
      installIdRepository: InstallIdRepository(),
    );

    await controller.fetch();

    expect(gateway.fetchCallCount, 0);
    expect(controller.initialLoading, isFalse);
    controller.dispose();
  });

  test('fetch populates banners and marks the cache as fresh', () async {
    final gateway = FakeAdvertisingGateway()..bannersToReturn = [_banner('a')];
    final controller = AdBannerController(
      gateway: gateway,
      installIdRepository: InstallIdRepository(),
    );

    await controller.fetch();

    expect(controller.banners.map((b) => b.bannerId), ['a']);
    expect(controller.initialLoading, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.lastSuccessfulFetch, isNotNull);
    controller.dispose();
  });

  test(
    'a second fetch within the cache window does not re-hit the gateway',
    () async {
      final gateway = FakeAdvertisingGateway()
        ..bannersToReturn = [_banner('a')];
      final controller = AdBannerController(
        gateway: gateway,
        installIdRepository: InstallIdRepository(),
        cacheDuration: const Duration(minutes: 20),
      );
      await controller.fetch();

      await controller.fetch();

      expect(gateway.fetchCallCount, 1);
      controller.dispose();
    },
  );

  test(
    'force fetch re-hits the gateway even inside the cache window',
    () async {
      final gateway = FakeAdvertisingGateway()
        ..bannersToReturn = [_banner('a')];
      final controller = AdBannerController(
        gateway: gateway,
        installIdRepository: InstallIdRepository(),
      );
      await controller.fetch();

      await controller.fetch(force: true);

      expect(gateway.fetchCallCount, 2);
      controller.dispose();
    },
  );

  test(
    'concurrent fetch calls are deduplicated into a single gateway call',
    () async {
      final gateway = FakeAdvertisingGateway()
        ..bannersToReturn = [_banner('a')]
        ..fetchDelay = const Duration(milliseconds: 30);
      final controller = AdBannerController(
        gateway: gateway,
        installIdRepository: InstallIdRepository(),
      );

      await Future.wait([controller.fetch(), controller.fetch()]);

      expect(gateway.fetchCallCount, 1);
      controller.dispose();
    },
  );

  test(
    'on refresh failure, the previous banners are kept and an error message is set',
    () async {
      final gateway = FakeAdvertisingGateway()
        ..bannersToReturn = [_banner('a')];
      final controller = AdBannerController(
        gateway: gateway,
        installIdRepository: InstallIdRepository(),
      );
      await controller.fetch();

      gateway.fetchError = const AdsApiException('دریافت تبلیغات ناموفق بود');
      await controller.fetch(force: true);

      expect(controller.banners.map((b) => b.bannerId), ['a']);
      expect(controller.errorMessage, 'دریافت تبلیغات ناموفق بود');
      controller.dispose();
    },
  );

  test(
    'handleBannerTap deduplicates a rapid double tap into one click registration',
    () async {
      final gateway = FakeAdvertisingGateway();
      final controller = AdBannerController(
        gateway: gateway,
        installIdRepository: InstallIdRepository(),
      );
      final banner = _banner('a');

      final results = await Future.wait([
        controller.handleBannerTap(banner),
        controller.handleBannerTap(banner),
      ]);

      expect(gateway.registerClickCallCount, 1);
      expect(results.where((r) => r != null), hasLength(1));
      controller.dispose();
    },
  );

  test(
    'handleBannerTap falls back to the banner destinationUrl if click registration fails',
    () async {
      final gateway = FakeAdvertisingGateway()
        ..registerClickError = const AdsApiException('network');
      final controller = AdBannerController(
        gateway: gateway,
        installIdRepository: InstallIdRepository(),
      );
      final banner = _banner('a');

      final destination = await controller.handleBannerTap(banner);

      expect(destination, banner.destinationUrl);
      controller.dispose();
    },
  );
}
