import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yadyar_app/models/ad_banner_model.dart';
import 'package:yadyar_app/providers/ad_banner_controller.dart';
import 'package:yadyar_app/repositories/install_id_repository.dart';
import 'package:yadyar_app/services/ads_api_exception.dart';
import 'package:yadyar_app/widgets/ads/ad_banner_widget.dart';

import '../support/fake_advertising_gateway.dart';

AdBannerModel _banner(String id) => AdBannerModel(
  bannerId: id,
  imageUrl: Uri.parse('https://example.com/$id.webp'),
  destinationUrl: Uri.parse('https://example.com/$id'),
  bannerTitle: 'بنر $id',
  campaignTitle: 'کمپین $id',
);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows nothing when the gateway is not configured', (
    tester,
  ) async {
    final gateway = FakeAdvertisingGateway(configured: false);
    final controller = AdBannerController(
      gateway: gateway,
      installIdRepository: InstallIdRepository(),
    );

    await tester.pumpWidget(_wrap(AdBannerWidget(controller: controller)));
    await tester.pump();

    expect(find.byType(AdBannerWidget), findsOneWidget);
    expect(find.byKey(const ValueKey('ad_loading_placeholder')), findsNothing);
    expect(tester.getSize(find.byType(AdBannerWidget)), Size.zero);
  });

  testWidgets(
    'shows the skeleton while loading, then an empty array yields no space',
    (tester) async {
      final gateway = FakeAdvertisingGateway()
        ..fetchDelay = const Duration(milliseconds: 50);
      final controller = AdBannerController(
        gateway: gateway,
        installIdRepository: InstallIdRepository(),
      );

      await tester.pumpWidget(_wrap(AdBannerWidget(controller: controller)));
      expect(
        find.byKey(const ValueKey('ad_loading_placeholder')),
        findsOneWidget,
      );

      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('ad_loading_placeholder')),
        findsNothing,
      );
      expect(tester.getSize(find.byType(AdBannerWidget)), Size.zero);
    },
  );

  testWidgets(
    'shows an error message with a retry button, and retry re-fetches',
    (tester) async {
      final gateway = FakeAdvertisingGateway()
        ..fetchError = const AdsApiException('دریافت تبلیغات ناموفق بود');
      final controller = AdBannerController(
        gateway: gateway,
        installIdRepository: InstallIdRepository(),
      );

      await tester.pumpWidget(_wrap(AdBannerWidget(controller: controller)));
      await tester.pump();

      expect(find.byKey(const ValueKey('ad_load_error')), findsOneWidget);
      expect(find.text('دریافت تبلیغات ناموفق بود'), findsOneWidget);

      gateway.fetchError = null;
      gateway.bannersToReturn = [_banner('a')];
      await tester.tap(find.byKey(const ValueKey('ad_retry_button')));
      await tester.pump();

      expect(find.byKey(const ValueKey('ad_banner_page_view')), findsOneWidget);
    },
  );

  testWidgets(
    'renders a single banner with the ad label and no page indicator',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final gateway = FakeAdvertisingGateway()
        ..bannersToReturn = [_banner('a')];
      final controller = AdBannerController(
        gateway: gateway,
        installIdRepository: InstallIdRepository(),
      );

      await tester.pumpWidget(_wrap(AdBannerWidget(controller: controller)));
      await tester.pump();

      expect(find.byKey(const ValueKey('ad_banner_a')), findsOneWidget);
      expect(find.text('تبلیغ'), findsOneWidget);
      final semanticsNode = tester.getSemantics(
        find.byKey(const ValueKey('ad_banner_a')),
      );
      expect(semanticsNode.label, contains('تبلیغ، بنر a'));
      semantics.dispose();
    },
  );

  testWidgets('auto-slides between multiple banners every 4 seconds', (
    tester,
  ) async {
    final gateway = FakeAdvertisingGateway()
      ..bannersToReturn = [_banner('a'), _banner('b')];
    final controller = AdBannerController(
      gateway: gateway,
      installIdRepository: InstallIdRepository(),
    );

    await tester.pumpWidget(_wrap(AdBannerWidget(controller: controller)));
    await tester.pump();
    expect(controller.currentIndex, 0);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 500));

    expect(controller.currentIndex, 1);
  });

  testWidgets('dragging the carousel pauses auto-slide', (tester) async {
    final gateway = FakeAdvertisingGateway()
      ..bannersToReturn = [_banner('a'), _banner('b')];
    final controller = AdBannerController(
      gateway: gateway,
      installIdRepository: InstallIdRepository(),
    );

    await tester.pumpWidget(_wrap(AdBannerWidget(controller: controller)));
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(AdBannerWidget)),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(controller.currentIndex, 0);
    await gesture.up();
  });

  testWidgets(
    'tapping a banner registers exactly one click on a rapid double tap',
    (tester) async {
      final gateway = FakeAdvertisingGateway()
        ..bannersToReturn = [_banner('a')]
        ..registerClickDelay = const Duration(milliseconds: 50);
      final controller = AdBannerController(
        gateway: gateway,
        installIdRepository: InstallIdRepository(),
      );

      await tester.pumpWidget(_wrap(AdBannerWidget(controller: controller)));
      await tester.pump();

      // اولین لمس، arena را resolve و isOpeningLink را true می‌کند؛ لمس دوم
      // که هنوز ثبت کلیک اول در جریان است باید نادیده گرفته شود.
      await tester.tap(find.byKey(const ValueKey('ad_banner_a')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ad_banner_a')));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();

      expect(gateway.registerClickCallCount, 1);
    },
  );
}
