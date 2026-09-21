import 'dart:convert';

import '../config/ads_config.dart';
import '../models/support_receipt.dart';
import 'ads_api_exception.dart';
import 'app_support_gateway.dart';
import 'secure_http_transport.dart';

class AppSupportService implements AppSupportGateway {
  AppSupportService({required AdsConfig config, SecureHttpTransport? transport})
    : _config = config,
      _transport = transport ?? SecureHttpTransport();

  final AdsConfig _config;
  final SecureHttpTransport _transport;

  @override
  bool get isConfigured => _config.isConfigured;

  @override
  Future<SupportReceipt> submitErrorReport({required String description}) {
    return _submit(
      path: '/api/public/app-submissions/error-reports',
      payload: {'description': description.trim()},
    );
  }

  @override
  Future<SupportReceipt> submitAdvertisingRequest({
    required String fullName,
    required String phoneNumber,
    required String province,
    required String city,
    required String details,
  }) {
    return _submit(
      path: '/api/public/app-submissions/advertising-requests',
      payload: {
        'fullName': fullName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'province': province.trim(),
        'city': city.trim(),
        'details': details.trim(),
      },
    );
  }

  Future<SupportReceipt> _submit({
    required String path,
    required Map<String, String> payload,
  }) async {
    if (!isConfigured) throw notConfiguredException;

    final uri = _config.baseUri.resolve(path);
    final TransportResponse response;
    try {
      response = await _transport.send(
        method: 'POST',
        url: uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json; charset=utf-8',
          ..._config.authHeaders,
        },
        body: jsonEncode(payload),
      );
    } on TransportFailure catch (failure) {
      throw mapTransportFailure(failure);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw mapHttpStatus(response.statusCode);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw invalidResponseException;
    }
    if (decoded is! Map<String, dynamic>) throw invalidResponseException;

    final receipt = SupportReceipt.tryParse(decoded);
    if (receipt == null) throw invalidResponseException;
    return receipt;
  }

  @override
  void close() => _transport.close();
}
