/// پیکربندی سرویس تبلیغات پارسیک؛ مقادیر حساس فقط از --dart-define خوانده
/// می‌شوند و هرگز در سورس hardcode نمی‌شوند.
class AdsConfig {
  const AdsConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.externalAppApiKey,
    required this.appName,
    required this.platform,
    this.sectionCode = '',
    this.allowInsecureHttp = false,
  });

  factory AdsConfig.fromEnvironment() => const AdsConfig(
    baseUrl: String.fromEnvironment(
      'ADS_BASE_URL',
      defaultValue: 'https://ads.parsikonline.ir/',
    ),
    apiKey: String.fromEnvironment('ADS_API_KEY'),
    externalAppApiKey: String.fromEnvironment('ADS_EXTERNAL_APP_API_KEY'),
    appName: String.fromEnvironment('ADS_APP_NAME', defaultValue: 'yadyar'),
    platform: String.fromEnvironment('ADS_PLATFORM', defaultValue: 'Android'),
    sectionCode: String.fromEnvironment(
      'ADS_SECTION_CODE',
      defaultValue: '100',
    ),
    allowInsecureHttp: bool.fromEnvironment('ADS_ALLOW_INSECURE_HTTP'),
  );

  final String baseUrl;
  final String apiKey;
  final String externalAppApiKey;
  final String appName;
  final String platform;
  final String sectionCode;
  final bool allowInsecureHttp;

  bool get isConfigured =>
      apiKey.trim().isNotEmpty && externalAppApiKey.trim().isNotEmpty;

  Uri get baseUri => Uri.parse(baseUrl);

  Map<String, String> get authHeaders => {
    'X-API-KEY': apiKey,
    'X-EXTERNAL-APP-API-KEY': externalAppApiKey,
  };

  /// URL نسبی یا مطلق ورودی را نسبت به baseUrl resolve و اعتبارسنجی می‌کند؛
  /// فقط HTTPS در production و HTTP تنها با opt-in صریح محلی پذیرفته می‌شود.
  Uri? resolvePublicUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final Uri resolved;
    try {
      resolved = baseUri.resolve(trimmed);
    } on FormatException {
      return null;
    }
    if (resolved.scheme == 'https') return resolved;
    if (resolved.scheme == 'http' && allowInsecureHttp) return resolved;
    return null;
  }
}
