import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../services/database_service.dart';

/// Hadith Screen - Using Hadith API
/// Features: Narrator selection, Hadith list with Arabic text, search, pagination
class HadithScreen extends StatefulWidget {
  const HadithScreen({super.key});

  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen> {
  final DatabaseService _dbService = DatabaseService();

  // State
  List<Map<String, dynamic>> _narrators = [];
  List<Map<String, dynamic>> _hadiths = [];
  String? _selectedNarrator;
  String _selectedNarratorName = 'Pilih Perawi';
  bool _isLoadingNarrators = true;
  bool _isLoadingHadiths = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMorePages = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Scroll controller for pagination
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchNarrators();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingHadiths && _hasMorePages && _selectedNarrator != null) {
        _loadMoreHadiths();
      }
    }
  }

  // Convert slug to formatted name (e.g., "abu-dawud" -> "Abu Dawud")
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

  Future<void> _fetchNarrators() async {
    setState(() {
      _isLoadingNarrators = true;
      _error = null;
    });

    try {
      final response = await http
          .get(Uri.parse('https://hadith-api-go.vercel.app/api/v1/narrators'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // API returns data.available as list of strings (slugs)
        final List<dynamic> narratorSlugs = data['data']?['available'] ?? [];

        final narratorsMapped = narratorSlugs
            .map(
              (slug) => {
                'slug': slug.toString(),
                'name': _formatNarratorName(slug.toString()),
                'total': 0, // API doesn't provide total in this endpoint
              },
            )
            .toList();

        // Save to SQLite
        await _dbService.saveNarrators(narratorsMapped);

        setState(() {
          _narrators = narratorsMapped;
          _isLoadingNarrators = false;
        });

        if (_narrators.isNotEmpty) {
          _selectNarrator(_narrators[0]);
        }
        return;
      }
    } catch (e) {
      debugPrint('Narrators API Error: $e');
    }

    // Fallback: Try SQLite
    try {
      final cachedNarrators = await _dbService.getNarrators();
      if (cachedNarrators.isNotEmpty) {
        setState(() {
          _narrators = cachedNarrators;
          _isLoadingNarrators = false;
        });
        if (_narrators.isNotEmpty) {
          _selectNarrator(_narrators[0]);
        }
        return;
      }
    } catch (_) {}

    setState(() {
      _isLoadingNarrators = false;
      _error = 'Gagal memuat data perawi';
    });
  }

  void _selectNarrator(Map<String, dynamic> narrator) {
    setState(() {
      _selectedNarrator = narrator['slug'];
      _selectedNarratorName = narrator['name'];
      _hadiths = [];
      _currentPage = 1;
      _hasMorePages = true;
    });
    _fetchHadiths();
  }

  Future<void> _fetchHadiths() async {
    if (_selectedNarrator == null) return;

    setState(() {
      _isLoadingHadiths = true;
      _error = null;
    });

    try {
      String url =
          'https://hadith-api-go.vercel.app/api/v1/hadis/$_selectedNarrator?page=$_currentPage&limit=20';
      if (_searchQuery.isNotEmpty) {
        url += '&q=$_searchQuery';
      }

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> hadithList = data['data'] ?? [];

        final hadithsMapped = hadithList
            .map(
              (h) => {
                'number': h['number'] ?? 0,
                'arab': h['arab'] ?? '',
                'id': h['id'] ?? '',
              },
            )
            .toList();

        // Save to SQLite (only first page without search)
        if (_currentPage == 1 && _searchQuery.isEmpty) {
          await _dbService.saveHadiths(_selectedNarrator!, hadithsMapped);
        }

        setState(() {
          if (_currentPage == 1) {
            _hadiths = hadithsMapped;
          } else {
            _hadiths.addAll(hadithsMapped);
          }
          _hasMorePages = hadithList.length >= 20;
          _isLoadingHadiths = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Hadiths API Error: $e');
    }

    // Fallback: Try SQLite
    if (_currentPage == 1) {
      try {
        final cachedHadiths = await _dbService.getHadithsByNarrator(
          _selectedNarrator!,
          page: _currentPage,
          limit: 20,
        );
        if (cachedHadiths.isNotEmpty) {
          setState(() {
            _hadiths = cachedHadiths;
            _hasMorePages = cachedHadiths.length >= 20;
            _isLoadingHadiths = false;
          });
          return;
        }
      } catch (_) {}
    }

    setState(() {
      _isLoadingHadiths = false;
      if (_currentPage == 1) {
        _error = 'Gagal memuat hadits';
      }
    });
  }

  Future<void> _loadMoreHadiths() async {
    if (_isLoadingHadiths || !_hasMorePages) return;
    _currentPage++;
    await _fetchHadiths();
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 1;
      _hadiths = [];
    });
    _fetchHadiths();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF10221b)
          : const Color(0xFFF5F8F7),
      body: Stack(
        children: [
          // Subtle background pattern
          Positioned.fill(
            child: Opacity(
              opacity: 0.03,
              child: CustomPaint(
                painter: DotPatternPainter(color: AppColors.primary),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, isDark),
                _buildNarratorSelector(isDark),
                _buildSearchBar(isDark),
                Expanded(
                  child: _isLoadingNarrators
                      ? _buildLoading()
                      : _error != null && _hadiths.isEmpty
                      ? _buildError(isDark)
                      : _buildHadithList(isDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    final canPop = Navigator.canPop(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(
                Icons.arrow_back,
                color: isDark ? Colors.white : const Color(0xFF0d1c16),
              ),
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              'Hadits',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSerif(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0d1c16),
              ),
            ),
          ),
          IconButton(
            onPressed: _fetchNarrators,
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white : const Color(0xFF0d1c16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarratorSelector(bool isDark) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _narrators.length,
        itemBuilder: (context, index) {
          final narrator = _narrators[index];
          final isSelected = _selectedNarrator == narrator['slug'];

          return GestureDetector(
            onTap: () => _selectNarrator(narrator),
            child: Container(
              margin: EdgeInsets.only(
                right: index < _narrators.length - 1 ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF1a2e26) : Colors.white),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    narrator['name'],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.black
                          : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                  Text(
                    '${narrator['total']} hadits',
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected
                          ? Colors.black54
                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a2e26) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: 'Cari hadits...',
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[500] : Colors.grey[400],
          ),
          prefixIcon: Icon(
            Icons.search,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onSubmitted: _onSearch,
        onChanged: (value) {
          if (value.isEmpty && _searchQuery.isNotEmpty) {
            _onSearch('');
          }
        },
      ),
    );
  }

  Widget _buildHadithList(bool isDark) {
    if (_hadiths.isEmpty && !_isLoadingHadiths) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _selectedNarrator == null
                  ? 'Pilih perawi untuk melihat hadits'
                  : 'Tidak ada hadits ditemukan',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _currentPage = 1;
        await _fetchHadiths();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _hadiths.length + (_hasMorePages ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _hadiths.length) {
            return _isLoadingHadiths
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }

          final hadith = _hadiths[index];
          return _buildHadithCard(hadith, isDark, index);
        },
      ),
    );
  }

  Widget _buildHadithCard(Map<String, dynamic> hadith, bool isDark, int index) {
    return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1a332a) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_selectedNarratorName #${hadith['number']}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final text =
                          '${hadith['arab']}\n\n${hadith['id']}\n\n- $_selectedNarratorName #${hadith['number']}';
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hadits berhasil disalin'),
                        ),
                      );
                    },
                    icon: Icon(Icons.copy, size: 20, color: Colors.grey[500]),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Arabic text
              if ((hadith['arab'] as String?)?.isNotEmpty ?? false)
                Text(
                  hadith['arab'] ?? '',
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.amiri(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0d1c16),
                    height: 2.0,
                  ),
                ),

              const SizedBox(height: 16),

              // Divider
              Container(
                height: 2,
                width: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),

              const SizedBox(height: 16),

              // Indonesian translation
              Text(
                hadith['id'] ?? '',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                  height: 1.6,
                ),
              ),
            ],
          ),
        )
        .animate(delay: Duration(milliseconds: 50 * (index % 10)))
        .fadeIn()
        .slideY(begin: 0.05, end: 0);
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text('Memuat data...', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Terjadi kesalahan',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchNarrators,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for dot pattern background
class DotPatternPainter extends CustomPainter {
  final Color color;

  DotPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const spacing = 24.0;
    const radius = 1.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
