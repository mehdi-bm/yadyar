import 'dart:convert';

import '../config/ads_config.dart';
import '../models/ad_banner_model.dart';
import '../models/ad_click_receipt.dart';
import 'ads_api_exception.dart';
import 'advertising_gateway.dart';
import 'secure_http_transport.dart';

class AdvertisingService implements AdvertisingGateway {
  AdvertisingService({
    required AdsConfig config,
    SecureHttpTransport? transport,
  }) : _config = config,
       _transport = transport ?? SecureHttpTransport();

  final AdsConfig _config;
  final SecureHttpTransport _transport;

  @override
  bool get isConfigured => _config.isConfigured;

  @override
  Uri? resolvePublicUrl(String value) => _config.resolvePublicUrl(value);

  @override
  Future<List<AdBannerModel>> fetchBanners() async {
    if (!isConfigured) throw notConfiguredException;

    final query = <String, String>{'platform': _config.platform};
    final sectionCode = _config.sectionCode.trim();
    if (sectionCode.isNotEmpty) query['sectionCode'] = sectionCode;
    final uri = _config.baseUri
        .resolve('/api/public/ads/banners')
        .replace(queryParameters: query);

    final response = await _send(
      'GET',
      uri,
      headers: {'Accept': 'application/json', ..._config.authHeaders},
    );
    if (response.statusCode != 200) throw mapHttpStatus(response.statusCode);

    final trimmedBody = response.body.trim();
    if (trimmedBody.isEmpty || trimmedBody == 'null') return const [];

    final decoded = _tryDecode(response.body);
    if (decoded is! List) throw invalidResponseException;

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => AdBannerModel.tryParse(item, resolveUrl: resolvePublicUrl),
        )
        .whereType<AdBannerModel>()
        .toList(growable: false);
  }

  @override
  Future<AdClickReceipt> registerClick({
    required String bannerId,
    required String externalUserId,
  }) async {
    if (!isConfigured) throw notConfiguredException;

    final uri = _config.baseUri.resolve('/api/public/ads/click');
    final payload = {
      'bannerId': bannerId,
      'externalUserId': _clamp(externalUserId, 150),
      'appName': _clamp(_config.appName, 150),
      'platform': _config.platform,
      'referrerUrl': _clamp(
        'https://parsikhesab.com/apps/${_config.appName}/ads/$bannerId',
        2048,
      ),
    };

    final response = await _send(
      'POST',
      uri,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json; charset=utf-8',
        ..._config.authHeaders,
      },
      body: jsonEncode(payload),
    );
    if (response.statusCode != 201) throw mapHttpStatus(response.statusCode);

    final decoded = _tryDecode(response.body);
    if (decoded is! Map<String, dynamic>) throw invalidResponseException;

    final receipt = AdClickReceipt.tryParse(
      decoded,
      resolveUrl: resolvePublicUrl,
    );
    if (receipt == null) throw invalidResponseException;
    return receipt;
  }

  Future<TransportResponse> _send(
    String method,
    Uri url, {
    Map<String, String> headers = const {},
    String? body,
  }) async {
    try {
      return await _transport.send(
        method: method,
        url: url,
        headers: headers,
        body: body,
      );
    } on TransportFailure catch (failure) {
      throw mapTransportFailure(failure);
    }
  }

  Object? _tryDecode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  String _clamp(String value, int maxLength) =>
      value.length <= maxLength ? value : value.substring(0, maxLength);

  @override
  void close() => _transport.close();
}
