import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../core/utils/tajweed_parser.dart';
import '../../core/data/surah_translations.dart'; // Added
import '../../core/theme/app_colors.dart';
import '../../models/quran_model.dart';
import '../../models/qari_model.dart';
import '../../services/quran_service.dart';
import '../../services/database_service.dart'; // Added
import '../../services/storage_service.dart';

class QuranReaderScreen extends StatefulWidget {
  final int surahNumber;
  final String surahName;
  final String arabicName;

  const QuranReaderScreen({
    super.key,
    required this.surahNumber,
    required this.surahName,
    required this.arabicName,
  });

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  // Navigation & State
  int _selectedTab = 1;
  // Replace ScrollController with ItemScrollController
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  // Data
  late Future<List<Ayah>> _ayahsFuture;
  List<Ayah> _ayahs = [];
  Set<int> _bookmarkedAyahs = {};

  // Text Settings
  double _arabicFontSize = 28.0;

  // Audio Settings
  final AudioPlayer _audioPlayer = AudioPlayer();
  String _selectedQariIdentifier = 'ar.alafasy';
  List<Qari> _availableQaris = [];
  int? _playingVerse;
  bool _isPlayingAll = false;

  @override
  void initState() {
    super.initState();
    _fetchSurahDetail();
    _loadQaris();
    _loadBookmarks();

    _audioPlayer.onPlayerComplete.listen((event) {
      if (_playingVerse != null) {
        if (_isPlayingAll) {
          int nextIndex = _playingVerse! + 1;
          if (nextIndex < _ayahs.length) {
            _playVerse(nextIndex, _ayahs[nextIndex].audio);
            // Auto Scroll to next verse
            // Index in list is nextIndex + 1 (because index 0 is Header)
            _scrollToVerse(nextIndex + 1);
          } else {
            if (mounted) {
              setState(() {
                _playingVerse = null;
                _isPlayingAll = false;
              });
            }
          }
        } else {
          if (mounted) setState(() => _playingVerse = null);
        }
      }
    });
  }

  void _scrollToVerse(int listIndex) {
    try {
      _itemScrollController.scrollTo(
        index: listIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.1, // Align near top
      );
    } catch (e) {
      debugPrint("Scroll error: $e");
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _saveLastRead();
    super.dispose();
  }

  void _saveLastRead() async {
    // Save the first visible item index as last read
    // This is an approximation since we don't track exact scroll pixel
    // itemPositionsListener gives visible indices.
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isNotEmpty) {
      // Find the item closest to top (min index)
      int minIndex = positions
          .where((item) => item.itemLeadingEdge >= 0)
          .map((item) => item.index)
          .fold(9999, (prev, element) => element < prev ? element : prev);

      if (minIndex == 9999 && positions.isNotEmpty) {
        // If all are negative (scrolled past), take the last one or first visible
        minIndex = positions.first.index;
      }

      // Index 0 is header (Bismillah), verses start at 1?
      // Actually verses list includes header?
      // Let's check _buildVerseCard usage.
      // In _buildVerseCard logic (not visible here but general knowledge of this app structure),
      // usually list contains Ayah objects.
      // If index 0 is used for something else, we adjust.
      // Assuming naive 1-based mapping for now or 0-based from list.
      // Ayah object has 'numberInSurah'.

      if (minIndex < _ayahs.length && minIndex >= 0) {
        final ayah = _ayahs[minIndex];
        final storage = await StorageService.getInstance();
        storage.saveLastRead(
          widget.surahNumber,
          ayah.numberInSurah,
          widget.surahName,
        );

        // Mark as read if we reached near the end
        if (minIndex >= _ayahs.length - 2) {
          storage.markSurahAsRead(widget.surahNumber);
        }
      }
    }
  }

  // ... [Keep _loadBookmarks, _toggleBookmark, _fetchSurahDetail, _loadQaris] ...
  Future<void> _loadBookmarks() async {
    final dbService = DatabaseService();
    // We fetch all bookmarks to check containment efficiently?
    // Or just check for THIS surah?
    // Current design uses Set<int> _bookmarkedAyahs for the current surah.
    // Let's just fetch IDs for this Surah.
    // But our getBookmarks fetches ALL.
    // Optimization: Add getBookmarksBySurah to DB?
    // Or just iterate. Since bookmarks count is usually low (dozens), getAll is fine.

    final allBookmarks = await dbService.getBookmarks();
    final surahBookmarks = allBookmarks
        .where((b) => b.surahNumber == widget.surahNumber)
        .map((b) => b.ayahNumber)
        .toSet();

    if (mounted) {
      setState(() {
        _bookmarkedAyahs = surahBookmarks;
      });
    }
  }

  Future<void> _toggleBookmark(int index) async {
    final dbService = DatabaseService();

    // index in list usually maps to ayah.numberInSurah which is 'index' here?
    // Wait, _buildVerseCard passes `ayah.number`.
    // Let's verify usage in build method first.
    // Assuming 'index' passed here is actually the AYAH NUMBER (1-based) or LIST INDEX?
    // In _buildVerseCard: `_toggleBookmark(ayah.number)`

    // Check if currently bookmarked
    if (_bookmarkedAyahs.contains(index)) {
      await dbService.removeBookmark(widget.surahNumber, index);
      _bookmarkedAyahs.remove(index);
    } else {
      await dbService.addBookmark(widget.surahNumber, index);
      _bookmarkedAyahs.add(index);
    }

    setState(() {});
    HapticFeedback.lightImpact();
  }

  Future<void> _fetchSurahDetail() async {
    try {
      final dbService = DatabaseService();
      final ayahsTable = await dbService.getAyahsBySurah(widget.surahNumber);

      if (ayahsTable.isNotEmpty) {
        final List<Ayah> mappedAyahs = ayahsTable
            .map(
              (t) => Ayah(
                numberInSurah: t.numberInSurah,
                text: t.text,
                translation: t.textIndo,
                // Construct Audio URL dynamically
                audio:
                    'https://cdn.islamic.network/quran/audio/128/$_selectedQariIdentifier/${t.number}.mp3',
                number: t.number,
                juz: t.juz,
                manzil: t.manzil,
                page: t.page,
                ruku: t.ruku,
                hizbQuarter: t.hizbQuarter,
                sajdah: t.sajda, // Fixed: sajda -> sajdah
                tajweed: t.tajweed, // Map tajweed
              ),
            )
            .toList();

        if (mounted) {
          setState(() {
            _ayahs = mappedAyahs;
            _ayahsFuture = Future.value(mappedAyahs);
          });
        }
      } else {
        // Fallback to API if DB is empty (shouldn't happen if check passed)
        // Or just show empty/error
        setState(() {
          _ayahsFuture =
              QuranService.getSurahDetail(
                widget.surahNumber,
                audioIdentifier: _selectedQariIdentifier,
              ).then((value) {
                _ayahs = value;
                return value;
              });
        });
      }
    } catch (e) {
      debugPrint('Error fetching from DB: $e');
    }
  }

  Future<void> _loadQaris() async {
    try {
      final qaris = await QuranService.getQariList();
      if (mounted) setState(() => _availableQaris = qaris);
    } catch (e) {
      debugPrint('Error loading qaris: $e');
    }
  }

  Future<void> _playVerse(int index, String? audioUrl) async {
    if (audioUrl == null) return;

    if (_playingVerse == index && _playingVerse != null) {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _playingVerse = null;
          _isPlayingAll = false;
        });
      }
    } else {
      if (mounted) setState(() => _playingVerse = index);
      try {
        await _audioPlayer.play(UrlSource(audioUrl));
      } catch (e) {
        debugPrint("Audio Play Error: $e");
        if (mounted) setState(() => _playingVerse = null);
      }
    }
  }

  Future<void> _playAll() async {
    if (_ayahs.isEmpty) return;

    if (_isPlayingAll && _playingVerse != null) {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _playingVerse = null;
          _isPlayingAll = false;
        });
      }
    } else {
      int startIndex = 0;
      if (_playingVerse != null) startIndex = _playingVerse!;

      setState(() => _isPlayingAll = true);
      _playVerse(startIndex, _ayahs[startIndex].audio);

      // Initial Scroll
      _scrollToVerse(startIndex + 1);
    }
  }

  // ... [Keep _showQariSelection, _showTextSettings, _navigateToSurah] ...

  // Available Tafsirs
  final Map<String, String> _tafsirEditions = {
    'id.jalalayn': 'Tafsir Jalalayn',
    'id.muntakhab': 'Tafsir Quraish Shihab (Muntakhab)',
    'id.indonesian': 'Terjemahan Kemenag',
  };
  String _selectedTafsirEdition = 'id.jalalayn';

  void _showTafsirDialog(int surahNumber, int verseNumber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return StatefulBuilder(
              builder: (context, setSheetState) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1a2c26) : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Tafsir',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : Colors.grey.shade900,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey.shade900
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedTafsirEdition,
                                  isDense: true,
                                  dropdownColor: isDark
                                      ? Colors.grey.shade900
                                      : Colors.white,
                                  items: _tafsirEditions.entries
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e.key,
                                          child: Text(
                                            e.value,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setSheetState(
                                        () => _selectedTafsirEdition = val,
                                      );
                                      // Also update main state to persist? Unnecessary if per-session.
                                      setState(
                                        () => _selectedTafsirEdition = val,
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Surah ${widget.surahName} : $verseNumber',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: FutureBuilder<String?>(
                          future: QuranService.getAyahTafsir(
                            surahNumber,
                            verseNumber,
                            editionId: _selectedTafsirEdition,
                          ),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            } else if (snapshot.hasError) {
                              return Center(
                                child: Text(
                                  "Gagal memuat tafsir",
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              );
                            } else if (!snapshot.hasData ||
                                snapshot.data == null) {
                              return Center(
                                child: Text(
                                  "Tafsir tidak tersedia",
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              );
                            }

                            return ListView(
                              controller: scrollController,
                              padding: const EdgeInsets.all(24),
                              children: [
                                Text(
                                  snapshot.data!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.6,
                                    color: isDark
                                        ? Colors.grey.shade200
                                        : Colors.grey.shade800,
                                  ),
                                  textAlign: TextAlign.justify,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showQariSelection() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Pilih Qari (Pengajian)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _availableQaris.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _availableQaris.length,
                        itemBuilder: (context, index) {
                          final qari = _availableQaris[index];
                          final isSelected =
                              qari.identifier == _selectedQariIdentifier;
                          return ListTile(
                            title: Text(qari.name),
                            subtitle: Text(qari.englishName),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: AppColors.primary,
                                  )
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedQariIdentifier = qari.identifier;
                              });
                              _fetchSurahDetail();
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Display Settings
  bool _showTranslation = true;
  bool _showActions = true;
  bool _showTajweed = false;

  void _showSearchDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String searchQuery = '';

        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return StatefulBuilder(
              builder: (context, setSheetState) {
                // Filter Logic (Current Surah Only)
                List<Ayah> results = [];
                bool isNumeric = int.tryParse(searchQuery) != null;

                if (searchQuery.isNotEmpty) {
                  if (!isNumeric) {
                    // Text: Filter current surah ayahs
                    results = _ayahs
                        .where(
                          (ayah) =>
                              (ayah.translation ?? '').toLowerCase().contains(
                                searchQuery.toLowerCase(),
                              ) ||
                              ayah.text.contains(searchQuery),
                        )
                        .toList();
                  }
                }

                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1a2c26) : Colors.white,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          "Cari di Surah ${widget.surahName}",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.grey.shade900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: TextField(
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText:
                                "Nomor ayat (1-${_ayahs.length}) atau teks...",
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: isDark
                                ? Colors.grey.shade900
                                : Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          onChanged: (value) {
                            setSheetState(() => searchQuery = value);
                          },
                          onSubmitted: (value) {
                            if (value.isEmpty) return;
                            final number = int.tryParse(value);
                            if (number != null &&
                                number > 0 &&
                                number <= _ayahs.length) {
                              Navigator.pop(context);
                              _scrollToVerse(number);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: searchQuery.isEmpty
                            ? Center(
                                child: Text(
                                  "Ketik angka untuk lompat ke ayat\natau teks untuk mencari.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: isNumeric ? 1 : results.length,
                                padding: const EdgeInsets.all(24),
                                itemBuilder: (context, index) {
                                  if (isNumeric) {
                                    int target = int.tryParse(searchQuery) ?? 1;
                                    if (target > 0 && target <= _ayahs.length) {
                                      return ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.2,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            "$target",
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          "Lompat ke Ayat $target",
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onTap: () {
                                          Navigator.pop(context);
                                          _scrollToVerse(target);
                                        },
                                      );
                                    } else {
                                      return ListTile(
                                        title: Text(
                                          "Ayat tidak ditemukan (Max ${_ayahs.length})",
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      );
                                    }
                                  } else {
                                    final ayah = results[index];
                                    return ListTile(
                                      leading: Text(
                                        "${ayah.numberInSurah}",
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      title: Text(
                                        ayah.translation ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(
                                        ayah.text,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.amiri(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        _scrollToVerse(ayah.numberInSurah);
                                      },
                                    );
                                  }
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showTextSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true, // Allow full height if needed
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text(
                        'Tampilan Ayat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Font Size Slider
                      Row(
                        children: [
                          const Text(
                            'Ukuran Teks',
                            style: TextStyle(fontSize: 14),
                          ),
                          Expanded(
                            child: Slider(
                              value: _arabicFontSize,
                              min: 20.0,
                              max: 60.0,
                              divisions: 8,
                              label: _arabicFontSize.round().toString(),
                              onChanged: (value) {
                                setModalState(() => _arabicFontSize = value);
                                setState(() => _arabicFontSize = value);
                              },
                            ),
                          ),
                          Text(
                            '${_arabicFontSize.toInt()}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      // Toggles
                      SwitchListTile(
                        title: const Text('Terjemahan'),
                        value: _showTranslation,
                        onChanged: (val) {
                          setModalState(() => _showTranslation = val);
                          setState(() => _showTranslation = val);
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Tombol Aksi'),
                        subtitle: const Text('Play, Bookmark, Tafsir'),
                        value: _showActions,
                        onChanged: (val) {
                          setModalState(() => _showActions = val);
                          setState(() => _showActions = val);
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Tajweed Berwarna'),
                        value: _showTajweed,
                        onChanged: (val) {
                          setModalState(() => _showTajweed = val);
                          setState(() => _showTajweed = val);
                        },
                      ),
                      if (_showTajweed) ...[
                        const Divider(),
                        const Text(
                          'Panduan Warna Tajweed',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: TajweedParser.rules.values.map((rule) {
                            return _buildTajweedLegendItem(
                              rule.color,
                              rule.label,
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTajweedLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF10221b)
          : const Color(0xFFF6F8F7),
      body: Stack(
        children: [
          Column(
            children: [
              _buildNavBar(context, isDark),
              Expanded(
                child: FutureBuilder<List<Ayah>>(
                  future: _ayahsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('Data tidak ditemukan'));
                    }

                    final ayahs = snapshot.data!;

                    // Use ScrollablePositionedList instead of ListView
                    return ScrollablePositionedList.builder(
                      itemScrollController: _itemScrollController,
                      itemPositionsListener: _itemPositionsListener,
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 0,
                        bottom: 100,
                      ),
                      itemCount: ayahs.length + 2,
                      itemBuilder: (context, index) {
                        // 0 = Header
                        if (index == 0) {
                          return Column(
                            children: [
                              if (widget.surahNumber != 9 &&
                                  widget.surahNumber != 1)
                                _buildBismillahHeader(
                                  isDark,
                                ).animate().fadeIn(duration: 400.ms)
                              else
                                const SizedBox(height: 24),

                              Center(
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  child: ElevatedButton.icon(
                                    onPressed: _playAll,
                                    icon: Icon(
                                      _isPlayingAll
                                          ? Icons.stop
                                          : Icons.play_arrow,
                                    ),
                                    label: Text(
                                      _isPlayingAll
                                          ? 'Stop Info Audio'
                                          : 'Putar Semua Ayat',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: const StadiumBorder(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        // Last Item = Navigation Buttons
                        if (index == ayahs.length + 1) {
                          return _buildSurahNavigation(isDark);
                        }

                        final ayahIndex = index - 1;
                        final ayah = ayahs[ayahIndex];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child:
                              _buildVerseCard(
                                    context,
                                    isDark: isDark,
                                    verseNumber: ayah.numberInSurah,
                                    arabic: ayah.text,
                                    translation: ayah.translation ?? '',
                                    tajweedText: ayah.tajweed,
                                    isPlaying: _playingVerse == ayahIndex,
                                    isBookmarked: _bookmarkedAyahs.contains(
                                      ayahIndex,
                                    ),
                                    onPlay: () {
                                      if (_isPlayingAll) {
                                        setState(() => _isPlayingAll = false);
                                      }
                                      _playVerse(ayahIndex, ayah.audio);
                                    },
                                    onBookmark: () =>
                                        _toggleBookmark(ayahIndex),
                                    onTafsir: () => _showTafsirDialog(
                                      widget.surahNumber,
                                      ayah.numberInSurah,
                                    ),
                                  )
                                  .animate(
                                    delay: Duration(
                                      milliseconds:
                                          30 *
                                          (ayahIndex > 10 ? 10 : ayahIndex),
                                    ),
                                  )
                                  .fadeIn(duration: 300.ms)
                                  .slideY(begin: 0.05, end: 0),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomToolbar(context, isDark),
          ),
        ],
      ),
    );
  }

  // ... [Rest of method implementations: _buildSurahNavigation, _buildNavBar, etc. MUST BE INCLUDED] ...
  // Navigation Footer with Previous / Next Surah Buttons
  Widget _buildSurahNavigation(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Button
          if (widget.surahNumber > 1)
            Expanded(
              child: InkWell(
                onTap: () => _navigateToSurah(widget.surahNumber - 1),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2F29) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.arrow_back_ios,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sebelumnya',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                            Text(
                              surahTranslationsId[widget.surahNumber - 1] ??
                                  'Surah ${widget.surahNumber - 1}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            const Expanded(child: SizedBox()),

          if (widget.surahNumber > 1 && widget.surahNumber < 114)
            const SizedBox(width: 12),

          // Next Button
          if (widget.surahNumber < 114)
            Expanded(
              child: InkWell(
                onTap: () => _navigateToSurah(widget.surahNumber + 1),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2F29) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Selanjutnya',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                            Text(
                              surahTranslationsId[widget.surahNumber + 1] ??
                                  'Surah ${widget.surahNumber + 1}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  void _navigateToSurah(int number) {
    if (number < 1 || number > 114) return;

    // Use the translation map for name or generic
    String name = surahTranslationsId[number] ?? 'Surah $number';

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuranReaderScreen(
          surahNumber: number,
          surahName: name, // Passed name
          arabicName: '', // Can be fetched inside or passed if known
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context, bool isDark) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 4,
            right: 4,
            bottom: 12,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF10221b).withValues(alpha: 0.95)
                : const Color(0xFFF6F8F7).withValues(alpha: 0.95),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.grey.shade800.withValues(alpha: 0.5)
                    : Colors.grey.shade200.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : Colors.grey.shade800,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.surahName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.arabicName.isNotEmpty
                          ? widget.arabicName
                          : 'Surah ${widget.surahNumber}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBismillahHeader(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24, top: 16),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: isDark ? 0.1 : 0.05),
            Colors.transparent,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: GoogleFonts.amiri(
          fontSize: 32,
          fontWeight: FontWeight.w400,
          color: isDark ? Colors.grey.shade100 : Colors.grey.shade800,
          height: 1.8,
        ),
      ),
    );
  }

  // ... (inside class)

  Widget _buildVerseCard(
    BuildContext context, {
    required bool isDark,
    required int verseNumber,
    required String arabic,
    required String translation,
    String? tajweedText,
    required bool isPlaying,
    required bool isBookmarked,
    required VoidCallback onPlay,
    required VoidCallback onBookmark,
    required VoidCallback onTafsir,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a2c26) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: AppColors.primary, width: 6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Verse Number and Arabic Text
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Verse Number Bubble
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(
                      alpha: isDark ? 0.2 : 0.1,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$verseNumber',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Arabic Text (Tajweed or Plain)
                Expanded(
                  child: _showTajweed && tajweedText != null
                      ? RichText(
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          text: TextSpan(
                            children: TajweedParser.parseToSpans(
                              tajweedText,
                              fontSize: _arabicFontSize,
                              isDark: isDark,
                            ),
                            style: GoogleFonts.amiri(height: 2.5),
                          ),
                        )
                      : Text(
                          arabic,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: GoogleFonts.amiri(
                            fontSize: _arabicFontSize,
                            fontWeight: FontWeight.w400,
                            color: isDark
                                ? Colors.grey.shade100
                                : Colors.grey.shade800,
                            height: 2.5,
                          ),
                        ),
                ),
              ],
            ),

            // Translation
            if (_showTranslation) ...[
              const SizedBox(height: 16),
              Text(
                translation,
                style: TextStyle(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],

            // Action Buttons
            if (_showActions) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.grey.shade800.withValues(alpha: 0.5)
                          : Colors.grey.shade100,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _buildCircleButton(
                      icon: _isPlayingAll && isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      isPrimary: isPlaying,
                      isDark: isDark,
                      onTap: onPlay,
                    ),
                    const SizedBox(width: 8),
                    _buildCircleButton(
                      icon: Icons.menu_book,
                      isPrimary: false,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onTafsir();
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildCircleButton(
                      icon: isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      isPrimary: false,
                      isDark: isDark,
                      isActive: isBookmarked,
                      onTap: onBookmark,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => HapticFeedback.lightImpact(),
                      icon: Icon(
                        Icons.share,
                        size: 20,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required bool isPrimary,
    required bool isDark,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isPrimary
              ? AppColors.primary
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
          shape: BoxShape.circle,
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 20,
          color: isPrimary
              ? Colors.white
              : isActive
              ? AppColors.primary
              : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1a2c26) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: SizedBox(
            height: 80, // Increased to accommodate icon + text
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceAround, // Evenly space 3 items
              children: [
                _buildToolbarItem(
                  icon: Icons.search,
                  label: 'Search',
                  isSelected: _selectedTab == 2,
                  isDark: isDark,
                  onTap: () {
                    setState(() => _selectedTab = 2);
                    _showSearchDialog();
                  },
                ),
                _buildMainAudioButton(isDark),
                _buildToolbarItem(
                  icon: Icons.settings,
                  label: 'Settings',
                  isSelected: _selectedTab == 3,
                  isDark: isDark,
                  onTap: () {
                    setState(() => _selectedTab = 3);
                    _showTextSettings();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.lightImpact();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 26,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade500),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainAudioButton(bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedTab = 1);
        _showQariSelection();
        HapticFeedback.mediumImpact();
      },
      child: Transform.translate(
        offset: const Offset(0, -12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark ? const Color(0xFF1a2c26) : Colors.white,
                  width: 4,
                ),
              ),
              child: const Icon(
                Icons.music_note_rounded, // Changed from play_arrow
                size: 32,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Audio',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
