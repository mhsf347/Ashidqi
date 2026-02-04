import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/quran_model.dart';
import '../models/qari_model.dart';

class QuranService {
  static const String _baseUrl = 'http://api.alquran.cloud/v1';

  /// Fetch list of all 114 Surahs
  static Future<List<Surah>> getAllSurahs() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/surah'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> surahsJson = data['data'];
        return surahsJson.map((json) => Surah.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load surahs');
      }
    } catch (e) {
      debugPrint('Error fetching surahs: $e');
      return [];
    }
  }

  // Cache for Surah names
  static final Map<int, String> _surahNamesCache = {};

  /// Get cached Surah Name (English)
  static String? getSurahName(int number) {
    return _surahNamesCache[number];
  }

  /// Get specific Surah with Arabic Text, Indonesian Translation, Audio, and Tajweed
  static Future<List<Ayah>> getSurahDetail(
    int surahNumber, {
    String audioIdentifier = 'ar.alafasy',
  }) async {
    try {
      // Fetch Arabic, Indonesian, Audio, and Tajweed
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/surah/$surahNumber/editions/quran-uthmani,id.indonesian,$audioIdentifier,quran-tajweed',
        ),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> data = json['data'];

        // data[0] is Arabic, data[1] is Indonesian, data[2] is Audio, data[3] is Tajweed
        final arabicAyahs = data[0]['ayahs'] as List;
        final indoAyahs = data[1]['ayahs'] as List;
        final audioAyahs = data[2]['ayahs'] as List;
        final tajweedAyahs = data[3]['ayahs'] as List;

        List<Ayah> result = [];

        for (int i = 0; i < arabicAyahs.length; i++) {
          final arabic = arabicAyahs[i];
          final indo = indoAyahs[i];
          final audio = audioAyahs[i];
          final tajweed = tajweedAyahs[i];

          final Map<String, dynamic> ayahMap = arabic;
          ayahMap['translation'] = indo['text'];
          ayahMap['audio'] = audio['audio'];
          ayahMap['tajweed'] = tajweed['text']; // Add Tajweed text

          result.add(Ayah.fromJson(ayahMap));
        }

        return result;
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching surah detail: $e');
      return [];
    }
  }

  /// Fetch list of available Qaris (Audio Editions)
  static Future<List<Qari>> getQariList() async {
    try {
      // Filter for audio format and versebyverse type
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/edition?format=audio&language=ar&type=versebyverse',
        ),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List<dynamic> data = json['data'];
        return data.map((json) => Qari.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching qari list: $e');
      return [];
    }
  }

  /// Get Tafsir for a specific Ayah
  static Future<String?> getAyahTafsir(
    int surahNumber,
    int ayahNumber, {
    String editionId = 'id.jalalayn',
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/ayah/$surahNumber:$ayahNumber/$editionId'),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'];
        return data['text'];
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching tafsir: $e');
      return null;
    }
  }
}
