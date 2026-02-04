import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  String? _soundPath;
  bool _isInit = false;

  Future<void> init() async {
    if (_isInit) return;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tasbih_click.wav');

      // Write file if not exists
      if (!await file.exists()) {
        final wavData = _createWavBytes();
        await file.writeAsBytes(wavData);
      }
      _soundPath = file.path;

      // Configure player
      await _player.setReleaseMode(ReleaseMode.stop);
      // Preload source
      await _player.setSource(DeviceFileSource(_soundPath!));

      _isInit = true;
    } catch (e) {
      debugPrint('Error initializing AudioService: $e');
    }
  }

  Future<void> playClick() async {
    if (_soundPath != null) {
      try {
        await _player.stop();
        await _player.play(DeviceFileSource(_soundPath!), volume: 1.0);
      } catch (e) {
        debugPrint('Error playing click: $e');
      }
    }
  }

  Uint8List _createWavBytes() {
    final int sampleRate = 44100;
    final int durationMs = 30; // 30ms short click
    final int numSamples = (sampleRate * durationMs / 1000).round();
    final int fileSize = 36 + numSamples * 2;

    final buffer = ByteData(fileSize + 8);

    // RIFF chunk
    buffer.setUint32(0, 0x52494646, Endian.big); // "RIFF"
    buffer.setUint32(4, fileSize, Endian.little);
    buffer.setUint32(8, 0x57415645, Endian.big); // "WAVE"

    // fmt chunk
    buffer.setUint32(12, 0x666d7420, Endian.big); // "fmt "
    buffer.setUint32(16, 16, Endian.little); // chunk size
    buffer.setUint16(20, 1, Endian.little); // audio format (1=PCM)
    buffer.setUint16(22, 1, Endian.little); // num channels (1)
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    buffer.setUint16(32, 2, Endian.little); // block align
    buffer.setUint16(34, 16, Endian.little); // bits per sample

    // data chunk
    buffer.setUint32(36, 0x64617461, Endian.big); // "data"
    buffer.setUint32(40, numSamples * 2, Endian.little);

    // Generate click sound (decaying sine/square mix)
    for (int i = 0; i < numSamples; i++) {
      // High pitch 800-1200Hz sweep for "tick" sound
      // double t = i / sampleRate;
      double freq = 800.0;

      // Simple sine wave
      // double val = (i % (sampleRate ~/ freq)) < (sampleRate ~/ (freq * 2)) ? 0.5 : -0.5;

      // Let's use noise burst for better "wood" sound? No, simple decay sine is safer.
      double val = (i % (sampleRate ~/ freq)) < (sampleRate ~/ (freq * 2))
          ? 0.3
          : -0.3;

      // Decay envelope
      val *= (1.0 - (i / numSamples));

      int sample = (val * 32767).toInt();
      buffer.setInt16(44 + i * 2, sample, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }
}
