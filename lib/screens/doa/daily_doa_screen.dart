import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../services/database_service.dart';

/// Daily Doa Screen - Using Doa API
/// Features: Category chips, Doa cards with Arabic text, translation, actions
class DailyDoaScreen extends StatefulWidget {
  const DailyDoaScreen({super.key});

  @override
  State<DailyDoaScreen> createState() => _DailyDoaScreenState();
}

class _DailyDoaScreenState extends State<DailyDoaScreen> {
  String _selectedCategory = 'Semua';
  final Set<String> _bookmarkedDoas = {}; // IDs of bookmarked doas
  List<Map<String, dynamic>> _doaList = [];
  bool _isLoading = true;
  String? _error;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<String> _categories = [
    'Semua',
    'Harian',
    'Ibadah',
    'Makan',
    'Tidur',
    'Bepergian',
  ];

  @override
  void initState() {
    super.initState();
    _fetchDoaList();
  }

  final DatabaseService _dbService = DatabaseService();

  Future<void> _fetchDoaList() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http
          .get(Uri.parse('https://doa-doa-api-ahmadramadhan.fly.dev/api'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Map API response to our format
        final List<Map<String, dynamic>> doaListMapped = data.map((doa) {
          return {
            'id': doa['id']?.toString() ?? '',
            'title': doa['doa'] ?? 'Doa',
            'arabic': doa['ayat'] ?? '',
            'latin': doa['latin'] ?? '',
            'translation': doa['artinya'] ?? '',
            'category': _categorize(doa['doa'] ?? ''),
          };
        }).toList();

        // Save to SQLite for offline access
        await _dbService.saveDoas(doaListMapped);

        // Load bookmarks from database
        await _loadBookmarksFromDb();

        setState(() {
          _doaList = doaListMapped;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Doa API Error: $e');
    }

    // Fallback: Try SQLite cache
    try {
      final cachedDoas = await _dbService.getAllDoas();
      if (cachedDoas.isNotEmpty) {
        setState(() {
          _doaList = cachedDoas;
          _bookmarkedDoas.addAll(
            cachedDoas
                .where((d) => d['isBookmarked'] == true)
                .map((d) => d['id'].toString()),
          );
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    // No data available
    setState(() {
      _isLoading = false;
      _error = 'Gagal memuat doa. Periksa koneksi internet.';
    });
  }

  Future<void> _loadBookmarksFromDb() async {
    final bookmarkedDoas = await _dbService.getBookmarkedDoas();
    setState(() {
      _bookmarkedDoas.addAll(bookmarkedDoas.map((d) => d['id'].toString()));
    });
  }

  Future<void> _toggleBookmark(String doaId, bool isCurrentlyBookmarked) async {
    final newState = !isCurrentlyBookmarked;
    await _dbService.toggleDoaBookmark(doaId, newState);
    setState(() {
      if (newState) {
        _bookmarkedDoas.add(doaId);
      } else {
        _bookmarkedDoas.remove(doaId);
      }
    });
  }

  String _categorize(String doaName) {
    final name = doaName.toLowerCase();
    if (name.contains('makan') || name.contains('minum')) return 'Makan';
    if (name.contains('tidur') || name.contains('bangun')) return 'Tidur';
    if (name.contains('pergi') ||
        name.contains('keluar') ||
        name.contains('masuk') ||
        name.contains('kendaraan')) {
      return 'Bepergian';
    }
    if (name.contains('sholat') ||
        name.contains('wudhu') ||
        name.contains('masjid') ||
        name.contains('adzan')) {
      return 'Ibadah';
    }
    return 'Harian';
  }

  List<Map<String, dynamic>> get _filteredDoas {
    var result = _doaList;

    // Filter by category
    if (_selectedCategory != 'Semua') {
      result = result.where((d) => d['category'] == _selectedCategory).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((d) {
        final title = (d['title'] ?? '').toString().toLowerCase();
        final translation = (d['translation'] ?? '').toString().toLowerCase();
        return title.contains(query) || translation.contains(query);
      }).toList();
    }

    return result;
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
            _buildSearchBar(isDark),
            _buildCategoryChips(isDark),
            Expanded(
              child: _isLoading
                  ? _buildLoadingIndicator()
                  : _error != null
                  ? _buildErrorWidget(isDark)
                  : _buildDoaListView(isDark),
            ),
          ],
        ),
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
          hintText: 'Cari doa...',
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
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  Widget _buildErrorWidget(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchDoaList,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildDoaListView(bool isDark) {
    final filteredDoas = _filteredDoas;

    if (filteredDoas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off
                  : Icons.hourglass_empty,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Tidak ada doa dengan kata kunci "$_searchQuery"'
                  : 'Tidak ada doa dalam kategori ini',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDoaList,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filteredDoas.length,
        itemBuilder: (context, index) {
          final doa = filteredDoas[index];
          final isBookmarked = _bookmarkedDoas.contains(doa['id']);

          return _buildDoaCard(
            context,
            isDark: isDark,
            doa: doa,
            index: index,
            total: filteredDoas.length,
            isBookmarked: isBookmarked,
          );
        },
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
              'Doa Harian',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0e1b16),
              ),
            ),
          ),
          IconButton(
            onPressed: _fetchDoaList,
            icon: Icon(
              Icons.refresh,
              color: isDark ? Colors.white : const Color(0xFF0e1b16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(bool isDark) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;

          return Container(
            margin: EdgeInsets.only(
              right: index < _categories.length - 1 ? 8 : 0,
            ),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                HapticFeedback.selectionClick();
                setState(() => _selectedCategory = category);
              },
              selectedColor: AppColors.primary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: isDark ? const Color(0xFF1a2e26) : Colors.white,
              side: BorderSide(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDoaCard(
    BuildContext context, {
    required bool isDark,
    required Map<String, dynamic> doa,
    required int index,
    required int total,
    required bool isBookmarked,
  }) {
    return Container(
          margin: const EdgeInsets.only(bottom: 16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with category
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        doa['category'] ?? 'Harian',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        doa['title'] ?? 'Doa',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        color: isBookmarked ? AppColors.primary : Colors.grey,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        _toggleBookmark(doa['id'].toString(), isBookmarked);
                      },
                    ),
                  ],
                ),
              ),

              // Arabic text
              if ((doa['arabic'] as String?)?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    doa['arabic'] ?? '',
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 22,
                      fontFamily: 'KFGQPC Uthmanic Script HAFS',
                      height: 2.0,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),

              // Latin transliteration
              if ((doa['latin'] as String?)?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    doa['latin'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),

              // Translation
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  doa['translation'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),

              // Action buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Clipboard.setData(
                          ClipboardData(
                            text:
                                '${doa['title']}\n\n${doa['arabic']}\n\n${doa['latin']}\n\n${doa['translation']}',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Doa berhasil disalin'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.copy,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      label: Text(
                        'Salin',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Clipboard.setData(
                          ClipboardData(
                            text:
                                '${doa['title']}\n\n${doa['arabic']}\n\n${doa['latin']}\n\n${doa['translation']}',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Doa disalin, siap untuk dibagikan'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.share,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      label: Text(
                        'Bagikan',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate(delay: Duration(milliseconds: 50 * index))
        .fadeIn()
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text('Memuat doa...', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}
