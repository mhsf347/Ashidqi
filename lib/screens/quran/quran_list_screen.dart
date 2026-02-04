import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../models/quran_model.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../core/data/surah_translations.dart';
import 'quran_reader_screen.dart';

class QuranListScreen extends StatefulWidget {
  const QuranListScreen({super.key});

  @override
  State<QuranListScreen> createState() => _QuranListScreenState();
}

class _QuranListScreenState extends State<QuranListScreen> {
  late Future<List<Surah>> _surahListFuture;
  final TextEditingController _searchController = TextEditingController();
  List<Surah> _allSurahs = [];
  List<Surah> _filteredSurahs = [];

  Map<String, dynamic>? _lastRead;
  int _readSurahCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _checkDatabase();

    // Listen to progress stream for real-time UI updates
    DatabaseService().downloadProgress.listen((progress) {
      if (mounted) setState(() {});
    });

    // Initial empty state until DB check passes
    _surahListFuture = Future.value([]);
  }

  Future<void> _checkDatabase() async {
    final dbService = DatabaseService();
    final isSeeded = await dbService.isDatabaseSeeded();

    if (isSeeded) {
      _loadSurahsFromDB();
    }
    // Else: Banner in build() handles it
  }

  Future<void> _loadSurahsFromDB() async {
    final dbService = DatabaseService();
    final surahs = await dbService.getAllSurahs();

    List<Surah> mappedSurahs = surahs
        .map(
          (s) => Surah(
            number: s.number,
            name: s.name,
            englishName: s.englishName,
            englishNameTranslation: s.englishNameTranslation,
            numberOfAyahs: s.numberOfAyahs,
            revelationType: s.revelationType,
          ),
        )
        .toList();

    if (mounted) {
      setState(() {
        _allSurahs = mappedSurahs;
        _filteredSurahs = mappedSurahs;
        _surahListFuture = Future.value(mappedSurahs);
      });
    }
  }

  Future<void> _loadProgress() async {
    final storage = await StorageService.getInstance();
    setState(() {
      _lastRead = storage.getLastRead();
      _readSurahCount = storage.getReadSurahs().length;
    });
  }

  void _filterSurahs(String query) {
    if (query.isEmpty) {
      setState(() => _filteredSurahs = _allSurahs);
    } else {
      setState(() {
        _filteredSurahs = _allSurahs.where((surah) {
          final translation = surahTranslationsId[surah.number] ?? '';
          return surah.englishName.toLowerCase().contains(
                query.toLowerCase(),
              ) ||
              surah.name.contains(query) ||
              translation.toLowerCase().contains(
                query.toLowerCase(),
              ) || // Search Indonesian meaning
              surah.number.toString().contains(query); // Search by number
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF10221b)
          : const Color(0xFFF8FCFB),
      appBar: AppBar(
        title: const Text('Al-Quran Offline'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/main',
            (route) => false,
          ),
        ),
      ),
      body: Column(
        children: [
          // Download Banner
          FutureBuilder<bool>(
            future: DatabaseService().isDatabaseSeeded(),
            builder: (context, snapshot) {
              // Show banner if NOT seeded OR if actually downloading/paused (even if partially seeded)
              // But 'isDatabaseSeeded' returns false if < 114 surahs.
              // We also check 'isDownloading' / 'isPaused' to keep banner visible during process.
              final dbService = DatabaseService();
              final showBanner =
                  (snapshot.hasData && !snapshot.data!) ||
                  dbService.isDownloading ||
                  dbService.isPaused;

              if (showBanner) {
                return _buildDownloadBanner(isDark);
              }
              return const SizedBox.shrink();
            },
          ),

          // Header: Last Read & Progress
          _buildHeader(isDark),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _filterSurahs,
              decoration: InputDecoration(
                hintText: 'Cari Surah...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // List
          Expanded(
            child: FutureBuilder<List<Surah>>(
              future: _surahListFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _allSurahs.isEmpty) {
                  // Only show loading if we are NOT downloading (because download shows banner)
                  // If downloading, the list might be empty initially.
                  return const SizedBox.shrink(); // Or generic loader
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text('Gagal memuat daftar surah'),
                        TextButton(
                          onPressed: () {
                            _checkDatabase();
                          },
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  // Show a hint that data is empty (banner handles CTA)
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.library_books_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text('Belum ada data Al-Quran'),
                        Text(
                          'Silakan unduh data di atas.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredSurahs.length,
                  itemBuilder: (context, index) {
                    final surah = _filteredSurahs[index];
                    return _buildSurahItem(context, surah, isDark)
                        .animate(delay: (20 * index).ms) // Staggered animation
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.1, end: 0);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadBanner(bool isDark) {
    final dbService = DatabaseService();
    final isDownloading = dbService.isDownloading;
    final isPaused = dbService.isPaused;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a2c26) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Database Offline',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (!isDownloading && !isPaused)
            const Text(
              'Unduh data Al-Quran agar bisa digunakan tanpa internet.',
            ),

          if (isDownloading || isPaused)
            StreamBuilder<double>(
              stream: dbService.downloadProgress,
              builder: (context, snapshot) {
                final progress = snapshot.data ?? 0.0;
                final percent = (progress * 100).toInt();
                return Column(
                  children: [
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isPaused ? 'Terjeda' : 'Mengunduh... $percent%'),
                        if (percent >= 100)
                          const Text(
                            'Selesai',
                            style: TextStyle(color: Colors.green),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),

          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isDownloading)
                TextButton.icon(
                  icon: const Icon(Icons.pause),
                  label: const Text('Jeda'),
                  onPressed: () {
                    dbService.pauseDownload();
                    setState(() {});
                  },
                )
              else if (isPaused)
                TextButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Lanjutkan'),
                  onPressed: () {
                    dbService.resumeDownload().then((_) => _loadSurahsFromDB());
                    setState(() {});
                  },
                )
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.download),
                  label: const Text('Download'),
                  onPressed: () {
                    dbService.seedDatabase().then((_) {
                      _loadSurahsFromDB(); // Reload when done
                    });
                    setState(() {});
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSurahItem(BuildContext context, Surah surah, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a2c26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            image: const DecorationImage(
              image: AssetImage(
                'assets/images/rub_el_hizb.png',
              ), // Optional decoration
              opacity: 0.2,
            ),
          ),
          child: Center(
            child: Text(
              '${surah.number}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          surah.englishName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          '${surahTranslationsId[surah.number] ?? surah.englishNameTranslation} • ${surah.numberOfAyahs} Ayat',
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: Text(
          surah.name,
          style: TextStyle(
            fontFamily: 'Amiri', // Assuming fonts are set up
            fontSize: 20,
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: () {
          // Navigate to Reader with args
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuranReaderScreen(
                surahNumber: surah.number,
                surahName: surah.englishName,
                arabicName: surah.name,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Last Read Card
          if (_lastRead != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.menu_book,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Terakhir Dibaca',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _lastRead!['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ayat No: ${_lastRead!['ayah']}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuranReaderScreen(
                            surahNumber: _lastRead!['surah'],
                            surahName: _lastRead!['name'],
                            arabicName: '', // Optional or fetch
                          ),
                        ),
                      ).then((_) => _loadProgress());
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Lanjutkan',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 24),

          // Progress Tilawah
          Text(
            'Progress Tilawah',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1a2c26) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_readSurahCount dari 114 Surah',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      '${(_readSurahCount / 114 * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _readSurahCount / 114,
                    backgroundColor: isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
