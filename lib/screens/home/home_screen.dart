import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../models/prayer_times_model.dart';
import '../../services/prayer_times_service.dart';
import 'dart:math';
import 'package:hijri/hijri_calendar.dart';
import '../../services/widget_service.dart';
import '../../services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Home Dashboard Screen - Converted from HTML Design
/// Features: Gradient header, Next Prayer Card, Quick Actions, Today's Highlights
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PrayerTimes? _prayerTimes;
  Map<String, dynamic>? _randomDoa;
  Map<String, dynamic>? _randomHadith;
  Map<String, dynamic>? _fastingInfo;
  Map<String, dynamic>? _randomQuran;

  // Session state for donation dialog
  static bool _donationShown = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // 1. Request Notification Permissions first
    await NotificationService().requestPermissions();

    // 2. Load Prayer Times (will trigger Location Permission if GPS enabled)
    await _loadPrayerTimes();
    _loadRandomDoa();
    _loadRandomHadith();
    _loadRandomQuran();
    _loadFastingInfo();
  }

  Future<void> _loadRandomDoa() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://doa-doa-api-ahmadramadhan.fly.dev/api/doa/v1/random',
            ),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty && mounted) {
          final doa = data[0];
          prefs.setString('cached_random_doa', response.body);
          setState(() {
            _randomDoa = {
              'title': doa['doa'] ?? 'Doa Hari Ini',
              'arabic': doa['ayat'] ?? '',
              'translation': doa['artinya'] ?? '',
            };
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Random Doa API Error: $e');
    }

    // Fallback: Try cache
    try {
      final cached = prefs.getString('cached_random_doa');
      if (cached != null && mounted) {
        final List<dynamic> data = json.decode(cached);
        if (data.isNotEmpty) {
          final doa = data[0];
          setState(() {
            _randomDoa = {
              'title': doa['doa'] ?? 'Doa Hari Ini',
              'arabic': doa['ayat'] ?? '',
              'translation': doa['artinya'] ?? '',
            };
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadRandomHadith() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      // Narrators support check on API: bukhari, muslim, abu-dawud, etc.
      final narrators = [
        'bukhari',
        'muslim',
        'abu-dawud',
        'tirmidzi',
        'nasai',
        'ibnu-majah',
      ];
      final narrator = narrators[Random().nextInt(narrators.length)];
      // Assume a safe random range (1-500) for "highlight" purposes to ensure hits
      final number = Random().nextInt(500) + 1;

      final response = await http
          .get(
            Uri.parse(
              'https://hadith-api-go.vercel.app/api/v1/hadis/$narrator/$number',
            ),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hadithData = data['data']; // Expected structure based on API

        if (mounted && hadithData != null) {
          final title = 'HR. ${_formatNarratorName(narrator)} No. $number';
          final content = hadithData['id'] ?? hadithData['contents'] ?? '';

          if (content.isNotEmpty) {
            final hadithMap = {'title': title, 'content': content};
            prefs.setString('cached_random_hadith', json.encode(hadithMap));
            setState(() {
              _randomHadith = hadithMap;
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Random Hadith Error: $e');
    }

    // Fallback: Cache
    try {
      final cached = prefs.getString('cached_random_hadith');
      if (cached != null && mounted) {
        setState(() {
          _randomHadith = json.decode(cached);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRandomQuran() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      // Random ayah 1-6236
      final number = Random().nextInt(6236) + 1;
      final response = await http
          .get(
            Uri.parse(
              'https://api.alquran.cloud/v1/ayah/$number/editions/quran-uthmani,id.indonesian',
            ),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> editions = data['data'];

        if (editions.length >= 2 && mounted) {
          final arabic = editions[0];
          final translation = editions[1];

          final quranMap = {
            'surah': arabic['surah']['englishName'],
            'number': arabic['numberInSurah'].toString(),
            'arabic': arabic['text'],
            'translation': translation['text'],
          };

          prefs.setString('cached_random_quran', json.encode(quranMap));
          setState(() {
            _randomQuran = quranMap;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Random Quran Error: $e');
    }

    // Fallback: Cache
    try {
      final cached = prefs.getString('cached_random_quran');
      if (cached != null && mounted) {
        setState(() {
          _randomQuran = json.decode(cached);
        });
      }
    } catch (_) {}
  }

  String _formatNarratorName(String slug) {
    return slug
        .split('-')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1)}'
              : '',
        )
        .join(' ');
  }

  void _loadFastingInfo() {
    // Check for TOMORROW
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final hDate = HijriCalendar.fromDate(tomorrow);

    String? title;
    String? subtitle;
    bool isFasting = false;

    // 1. Senin / Kamis
    if (tomorrow.weekday == DateTime.monday) {
      title = 'Puasa Senin';
      subtitle = 'Besok adalah hari Senin, disunnahkan berpuasa.';
      isFasting = true;
    } else if (tomorrow.weekday == DateTime.thursday) {
      title = 'Puasa Kamis';
      subtitle = 'Besok adalah hari Kamis, disunnahkan berpuasa.';
      isFasting = true;
    }

    // 2. Ayyamul Bidh (13, 14, 15)
    if ([13, 14, 15].contains(hDate.hDay)) {
      final ayyamTitle = 'Puasa Ayyamul Bidh';
      final ayyamSubtitle =
          'Besok tanggal ${hDate.hDay} ${hDate.longMonthName}, jadwal puasa tengah bulan.';

      // Priority: If overlay with Senin/Kamis, combine or prefer Ayyamul Bidh?
      // Simple logic: Overwrite if it's Ayyamul Bidh (more specific)
      title = ayyamTitle;
      subtitle = ayyamSubtitle;
      isFasting = true;
    }

    // 3. Ramadhan (Month 9)
    if (hDate.hMonth == 9) {
      title = 'Puasa Ramadhan';
      subtitle = 'Besok adalah hari ke-${hDate.hDay} Ramadhan.';
      isFasting = true;
    }

    // 4. Arafah (9 Dzulhijjah)
    if (hDate.hMonth == 12 && hDate.hDay == 9) {
      title = 'Puasa Arafah';
      subtitle = 'Besok adalah 9 Dzulhijjah, disunnahkan puasa Arafah.';
      isFasting = true;
    }
    // 5. Asyura (10 Muharram)
    if (hDate.hMonth == 1 && hDate.hDay == 10) {
      title = 'Puasa Asyura';
      subtitle = 'Besok adalah 10 Muharram, disunnahkan puasa Asyura.';
      isFasting = true;
    }

    if (isFasting && mounted) {
      setState(() {
        _fastingInfo = {'title': title, 'subtitle': subtitle};
      });
    }
  }

  Future<void> _loadPrayerTimes() async {
    final prayerTimes = await PrayerTimesService.getPrayerTimes();
    if (mounted) {
      setState(() {
        _prayerTimes = prayerTimes;
      });
      if (prayerTimes != null) {
        WidgetService.updateWidget(prayerTimes);
      }
      _checkAndShowDonation();
    }
  }

  void _checkAndShowDonation() async {
    // Check session flag
    if (_donationShown) return;

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Mark as shown for this session
    _donationShown = true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 140,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: const Center(
                child: Icon(
                  Icons.volunteer_activism,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Dukung Ashidqi',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aplikasi ini 100% Gratis.\nJika bermanfaat, Anda bisa menyisihkan sedikit rezeki untuk pengembangan fitur selanjutnya.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Nanti Saja'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final uri = Uri.parse('https://trakteer.id/mhsf/tip');
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tidak dapat membuka link')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Donasi Sekarang'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF10221b)
          : const Color(0xFFF8FCFB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with Gradient
            _buildHeader(context, isDark),

            // Content overlapping header
            Transform.translate(
              offset: const Offset(0, -64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // Next Prayer Card
                    _buildNextPrayerCard(context, isDark)
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 24),

                    // Quick Actions
                    _buildQuickActions(
                      context,
                      isDark,
                    ).animate(delay: 100.ms).fadeIn(duration: 400.ms),

                    const SizedBox(height: 24),

                    // Today's Highlight Section
                    _buildHighlightSection(context, isDark),

                    const SizedBox(height: 24),

                    // Quote Card
                    _buildQuoteCard(context, isDark)
                        .animate(delay: 400.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),

                    const SizedBox(height: 100), // Space for bottom nav
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
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 24,
        right: 24,
        bottom: 80,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF085e3f), const Color(0xFF0c8558)]
              : [const Color(0xFF0d9463), const Color(0xFF11bb7d)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // Pattern overlay
          Positioned.fill(
            child: Opacity(
              opacity: 0.1,
              child: CustomPaint(painter: PatternPainter()),
            ),
          ),

          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Title & Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // App Icon
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/icon/icon.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ashidqi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Teman Ibadahmu',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Action buttons
                  Row(
                    children: [
                      _buildHeaderButton(
                        context,
                        Icons.settings_outlined,
                        () => Navigator.pushNamed(context, '/settings'),
                      ),
                      const SizedBox(width: 8),
                      _buildHeaderButton(
                        context,
                        Icons.notifications_outlined,
                        () {
                          Navigator.pushNamed(context, '/adzan-notification');
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Date Display (Hijri & Gregorian)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _prayerTimes?.hijriDate ?? '...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildNextPrayerCard(BuildContext context, bool isDark) {
    final nextPrayer = _prayerTimes?.getNextPrayer();
    final timeRemaining = _prayerTimes?.getTimeUntilNextPrayer();

    String formatDuration(Duration? d) {
      if (d == null) return '--:--:--';
      final hours = d.inHours.toString().padLeft(2, '0');
      final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
      return '-$hours:$minutes:$seconds';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a2e26) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background mosque icon
          Positioned(
            top: 0,
            right: 0,
            child: Opacity(
              opacity: 0.05,
              child: Icon(
                Icons.mosque,
                size: 120,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),

          Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left side - Prayer info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NEXT PRAYER',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nextPrayer?['name'] ?? 'Loading...',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.grey.shade900,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            nextPrayer?['time'] ?? '--:--',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white
                                  : Colors.grey.shade900,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'PM',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade500,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Right side - Timer
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Animated clock icon
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Ping animation
                            Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                )
                                .animate(onPlay: (c) => c.repeat())
                                .scaleXY(
                                  begin: 0.8,
                                  end: 1.2,
                                  duration: 1500.ms,
                                )
                                .fadeOut(duration: 1500.ms),
                            // Icon
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withValues(alpha: 0.1),
                              ),
                              child: Icon(
                                Icons.schedule,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Countdown badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          formatDuration(timeRemaining),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Bottom row - Location & View Schedule
              Container(
                padding: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade100,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Location
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _prayerTimes?.city ?? 'Jakarta',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    // View Schedule button
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/prayer-times'),
                      child: Row(
                        children: [
                          Text(
                            'View Schedule',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, bool isDark) {
    final actions = [
      {'icon': Icons.explore_outlined, 'label': 'Qibla', 'route': '/qibla'},
      {'icon': Icons.groups_outlined, 'label': 'Tasbih', 'route': '/tasbih'},
      {
        'icon': Icons.mosque_outlined,
        'label': 'Masjid',
        'route': '/mosque-map',
      },
      {'icon': Icons.auto_stories_outlined, 'label': 'Doa', 'route': '/doa'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: actions.asMap().entries.map((entry) {
          final index = entry.key;
          final action = entry.value;

          return Padding(
                padding: EdgeInsets.only(
                  left: index == 0 ? 0 : 8,
                  right: index == actions.length - 1 ? 24 : 8,
                ),
                child: SizedBox(
                  width: 70,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pushNamed(context, action['route'] as String);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1a2e26)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade100,
                            ),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Icon(
                            action['icon'] as IconData,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          action['label'] as String,
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .animate(delay: Duration(milliseconds: 50 * index))
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.2, end: 0);
        }).toList(),
      ),
    );
  }

  Widget _buildHighlightSection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Today's Highlight",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              if (_randomQuran != null)
                _buildHighlightCard(
                  context,
                  isDark: isDark,
                  title: 'Ayat of the Day',
                  subtitle:
                      '${_randomQuran!['surah']} : ${_randomQuran!['number']}',
                  content: _randomQuran!['translation'],
                  arabic: _randomQuran!['arabic'],
                  icon: Icons.menu_book,
                  color: const Color(0xFF169278),
                )
              else
                _buildHighlightCard(
                  context,
                  isDark: isDark,
                  title: 'Ayat of the Day',
                  subtitle: 'Loading...',
                  content: 'Mengambil ayat pilihan...',
                  icon: Icons.menu_book,
                  color: const Color(0xFF169278),
                ),

              const SizedBox(width: 16),

              if (_randomDoa != null) ...[
                _buildHighlightCard(
                  context,
                  isDark: isDark,
                  title: _randomDoa!['title'],
                  subtitle: 'Doa Harian',
                  content: _randomDoa!['translation'],
                  arabic: _randomDoa!['arabic'],
                  icon: Icons.volunteer_activism,
                  color: const Color(0xFFE85C0D),
                ),
                const SizedBox(width: 16),
              ],

              if (_randomHadith != null) ...[
                _buildHighlightCard(
                  context,
                  isDark: isDark,
                  title: 'Hadits Pilihan',
                  subtitle: _randomHadith!['title'],
                  content: _randomHadith!['content'],
                  icon: Icons.format_quote,
                  color: const Color(0xFF8E44AD),
                ),
                const SizedBox(width: 16),
              ],

              if (_fastingInfo != null) ...[
                _buildHighlightCard(
                  context,
                  isDark: isDark,
                  title: _fastingInfo!['title'],
                  subtitle: 'Jadwal Puasa',
                  content: _fastingInfo!['subtitle'],
                  icon: Icons.event,
                  color: const Color(0xFF2980B9),
                ),
                const SizedBox(width: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightCard(
    BuildContext context, {
    required bool isDark,
    required String title,
    required String subtitle,
    required String content,
    String? arabic,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a2c24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey.shade900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          if (arabic != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                arabic,
                style: GoogleFonts.amiri(
                  fontSize: 16,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),
            ),
          Text(
            content,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              height: 1.5,
            ),
            maxLines: arabic != null ? 2 : 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote, color: AppColors.primary, size: 32),
          const SizedBox(height: 8),
          Text(
            '"Maka sesungguhnya bersama kesulitan ada kemudahan."',
            style: TextStyle(
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              fontSize: 17,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'QS. Al-Insyirah: 5',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for background pattern
class PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Draw small plus signs
        canvas.drawLine(Offset(x - 4, y), Offset(x + 4, y), paint);
        canvas.drawLine(Offset(x, y - 4), Offset(x, y + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
