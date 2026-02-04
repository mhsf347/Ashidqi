import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/prayer_times_model.dart';
import '../../services/notification_service.dart';
import '../../providers/prayer_settings_provider.dart';

/// Prayer Times Screen - Refactored to use PrayerSettingsProvider
class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  Timer? _countdownTimer;
  Duration _timeRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    // NotificationService permission request moved here or in main
    NotificationService().requestPermissions();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final provider = Provider.of<PrayerSettingsProvider>(
        context,
        listen: false,
      );
      if (provider.prayerTimes != null && mounted) {
        final remaining = provider.prayerTimes!.getTimeUntilNextPrayer();
        setState(() => _timeRemaining = remaining);
      }
    });
  }

  Future<void> _refreshData() async {
    await Provider.of<PrayerSettingsProvider>(
      context,
      listen: false,
    ).fetchPrayerTimes();
  }

  String _formatCountdown(Duration d) {
    final hours = d.inHours.abs().toString().padLeft(2, '0');
    final minutes = (d.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds.abs() % 60).toString().padLeft(2, '0');
    return '-$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<PrayerSettingsProvider>(
      builder: (context, provider, child) {
        final prayerTimes = provider.prayerTimes;
        final isLoading = provider.isLoading;

        // Determine Display Location
        final displayCity = provider.useGPS
            ? (prayerTimes?.city ?? 'Mencari Lokasi...')
            : provider.manualCity;
        final displayCountry = provider.useGPS
            ? 'GPS Otomatis'
            : provider.manualCountry;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF152822) : Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(context, isDark),

                // Main Content
                Expanded(
                  child: isLoading && prayerTimes == null
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _refreshData,
                          color: AppColors.primary,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                const SizedBox(height: 8),

                                // Location Chip
                                _buildLocationChip(
                                  isDark,
                                  displayCity,
                                  displayCountry,
                                ).animate().fadeIn(duration: 300.ms),

                                const SizedBox(height: 24),

                                // Date Display
                                _buildDateDisplay(isDark, prayerTimes)
                                    .animate(delay: 100.ms)
                                    .fadeIn(duration: 300.ms),

                                const SizedBox(height: 32),

                                // Countdown Card
                                _buildCountdownCard(context, isDark, provider)
                                    .animate(delay: 300.ms)
                                    .fadeIn(duration: 400.ms)
                                    .slideY(begin: 0.1, end: 0),

                                const SizedBox(height: 24),

                                // Navigation Cards
                                _buildNavigationCards(context, isDark)
                                    .animate(delay: 400.ms)
                                    .fadeIn(duration: 400.ms)
                                    .slideY(begin: 0.1, end: 0),

                                const SizedBox(height: 32),

                                // Prayer Schedule
                                _buildPrayerList(context, isDark, prayerTimes)
                                    .animate(delay: 500.ms)
                                    .fadeIn(duration: 400.ms),

                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/main',
              (route) => false,
            ),
            icon: Icon(
              Icons.arrow_back,
              color: isDark ? Colors.white : Colors.grey.shade800,
            ),
          ),
          Expanded(
            child: Text(
              'Jadwal Sholat',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey.shade900,
                letterSpacing: -0.3,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? Colors.white : Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  // Updated Signature
  Widget _buildLocationChip(bool isDark, String city, String country) {
    return GestureDetector(
      onTap: () => _showLocationDialog(context, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1c382f) : const Color(0xFFe7f3ef),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF2a4d41) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$city, $country',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Updated Signature
  Widget _buildDateDisplay(bool isDark, PrayerTimes? prayerTimes) {
    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, dd MMM yyyy');

    return Column(
      children: [
        Text(
          dateFormat.format(now),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          prayerTimes?.hijriDate ?? 'Loading...',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  // Updated Signature
  Widget _buildPrayerList(
    BuildContext context,
    bool isDark,
    PrayerTimes? prayerTimes,
  ) {
    final nextPrayer = prayerTimes?.getNextPrayer();
    final nextPrayerName = nextPrayer?['name'] ?? '';

    final prayers = [
      {
        'name': 'Subuh',
        'time': prayerTimes?.fajr ?? '--:--',
        'icon': Icons.wb_twilight,
      },
      {
        'name': 'Dzuhur',
        'time': prayerTimes?.dhuhr ?? '--:--',
        'icon': Icons.light_mode,
      },
      {
        'name': 'Ashar',
        'time': prayerTimes?.asr ?? '--:--',
        'icon': Icons.wb_sunny,
      },
      {
        'name': 'Maghrib',
        'time': prayerTimes?.maghrib ?? '--:--',
        'icon': Icons.wb_twilight,
      },
      {
        'name': 'Isya',
        'time': prayerTimes?.isha ?? '--:--',
        'icon': Icons.dark_mode,
      },
    ];

    return Column(
      children: prayers.map((prayer) {
        final name = prayer['name'] as String;
        final time = prayer['time'] as String;
        final icon = prayer['icon'] as IconData;
        final isNext =
            nextPrayerName ==
            (name == 'Subuh'
                ? 'Fajr'
                : name == 'Dzuhur'
                ? 'Dhuhr'
                : name == 'Ashar'
                ? 'Asr'
                : name == 'Isya'
                ? 'Isha'
                : name);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildPrayerListCard(
            context,
            isDark: isDark,
            name: name,
            time: time,
            icon: icon,
            isNext: isNext,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrayerListCard(
    BuildContext context, {
    required bool isDark,
    required String name,
    required String time,
    required IconData icon,
    required bool isNext,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isNext
            ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
            : (isDark ? const Color(0xFF1a2c24) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNext
              ? AppColors.primary
              : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100),
          width: isNext ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: isNext
                  ? AppColors.primary
                  : (isDark ? Colors.grey.shade500 : Colors.grey.shade400),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
              color: isNext
                  ? AppColors.primary
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
          ),
          const Spacer(),
          Text(
            time,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right,
            color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownCard(
    BuildContext context,
    bool isDark,
    PrayerSettingsProvider provider,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primary.withValues(alpha: 0.2) : null,
        gradient: isDark
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  const Color(0xFFE8F5E9), // Very light green
                ],
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: isDark
            ? null
            : Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEXT PRAYER IN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.8)
                          : Colors.grey.shade600,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatCountdown(_timeRemaining),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.primary
                          : const Color(0xFF064e3b),
                      letterSpacing: -0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Refresh Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                await provider
                    .fetchPrayerTimes(); // Refresh fetches and reschedules
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Jadwal Sholat & Notifikasi Diperbarui!',
                      ),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: isDark ? 8 : 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Refresh Jadwal',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationCards(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildNavCard(
            context,
            isDark: isDark,
            title: 'Mesjid Sekitar',
            icon: Icons.mosque,
            onTap: () {
              Navigator.pushNamed(context, '/mosque-map');
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildNavCard(
            context,
            isDark: isDark,
            title: 'Arah Kiblat',
            icon: Icons.explore,
            onTap: () {
              Navigator.pushNamed(context, '/qibla');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNavCard(
    BuildContext context, {
    required bool isDark,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF085e3f), const Color(0xFF0c8558)]
                : [const Color(0xFF0d9463), const Color(0xFF11bb7d)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationDialog(BuildContext context, bool isDark) {
    final provider = Provider.of<PrayerSettingsProvider>(
      context,
      listen: false,
    );
    final cityController = TextEditingController(text: provider.manualCity);
    final countryController = TextEditingController(
      text: provider.manualCountry,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1a2c24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Ubah Lokasi',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.grey.shade900,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // GPS Button
            ElevatedButton.icon(
              onPressed: () {
                provider.updateLocationMode(true);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.my_location, color: Colors.white),
              label: const Text(
                'Gunakan Lokasi Saat Ini',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    "ATAU",
                    style: TextStyle(
                      color: isDark ? Colors.grey : Colors.black54,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: cityController,
              decoration: InputDecoration(
                labelText: 'Kota',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: countryController,
              decoration: InputDecoration(
                labelText: 'Negara',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey.shade500)),
          ),
          ElevatedButton(
            onPressed: () {
              provider.updateLocationMode(
                false,
                city: cityController.text,
                country: countryController.text,
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? const Color(0xFF1a2c24)
                  : Colors.grey.shade200,
              foregroundColor: isDark ? Colors.white : Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Simpan Manual'),
          ),
        ],
      ),
    );
  }
}
