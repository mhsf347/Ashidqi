import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AudioDownloadService {
  // Singleton
  static final AudioDownloadService _instance = AudioDownloadService._internal();
  factory AudioDownloadService() => _instance;
  AudioDownloadService._internal();

  /// Gets the local path where audio files are stored
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${directory.path}/ashidqi_audio');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir.path;
  }

  /// Generates the local file name for a specific ayah audio
  String _getFileName(int ayahNumber, String qariIdentifier) {
    return '${qariIdentifier}_$ayahNumber.mp3';
  }

  /// Checks if the audio file for a specific ayah is already downloaded
  Future<bool> isAudioDownloaded(int ayahNumber, String qariIdentifier) async {
    final path = await _localPath;
    final fileName = _getFileName(ayahNumber, qariIdentifier);
    final file = File('$path/$fileName');
    return await file.exists();
  }

  /// Gets the local file path if downloaded, else returns null
  Future<String?> getLocalAudioPath(int ayahNumber, String qariIdentifier) async {
    final path = await _localPath;
    final fileName = _getFileName(ayahNumber, qariIdentifier);
    final file = File('$path/$fileName');
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  /// Downloads the audio file for a specific ayah
  Future<bool> downloadAudio(int ayahNumber, String audioUrl, String qariIdentifier) async {
    try {
      final response = await http.get(Uri.parse(audioUrl));
      if (response.statusCode == 200) {
        final path = await _localPath;
        final fileName = _getFileName(ayahNumber, qariIdentifier);
        final file = File('$path/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Downloads all ayahs for a given surah
  /// Provide a progress callback to update UI
  Future<void> downloadSurahAudio({
    required List<dynamic> ayahs, // List<Ayah> from QuranReaderScreen
    required String qariIdentifier,
    required Function(double progress) onProgress,
  }) async {
    int total = ayahs.length;
    int downloaded = 0;

    for (var ayah in ayahs) {
      final isDownloaded = await isAudioDownloaded(ayah.number, qariIdentifier);
      if (!isDownloaded && ayah.audio != null) {
        await downloadAudio(ayah.number, ayah.audio!, qariIdentifier);
      }
      downloaded++;
      onProgress(downloaded / total);
    }
  }

  /// Deletes a specific audio file
  Future<void> deleteAudio(int ayahNumber, String qariIdentifier) async {
    final path = await _localPath;
    final fileName = _getFileName(ayahNumber, qariIdentifier);
    final file = File('$path/$fileName');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
