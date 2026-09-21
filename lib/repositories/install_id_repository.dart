import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// شناسه ناشناس و پایدار همین نصب برای رهگیری کلیک بنر؛ هرگز از Android ID،
/// IMEI یا شماره موبایل ساخته نمی‌شود.
class InstallIdRepository {
  InstallIdRepository({SharedPreferences? preferences})
    : _preferencesOverride = preferences;

  static const _prefsKey = 'ads_install_id';

  final SharedPreferences? _preferencesOverride;
  Future<String>? _pending;

  Future<String> getOrCreateId() async {
    _pending ??= _load();
    try {
      return await _pending!;
    } catch (_) {
      _pending = null;
      rethrow;
    }
  }

  Future<String> _load() async {
    final prefs = _preferencesOverride ?? await SharedPreferences.getInstance();
    final existing = prefs.getString(_prefsKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = _generateHexId();
    await prefs.setString(_prefsKey, generated);
    return generated;
  }

  String _generateHexId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
