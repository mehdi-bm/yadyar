import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:provider/provider.dart';

import 'constants/app_constants.dart';
import 'providers/bills_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/shopping_provider.dart';
import 'screens/bills/bills_list_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/notes/notes_list_screen.dart';
import 'screens/shopping/shopping_lists_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestPermissionOnFirstLaunch();
  runApp(const YadyarApp());
}

class YadyarApp extends StatelessWidget {
  const YadyarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => BillsProvider()),
        ChangeNotifierProvider(create: (_) => ShoppingProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppConstants.primaryColor,
          ),
          scaffoldBackgroundColor: AppConstants.backgroundColor,
        ),
        locale: const Locale('fa', 'IR'),
        supportedLocales: const [Locale('fa', 'IR')],
        localizationsDelegates: const [
          PersianMaterialLocalizations.delegate,
          PersianCupertinoLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HomeScreen(),
      ),
    );
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: _selectTab,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'داشبورد',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note_outlined),
            activeIcon: Icon(Icons.note),
            label: 'یادداشت',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'قبض‌ها',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'خرید',
          ),
        ],
      ),
    );
  }
}
