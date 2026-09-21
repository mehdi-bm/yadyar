import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yadyar_app/config/ads_config.dart';
import 'package:yadyar_app/services/ads_api_exception.dart';
import 'package:yadyar_app/services/app_support_service.dart';

AdsConfig _configFor(int port) => AdsConfig(
  baseUrl: 'http://127.0.0.1:$port/',
  apiKey: 'test-api-key',
  externalAppApiKey: 'test-external-key',
  appName: 'yadyar',
  platform: 'Android',
  allowInsecureHttp: true,
);

void main() {
  late HttpServer server;

  Future<List<String>> startServer({
    required int statusCode,
    String Function(Map<String, dynamic> body)? responseBodyFor,
  }) async {
    final bodies = <String>[];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final rawBody = await utf8.decodeStream(request);
      bodies.add(rawBody);
      request.response.statusCode = statusCode;
      request.response.headers.set('X-API-KEY', 'ignored');
      final decoded = rawBody.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(rawBody) as Map<String, dynamic>;
      request.response.write(responseBodyFor?.call(decoded) ?? '');
      await request.response.close();
    });
    return bodies;
  }

  tearDown(() async {
    await server.close(force: true);
  });

  group('submitErrorReport', () {
    test(
      'sends both auth headers, trimmed JSON body, and parses the receipt',
      () async {
        final bodies = await startServer(
          statusCode: 201,
          responseBodyFor: (_) =>
              jsonEncode({'id': 'r1', 'type': 'ErrorReport', 'status': 'New'}),
        );
        final service = AppSupportService(config: _configFor(server.port));

        final receipt = await service.submitErrorReport(
          description: '  یک خطا رخ داد  ',
        );

        final body = jsonDecode(bodies.single) as Map<String, dynamic>;
        expect(body['description'], 'یک خطا رخ داد');
        expect(receipt.id, 'r1');
        expect(receipt.type, 'ErrorReport');
        service.close();
      },
    );

    test(
      'maps status codes to Persian messages without leaking server details',
      () async {
        for (final entry in {
          400: 'اطلاعات واردشده معتبر نیست',
          401: 'ارتباط امن برنامه با سرور تأیید نشد',
          429: 'تعداد درخواست‌ها زیاد است',
          500: 'خطایی در ارتباط با سرور',
        }.entries) {
          await startServer(statusCode: entry.key);
          final service = AppSupportService(config: _configFor(server.port));

          await expectLater(
            service.submitErrorReport(description: 'خطا'),
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

    test('empty successful body is not treated as success', () async {
      await startServer(statusCode: 201, responseBodyFor: (_) => '');
      final service = AppSupportService(config: _configFor(server.port));

      await expectLater(
        service.submitErrorReport(description: 'خطا'),
        throwsA(
          isA<AdsApiException>().having(
            (e) => e.message,
            'message',
            contains('پاسخ سرور معتبر نیست'),
          ),
        ),
      );
      service.close();
    });

    test('does not hit the network and throws when not configured', () async {
      final service = AppSupportService(
        config: const AdsConfig(
          baseUrl: 'https://ads.parsikonline.ir/',
          apiKey: '',
          externalAppApiKey: '',
          appName: 'yadyar',
          platform: 'Android',
        ),
      );

      await expectLater(
        service.submitErrorReport(description: 'خطا'),
        throwsA(isA<AdsApiException>()),
      );
      service.close();
    });
  });

  group('submitAdvertisingRequest', () {
    test('sends all five fields trimmed and parses the receipt', () async {
      final bodies = await startServer(
        statusCode: 201,
        responseBodyFor: (_) => jsonEncode({
          'id': 'r2',
          'type': 'AdvertisingRequest',
          'status': 'New',
        }),
      );
      final service = AppSupportService(config: _configFor(server.port));

      final receipt = await service.submitAdvertisingRequest(
        fullName: ' علی رضایی ',
        phoneNumber: ' 09123456789 ',
        province: ' تهران ',
        city: ' تهران ',
        details: ' توضیح ',
      );

      final body = jsonDecode(bodies.single) as Map<String, dynamic>;
      expect(body['fullName'], 'علی رضایی');
      expect(body['phoneNumber'], '09123456789');
      expect(body['province'], 'تهران');
      expect(body['city'], 'تهران');
      expect(body['details'], 'توضیح');
      expect(receipt.id, 'r2');
      service.close();
    });
  });
}
