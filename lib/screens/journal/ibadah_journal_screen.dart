import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../services/journal_service.dart';

/// Ibadah Journal Screen (Mutaba'ah Yaumiyah)
/// Daily worship checklist with weekly statistics
class IbadahJournalScreen extends StatefulWidget {
  const IbadahJournalScreen({super.key});

  @override
  State<IbadahJournalScreen> createState() => _IbadahJournalScreenState();
}

class _IbadahJournalScreenState extends State<IbadahJournalScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _items = [];
  Map<DateTime, double> _weeklyStats = {};
  int _streak = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final items = await JournalService.loadDay(_selectedDate);
    final stats = await JournalService.getWeeklyStats(days: 7);
    final streak = await JournalService.getStreak();
    if (mounted) {
      setState(() {
        _items = items;
        _weeklyStats = stats;
        _streak = streak;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleItem(String itemId) async {
    HapticFeedback.lightImpact();
    final updated = await JournalService.toggleItem(_selectedDate, itemId);
    final stats = await JournalService.getWeeklyStats(days: 7);
    final streak = await JournalService.getStreak();
    if (mounted) {
      setState(() {
        _items = updated;
        _weeklyStats = stats;
        _streak = streak;
      });
    }
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
    _loadData();
  }

  double get _todayCompletion {
    if (_items.isEmpty) return 0.0;
    return _items.where((i) => i['done'] == true).length / _items.length;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  IconData _getItemIcon(String id) {
    switch (id) {
      case 'subuh':
        return Icons.wb_twilight;
      case 'dzuhur':
        return Icons.wb_sunny;
      case 'ashar':
        return Icons.sunny_snowing;
      case 'maghrib':
        return Icons.nights_stay_outlined;
      case 'isya':
        return Icons.dark_mode;
      case 'dhuha':
        return Icons.light_mode;
      case 'tahajud':
        return Icons.bedtime;
      case 'quran':
        return Icons.menu_book;
      case 'puasa':
        return Icons.restaurant;
      case 'sedekah':
        return Icons.volunteer_activism;
      case 'dzikir_pagi':
        return Icons.wb_sunny_outlined;
      case 'dzikir_sore':
        return Icons.wb_twilight;
      default:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF10221b) : const Color(0xFFF6F8F7),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Column(
                children: [
                  _buildHeader(context, isDark),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildDateSelector(isDark),
                          const SizedBox(height: 20),
                          _buildStatsRow(isDark),
                          const SizedBox(height: 20),
                          _buildProgressBar(isDark),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Sholat Wajib', isDark),
                          const SizedBox(height: 12),
                          _buildItemsGrid(
                            isDark,
                            _items
                                .where((i) => [
                                      'subuh',
                                      'dzuhur',
                                      'ashar',
                                      'maghrib',
                                      'isya'
                                    ].contains(i['id']))
                                .toList(),
                          ),
                          const SizedBox(height: 20),
                          _buildSectionTitle('Sholat Sunnah', isDark),
                          const SizedBox(height: 12),
                          _buildItemsGrid(
                            isDark,
                            _items
                                .where((i) =>
                                    ['dhuha', 'tahajud'].contains(i['id']))
                                .toList(),
                          ),
                          const SizedBox(height: 20),
                          _buildSectionTitle('Ibadah Lainnya', isDark),
                          const SizedBox(height: 12),
                          _buildItemsGrid(
                            isDark,
                            _items
                                .where((i) => [
                                      'quran',
                                      'puasa',
                                      'sedekah',
                                      'dzikir_pagi',
                                      'dzikir_sore'
                                    ].contains(i['id']))
                                .toList(),
                          ),
                          const SizedBox(height: 24),
                          _buildWeeklyChart(isDark),
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
              'Jurnal Ibadah',
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

  Widget _buildDateSelector(bool isDark) {
    final now = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day - (6 - i)),
    );

    final dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return SizedBox(
      height: 80,
      child: Row(
        children: days.map((date) {
          final isSelected = _isSameDay(date, _selectedDate);
          final isToday = _isSameDay(date, now);
          final completion = _weeklyStats[DateTime(date.year, date.month, date.day)] ?? 0.0;

          return Expanded(
            child: GestureDetector(
              onTap: () => _selectDate(date),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? const Color(0xFF1a2e26) : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: isToday && !isSelected
                      ? Border.all(color: AppColors.primary, width: 2)
                      : Border.all(
                          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                        ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dayNames[(date.weekday - 1) % 7],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? Colors.white70
                            : (isDark ? Colors.grey[500] : Colors.grey[500]),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Completion dot
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: completion >= 0.8
                            ? (isSelected ? Colors.white : Colors.green)
                            : completion >= 0.5
                                ? (isSelected ? Colors.white70 : Colors.orange)
                                : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildStatsRow(bool isDark) {
    final doneCount = _items.where((i) => i['done'] == true).length;
    final totalCount = _items.length;
    final percentage = (_todayCompletion * 100).round();

    return Row(
      children: [
        _buildStatCard(
          isDark: isDark,
          icon: Icons.check_circle,
          label: 'Hari Ini',
          value: '$doneCount/$totalCount',
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          isDark: isDark,
          icon: Icons.percent,
          label: 'Capaian',
          value: '$percentage%',
          color: const Color(0xFF2980B9),
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          isDark: isDark,
          icon: Icons.local_fire_department,
          label: 'Streak',
          value: '$_streak hari',
          color: const Color(0xFFE85C0D),
        ),
      ],
    ).animate(delay: 100.ms).fadeIn(duration: 300.ms);
  }

  Widget _buildStatCard({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1a2e26) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress Hari Ini',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '${(_todayCompletion * 100).round()}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _todayCompletion,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              color: AppColors.primary,
              minHeight: 8,
            ),
          ),
        ],
      ),
    ).animate(delay: 150.ms).fadeIn(duration: 300.ms);
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : const Color(0xFF0e1b16),
      ),
    );
  }

  Widget _buildItemsGrid(bool isDark, List<Map<String, dynamic>> items) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isDone = item['done'] == true;
        final id = item['id'] as String;

        return GestureDetector(
          onTap: () => _toggleItem(id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: (MediaQuery.of(context).size.width - 52) / 3,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : (isDark ? const Color(0xFF1a2e26) : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDone
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
                width: isDone ? 1.5 : 1,
              ),
              boxShadow: isDone
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isDone
                      ? Icon(
                          Icons.check_circle,
                          key: const ValueKey('done'),
                          color: AppColors.primary,
                          size: 28,
                        )
                      : Icon(
                          _getItemIcon(id),
                          key: const ValueKey('not_done'),
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                          size: 28,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['label'],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                    color: isDone
                        ? AppColors.primary
                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    decoration:
                        isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
        ).animate(delay: Duration(milliseconds: 30 * index)).fadeIn(duration: 200.ms);
      }).toList(),
    );
  }

  Widget _buildWeeklyChart(bool isDark) {
    final now = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day - (6 - i)),
    );
    final dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a2e26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistik Mingguan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((date) {
                final completion = _weeklyStats[DateTime(date.year, date.month, date.day)] ?? 0.0;
                final isToday = _isSameDay(date, now);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${(completion * 100).round()}%',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey[500] : Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: isToday
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.3),
                              gradient: isToday
                                  ? LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        AppColors.primary,
                                        AppColors.primary.withValues(alpha: 0.7),
                                      ],
                                    )
                                  : null,
                            ),
                            child: FractionallySizedBox(
                              heightFactor: completion.clamp(0.05, 1.0),
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color: isToday
                                      ? AppColors.primary
                                      : AppColors.primary.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayLabels[(date.weekday - 1) % 7],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.w500,
                            color: isToday
                                ? AppColors.primary
                                : (isDark ? Colors.grey[500] : Colors.grey[500]),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ).animate(delay: 300.ms).fadeIn(duration: 400.ms);
  }
}
