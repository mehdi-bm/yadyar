import 'dart:async';
import 'dart:convert';
import 'dart:io';

enum TransportFailureKind { timeout, network, unsafeRedirect, responseTooLarge }

class TransportFailure implements Exception {
  const TransportFailure(this.kind, [this.message]);

  final TransportFailureKind kind;
  final String? message;

  @override
  String toString() => message ?? kind.toString();
}

class TransportResponse {
  const TransportResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

/// یک لایه نازک روی dart:io HttpClient که فقط ریدایرکت هم‌مبدأ را با سقف
/// مشخص دنبال می‌کند تا هدرهای امنیتی (کلیدهای API) هرگز به دامنه دیگری نشت
/// نکنند، و اندازه پاسخ را محدود می‌کند.
class SecureHttpTransport {
  SecureHttpTransport({
    HttpClient? client,
    this.maxRedirects = 3,
    this.maxResponseBytes = 2 * 1024 * 1024,
  }) : _client = client ?? (HttpClient()..autoUncompress = true);

  final HttpClient _client;
  final int maxRedirects;
  final int maxResponseBytes;

  Future<TransportResponse> send({
    required String method,
    required Uri url,
    Map<String, String> headers = const {},
    String? body,
    Duration connectTimeout = const Duration(seconds: 8),
    Duration receiveTimeout = const Duration(seconds: 12),
  }) async {
    var currentUrl = url;
    var redirects = 0;
    try {
      while (true) {
        final request = await _client
            .openUrl(method, currentUrl)
            .timeout(connectTimeout);
        request.followRedirects = false;
        request.persistentConnection = true;
        headers.forEach(request.headers.set);
        if (body != null) {
          final bytes = utf8.encode(body);
          request.headers.contentLength = bytes.length;
          request.add(bytes);
        }
        final response = await request.close().timeout(receiveTimeout);

        if (response.statusCode >= 300 && response.statusCode < 400) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>();
          if (location == null) {
            throw const TransportFailure(
              TransportFailureKind.unsafeRedirect,
              'ریدایرکت بدون مقصد معتبر',
            );
          }
          redirects++;
          if (redirects > maxRedirects) {
            throw const TransportFailure(
              TransportFailureKind.unsafeRedirect,
              'تعداد ریدایرکت‌ها بیش از حد مجاز است',
            );
          }
          final nextUrl = currentUrl.resolve(location);
          final sameOrigin =
              nextUrl.scheme == url.scheme &&
              nextUrl.host == url.host &&
              nextUrl.port == url.port;
          if (!sameOrigin) {
            throw const TransportFailure(
              TransportFailureKind.unsafeRedirect,
              'مقصد ریدایرکت هم‌مبدأ نیست',
            );
          }
          currentUrl = nextUrl;
          continue;
        }

        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > maxResponseBytes) {
            throw const TransportFailure(TransportFailureKind.responseTooLarge);
          }
        }
        return TransportResponse(
          statusCode: response.statusCode,
          body: utf8.decode(bytes, allowMalformed: true),
        );
      }
    } on TransportFailure {
      rethrow;
    } on TimeoutException {
      throw const TransportFailure(TransportFailureKind.timeout);
    } on SocketException {
      throw const TransportFailure(TransportFailureKind.network);
    } on HandshakeException {
      throw const TransportFailure(TransportFailureKind.network);
    } on HttpException {
      throw const TransportFailure(TransportFailureKind.network);
    }
  }

  void close({bool force = false}) => _client.close(force: force);
}
