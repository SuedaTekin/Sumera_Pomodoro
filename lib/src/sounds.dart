import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Procedurally generated, seamlessly looping focus sounds in
/// `assets/sounds/` (see `tool/make_sounds.py`).
enum AmbientSound { none, rain, ocean, white, pink, brown }

extension AmbientSoundInfo on AmbientSound {
  String get labelKey => 'sound_$name';

  IconData get icon => switch (this) {
    AmbientSound.none => Icons.volume_off_rounded,
    AmbientSound.rain => Icons.water_drop_rounded,
    AmbientSound.ocean => Icons.waves_rounded,
    AmbientSound.white => Icons.blur_on_rounded,
    AmbientSound.pink => Icons.grain_rounded,
    AmbientSound.brown => Icons.landscape_rounded,
  };

  static AmbientSound parse(String name) =>
      AmbientSound.values.asNameMap()[name] ?? AmbientSound.none;
}

/// Loops one ambient sound at a time. Every call is best-effort: audio
/// problems never affect the timer.
class SoundPlayer {
  AudioPlayer? _player;
  AmbientSound _current = AmbientSound.none;
  Timer? _previewTimer;

  AmbientSound get current => _current;

  Future<void> play(AmbientSound sound, int volume) async {
    _previewTimer?.cancel();
    if (sound == AmbientSound.none) return stop();
    try {
      final player =
          _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.loop);
      final v = volume.clamp(0, 100) / 100;
      if (_current == sound) {
        await player.setVolume(v);
        return;
      }
      _current = sound;
      await player.stop();
      await player.play(AssetSource('sounds/${sound.name}.wav'), volume: v);
    } catch (error) {
      debugPrint('Sound unavailable: $error');
    }
  }

  /// Plays a few seconds so the user can hear the choice.
  Future<void> preview(
    AmbientSound sound,
    int volume, {
    bool keep = false,
  }) async {
    await play(sound, volume);
    if (keep || sound == AmbientSound.none) return;
    _previewTimer = Timer(const Duration(seconds: 5), stop);
  }

  Future<void> stop() async {
    _previewTimer?.cancel();
    if (_current == AmbientSound.none) return;
    _current = AmbientSound.none;
    try {
      await _player?.stop();
    } catch (error) {
      debugPrint('Sound stop failed: $error');
    }
  }

  Future<void> dispose() async {
    _previewTimer?.cancel();
    await _player?.dispose();
  }
}
