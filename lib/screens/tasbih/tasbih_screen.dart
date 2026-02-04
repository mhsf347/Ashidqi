import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../services/audio_service.dart';
import '../../services/storage_service.dart';

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class DhikrOption {
  final String title;
  final String arabic;
  const DhikrOption(this.title, this.arabic);
}

class _TasbihScreenState extends State<TasbihScreen> {
  int _count = 0;
  int _target = 33; // 0 means infinity
  late StorageService _storage;
  bool _isLoading = true;

  // Settings
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  // Dhikr Options
  final List<DhikrOption> _dhikrList = [
    const DhikrOption('SubhanAllah', 'سُبْحَانَ الله'),
    const DhikrOption('Alhamdulillah', 'الْحَمْدُ لِلَّهِ'),
    const DhikrOption('Allahu Akbar', 'اللهُ أَكْبَرُ'),
    const DhikrOption('La ilaha illallah', 'لَا إِلَهَ إِلَّا اللهُ'),
    const DhikrOption('Astaghfirullah', 'أَسْتَغْفِرُ اللهَ'),
  ];

  int _selectedDhikrIndex = 0;

  @override
  void initState() {
    super.initState();
    AudioService().init(); // Initialize Audio Service
    _loadData();
  }

  Future<void> _loadData() async {
    _storage = await StorageService.getInstance();
    setState(() {
      _count = _storage.getTasbihCount();
      _target = _storage.getTasbihTarget();
      // Default target fix if stored value is weird
      if (_target <= 0 && _target != 0) _target = 33;
      _isLoading = false;
    });
  }

  void _increment() {
    setState(() {
      _count++;

      // Sound feedback
      if (_soundEnabled) {
        AudioService().playClick();
      }

      // Target reached logic
      if (_target > 0 && _count % _target == 0) {
        if (_vibrationEnabled) HapticFeedback.heavyImpact();
        // Reset count automatically or keep going?
        // Typically keeps going but gives feedback.
        // Or maybe reset? Let's keep going properly like a counter.
      } else {
        if (_vibrationEnabled) HapticFeedback.lightImpact();
      }

      _storage.saveTasbihCount(_count);
    });
  }

  void _decrement() {
    if (_count > 0) {
      setState(() {
        _count--;
        _storage.saveTasbihCount(_count);
      });
      if (_vibrationEnabled) HapticFeedback.selectionClick();
    }
  }

  void _reset() {
    if (_vibrationEnabled) HapticFeedback.mediumImpact();
    setState(() {
      _count = 0;
      _storage.saveTasbihCount(0);
    });
  }

  void _updateTarget(int newTarget) {
    setState(() {
      _target = newTarget;
      _storage.saveTasbihTarget(newTarget);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Determine current progress
    double progress = 0.0;
    if (_target > 0) {
      progress = (_count % _target) / _target;
      if (progress == 0 && _count > 0 && _count % _target == 0) progress = 1.0;
    } else {
      // Infinity mode visual effect
      progress = 1.0;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF10221b) : Colors.white,
      appBar: AppBar(
        title: const Text('Tasbih Digital'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () {
              // Simple settings dialog? or just inline toggles
              showModalBottomSheet(
                context: context,
                builder: (context) => _buildSettingsSheet(isDark),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Top Section: Dhikr Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT DHIKR',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _showDhikrSelector(context, isDark),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _dhikrList[_selectedDhikrIndex].title,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // 2. Circular Progress (Main Interaction)
          GestureDetector(
            onTap: _increment,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background Circle - Container for touch area
                Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent, // Transparent to catch taps
                  ),
                ),

                // Track Ring
                SizedBox(
                  width: 280,
                  height: 280,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 24,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade100,
                  ),
                ),

                // Progress Ring
                SizedBox(
                  width: 280,
                  height: 280,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.transparent,
                  ),
                ),

                // Center Content
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Arabic Text
                    Text(
                      _dhikrList[_selectedDhikrIndex].arabic,
                      style: TextStyle(
                        fontFamily:
                            'Amiri', // Assuming you have this or generic Arabic font
                        fontSize: 32,
                        color: isDark ? Colors.white : Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Count
                    Text(
                          '$_count',
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                            height: 1,
                          ),
                        )
                        .animate(key: ValueKey(_count))
                        .scale(
                          duration: 100.ms,
                          begin: const Offset(0.95, 0.95),
                          curve: Curves.easeOutBack,
                        ),
                    const SizedBox(height: 8),
                    Text(
                      'TAP',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // 3. Progress Bar & Total
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _target == 0
                          ? 'Total: $_count'
                          : '${(_count % _target == 0 && _count > 0) ? _target : _count % _target} / $_target',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: isDark
                        ? Colors.grey[800]
                        : Colors.grey[200],
                    color: AppColors.primary,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // 4. Target Presets
          Text(
            'TARGET PRESETS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[500] : Colors.grey[400],
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPresetButton(33, isDark),
              const SizedBox(width: 12),
              _buildPresetButton(99, isDark),
              const SizedBox(width: 12),
              _buildPresetButton(100, isDark),
              const SizedBox(width: 12),
              _buildPresetButton(0, isDark), // Infinity
            ],
          ),

          const SizedBox(height: 32),

          // 5. Bottom Actions
          Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1a2e26) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActionButton(
                  icon: Icons.undo_rounded,
                  label: 'Undo',
                  onTap: _decrement,
                  isDark: isDark,
                ),
                _buildActionButton(
                  icon: Icons.refresh_rounded,
                  label: 'Reset',
                  onTap: _reset,
                  isDark: isDark,
                ),
                _buildActionButton(
                  icon: _soundEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  label: _soundEnabled ? 'On' : 'Off',
                  onTap: () => setState(() => _soundEnabled = !_soundEnabled),
                  isDark: isDark,
                  isActive: _soundEnabled,
                ),
                _buildActionButton(
                  icon: _vibrationEnabled
                      ? Icons.vibration_rounded
                      : Icons.smartphone_rounded,
                  label: _vibrationEnabled ? 'Vibe' : 'Silent',
                  onTap: () =>
                      setState(() => _vibrationEnabled = !_vibrationEnabled),
                  isDark: isDark,
                  isActive: _vibrationEnabled,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton(int target, bool isDark) {
    final isSelected = _target == target;
    final label = target == 0 ? '∞' : '$target';

    return InkWell(
      onTap: () => _updateTarget(target),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 60,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? AppColors.primary
                : (isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive
                  ? AppColors.primary
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDhikrSelector(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1f2937) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pilih Dzikir',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              ..._dhikrList.asMap().entries.map((entry) {
                final index = entry.key;
                final dhikr = entry.value;
                final isSelected = index == _selectedDhikrIndex;

                return ListTile(
                  title: Text(
                    dhikr.title,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  trailing: Text(
                    dhikr.arabic,
                    style: TextStyle(
                      fontFamily: 'Amiri',
                      fontSize: 18,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    setState(() => _selectedDhikrIndex = index);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsSheet(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1f2937) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pengaturan Tasbih',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Suara'),
            value: _soundEnabled,
            onChanged: (v) {
              setState(() => _soundEnabled = v);
              Navigator.pop(context);
            },
            activeThumbColor: AppColors.primary,
          ),
          SwitchListTile(
            title: const Text('Getar'),
            value: _vibrationEnabled,
            onChanged: (v) {
              setState(() => _vibrationEnabled = v);
              Navigator.pop(context);
            },
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
