import 'package:shared_preferences/shared_preferences.dart';

/// Storage Service for managing local data persistence
class StorageService {
  static const String _themeKey = 'theme_mode';
  static const String _tasbihCountKey = 'tasbih_count';
  static const String _tasbihTargetKey = 'tasbih_target';
  static const String _locationCityKey = 'location_city';
  static const String _locationCountryKey = 'location_country';

  // Singleton pattern
  static StorageService? _instance;
  static SharedPreferences? _prefs;

  StorageService._();

  static Future<StorageService> getInstance() async {
    _instance ??= StorageService._();
    _prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  // Theme Methods
  Future<void> saveThemeMode(String mode) async {
    await _prefs?.setString(_themeKey, mode);
  }

  String getThemeMode() {
    return _prefs?.getString(_themeKey) ?? 'system';
  }

  // Tasbih Methods
  Future<void> saveTasbihCount(int count) async {
    await _prefs?.setInt(_tasbihCountKey, count);
  }

  int getTasbihCount() {
    return _prefs?.getInt(_tasbihCountKey) ?? 0;
  }

  Future<void> saveTasbihTarget(int target) async {
    await _prefs?.setInt(_tasbihTargetKey, target);
  }

  int getTasbihTarget() {
    return _prefs?.getInt(_tasbihTargetKey) ?? 33;
  }

  // Location Methods
  Future<void> saveLocation(String city, String country) async {
    await _prefs?.setString(_locationCityKey, city);
    await _prefs?.setString(_locationCountryKey, country);
  }

  String getCity() {
    return _prefs?.getString(_locationCityKey) ?? 'Jakarta';
  }

  String getCountry() {
    return _prefs?.getString(_locationCountryKey) ?? 'Indonesia';
  }

  // Last Read Logic
  static const String _lastReadSurahKey = 'last_read_surah';
  static const String _lastReadAyahKey = 'last_read_ayah';
  static const String _lastReadSurahNameKey = 'last_read_surah_name';
  static const String _readSurahsKey = 'read_surahs_ids';

  Future<void> saveLastRead(
    int surahNumber,
    int ayahNumber,
    String surahName,
  ) async {
    await _prefs?.setInt(_lastReadSurahKey, surahNumber);
    await _prefs?.setInt(_lastReadAyahKey, ayahNumber);
    await _prefs?.setString(_lastReadSurahNameKey, surahName);
  }

  Map<String, dynamic>? getLastRead() {
    final surah = _prefs?.getInt(_lastReadSurahKey);
    final ayah = _prefs?.getInt(_lastReadAyahKey);
    final name = _prefs?.getString(_lastReadSurahNameKey);

    if (surah != null && ayah != null && name != null) {
      return {'surah': surah, 'ayah': ayah, 'name': name};
    }
    return null;
  }

  // Progress Logic (Surahs Completed)
  Future<void> markSurahAsRead(int surahNumber) async {
    final List<String> readSurahs = _prefs?.getStringList(_readSurahsKey) ?? [];
    if (!readSurahs.contains(surahNumber.toString())) {
      readSurahs.add(surahNumber.toString());
      await _prefs?.setStringList(_readSurahsKey, readSurahs);
    }
  }

  List<int> getReadSurahs() {
    final List<String> readSurahs = _prefs?.getStringList(_readSurahsKey) ?? [];
    return readSurahs.map((e) => int.parse(e)).toList();
  }

  // Quran Bookmarks
  // Key format: 'bookmark_surah_{surahId}' -> List<String> of ayah indices

  Future<void> toggleAyahBookmark(int surahNumber, int ayahIndex) async {
    final key = 'bookmark_surah_$surahNumber';
    List<String> bookmarks = _prefs?.getStringList(key) ?? [];

    final val = ayahIndex.toString();
    if (bookmarks.contains(val)) {
      bookmarks.remove(val);
    } else {
      bookmarks.add(val);
    }

    await _prefs?.setStringList(key, bookmarks);
  }

  List<int> getBookmarkedAyahs(int surahNumber) {
    final key = 'bookmark_surah_$surahNumber';
    final bookmarks = _prefs?.getStringList(key) ?? [];
    return bookmarks.map((e) => int.parse(e)).toList();
  }

  // Clear all data
  Future<void> clearAll() async {
    await _prefs?.clear();
  }
}
