import 'package:flutter/widgets.dart';

import '../config/ads_config.dart';
import '../models/ad_banner_model.dart';
import '../repositories/install_id_repository.dart';
import '../services/ads_api_exception.dart';
import '../services/advertising_gateway.dart';
import '../services/advertising_service.dart';

/// State بنر تبلیغاتی داشبورد: دریافت، cache حدود ۲۰ دقیقه‌ای، refresh روی
/// resumed شدن اپ (فقط وقتی cache منقضی شده) و ثبت کلیک با جلوگیری از تکرار.
class AdBannerController extends ChangeNotifier with WidgetsBindingObserver {
  AdBannerController({
    AdvertisingGateway? gateway,
    InstallIdRepository? installIdRepository,
    Duration cacheDuration = const Duration(minutes: 20),
  }) : _gateway =
           gateway ?? AdvertisingService(config: AdsConfig.fromEnvironment()),
       _installIdRepository = installIdRepository ?? InstallIdRepository(),
       _cacheDuration = cacheDuration {
    WidgetsBinding.instance.addObserver(this);
  }

  final AdvertisingGateway _gateway;
  final InstallIdRepository _installIdRepository;
  final Duration _cacheDuration;

  List<AdBannerModel> _banners = const [];
  bool _initialLoading = true;
  bool _refreshing = false;
  int _currentIndex = 0;
  String? _errorMessage;
  DateTime? _lastSuccessfulFetch;
  bool _isOpeningLink = false;
  Future<void>? _pendingFetch;
  String? _pendingClickBannerId;
  bool _disposed = false;

  List<AdBannerModel> get banners => _banners;
  bool get initialLoading => _initialLoading;
  bool get refreshing => _refreshing;
  int get currentIndex => _currentIndex;
  String? get errorMessage => _errorMessage;
  DateTime? get lastSuccessfulFetch => _lastSuccessfulFetch;
  bool get isOpeningLink => _isOpeningLink;
  bool get isConfigured => _gateway.isConfigured;

  bool get _cacheExpired {
    final last = _lastSuccessfulFetch;
    if (last == null) return true;
    return DateTime.now().difference(last) > _cacheDuration;
  }

  Future<void> loadInitial() => fetch();

  /// درخواست هم‌زمان refresh را deduplicate می‌کند؛ با force=true حتی اگر
  /// cache معتبر باشد دوباره fetch می‌کند.
  Future<void> fetch({bool force = false}) {
    if (!_gateway.isConfigured) {
      _initialLoading = false;
      _safeNotify();
      return Future.value();
    }
    if (!force && !_cacheExpired && _banners.isNotEmpty) {
      _initialLoading = false;
      return Future.value();
    }
    return _pendingFetch ??= _doFetch();
  }

  Future<void> _doFetch() async {
    final isFirstLoad = _banners.isEmpty;
    if (isFirstLoad) {
      _initialLoading = true;
    } else {
      _refreshing = true;
    }
    _errorMessage = null;
    _safeNotify();
    try {
      final banners = await _gateway.fetchBanners();
      _banners = banners;
      _currentIndex = 0;
      _lastSuccessfulFetch = DateTime.now();
      _errorMessage = null;
    } on AdsApiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'دریافت تبلیغات ناموفق بود';
    } finally {
      _initialLoading = false;
      _refreshing = false;
      _pendingFetch = null;
      _safeNotify();
    }
  }

  void setPageIndex(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    _safeNotify();
  }

  /// ثبت کلیک را انجام می‌دهد و مقصد نهایی برای باز کردن را برمی‌گرداند؛ اگر
  /// ثبت کلیک شکست بخورد، همچنان destinationUrl خود بنر را برمی‌گرداند.
  Future<Uri?> handleBannerTap(AdBannerModel banner) async {
    if (_isOpeningLink || _pendingClickBannerId == banner.bannerId) return null;
    _isOpeningLink = true;
    _pendingClickBannerId = banner.bannerId;
    _safeNotify();
    try {
      final externalUserId = await _installIdRepository.getOrCreateId();
      final receipt = await _gateway.registerClick(
        bannerId: banner.bannerId,
        externalUserId: externalUserId,
      );
      return receipt.destinationUrl;
    } catch (_) {
      return banner.destinationUrl;
    } finally {
      _isOpeningLink = false;
      _pendingClickBannerId = null;
      _safeNotify();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _cacheExpired) {
      fetch();
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _gateway.close();
    super.dispose();
  }
}
