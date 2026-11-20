import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

/// Service responsible for managing high-priority looping audio and vibration alerts
/// for incoming driver ride requests.
class DriverAlertAudioService {
  DriverAlertAudioService._();

  @visibleForTesting
  DriverAlertAudioService();

  static final DriverAlertAudioService instance = DriverAlertAudioService._();

  AudioPlayer? _player;
  Timer? _testStopTimer;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  /// Starts looping the ringtone alert (`assets/audio/ride_ringtone.wav`) and vibration pattern.
  Future<void> startAlert() async {
    _testStopTimer?.cancel();
    _testStopTimer = null;
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

      await _player!.play(AssetSource('audio/ride_ringtone.wav'));
    } catch (e) {
      debugPrint('[DriverAlertAudioService] Error starting audio player: $e');
    }

    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(
          pattern: [0, 500, 500, 1000],
          repeat: 0,
        );
      }
    } catch (e) {
      debugPrint('[DriverAlertAudioService] Error starting vibration: $e');
    }
  }

  /// Plays a brief preview of the incoming ride ringtone for readiness verification.
  Future<void> playTestRingtone({
    Duration duration = const Duration(seconds: 4),
  }) async {
    await stopAlert();
    await startAlert();
    _testStopTimer = Timer(duration, () {
      unawaited(stopAlert());
    });
  }

  /// Stops the alert sound and vibration immediately.
  Future<void> stopAlert() async {
    _testStopTimer?.cancel();
    _testStopTimer = null;
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
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}
