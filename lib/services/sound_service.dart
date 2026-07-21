import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays short sound effects for game events.
///
/// Every effect maps to its own bundled asset under `assets/sounds/`. Drop the
/// following files in to enable audio (any short WAV/OGG works):
///   click.wav, buy.wav, unlock.wav, event_good.wav, event_bad.wav, halving.wav
/// A missing file is logged and skipped, never fatal.
class SoundService {
  // Separate player for the mine click so rapid taps use a low-latency path
  // and don't cut off longer effect sounds.
  final AudioPlayer _clickPlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();
  bool _muted = false;

  SoundService() {
    _clickPlayer.setPlayerMode(PlayerMode.lowLatency);
  }

  bool get isMuted => _muted;

  void setMuted(bool muted) {
    _muted = muted;
    if (_muted) {
      _clickPlayer.stop();
      _effectPlayer.stop();
    }
  }

  Future<void> _play(AudioPlayer player, String file) async {
    if (_muted) return;
    try {
      await player.play(AssetSource('sounds/$file'));
    } catch (e) {
      // Missing/invalid asset must not crash the game or spam the user.
      debugPrint('SoundService: could not play sounds/$file: $e');
    }
  }

  /// Mining tap. Uses a bundled low-latency asset instead of SystemSound, which
  /// was silent whenever the OS "touch sounds" setting was off (the default on
  /// many devices) and ignored the in-game mute.
  Future<void> playMine() => _play(_clickPlayer, 'click.wav');

  Future<void> playSound(String soundName) =>
      _play(_effectPlayer, '$soundName.wav');

  Future<void> playBuy() => playSound('buy');
  Future<void> playUnlock() => playSound('unlock');
  Future<void> playEventGood() => playSound('event_good');
  Future<void> playEventBad() => playSound('event_bad');
  Future<void> playHalving() => playSound('halving');
}
