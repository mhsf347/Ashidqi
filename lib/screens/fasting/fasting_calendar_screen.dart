import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';

/// Fasting Calendar Screen - Using Aladhan API for Hijri Calendar
/// Features: Calendar grid, Sunnah fasting highlights, stats, schedule list
class FastingCalendarScreen extends StatefulWidget {
  const FastingCalendarScreen({super.key});

  @override
  State<FastingCalendarScreen> createState() => _FastingCalendarScreenState();
}

class _FastingCalendarScreenState extends State<FastingCalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  // API Data
  Map<int, Map<String, dynamic>>? _hijriData; // day -> hijri info
  bool _isLoading = false;
  String _hijriMonthName = '';

  @override
  void initState() {
    super.initState();
    HijriCalendar.setLocal('id'); // Fallback locale
    _fetchHijriCalendar(_currentMonth.month, _currentMonth.year);
  }

  /// Fetch Hijri calendar data from Aladhan API
  Future<void> _fetchHijriCalendar(int month, int year) async {
    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'hijri_calendar_${month}_$year';

    try {
      // Try API first
      final url = Uri.parse(
        'http://api.aladhan.com/v1/gToHCalendar/$month/$year',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _parseHijriData(data);
        // Cache the response
        prefs.setString(cacheKey, response.body);
        setState(() => _isLoading = false);
        return;
      }
    } catch (e) {
      debugPrint('Aladhan Calendar API Error: $e');
    }

    // Fallback: Try cache
    try {
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final data = json.decode(cached);
        _parseHijriData(data);
        setState(() => _isLoading = false);
        return;
      }
    } catch (_) {}

    // Final fallback: use local package
    setState(() {
      _hijriData = null;
      _isLoading = false;
    });
  }

  void _parseHijriData(Map<String, dynamic> data) {
    final days = data['data'] as List;
    final Map<int, Map<String, dynamic>> result = {};

    for (var dayData in days) {
      final gregorian = dayData['gregorian'];
      final hijri = dayData['hijri'];
      // Handle both string and int values from API
      final gDay = gregorian['day'];
      final day = gDay is int ? gDay : int.parse(gDay.toString());

      final hDay = hijri['day'];
      final hMonth = hijri['month']['number'];
      final hYear = hijri['year'];

      result[day] = {
        'hDay': hDay is int ? hDay : int.parse(hDay.toString()),
        'hMonth': hMonth is int ? hMonth : int.parse(hMonth.toString()),
        'hMonthName': hijri['month']['en'] ?? '-',
        'hMonthNameAr': hijri['month']['ar'] ?? '',
        'hYear': hYear is int ? hYear : int.parse(hYear.toString()),
        'weekday': gregorian['weekday']['en'] ?? '',
      };
    }

    // Get the hijri month name from the middle of the month
    if (result.isNotEmpty) {
      final midDay = result[15] ?? result.values.first;
      _hijriMonthName = '${midDay['hMonthName']} ${midDay['hYear']}';
    }

    _hijriData = result;
  }

  /// Get Hijri info for a specific day (from API or fallback)
  Map<String, dynamic> _getHijriInfo(DateTime date) {
    if (_hijriData != null && _hijriData!.containsKey(date.day)) {
      return _hijriData![date.day]!;
    }

    // Fallback to local package
    try {
      final hijri = HijriCalendar.fromDate(date);
      return {
        'hDay': hijri.hDay,
        'hMonth': hijri.hMonth,
        'hMonthName': hijri.longMonthName,
        'hYear': hijri.hYear,
      };
    } catch (e) {
      return {'hDay': 1, 'hMonth': 1, 'hMonthName': '-', 'hYear': 1446};
    }
  }

  // Determine fasting type for a specific date
  FastingType? _getFastingType(DateTime date) {
    final hijri = _getHijriInfo(date);
    final hMonth = hijri['hMonth'] as int;
    final hDay = hijri['hDay'] as int;

    // Ramadan
    if (hMonth == 9) return FastingType.wajib;

    // Arafah (9 Dzulhijjah)
    if (hMonth == 12 && hDay == 9) return FastingType.sunnahMuakkad;

    // Tasu'a & Ashura (9, 10 Muharram)
    if (hMonth == 1 && (hDay == 9 || hDay == 10)) {
      return FastingType.sunnah;
    }

    // Ayyamul Bidh (13, 14, 15) - except if 13 Dzulhijjah (Tasyrik - Forbidden)
    if (hDay >= 13 && hDay <= 15) {
      if (hMonth == 12 && hDay == 13) {
        return FastingType.forbidden; // Hari Tasyrik
      }
      return FastingType.sunnah;
    }

    // Monday & Thursday
    if (date.weekday == DateTime.monday || date.weekday == DateTime.thursday) {
      // Check for forbidden days (Eid & Tasyrik)
      if (_isForbidden(hMonth, hDay)) return FastingType.forbidden;
      return FastingType.sunnah;
    }

    // Forbidden Days (Eid & Tasyrik)
    if (_isForbidden(hMonth, hDay)) return FastingType.forbidden;

    return null;
  }

  bool _isForbidden(int hMonth, int hDay) {
    // Eid al-Fitr (1 Shawwal)
    if (hMonth == 10 && hDay == 1) return true;

    // Eid al-Adha (10 Dzulhijjah)
    if (hMonth == 12 && hDay == 10) return true;

    // Days of Tasyrik (11, 12, 13 Dzulhijjah)
    if (hMonth == 12 && (hDay >= 11 && hDay <= 13)) {
      return true;
    }

    return false;
  }

  Color _getFastingColor(FastingType type) {
    switch (type) {
      case FastingType.wajib:
        return Colors.green; // Ramadan
      case FastingType.sunnahMuakkad:
        return Colors.orange; // Arafah
      case FastingType.sunnah:
        return AppColors.primary; // Mon/Thu, Ayyamul Bidh
      case FastingType.forbidden:
        return Colors.red.withValues(alpha: 0.5); // Eid, Tasyrik
    }
  }

  String _getFastingName(DateTime date) {
    final type = _getFastingType(date);
    if (type == null) return 'Tidak ada puasa khusus';

    final hijri = _getHijriInfo(date);
    final hMonth = hijri['hMonth'] as int;
    final hDay = hijri['hDay'] as int;

    if (type == FastingType.forbidden) {
      if (hMonth == 10 && hDay == 1) {
        return 'Hari Raya Idul Fitri (Diharamkan)';
      }
      if (hMonth == 12 && hDay == 10) {
        return 'Hari Raya Idul Adha (Diharamkan)';
      }
      return 'Hari Tasyrik (Diharamkan)';
    }

    if (hMonth == 9) return 'Puasa Ramadhan (Wajib)';
    if (hMonth == 12 && hDay == 9) return 'Puasa Arafah';
    if (hMonth == 1 && hDay == 10) return 'Puasa Asyura';
    if (hMonth == 1 && hDay == 9) return 'Puasa Tasu\'a';
    if (hDay >= 13 && hDay <= 15) return 'Puasa Ayyamul Bidh';
    if (date.weekday == DateTime.monday) return 'Puasa Sunnah Senin';
    if (date.weekday == DateTime.thursday) return 'Puasa Sunnah Kamis';

    return 'Puasa Sunnah';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF10221b)
          : const Color(0xFFF6F8F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildCalendarCard(
                            context,
                            isDark,
                          ).animate().fadeIn(duration: 400.ms),
                          const SizedBox(height: 16),
                          _buildSelectedDateInfo(
                            context,
                            isDark,
                          ).animate(delay: 150.ms).fadeIn(),
                          const SizedBox(height: 24),
                          Text(
                            'Jadwal Puasa Berikutnya',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0e1b16),
                            ),
                          ).animate(delay: 200.ms).fadeIn(),
                          const SizedBox(height: 16),
                          _buildUpcomingList(context, isDark),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final canPop = Navigator.canPop(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back,
                color: isDark ? Colors.white : const Color(0xFF0e1b16),
              ),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              'Kalender Puasa',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0e1b16),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildCalendarCard(BuildContext context, bool isDark) {
    final monthFormat = DateFormat('MMMM yyyy', 'id_ID');
    final daysInMonth = DateUtils.getDaysInMonth(
      _currentMonth.year,
      _currentMonth.month,
    );
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final startingWeekday = (firstDayOfMonth.weekday % 7); // Sunday=0

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162e25) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // Month Navigator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  final newMonth = DateTime(
                    _currentMonth.year,
                    _currentMonth.month - 1,
                  );
                  setState(() => _currentMonth = newMonth);
                  _fetchHijriCalendar(newMonth.month, newMonth.year);
                },
                icon: Icon(Icons.chevron_left, color: AppColors.primary),
              ),
              Column(
                children: [
                  Text(
                    monthFormat.format(_currentMonth),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    _hijriMonthName.isNotEmpty
                        ? _hijriMonthName
                        : _safeHijriFormat(_currentMonth, "MMMM yyyy"),
                    style: TextStyle(fontSize: 12, color: AppColors.primary),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  final newMonth = DateTime(
                    _currentMonth.year,
                    _currentMonth.month + 1,
                  );
                  setState(() => _currentMonth = newMonth);
                  _fetchHijriCalendar(newMonth.month, newMonth.year);
                },
                icon: Icon(Icons.chevron_right, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Days Header
          Row(
            children: ['M', 'S', 'S', 'R', 'K', 'J', 'S']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          // Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemCount: startingWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startingWeekday) return const SizedBox.shrink();
              final day = index - startingWeekday + 1;
              final date = DateTime(
                _currentMonth.year,
                _currentMonth.month,
                day,
              );
              final fastingType = _getFastingType(date);
              final isSelected = DateUtils.isSameDay(date, _selectedDate);

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = date),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (fastingType != null
                              ? _getFastingColor(
                                  fastingType,
                                ).withValues(alpha: 0.2)
                              : Colors.transparent),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white : Colors.black),
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (fastingType != null && !isSelected)
                        Positioned(
                          bottom: 4,
                          child: Icon(
                            Icons.circle,
                            size: 4,
                            color: _getFastingColor(fastingType),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDateInfo(BuildContext context, bool isDark) {
    final hijri = _getHijriInfo(_selectedDate);
    final fastingName = _getFastingName(_selectedDate);
    final fastingType = _getFastingType(_selectedDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              "${hijri['hDay']}",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${hijri['hMonthName']} ${hijri['hYear']}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  DateFormat(
                    "EEEE, d MMMM yyyy",
                    "id_ID",
                  ).format(_selectedDate),
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: fastingType != null
                        ? _getFastingColor(fastingType)
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    fastingName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingList(BuildContext context, bool isDark) {
    // Generate next 30 days to find upcoming fasting
    final today = DateTime.now();
    List<DateTime> upcoming = [];
    for (int i = 0; i < 30; i++) {
      final d = today.add(Duration(days: i));
      if (_getFastingType(d) != null &&
          _getFastingType(d) != FastingType.forbidden) {
        upcoming.add(d);
      }
    }

    // Take top 5
    if (upcoming.length > 5) upcoming = upcoming.sublist(0, 5);

    if (upcoming.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Text(
          'Tidak ada jadwal puasa sunnah dalam 30 hari kedepan.',
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
      );
    }

    return Column(
      children: upcoming.map((date) {
        final fastingName = _getFastingName(date);
        final dateStr = DateFormat("EEEE, d MMM", "id_ID").format(date);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          ),
          child: Row(
            children: [
              Icon(Icons.event, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fastingName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.notifications_none, color: Colors.grey),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _safeHijriFormat(DateTime date, String format) {
    try {
      return HijriCalendar.fromDate(date).toFormat(format);
    } catch (e) {
      return "-";
    }
  }
}

enum FastingType { wajib, sunnahMuakkad, sunnah, forbidden }
