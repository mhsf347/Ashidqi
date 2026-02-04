import 'package:flutter/material.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/notification_service.dart';
import '../../providers/prayer_settings_provider.dart';

class AdzanNotificationScreen extends StatefulWidget {
  const AdzanNotificationScreen({super.key});

  @override
  State<AdzanNotificationScreen> createState() =>
      _AdzanNotificationScreenState();
}

class _AdzanNotificationScreenState extends State<AdzanNotificationScreen> {
  // Audio Player Local State
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;

  // Static Data
  final List<Map<String, String>> _muadzinList = [
    {
      'id': 'makkah',
      'name': 'Makkah',
      'location': 'Makkah, Saudi Arabia',
      'file': 'audio/makkah.mp3',
    },
    {
      'id': 'madinah',
      'name': 'Madinah',
      'location': 'Madinah, Saudi Arabia',
      'file': 'audio/madinah.mp3',
    },
    {
      'id': 'mishary_rashid',
      'name': 'Mishary Rashid',
      'location': 'Kuwait',
      'file': 'audio/mishary_rashid.mp3',
    },
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) setState(() => _currentlyPlayingId = null);
    });

    // Refresh data if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<PrayerSettingsProvider>(
        context,
        listen: false,
      );
      if (provider.prayerTimes == null) {
        provider.fetchPrayerTimes();
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPreview(String id, String file) async {
    if (_currentlyPlayingId == id) {
      await _audioPlayer.stop();
      setState(() => _currentlyPlayingId = null);
    } else {
      await _audioPlayer.stop();
      setState(() => _currentlyPlayingId = id);

      try {
        await _audioPlayer.play(AssetSource(file));
      } catch (e) {
        if (mounted) {
          setState(() => _currentlyPlayingId = null);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal memutar audio: $e')));
        }
      }
    }
  }

  Future<void> _testNotification(PrayerSettingsProvider provider) async {
    final service = NotificationService();
    final now = DateTime.now();
    final scheduledTime = now.add(const Duration(seconds: 5));

    await service.schedulePrayerNotification(
      id: 999,
      title: 'Tes Notifikasi Adzan',
      body: 'Simulasi notifikasi (Suara: ${provider.selectedMuadzin})',
      scheduledTime: scheduledTime,
      soundName: provider.selectedMuadzin,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notifikasi akan muncul dalam 5 detik. Segera kunci layar atau tekan Home.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<PrayerSettingsProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF11211b)
              : const Color(0xFFF6F8F7),
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, isDark, provider),
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: () => provider.fetchPrayerTimes(),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(
                                  'Jadwal & Notifikasi',
                                  isDark,
                                ),
                                const SizedBox(height: 12),

                                ...[
                                  'Subuh',
                                  'Dzuhur',
                                  'Ashar',
                                  'Maghrib',
                                  'Isya',
                                ].map((name) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildPrayerCard(
                                      context,
                                      provider,
                                      isDark,
                                      name,
                                    ),
                                  );
                                }),

                                const SizedBox(height: 32),
                                _buildSectionTitle(
                                  'Muadzin Global (Suara Adzan)',
                                  isDark,
                                ),
                                const SizedBox(height: 12),
                                _buildMuadzinSection(context, provider, isDark),
                                const SizedBox(height: 24),
                                _buildTestButton(context, provider),
                                const SizedBox(height: 32),
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

  Widget _buildPrayerCard(
    BuildContext context,
    PrayerSettingsProvider provider,
    bool isDark,
    String name,
  ) {
    final isEnabled = provider.adzanEnabled[name] ?? true;
    final reminder = provider.reminderMinutes[name] ?? 0;
    // We get time from provider if available
    final prayerTime = provider.prayerTimes?.getPrayerTime(name) ?? '--:--';

    IconData icon;
    Color color;
    switch (name) {
      case 'Subuh':
        icon = Icons.wb_twilight;
        color = AppColors.primary;
        break;
      case 'Dzuhur':
        icon = Icons.light_mode;
        color = Colors.orange;
        break;
      case 'Ashar':
        icon = Icons.sunny;
        color = Colors.amber;
        break;
      case 'Maghrib':
        icon = Icons.nights_stay;
        color = Colors.indigo;
        break;
      case 'Isya':
        icon = Icons.bedtime;
        color = Colors.deepPurple;
        break;
      default:
        icon = Icons.access_time;
        color = Colors.grey;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1c332b) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              prayerTime,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            value: isEnabled,
            activeThumbColor: AppColors.primary,
            onChanged: (val) => provider.toggleAdzan(name, val),
          ),
          if (isEnabled) ...[
            Divider(
              height: 1,
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ingatkan sebelumnya',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      Text(
                        '${reminder.toInt()} menit',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: reminder,
                    min: 0,
                    max: 30,
                    divisions: 6,
                    activeColor: AppColors.primary,
                    onChanged: (val) => provider.updateReminder(name, val),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMuadzinSection(
    BuildContext context,
    PrayerSettingsProvider provider,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1c332b) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        ),
      ),
      child: Column(
        children: _muadzinList.map((m) {
          final isPlaying = _currentlyPlayingId == m['id'];

          return RadioListTile<String>(
            title: Text(
              m['name']!,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              m['location']!,
              style: const TextStyle(fontSize: 12),
            ),
            value: m['id']!,
            // ignore: deprecated_member_use
            groupValue: provider.selectedMuadzin,
            // ignore: deprecated_member_use
            onChanged: (val) {
              if (val != null) provider.updateGlobalMuadzin(val);
            },
            secondary: IconButton(
              icon: Icon(
                isPlaying ? Icons.stop_circle : Icons.play_circle_outline,
              ),
              color: isPlaying ? Colors.red : AppColors.primary,
              onPressed: () => _playPreview(m['id']!, m['file']!),
            ),
            activeColor: AppColors.primary,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTestButton(
    BuildContext context,
    PrayerSettingsProvider provider,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.notifications_active),
        label: const Text('Tes Notifikasi (5 Detik)'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () => _testNotification(provider),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    PrayerSettingsProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      color: isDark ? const Color(0xFF11211b) : const Color(0xFFF6F8F7),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'Notifikasi Adzan',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 48), // Balance left icon
          if (provider.isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white54 : Colors.black45,
        letterSpacing: 1.2,
      ),
    );
  }
}
