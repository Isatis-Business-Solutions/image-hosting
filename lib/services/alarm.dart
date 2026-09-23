import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

/// Geluid + trillen wanneer de timer afloopt.
class Alarm {
  static final _player = AudioPlayer();
  static final Uint8List _wav = _buildBeeps();

  static Future<void> ring() async {
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 600, 250, 600, 250, 1200]);
      }
    } catch (e) {
      debugPrint('Trillen mislukt: $e');
    }
    try {
      await _player.stop();
      await _player.play(BytesSource(_wav, mimeType: 'audio/wav'),
          volume: 1.0);
    } catch (e) {
      debugPrint('Geluid mislukt: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _player.stop();
      await Vibration.cancel();
    } catch (_) {}
  }

  /// Genereert een WAV met drie oplopende piepreeksen, zodat er geen
  /// geluidsbestand nodig is.
  static Uint8List _buildBeeps() {
    const rate = 22050;
    final samples = <double>[];
    void tone(double freq, double sec) {
      final n = (rate * sec).round();
      for (var i = 0; i < n; i++) {
        final t = i / rate;
        final env = min(1.0, min(i / 300, (n - i) / 300));
        samples.add(env * 0.8 * sin(2 * pi * freq * t));
      }
    }

    void silence(double sec) =>
        samples.addAll(List.filled((rate * sec).round(), 0.0));

    for (var r = 0; r < 3; r++) {
      tone(880, 0.18);
      silence(0.08);
      tone(1175, 0.18);
      silence(0.08);
      tone(1568, 0.35);
      silence(0.35);
    }

    final data = ByteData(44 + samples.length * 2);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    data.setUint32(4, 36 + samples.length * 2, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, rate, Endian.little);
    data.setUint32(28, rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    str(36, 'data');
    data.setUint32(40, samples.length * 2, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      data.setInt16(44 + i * 2, (samples[i] * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }
}
