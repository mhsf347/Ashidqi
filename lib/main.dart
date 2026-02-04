import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/theme/app_theme.dart';
import 'providers/prayer_settings_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';

import 'widgets/app_bottom_nav_bar.dart';

// Screens
import 'screens/splash/splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/prayer_times/prayer_times_screen.dart';
import 'screens/quran/quran_list_screen.dart';
import 'screens/tasbih/tasbih_screen.dart';
import 'screens/qibla/qibla_screen.dart';
import 'screens/mosque_map/mosque_map_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/hadith/hadith_screen.dart';
import 'screens/fasting/fasting_calendar_screen.dart';
import 'screens/doa/daily_doa_screen.dart';
import 'screens/bookmarks/bookmark_list_screen.dart';
import 'screens/notification/adzan_notification_screen.dart';
import 'screens/settings/donation_screen.dart';
import 'screens/settings/license_screen.dart';
import 'screens/settings/contributor_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  // Initialize Notification Service (Fix LateInitializationError)
  await NotificationService().init();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => PrayerSettingsProvider()..init()),
      ],
      child: const AshidqiApp(),
    ),
  );
}

/// Ashidqi - Islamic Daily Worship App
/// A beautiful and professional Islamic app for daily worship activities
class AshidqiApp extends StatelessWidget {
  const AshidqiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Ashidqi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashScreen(),
      routes: {
        '/main': (context) => const MainNavigationScreen(),
        '/home': (context) => const HomeScreen(),
        '/prayer-times': (context) => const PrayerTimesScreen(),
        '/quran': (context) => const QuranListScreen(),
        '/tasbih': (context) => const TasbihScreen(),
        '/qibla': (context) => const QiblaScreen(),
        '/mosque-map': (context) => const MosqueMapScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/hadith': (context) => const HadithScreen(),
        '/fasting': (context) => const FastingCalendarScreen(),
        '/doa': (context) => const DailyDoaScreen(),
        '/bookmarks': (context) => const BookmarkListScreen(),
        '/adzan-notification': (context) => const AdzanNotificationScreen(),
        '/donation': (context) => const DonationScreen(),
        '/license': (context) => const LicenseScreen(),
        '/contributor': (context) => const ContributorScreen(),
      },
    );
  }
}

/// Main Navigation Screen with Bottom Navigation Bar
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const PrayerTimesScreen(),
    const QuranListScreen(),
    const HadithScreen(),
    const FastingCalendarScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          HapticFeedback.selectionClick();
        },
      ),
    );
  }
}
