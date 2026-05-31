import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import '../providers/prayer_settings_provider.dart';
import 'notification_service.dart';

const syncTaskName = "syncPrayerTimesTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint("Native called background task: $task");
      
      // Initialize core services needed for headless execution
      WidgetsFlutterBinding.ensureInitialized();
      await NotificationService().init();
      
      // Initialize PrayerSettingsProvider, which will load shared prefs
      // and implicitly call fetchPrayerTimes() and _scheduleNotifications() 
      // (which we just updated to schedule 7 days out).
      final provider = PrayerSettingsProvider();
      await provider.init();
      
      debugPrint("Background task completed successfully.");
      return Future.value(true);
    } catch (err) {
      debugPrint("Background task failed: $err");
      return Future.value(false);
    }
  });
}

class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, // Set to true to see debug notifications when task runs
    );
    
    // Register periodic task to run approximately every 24 hours
    // (Note: Android battery optimization might still delay this, 
    // but the 7-day schedule buffer ensures we don't miss alarms).
    await Workmanager().registerPeriodicTask(
      "1",
      syncTaskName,
      frequency: const Duration(hours: 24),
      initialDelay: const Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.connected, // Only run when internet is available to fetch new times
      ),
    );
  }
}
