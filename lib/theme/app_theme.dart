import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.success,
    required this.warning,
    required this.error,
  });

  final Color success;
  final Color warning;
  final Color error;

  @override
  AppStatusColors copyWith({Color? success, Color? warning, Color? error}) =>
      AppStatusColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        error: error ?? this.error,
      );

  @override
  AppStatusColors lerp(AppStatusColors? other, double t) {
    if (other == null) return this;
    return AppStatusColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

class AppTheme {
  AppTheme._();

  static final ThemeData light = _build(
    brightness: Brightness.light,
    seed: const Color(0xFF315C50),
    scaffold: const Color(0xFFF7F3E8),
    surface: const Color(0xFFFFFCF4),
    statusColors: const AppStatusColors(
      success: Color(0xFF2E7D32),
      warning: Color(0xFF8A5200),
      error: Color(0xFFC62828),
    ),
  );

  static final ThemeData dark = _build(
    brightness: Brightness.dark,
    seed: const Color(0xFF83B5A4),
    scaffold: const Color(0xFF121A17),
    surface: const Color(0xFF1B2521),
    statusColors: const AppStatusColors(
      success: Color(0xFF81C784),
      warning: Color(0xFFFFC46B),
      error: Color(0xFFEF9A9A),
    ),
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color seed,
    required Color scaffold,
    required Color surface,
    required AppStatusColors statusColors,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      surface: surface,
      error: statusColors.error,
    );
    final typography = Typography.material2021();
    final textTheme = (brightness == Brightness.dark
            ? typography.white
            : typography.black)
        .apply(fontFamily: 'Vazirmatn');
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Vazirmatn',
      materialTapTargetSize: MaterialTapTargetSize.padded,
      colorScheme: scheme,
      textTheme: textTheme.copyWith(
        bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
        bodyMedium: textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.45),
        labelLarge: textTheme.labelLarge?.copyWith(fontSize: 14),
      ),
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      cardColor: surface,
      extensions: [statusColors],
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: scheme.surfaceTint,
      ),
      cardTheme: CardThemeData(
        elevation: brightness == Brightness.dark ? 0 : 1,
        color: surface,
        surfaceTintColor: scheme.surfaceTint,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 3,
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: scheme.surfaceTint,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class ThemeController extends ChangeNotifier {
  ThemeController([this._themeMode = ThemeMode.system]);

  static const _preferenceKey = 'theme_mode';
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  static Future<ThemeController> load() async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_preferenceKey);
    var mode = ThemeMode.system;
    for (final candidate in ThemeMode.values) {
      if (candidate.name == saved) mode = candidate;
    }
    return ThemeController(mode);
  }

  Future<void> cycleThemeMode() async {
    _themeMode = switch (_themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, _themeMode.name);
  }
}

class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final (icon, label) = switch (controller.themeMode) {
      ThemeMode.system => (Icons.brightness_auto_outlined, 'تم سیستم'),
      ThemeMode.light => (Icons.light_mode_outlined, 'تم روشن'),
      ThemeMode.dark => (Icons.dark_mode_outlined, 'تم تیره'),
    };
    return IconButton(
      icon: Icon(icon),
      tooltip: '$label؛ تغییر تم',
      onPressed: controller.cycleThemeMode,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppStatusColors get statusColors =>
      Theme.of(this).extension<AppStatusColors>()!;
}
