import 'secure_http_transport.dart';

/// خطای کاربرپسند فارسی که هرگز جزئیات داخلی سرور یا شبکه را افشا نمی‌کند.
class AdsApiException implements Exception {
  const AdsApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

const notConfiguredException = AdsApiException(
  'این قابلیت در حال حاضر در دسترس نیست.',
);
const invalidResponseException = AdsApiException(
  'پاسخ سرور معتبر نیست؛ دوباره تلاش کنید.',
);
const networkErrorException = AdsApiException(
  'اتصال اینترنت را بررسی و دوباره تلاش کنید.',
);
const unsafeRedirectException = AdsApiException(
  'ارتباط امن برنامه با سرور برقرار نشد؛ دوباره تلاش کنید.',
);

AdsApiException mapHttpStatus(int statusCode) {
  switch (statusCode) {
    case 400:
      return const AdsApiException(
        'اطلاعات واردشده معتبر نیست؛ فیلدها را بررسی کنید.',
      );
    case 401:
    case 403:
      return const AdsApiException(
        'ارتباط امن برنامه با سرور تأیید نشد؛ نسخه برنامه را به‌روزرسانی کنید.',
      );
    case 429:
      return const AdsApiException(
        'تعداد درخواست‌ها زیاد است؛ کمی بعد دوباره تلاش کنید.',
      );
    default:
      return const AdsApiException(
        'خطایی در ارتباط با سرور رخ داد؛ دوباره تلاش کنید.',
      );
  }
}

AdsApiException mapTransportFailure(TransportFailure failure) {
  switch (failure.kind) {
    case TransportFailureKind.timeout:
    case TransportFailureKind.network:
      return networkErrorException;
    case TransportFailureKind.unsafeRedirect:
      return unsafeRedirectException;
    case TransportFailureKind.responseTooLarge:
      return invalidResponseException;
  }
}
