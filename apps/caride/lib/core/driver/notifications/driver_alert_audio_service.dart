import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

/// Service responsible for managing high-priority looping audio and vibration alerts
/// for incoming driver ride requests.
class DriverAlertAudioService {
  DriverAlertAudioService._();
  static final DriverAlertAudioService instance = DriverAlertAudioService._();

  AudioPlayer? _player;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  /// Starts looping the alert sound (`notification.wav`) and vibration pattern.
  Future<void> startAlert() async {
    if (_isPlaying) return;
    _isPlaying = true;

    try {
      _player ??= AudioPlayer();
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notificationRingtone,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.duckOthers,
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );

      await _player!.play(AssetSource('audio/notification.wav'));
    } catch (e) {
      debugPrint('[DriverAlertAudioService] Error starting audio player: $e');
    }

    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // Repeat pattern starting from index 0 until cancel() is called
        await Vibration.vibrate(
          pattern: [0, 500, 500, 1000],
          repeat: 0,
        );
      }
    } catch (e) {
      debugPrint('[DriverAlertAudioService] Error starting vibration: $e');
    }
  }

  /// Stops the alert sound and vibration immediately.
  Future<void> stopAlert() async {
    if (!_isPlaying && _player == null) return;
    _isPlaying = false;

    try {
      if (_player != null) {
        await _player!.stop();
      }
    } catch (e) {
      debugPrint('[DriverAlertAudioService] Error stopping audio player: $e');
    }

    try {
      await Vibration.cancel();
    } catch (e) {
      debugPrint('[DriverAlertAudioService] Error cancelling vibration: $e');
    }
  }

  /// Clean up player resources.
  Future<void> dispose() async {
    await stopAlert();
    await _player?.dispose();
    _player = null;
  }
}
