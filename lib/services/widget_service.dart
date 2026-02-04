import 'package:home_widget/home_widget.dart';
import 'package:flutter/foundation.dart';
import '../models/prayer_times_model.dart';

class WidgetService {
  static const String _androidWidgetName = 'PrayerTimesWidget';

  static Future<void> updateWidget(PrayerTimes prayerTimes) async {
    try {
      final nextPrayer = prayerTimes.getNextPrayer();
      final name = nextPrayer?['name'] ?? 'Loading';
      final time = nextPrayer?['time'] ?? '--:--';
      final city = prayerTimes.city.isEmpty ? 'Lokasi' : prayerTimes.city;

      await HomeWidget.saveWidgetData<String>('prayer_name', name);
      await HomeWidget.saveWidgetData<String>('prayer_time', time);
      await HomeWidget.saveWidgetData<String>('location', city);

      await HomeWidget.updateWidget(androidName: _androidWidgetName);
      debugPrint('Widget Updated: $name at $time');
    } catch (e) {
      debugPrint('Error updating widget: $e');
    }
  }
}
