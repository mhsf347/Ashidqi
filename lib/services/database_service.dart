import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quran_db_models.dart';
import 'notification_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  // Status Control
  bool _isDownloading = false;
  bool _isPaused = false;
  bool get isDownloading => _isDownloading;
  bool get isPaused => _isPaused;

  final StreamController<double> _progressController =
      StreamController<double>.broadcast();
  Stream<double> get downloadProgress => _progressController.stream;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'quran.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Drop tables to force re-seed/upgrade logic to work cleanly
          await db.execute('DROP TABLE IF EXISTS ayahs');
          await db.execute('DROP TABLE IF EXISTS surahs');
          await db.execute('DROP TABLE IF EXISTS bookmarks');
          await _createTables(db);

          // Reset progress
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('last_seeded_surah', 0);
        }
        if (oldVersion < 3) {
          // Add doa table
          await db.execute('''
            CREATE TABLE IF NOT EXISTS doas(
              id TEXT PRIMARY KEY,
              title TEXT,
              arabic TEXT,
              latin TEXT,
              translation TEXT,
              category TEXT,
              is_bookmarked INTEGER DEFAULT 0
            )
          ''');
        }
        if (oldVersion < 4) {
          // Add hadith tables
          await db.execute('''
            CREATE TABLE IF NOT EXISTS hadith_narrators(
              slug TEXT PRIMARY KEY,
              name TEXT,
              total INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS hadiths(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              narrator_slug TEXT,
              number INTEGER,
              arab TEXT,
              translation TEXT,
              FOREIGN KEY(narrator_slug) REFERENCES hadith_narrators(slug)
            )
          ''');
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
        CREATE TABLE surahs(
          number INTEGER PRIMARY KEY,
          name TEXT,
          englishName TEXT,
          englishNameTranslation TEXT,
          numberOfAyahs INTEGER,
          revelationType TEXT
        )
      ''');

    await db.execute('''
        CREATE TABLE ayahs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          surahNumber INTEGER,
          number INTEGER,
          numberInSurah INTEGER,
          juz INTEGER,
          manzil INTEGER,
          page INTEGER,
          ruku INTEGER,
          hizbQuarter INTEGER,
          sajda INTEGER,
          text TEXT,
          textIndo TEXT,
          audio TEXT,
          tajweed TEXT, 
          FOREIGN KEY(surahNumber) REFERENCES surahs(number)
        )
      ''');

    await db.execute('''
        CREATE TABLE bookmarks(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          surahNumber INTEGER,
          ayahNumber INTEGER,
          timestamp INTEGER
        )
      ''');

    // Doa table for offline storage
    await db.execute('''
        CREATE TABLE doas(
          id TEXT PRIMARY KEY,
          title TEXT,
          arabic TEXT,
          latin TEXT,
          translation TEXT,
          category TEXT,
          is_bookmarked INTEGER DEFAULT 0
        )
      ''');

    // Hadith tables
    await db.execute('''
        CREATE TABLE hadith_narrators(
          slug TEXT PRIMARY KEY,
          name TEXT,
          total INTEGER
        )
      ''');
    await db.execute('''
        CREATE TABLE hadiths(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          narrator_slug TEXT,
          number INTEGER,
          arab TEXT,
          translation TEXT,
          FOREIGN KEY(narrator_slug) REFERENCES hadith_narrators(slug)
        )
      ''');
  }

  // --- Data Access Methods ---

  Future<List<SurahTable>> getAllSurahs() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query('surahs');
      return List.generate(maps.length, (i) => SurahTable.fromMap(maps[i]));
    } catch (e) {
      return [];
    }
  }

  Future<List<AyahTable>> getAyahsBySurah(int surahNumber) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'ayahs',
        where: 'surahNumber = ?',
        whereArgs: [surahNumber],
        orderBy: 'numberInSurah ASC',
      );
      return List.generate(maps.length, (i) => AyahTable.fromMap(maps[i]));
    } catch (e) {
      return [];
    }
  }

  Future<bool> isDatabaseSeeded() async {
    final db = await database;
    final prefs = await SharedPreferences.getInstance();
    final lastSurah = prefs.getInt('last_seeded_surah') ?? 0;

    // Consider seeded only if we reached 114 surahs
    if (lastSurah < 114) return false;

    try {
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM surahs'),
      );
      return count != null && count > 0;
    } catch (e) {
      return false;
    }
  }

  // --- Download Control ---

  void pauseDownload() {
    _isPaused = true;
    _isDownloading = false;
    _progressController.add(-1); // Signal paused state? Or just handle in UI
    NotificationService().cancelNotification(888); // Remove notification
  }

  Future<void> resumeDownload() async {
    _isPaused = false;
    await seedDatabase();
  }

  // --- Bookmark Methods ---

  Future<void> addBookmark(int surahNumber, int ayahNumber) async {
    final db = await database;
    await db.insert('bookmarks', {
      'surahNumber': surahNumber,
      'ayahNumber': ayahNumber,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeBookmark(int surahNumber, int ayahNumber) async {
    final db = await database;
    await db.delete(
      'bookmarks',
      where: 'surahNumber = ? AND ayahNumber = ?',
      whereArgs: [surahNumber, ayahNumber],
    );
  }

  Future<bool> isBookmarked(int surahNumber, int ayahNumber) async {
    final db = await database;
    final maps = await db.query(
      'bookmarks',
      where: 'surahNumber = ? AND ayahNumber = ?',
      whereArgs: [surahNumber, ayahNumber],
    );
    return maps.isNotEmpty;
  }

  Future<List<BookmarkTable>> getBookmarks() async {
    final db = await database;
    // Join with Surahs and Ayahs to get context
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
          SELECT b.id, b.surahNumber, b.ayahNumber, b.timestamp, 
                 s.englishName as surahName, 
                 a.text, a.textIndo
          FROM bookmarks b
          INNER JOIN surahs s ON b.surahNumber = s.number
          INNER JOIN ayahs a ON b.surahNumber = a.surahNumber AND b.ayahNumber = a.number
          ORDER BY b.timestamp DESC
      ''');

    return List.generate(maps.length, (i) => BookmarkTable.fromMap(maps[i]));
  }

  // --- Search Method ---

  Future<List<Map<String, dynamic>>> searchAyahs(String query) async {
    final db = await database;
    // Search in Indonesian Translation and Arabic Text (rarely used but optional)
    // Limit to 50 results for performance
    return await db.rawQuery(
      '''
          SELECT a.surahNumber, a.number, a.text, a.textIndo, s.englishName as surahName
          FROM ayahs a
          INNER JOIN surahs s ON a.surahNumber = s.number
          WHERE a.textIndo LIKE ? OR s.englishName LIKE ?
          LIMIT 50
      ''',
      ['%$query%', '%$query%'],
    );
  }

  // --- Seeding Logic ---

  Future<void> seedDatabase({Function(double)? onProgress}) async {
    if (_isDownloading) return; // Already running

    _isDownloading = true;
    _isPaused = false;

    final db = await database;
    final prefs = await SharedPreferences.getInstance();
    final notificationService = NotificationService();

    int lastSeeded = prefs.getInt('last_seeded_surah') ?? 0;

    try {
      // 1. Surah Meta (Only if starting from scratch)
      if (lastSeeded == 0) {
        // Clear tables to be safe
        await db.delete('surahs');
        await db.delete('ayahs');

        // Notify Starting
        notificationService.showProgressNotification(
          id: 888,
          title: 'Download Data Al-Quran',
          body: 'Menyiapkan metadata...',
          progress: 0,
          maxProgress: 100,
        );

        final surahResponse = await http.get(
          Uri.parse('http://api.alquran.cloud/v1/surah'),
        );

        if (surahResponse.statusCode == 200) {
          final data = json.decode(surahResponse.body)['data'] as List;
          final batch = db.batch();

          for (var item in data) {
            batch.insert('surahs', {
              'number': item['number'],
              'name': item['name'],
              'englishName': item['englishName'],
              'englishNameTranslation': item['englishNameTranslation'],
              'numberOfAyahs': item['numberOfAyahs'],
              'revelationType': item['revelationType'],
            });
          }
          await batch.commit(noResult: true);

          // Update Progress
          _progressController.add(0.05);
          onProgress?.call(0.05);
        }
      }

      // 2. Ayah Data (Loop)
      for (int i = lastSeeded + 1; i <= 114; i++) {
        // Check Pause
        if (_isPaused) {
          _isDownloading = false;
          return;
        }

        double progress = 0.05 + (0.95 * (i / 114));
        int progressPercent = (progress * 100).toInt();

        // Notify
        notificationService.showProgressNotification(
          id: 888,
          title: 'Download Data Al-Quran',
          body: 'Mengunduh Surah ke-$i dari 114...',
          progress: progressPercent,
          maxProgress: 100,
        );
        _progressController.add(progress);
        onProgress?.call(progress);

        // Fetch
        final response = await http.get(
          Uri.parse(
            'http://api.alquran.cloud/v1/surah/$i/editions/quran-uthmani,id.indonesian,quran-tajweed',
          ),
        );

        if (response.statusCode == 200) {
          final jsonBody = json.decode(response.body);
          final data = jsonBody['data'] as List;

          final arabicSurah = data[0];
          final indoSurah = data[1];
          final tajweedSurah = data[2];

          final ayahsArabic = arabicSurah['ayahs'] as List;
          final ayahsIndo = indoSurah['ayahs'] as List;
          final ayahsTajweed = tajweedSurah['ayahs'] as List;

          final batch = db.batch();

          for (int j = 0; j < ayahsArabic.length; j++) {
            final ar = ayahsArabic[j];
            final id = ayahsIndo[j];
            final tj = ayahsTajweed[j];

            batch.insert('ayahs', {
              'surahNumber': arabicSurah['number'],
              'number': ar['number'],
              'numberInSurah': ar['numberInSurah'],
              'juz': ar['juz'],
              'manzil': ar['manzil'],
              'page': ar['page'],
              'ruku': ar['ruku'],
              'hizbQuarter': ar['hizbQuarter'],
              'sajda':
                  (ar['sajda'] is bool && ar['sajda']) || (ar['sajda'] is Map)
                  ? 1
                  : 0,
              'text': ar['text'],
              'textIndo': id['text'],
              'audio': ar['audio'] ?? '',
              'tajweed': tj['text'],
            });
          }

          await batch.commit(noResult: true);

          // Save checkpoint
          await prefs.setInt('last_seeded_surah', i);
        }
      }

      // Complete
      _isDownloading = false;
      notificationService.cancelNotification(888);
      notificationService.showProgressNotification(
        id: 889,
        title: 'Download Selesai',
        body: 'Data Al-Quran siap digunakan offline.',
        progress: 100,
        maxProgress: 100,
      );
      // clear ongoing notif after delay
      Future.delayed(
        const Duration(seconds: 3),
        () => notificationService.cancelNotification(889),
      );

      _progressController.add(1.0);
      onProgress?.call(1.0);
    } catch (e) {
      _isDownloading = false;
      _isPaused = true; // Treat error as pause?
      debugPrint('Error seeding database: $e');
      notificationService.cancelNotification(888);
      rethrow;
    }
  }

  // --- Doa Methods ---

  /// Save list of doa to local database
  Future<void> saveDoas(List<Map<String, dynamic>> doaList) async {
    final db = await database;
    final batch = db.batch();

    for (var doa in doaList) {
      batch.insert('doas', {
        'id': doa['id']?.toString() ?? '',
        'title': doa['title'] ?? '',
        'arabic': doa['arabic'] ?? '',
        'latin': doa['latin'] ?? '',
        'translation': doa['translation'] ?? '',
        'category': doa['category'] ?? 'Harian',
        'is_bookmarked': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  /// Get all doa from local database
  Future<List<Map<String, dynamic>>> getAllDoas() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query('doas');
      return maps
          .map(
            (m) => {
              'id': m['id'],
              'title': m['title'],
              'arabic': m['arabic'],
              'latin': m['latin'],
              'translation': m['translation'],
              'category': m['category'],
              'isBookmarked': m['is_bookmarked'] == 1,
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting doas: $e');
      return [];
    }
  }

  /// Search doa by keyword
  Future<List<Map<String, dynamic>>> searchDoas(String query) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'doas',
        where: 'title LIKE ? OR translation LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
      );
      return maps
          .map(
            (m) => {
              'id': m['id'],
              'title': m['title'],
              'arabic': m['arabic'],
              'latin': m['latin'],
              'translation': m['translation'],
              'category': m['category'],
              'isBookmarked': m['is_bookmarked'] == 1,
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error searching doas: $e');
      return [];
    }
  }

  /// Toggle bookmark for a doa
  Future<void> toggleDoaBookmark(String doaId, bool isBookmarked) async {
    final db = await database;
    await db.update(
      'doas',
      {'is_bookmarked': isBookmarked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [doaId],
    );
  }

  /// Get bookmarked doas
  Future<List<Map<String, dynamic>>> getBookmarkedDoas() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'doas',
        where: 'is_bookmarked = 1',
      );
      return maps
          .map(
            (m) => {
              'id': m['id'],
              'title': m['title'],
              'arabic': m['arabic'],
              'latin': m['latin'],
              'translation': m['translation'],
              'category': m['category'],
              'isBookmarked': true,
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting bookmarked doas: $e');
      return [];
    }
  }

  /// Check if doas are cached
  Future<bool> hasDoasCached() async {
    final db = await database;
    try {
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM doas'),
      );
      return (count ?? 0) > 0;
    } catch (e) {
      return false;
    }
  }

  // --- Hadith Methods ---

  /// Save narrators to local database
  Future<void> saveNarrators(List<Map<String, dynamic>> narrators) async {
    final db = await database;
    final batch = db.batch();

    for (var narrator in narrators) {
      batch.insert('hadith_narrators', {
        'slug': narrator['slug'] ?? '',
        'name': narrator['name'] ?? '',
        'total': narrator['total'] ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  /// Get all narrators from local database
  Future<List<Map<String, dynamic>>> getNarrators() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'hadith_narrators',
      );
      return maps
          .map(
            (m) => {'slug': m['slug'], 'name': m['name'], 'total': m['total']},
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting narrators: $e');
      return [];
    }
  }

  /// Save hadiths to local database
  Future<void> saveHadiths(
    String narratorSlug,
    List<Map<String, dynamic>> hadiths,
  ) async {
    final db = await database;
    final batch = db.batch();

    for (var hadith in hadiths) {
      batch.insert('hadiths', {
        'narrator_slug': narratorSlug,
        'number': hadith['number'] ?? 0,
        'arab': hadith['arab'] ?? '',
        'translation': hadith['id'] ?? hadith['translation'] ?? '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  /// Get hadiths by narrator from local database
  Future<List<Map<String, dynamic>>> getHadithsByNarrator(
    String narratorSlug, {
    int page = 1,
    int limit = 20,
  }) async {
    final db = await database;
    try {
      final offset = (page - 1) * limit;
      final List<Map<String, dynamic>> maps = await db.query(
        'hadiths',
        where: 'narrator_slug = ?',
        whereArgs: [narratorSlug],
        limit: limit,
        offset: offset,
        orderBy: 'number ASC',
      );
      return maps
          .map(
            (m) => {
              'number': m['number'],
              'arab': m['arab'],
              'id': m['translation'],
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error getting hadiths: $e');
      return [];
    }
  }

  /// Search hadiths in local database
  Future<List<Map<String, dynamic>>> searchHadiths(
    String narratorSlug,
    String query,
  ) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'hadiths',
        where: 'narrator_slug = ? AND (arab LIKE ? OR translation LIKE ?)',
        whereArgs: [narratorSlug, '%$query%', '%$query%'],
      );
      return maps
          .map(
            (m) => {
              'number': m['number'],
              'arab': m['arab'],
              'id': m['translation'],
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error searching hadiths: $e');
      return [];
    }
  }

  /// Check if hadiths are cached for a narrator
  Future<bool> hasHadithsCached(String narratorSlug) async {
    final db = await database;
    try {
      final count = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM hadiths WHERE narrator_slug = ?',
          [narratorSlug],
        ),
      );
      return (count ?? 0) > 0;
    } catch (e) {
      return false;
    }
  }
}
