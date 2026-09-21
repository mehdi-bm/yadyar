import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yadyar_app/config/ads_config.dart';
import 'package:yadyar_app/services/ads_api_exception.dart';
import 'package:yadyar_app/services/advertising_service.dart';

AdsConfig _configFor(int port, {String sectionCode = 'yadyar_app'}) =>
    AdsConfig(
      baseUrl: 'http://127.0.0.1:$port/',
      apiKey: 'test-api-key',
      externalAppApiKey: 'test-external-key',
      appName: 'yadyar',
      platform: 'Android',
      sectionCode: sectionCode,
      allowInsecureHttp: true,
    );

void main() {
  late HttpServer server;
  late List<HttpRequest> received;

  Future<void> startServer(
    Future<void> Function(HttpRequest request) handler,
  ) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    received = [];
    server.listen((request) async {
      received.add(request);
      await handler(request);
    });
  }

  tearDown(() async {
    await server.close(force: true);
  });

  group('fetchBanners', () {
    test(
      'sends both auth headers and platform+sectionCode query params',
      () async {
        await startServer((request) async {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode([]));
          await request.response.close();
        });
        final service = AdvertisingService(config: _configFor(server.port));

        await service.fetchBanners();

        final uri = received.single.uri;
        expect(uri.path, '/api/public/ads/banners');
        expect(uri.queryParameters['platform'], 'Android');
        expect(uri.queryParameters['sectionCode'], 'yadyar_app');
        expect(received.single.headers.value('X-API-KEY'), 'test-api-key');
        expect(
          received.single.headers.value('X-EXTERNAL-APP-API-KEY'),
          'test-external-key',
        );
        service.close();
      },
    );

    test('omits sectionCode query param when empty', () async {
      await startServer((request) async {
        request.response.write(jsonEncode([]));
        await request.response.close();
      });
      final service = AdvertisingService(
        config: _configFor(server.port, sectionCode: ''),
      );

      await service.fetchBanners();

      expect(
        received.single.uri.queryParameters.containsKey('sectionCode'),
        isFalse,
      );
      service.close();
    });

    test(
      'parses a valid banner array and resolves relative imageUrl',
      () async {
        await startServer((request) async {
          request.response.write(
            jsonEncode([
              {
                'bannerId': 'b1',
                'bannerTitle': ' عنوان ',
                'imageUrl': '/uploads/banners/example.webp',
                'destinationUrl': 'https://example.com/landing',
                'campaignTitle': 'کمپین',
                'sectionName': 'صفحه اصلی',
                'sectionCode': 'home-main',
              },
            ]),
          );
          await request.response.close();
        });
        final service = AdvertisingService(config: _configFor(server.port));

        final banners = await service.fetchBanners();

        expect(banners, hasLength(1));
        expect(banners.single.bannerId, 'b1');
        expect(banners.single.bannerTitle, 'عنوان');
        expect(
          banners.single.imageUrl.toString(),
          'http://127.0.0.1:${server.port}/uploads/banners/example.webp',
        );
        service.close();
      },
    );

    test('drops items without a bannerId and keeps valid ones', () async {
      await startServer((request) async {
        request.response.write(
          jsonEncode([
            {'imageUrl': '/a.webp', 'destinationUrl': 'https://example.com'},
            {
              'bannerId': 'b2',
              'imageUrl': '/b.webp',
              'destinationUrl': 'https://example.com',
            },
          ]),
        );
        await request.response.close();
      });
      final service = AdvertisingService(config: _configFor(server.port));

      final banners = await service.fetchBanners();

      expect(banners.map((b) => b.bannerId), ['b2']);
      service.close();
    });

    test('treats a null response body as an empty, non-error list', () async {
      await startServer((request) async {
        request.response.write('null');
        await request.response.close();
      });
      final service = AdvertisingService(config: _configFor(server.port));

      final banners = await service.fetchBanners();

      expect(banners, isEmpty);
      service.close();
    });

    test('does not hit the network and throws when not configured', () async {
      final service = AdvertisingService(
        config: const AdsConfig(
          baseUrl: 'https://ads.parsikonline.ir/',
          apiKey: '',
          externalAppApiKey: '',
          appName: 'yadyar',
          platform: 'Android',
        ),
      );

      await expectLater(
        service.fetchBanners(),
        throwsA(isA<AdsApiException>()),
      );
      service.close();
    });

    test(
      'maps 400, 401/403, 429 and unknown status codes to Persian messages',
      () async {
        for (final entry in {
          400: 'اطلاعات واردشده معتبر نیست',
          401: 'ارتباط امن برنامه با سرور تأیید نشد',
          403: 'ارتباط امن برنامه با سرور تأیید نشد',
          429: 'تعداد درخواست‌ها زیاد است',
          500: 'خطایی در ارتباط با سرور',
        }.entries) {
          await startServer((request) async {
            request.response.statusCode = entry.key;
            await request.response.close();
          });
          final service = AdvertisingService(config: _configFor(server.port));

          await expectLater(
            service.fetchBanners(),
            throwsA(
              isA<AdsApiException>().having(
                (e) => e.message,
                'message',
                contains(entry.value),
              ),
            ),
          );
          service.close();
          await server.close(force: true);
        }
      },
    );

    test(
      'invalid JSON body throws a "response not valid" message without leaking details',
      () async {
        await startServer((request) async {
          request.response.write('not json{{{');
          await request.response.close();
        });
        final service = AdvertisingService(config: _configFor(server.port));

        await expectLater(
          service.fetchBanners(),
          throwsA(
            isA<AdsApiException>().having(
              (e) => e.message,
              'message',
              contains('پاسخ سرور معتبر نیست'),
            ),
          ),
        );
        service.close();
      },
    );

    test(
      'rejects a cross-origin redirect and does not leak auth headers to it',
      () async {
        final evilServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final evilRequests = <HttpRequest>[];
        evilServer.listen((request) async {
          evilRequests.add(request);
          request.response.write(jsonEncode([]));
          await request.response.close();
        });

        await startServer((request) async {
          request.response
            ..statusCode = HttpStatus.found
            ..headers.set(
              HttpHeaders.locationHeader,
              'http://127.0.0.1:${evilServer.port}/api/public/ads/banners',
            );
          await request.response.close();
        });
        final service = AdvertisingService(config: _configFor(server.port));

        await expectLater(
          service.fetchBanners(),
          throwsA(isA<AdsApiException>()),
        );
        expect(evilRequests, isEmpty);

        service.close();
        await evilServer.close(force: true);
      },
    );
  });

  group('registerClick', () {
    test('sends the full payload and parses the 201 receipt', () async {
      final receivedBodies = <String>[];
      await startServer((request) async {
        receivedBodies.add(await utf8.decodeStream(request));
        request.response.statusCode = 201;
        request.response.write(
          jsonEncode({
            'clickId': 'c1',
            'bannerId': 'b1',
            'campaignId': 'camp1',
            'sectionId': 'sec1',
            'externalAppId': 'ext1',
            'destinationUrl': 'https://example.com/landing',
            'clickDateUtc': '2026-01-01T00:00:00Z',
            'deviceType': 'Mobile',
          }),
        );
        await request.response.close();
      });
      final service = AdvertisingService(config: _configFor(server.port));

      final receipt = await service.registerClick(
        bannerId: 'b1',
        externalUserId: 'abc123',
      );

      final body = jsonDecode(receivedBodies.single) as Map<String, dynamic>;
      expect(body['bannerId'], 'b1');
      expect(body['externalUserId'], 'abc123');
      expect(body['appName'], 'yadyar');
      expect(body['platform'], 'Android');
      expect(body['referrerUrl'], 'https://parsikhesab.com/apps/yadyar/ads/b1');
      expect(receipt.clickId, 'c1');
      expect(receipt.destinationUrl.toString(), 'https://example.com/landing');
      service.close();
    });
  });
}
