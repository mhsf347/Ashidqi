import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_times_model.dart';
import '../services/prayer_times_service.dart';
import '../services/notification_service.dart';

class PrayerSettingsProvider extends ChangeNotifier {
  PrayerTimes? _prayerTimes;
  bool _isLoading = true;

  // Settings State
  String _calculationMethod = 'Kemenag RI';
  String _manualCity = 'Jakarta';
  String _manualCountry = 'Indonesia';
  bool _useGPS = true;

  // Offsets (Tunes)
  final Map<String, int> _offsets = {
    'Subuh': 0,
    'Dzuhur': 0,
    'Ashar': 0,
    'Maghrib': 0,
    'Isya': 0,
  };

  // Notifications
  final Map<String, bool> _adzanEnabled = {
    'Subuh': true,
    'Dzuhur': true,
    'Ashar': true,
    'Maghrib': true,
    'Isya': true,
  };

  // Per-prayer Reminder (Minutes before)
  final Map<String, double> _reminderMinutes = {
    'Subuh': 15,
    'Dzuhur': 5,
    'Ashar': 10,
    'Maghrib': 5,
    'Isya': 5,
  };

  // Per-prayer Sound
  final Map<String, String> _prayerSounds = {
    'Subuh': 'Makkah',
    'Dzuhur': 'Madinah',
    'Ashar': 'Makkah',
    'Maghrib': 'Mishary Rashid',
    'Isya': 'Makkah',
  };

  String _selectedMuadzin =
      'makkah'; // Global default if not specified per prayer

  // Getters
  PrayerTimes? get prayerTimes => _prayerTimes;
  bool get isLoading => _isLoading;
  String get calculationMethod => _calculationMethod;
  String get manualCity => _manualCity;
  String get manualCountry => _manualCountry;
  bool get useGPS => _useGPS;

  Map<String, int> get offsets => _offsets;
  Map<String, bool> get adzanEnabled => _adzanEnabled;
  Map<String, double> get reminderMinutes => _reminderMinutes;
  Map<String, String> get prayerSounds => _prayerSounds;
  String get selectedMuadzin => _selectedMuadzin;

  Future<void> init() async {
    await _loadSettings();
    await fetchPrayerTimes();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _calculationMethod = prefs.getString('calculation_method') ?? 'Kemenag RI';
    _manualCity = prefs.getString('manual_city') ?? 'Jakarta';
    _manualCountry = prefs.getString('manual_country') ?? 'Indonesia';
    _useGPS = prefs.getBool('use_gps') ?? true;
    _selectedMuadzin = prefs.getString('selected_muadzin') ?? 'makkah';

    // Load Maps
    for (var p in ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya']) {
      final key = p.toLowerCase();
      _offsets[p] = prefs.getInt('offset_$key') ?? 0;
      _adzanEnabled[p] = prefs.getBool('adzan_$key') ?? true;
      _reminderMinutes[p] =
          prefs.getDouble('reminder_$key') ?? (p == 'Subuh' ? 15.0 : 5.0);
      _prayerSounds[p] = prefs.getString('sound_$key') ?? 'Makkah';
    }

    notifyListeners();
  }

  Future<void> fetchPrayerTimes() async {
    _isLoading = true;
    notifyListeners();

    try {
      final tune =
          '0,${_offsets['Subuh']},0,${_offsets['Dzuhur']},${_offsets['Ashar']},0,${_offsets['Maghrib']},${_offsets['Isya']},0';
      final methodId = PrayerTimesService.getMethodIdFromName(
        _calculationMethod,
      );

      _prayerTimes = await PrayerTimesService.getPrayerTimes(
        city: _useGPS ? null : _manualCity,
        country: _useGPS ? null : _manualCountry,
        useGPS: _useGPS,
        methodId: methodId,
        tune: tune,
      );

      _scheduleNotifications();
    } catch (e) {
      debugPrint('Error fetching prayer times in provider: $e');

      // Fallback: Try fetching with defaults (like Home Screen)
      try {
        debugPrint('Attempting fallback fetch...');
        _prayerTimes = await PrayerTimesService.getPrayerTimes();
        _scheduleNotifications();
      } catch (fallbackError) {
        debugPrint('Fallback failed: $fallbackError');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- UPDATERS ---

  Future<void> updateCalculationMethod(String method) async {
    _calculationMethod = method;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('calculation_method', method);
    notifyListeners();
    await fetchPrayerTimes();
  }

  Future<void> updateLocationMode(
    bool usingGPS, {
    String? city,
    String? country,
  }) async {
    _useGPS = usingGPS;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_gps', usingGPS);

    if (!usingGPS && city != null) {
      _manualCity = city;
      _manualCountry = country ?? 'Indonesia';
      await prefs.setString('manual_city', _manualCity);
      await prefs.setString('manual_country', _manualCountry);
    }
    notifyListeners();
    await fetchPrayerTimes();
  }

  Future<void> updateOffset(String prayer, int minutes) async {
    _offsets[prayer] = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('offset_${prayer.toLowerCase()}', minutes);
    notifyListeners();
    await fetchPrayerTimes();
  }

  Future<void> toggleAdzan(String prayer, bool enabled) async {
    _adzanEnabled[prayer] = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('adzan_${prayer.toLowerCase()}', enabled);
    notifyListeners();
    _scheduleNotifications();
  }

  Future<void> updateReminder(String prayer, double minutes) async {
    _reminderMinutes[prayer] = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('reminder_${prayer.toLowerCase()}', minutes);
    notifyListeners();
    _scheduleNotifications();
  }

  // Future<void> updateSound(String prayer, String soundName) async { ... } // Belum kepakai, pakai Global Muadzin dulu.

  Future<void> updateGlobalMuadzin(String muadzinId) async {
    _selectedMuadzin = muadzinId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_muadzin', muadzinId);
    notifyListeners();
    _scheduleNotifications();
  }

  Future<void> _scheduleNotifications() async {
    if (_prayerTimes == null) return;

    final service = NotificationService();
    await service.cancelAllNotifications();

    final prayers = _prayerTimes!.allPrayers;
    int id = 0;

    for (var p in prayers) {
      final name = p['name']!; // Subuh, Dzuhur...
      final timeStr = p['time']!;

      if (_adzanEnabled[name] != true) continue;

      final parts = timeStr.split(':');
      final now = DateTime.now();
      var scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );

      // Jika waktu sudah lewat hari ini, jangan schedule
      // Kita tidak schedule besok karena jadwal mungkin geser.
      // Solusinya: Schedule ulang tiap buka app / jam 12 malam via workmanager (next step).
      if (scheduledTime.isBefore(now)) continue;

      // 1. Schedules Adzan
      await service.schedulePrayerNotification(
        id: id++,
        title: 'Waktunya $name',
        body: 'Saatnya menunaikan sholat $name',
        scheduledTime: scheduledTime,
        soundName: _selectedMuadzin,
      );

      // 2. Reminder
      final reminder = _reminderMinutes[name] ?? 0;
      if (reminder > 0) {
        final reminderTime = scheduledTime.subtract(
          Duration(minutes: reminder.toInt()),
        );
        if (reminderTime.isAfter(now)) {
          await service.schedulePrayerNotification(
            id: id++,
            title: 'Persiapan $name',
            body: '$name akan masuk dalam ${reminder.toInt()} menit',
            scheduledTime: reminderTime,
          );
        }
      }
    }
  }
}
