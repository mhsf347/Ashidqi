/// Prayer Times Model
class PrayerTimes {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String date;
  final String hijriDate;
  final String city;

  PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.date,
    required this.hijriDate,
    required this.city,
  });

  factory PrayerTimes.fromJson(Map<String, dynamic> json) {
    final timings = json['timings'] as Map<String, dynamic>;
    final date = json['date'] as Map<String, dynamic>;
    final hijri = date['hijri'] as Map<String, dynamic>;
    final gregorian = date['gregorian'] as Map<String, dynamic>;

    // Remove timezone info from times (e.g., "05:00 (WIB)" -> "05:00")
    String cleanTime(String time) {
      return time.split(' ').first;
    }

    return PrayerTimes(
      fajr: cleanTime(timings['Fajr'] ?? ''),
      sunrise: cleanTime(timings['Sunrise'] ?? ''),
      dhuhr: cleanTime(timings['Dhuhr'] ?? ''),
      asr: cleanTime(timings['Asr'] ?? ''),
      maghrib: cleanTime(timings['Maghrib'] ?? ''),
      isha: cleanTime(timings['Isha'] ?? ''),
      date: gregorian['date'] ?? '',
      hijriDate: '${hijri['day']} ${hijri['month']['en']} ${hijri['year']}',
      city: '',
    );
  }

  /// Get all prayers as a list for easy iteration
  List<Map<String, String>> get allPrayers => [
    {'name': 'Subuh', 'time': fajr, 'icon': 'sunrise'},
    {'name': 'Syuruq', 'time': sunrise, 'icon': 'sun'},
    {'name': 'Dzuhur', 'time': dhuhr, 'icon': 'sun_high'},
    {'name': 'Ashar', 'time': asr, 'icon': 'sun_low'},
    {'name': 'Maghrib', 'time': maghrib, 'icon': 'sunset'},
    {'name': 'Isya', 'time': isha, 'icon': 'moon'},
  ];

  /// Get next prayer based on current time
  Map<String, String>? getNextPrayer() {
    final now = DateTime.now();
    final prayers = allPrayers;

    for (var prayer in prayers) {
      final timeParts = prayer['time']!.split(':');
      final prayerTime = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      if (prayerTime.isAfter(now)) {
        return prayer;
      }
    }

    // If all prayers have passed, return Fajr for tomorrow
    return prayers.first;
  }

  /// Calculate time remaining until next prayer
  Duration getTimeUntilNextPrayer() {
    final nextPrayer = getNextPrayer();
    if (nextPrayer == null) return Duration.zero;

    final now = DateTime.now();
    final timeParts = nextPrayer['time']!.split(':');
    var prayerTime = DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );

    // If prayer time has passed, it's for tomorrow
    if (prayerTime.isBefore(now)) {
      prayerTime = prayerTime.add(const Duration(days: 1));
    }

    return prayerTime.difference(now);
  }

  /// Get specific prayer time by name
  String getPrayerTime(String name) {
    switch (name.toLowerCase()) {
      case 'subuh':
        return fajr;
      case 'syuruq':
        return sunrise;
      case 'dzuhur':
        return dhuhr;
      case 'ashar':
        return asr;
      case 'maghrib':
        return maghrib;
      case 'isya':
        return isha;
      default:
        return '--:--';
    }
  }
}
