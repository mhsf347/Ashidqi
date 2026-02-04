import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/theme_provider.dart';
import '../../providers/prayer_settings_provider.dart';
import '../notification/adzan_notification_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final prayerSettings = Provider.of<PrayerSettingsProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // TAMPILAN
            _buildSectionHeader(context, 'Tampilan', Icons.palette_outlined),
            _buildSettingsCard(context, isDark, [
              SwitchListTile(
                title: const Text('Dark Mode'),
                secondary: Icon(
                  Icons.dark_mode_outlined,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                value: themeProvider.isDarkMode,
                onChanged: (_) => themeProvider.toggleTheme(),
                activeThumbColor: AppColors.primary,
              ),
            ]),

            const SizedBox(height: 24),

            // LOKASI & JADWAL
            _buildSectionHeader(
              context,
              'Lokasi & Jadwal',
              Icons.location_on_outlined,
            ),
            _buildSettingsCard(context, isDark, [
              // GPS Toggle
              SwitchListTile(
                title: const Text('Gunakan GPS Otomatis'),
                subtitle: Text(
                  prayerSettings.useGPS
                      ? 'Lokasi terdeteksi otomatis'
                      : '${prayerSettings.manualCity}, ${prayerSettings.manualCountry}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                secondary: Icon(
                  Icons.my_location,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                value: prayerSettings.useGPS,
                onChanged: (val) {
                  if (val) {
                    prayerSettings.updateLocationMode(true);
                  } else {
                    _showManualLocationDialog(context, prayerSettings);
                  }
                },
                activeThumbColor: AppColors.primary,
              ),
              if (!prayerSettings.useGPS)
                ListTile(
                  leading: const Icon(Icons.edit_location_alt_outlined),
                  title: const Text('Ubah Lokasi Manual'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      _showManualLocationDialog(context, prayerSettings),
                ),

              const Divider(),

              // Calculation Method
              ListTile(
                leading: const Icon(Icons.calculate_outlined),
                title: const Text('Metode Perhitungan'),
                subtitle: Text(prayerSettings.calculationMethod),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showMethodSelector(context, prayerSettings),
              ),

              // Time Correction
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Koreksi Waktu Sholat'),
                subtitle: const Text('Sesuaikan manual (± menit)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showOffsetDialog(context, prayerSettings),
              ),
            ]),

            const SizedBox(height: 24),

            // NOTIFIKASI
            _buildSectionHeader(
              context,
              'Notifikasi Adzan',
              Icons.notifications_active_outlined,
            ),
            _buildSettingsCard(context, isDark, [
              ListTile(
                leading: const Icon(Icons.volume_up_outlined),
                title: const Text('Atur Suara & Notifikasi'),
                subtitle: const Text(
                  'Pilih suara adzan dan pengingat per sholat',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => const AdzanNotificationScreen(),
                    ),
                  );
                },
              ),
            ]),

            const SizedBox(height: 24),

            // TENTANG APLIKASI
            _buildSectionHeader(
              context,
              'Tentang Aplikasi',
              Icons.info_outline,
            ),
            _buildSettingsCard(context, isDark, [
              ListTile(
                leading: const Icon(Icons.volunteer_activism_outlined),
                title: const Text('Donasi & Dukungan'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/donation'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Kontributor'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/contributor'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Lisensi & Hak Cipta'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, '/license'),
              ),
            ]),

            const SizedBox(height: 40),

            // Info Version
            Center(
              child: Text(
                'Versi 1.0.0',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- BUILDER HELPERS ---

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context,
    bool isDark,
    List<Widget> children,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2A25) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  // --- DIALOGS ---

  void _showManualLocationDialog(
    BuildContext context,
    PrayerSettingsProvider provider,
  ) {
    final cityCtrl = TextEditingController(text: provider.manualCity);
    final countryCtrl = TextEditingController(text: provider.manualCountry);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lokasi Manual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cityCtrl,
              decoration: const InputDecoration(labelText: 'Kota'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: countryCtrl,
              decoration: const InputDecoration(labelText: 'Negara'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.updateLocationMode(
                false,
                city: cityCtrl.text,
                country: countryCtrl.text,
              );
              Navigator.pop(context);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showMethodSelector(
    BuildContext context,
    PrayerSettingsProvider provider,
  ) {
    final methods = [
      'Kemenag RI',
      'Muslim World League',
      'Egyptian General Authority',
      'Makkah (Umm al-Qura)',
      'Singapore',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Metode Perhitungan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: methods
                .map(
                  (m) => RadioListTile<String>(
                    title: Text(m),
                    value: m,
                    // ignore: deprecated_member_use
                    groupValue: provider.calculationMethod,
                    // ignore: deprecated_member_use
                    onChanged: (val) {
                      if (val != null) {
                        provider.updateCalculationMethod(val);
                        Navigator.pop(context);
                      }
                    },
                    activeColor: AppColors.primary,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showOffsetDialog(
    BuildContext context,
    PrayerSettingsProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Koreksi Waktu Sholat'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', 'Isya'].map((
                  prayer,
                ) {
                  int current = provider.offsets[prayer] ?? 0;
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            prayer,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${current > 0 ? "+" : ""}$current menit',
                            style: TextStyle(
                              color: current == 0
                                  ? Colors.grey
                                  : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: current.toDouble(),
                        min: -30,
                        max: 30,
                        divisions: 60,
                        label: '$current',
                        activeColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() {
                            provider.updateOffset(prayer, val.round());
                          });
                        },
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ],
          );
        },
      ),
    );
  }
}
