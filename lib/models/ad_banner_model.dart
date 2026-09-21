import 'package:flutter/foundation.dart';

/// یک بنر تبلیغاتی فعال دریافت‌شده از API پارسیک.
@immutable
class AdBannerModel {
  const AdBannerModel({
    required this.bannerId,
    required this.imageUrl,
    required this.destinationUrl,
    this.bannerTitle = '',
    this.campaignTitle = '',
    this.sectionName = '',
    this.sectionCode = '',
  });

  final String bannerId;
  final String bannerTitle;
  final Uri imageUrl;
  final Uri destinationUrl;
  final String campaignTitle;
  final String sectionName;
  final String sectionCode;

  /// آیتم بدون bannerId یا بدون URL قابل resolve را رد می‌کند.
  static AdBannerModel? tryParse(
    Map<String, dynamic> json, {
    required Uri? Function(String value) resolveUrl,
  }) {
    final bannerId = _stringOf(json['bannerId']).trim();
    if (bannerId.isEmpty) return null;

    final imageUrl = resolveUrl(_stringOf(json['imageUrl']));
    final destinationUrl = resolveUrl(_stringOf(json['destinationUrl']));
    if (imageUrl == null || destinationUrl == null) return null;

    return AdBannerModel(
      bannerId: bannerId,
      imageUrl: imageUrl,
      destinationUrl: destinationUrl,
      bannerTitle: _stringOf(json['bannerTitle']).trim(),
      campaignTitle: _stringOf(json['campaignTitle']).trim(),
      sectionName: _stringOf(json['sectionName']).trim(),
      sectionCode: _stringOf(json['sectionCode']).trim(),
    );
  }

  static String _stringOf(Object? value) => value?.toString() ?? '';

  @override
  bool operator ==(Object other) =>
      other is AdBannerModel && other.bannerId == bannerId;

  @override
  int get hashCode => bannerId.hashCode;
}
