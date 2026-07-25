import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants/app_constants.dart';
import 'providers/bills_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/shopping_provider.dart';
import 'screens/bills/bills_list_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/notes/notes_list_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/shopping/shopping_lists_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  final themeController = await ThemeController.load();
  final preferences = await SharedPreferences.getInstance();
  final onboardingComplete =
      preferences.getBool(OnboardingScreen.preferenceKey) ?? false;
  runApp(
    YadyarApp(
      themeController: themeController,
      onboardingComplete: onboardingComplete,
    ),
  );
}

class YadyarApp extends StatelessWidget {
  const YadyarApp({
    super.key,
    this.themeController,
    this.onboardingComplete = true,
  });

  final ThemeController? themeController;
  final bool onboardingComplete;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => themeController ?? ThemeController(),
        ),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => BillsProvider()),
        ChangeNotifierProvider(create: (_) => ShoppingProvider()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, controller, _) => MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: controller.themeMode,
          locale: const Locale('fa', 'IR'),
          supportedLocales: const [Locale('fa', 'IR')],
          localizationsDelegates: const [
            PersianMaterialLocalizations.delegate,
            PersianCupertinoLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: LaunchGate(onboardingComplete: onboardingComplete),
        ),
      ),
    );
  }
}

class LaunchGate extends StatefulWidget {
  const LaunchGate({super.key, required this.onboardingComplete});

  final bool onboardingComplete;

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  bool _showSplash = true;
  late bool _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _onboardingComplete = widget.onboardingComplete;
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onFinished: () => setState(() => _showSplash = false),
      );
    }
    if (!_onboardingComplete) {
      return OnboardingScreen(
        onComplete: () => setState(() => _onboardingComplete = true),
      );
    }
    return const HomeScreen();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final _dashboardKey = GlobalKey<DashboardScreenState>();

  // هر تب Scaffold و AppBar مخصوص به خودش را دارد (نیاز صفحه یادداشت‌ها به
  // نوار جستجوی داخل بدنه، و نیاز آینده صفحات دیگر به اکشن‌های AppBar خاص خودشان).
  void _selectTab(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) _dashboardKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardScreen(key: _dashboardKey, onNavigateToTab: _selectTab),
      const NotesListScreen(),
      const BillsListScreen(),
      const ShoppingListsScreen(),
    ];
    return Scaffold(
      body: tabs[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'داشبورد',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_outlined),
            selectedIcon: Icon(Icons.note),
            label: 'یادداشت',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'قبض‌ها',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'خرید',
          ),
        ],
      ),
    );
  }
}
