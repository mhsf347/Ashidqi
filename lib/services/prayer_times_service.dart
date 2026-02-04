import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/prayer_times_model.dart' as model;

/// Prayer Times Service using Aladhan API with Offline Fallback
class PrayerTimesService {
  /// Get prayer times using API -> Cache -> Offline Fallback
  static Future<model.PrayerTimes?> getPrayerTimes({
    String? city,
    String? country,
    bool useGPS = true,
    int? methodId,
    String?
    tune, // Format: Imsak,Fajr,Sunrise,Dhuhr,Asr,Sunset,Maghrib,Isha,Midnight
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Determine Location
    Coordinates? coordinates;
    String locationName = city ?? 'Lokasi Saya';

    // GPS Mode
    if (useGPS || city == null || city.isEmpty) {
      Position? position = await _determinePosition();
      if (position != null) {
        coordinates = Coordinates(position.latitude, position.longitude);
        try {
          // Reverse Geocode
          List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          ).timeout(const Duration(seconds: 3));

          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            locationName =
                place.locality ?? place.subAdministrativeArea ?? 'Lokasi GPS';
            // Store for potential API fallback if needed
            if (place.locality != null) city = place.locality;
          }
        } catch (_) {}
      }
    }
    // Manual Mode
    else {
      try {
        List<Location> locations = await locationFromAddress(
          '$city, $country',
        ).timeout(const Duration(seconds: 3));
        if (locations.isNotEmpty) {
          coordinates = Coordinates(
            locations.first.latitude,
            locations.first.longitude,
          );
        }
      } catch (_) {}
    }

    // Default Jakarta if all else fails
    coordinates ??= Coordinates(-6.2088, 106.8456);

    // 2. Prepare Parameters
    // Default Method: Kemenag RI (20) if not provided
    final int finalMethodId = methodId ?? 20;
    // Default Tune: 0s if not provided
    final String finalTune = tune ?? '0,0,0,0,0,0,0,0,0';

    final dateStr = DateFormat('dd-MM-yyyy').format(DateTime.now());

    // Cache Key: Includes parameters to invalidate on change
    // Escape tune string for key safety
    final tuneKey = finalTune.replaceAll(',', '_');
    final cacheKey =
        'cached_prayer_times_${DateTime.now().day}_${finalMethodId}_$tuneKey';

    // 2b. Try Cache First (Optimization)
    // Note: Original code tried API first. Better to try cache first if parameters match?
    // Actually, API first ensures accuracy, but if we want offline-first feel...
    // Let's stick to API First as users want to fetch data, but fallback to cache.
    // However, if settings change, cacheKey changes, so we won't hit old cache. Good.

    // 3. Try Fetching from API
    try {
      String urlStr =
          'http://api.aladhan.com/v1/timings/$dateStr'
          '?latitude=${coordinates.latitude}&longitude=${coordinates.longitude}'
          '&method=$finalMethodId'
          '&tune=$finalTune';

      final url = Uri.parse(urlStr);

      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final timings = data['data']['timings'];
        final dateData = data['data']['date'];

        // Cache this successful response
        prefs.setString(cacheKey, response.body);
        prefs.setString('cached_prayer_city', locationName);

        return model.PrayerTimes(
          fajr: timings['Fajr'],
          sunrise: timings['Sunrise'],
          dhuhr: timings['Dhuhr'],
          asr: timings['Asr'],
          maghrib: timings['Maghrib'],
          isha: timings['Isha'],
          date: dateData['gregorian']['date'],
          hijriDate:
              '${dateData['hijri']['day']} ${dateData['hijri']['month']['en']} ${dateData['hijri']['year']} H',
          city: locationName,
        );
      }
    } catch (e) {
      debugPrint('API Error: $e');
    }

    // 4. Fallback: Try Cache
    try {
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final data = json.decode(cached);
        final timings = data['data']['timings'];
        final dateData = data['data']['date'];

        final cachedCity =
            prefs.getString('cached_prayer_city') ?? locationName;

        return model.PrayerTimes(
          fajr: timings['Fajr'],
          sunrise: timings['Sunrise'],
          dhuhr: timings['Dhuhr'],
          asr: timings['Asr'],
          maghrib: timings['Maghrib'],
          isha: timings['Isha'],
          date: dateData['gregorian']['date'],
          hijriDate:
              '${dateData['hijri']['day']} ${dateData['hijri']['month']['en']} ${dateData['hijri']['year']} H',
          city: cachedCity,
        );
      }
    } catch (_) {}

    // 5. Default Fallback: Offline Calculation (Adhan Package)
    // IMPORTANT: Adhan package also supports params, but mapping API method ID to Adhan params is complex.
    // For now we use Singapore/Standard as hard fallback if everything fails.
    final params = CalculationMethod.singapore.getParameters();
    params.madhab = Madhab.shafi;
    // Apply basic offset if possible? Adhan params.adjustments is available.
    // Tune string parsing to adjustments...
    // tune format: Imsak,Fajr,Sunrise,Dhuhr,Asr,Sunset,Maghrib,Isha,Midnight
    // Adhan adjustments: fajr, sunrise, dhuhr, asr, maghrib, isha
    if (tune != null) {
      final parts = tune.split(',');
      if (parts.length >= 8) {
        params.adjustments.fajr = int.tryParse(parts[1]) ?? 0;
        params.adjustments.sunrise = int.tryParse(parts[2]) ?? 0;
        params.adjustments.dhuhr = int.tryParse(parts[3]) ?? 0;
        params.adjustments.asr = int.tryParse(parts[4]) ?? 0;
        params.adjustments.maghrib = int.tryParse(parts[6]) ?? 0;
        params.adjustments.isha = int.tryParse(parts[7]) ?? 0;
      }
    }

    final now = DateTime.now();
    final prayerTimes = PrayerTimes(
      coordinates,
      DateComponents.from(now),
      params,
    );
    final hDate = HijriCalendar.fromDate(now);

    return model.PrayerTimes(
      fajr: _formatTime(prayerTimes.fajr),
      sunrise: _formatTime(prayerTimes.sunrise),
      dhuhr: _formatTime(prayerTimes.dhuhr),
      asr: _formatTime(prayerTimes.asr),
      maghrib: _formatTime(prayerTimes.maghrib),
      isha: _formatTime(prayerTimes.isha),
      date: '${now.day}-${now.month}-${now.year}',
      hijriDate: '${hDate.hDay} ${hDate.longMonthName} ${hDate.hYear} H',
      city: locationName,
    );
  }

  static int getMethodIdFromName(String name) {
    switch (name) {
      case 'Muslim World League':
        return 3;
      case 'Egyptian General Authority':
        return 5;
      case 'Makkah (Umm al-Qura)':
        return 4;
      case 'Singapore':
        return 11;
      case 'Kemenag RI':
      default:
        return 20; // Kemenag ID
    }
  }

  static String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Get Qibla Direction from Aladhan API
  static Future<double?> getQiblaDirection(double lat, double long) async {
    try {
      final url = Uri.parse('http://api.aladhan.com/v1/qibla/$lat/$long');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['data']['direction'] as num).toDouble();
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching Qibla direction: $e');
      return null;
    }
  }

  static Future<Position?> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      return null;
    }
  }
}
