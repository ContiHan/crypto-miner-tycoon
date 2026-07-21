import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays short sound effects for game events.
///
/// Each effect gets its OWN AudioPlayer. A single shared player was unreliable
/// on Android: replaying a new AssetSource on a player that had already played
/// another source did not always switch, so only one effect was ever audible.
/// Dedicated players also let effects overlap.
///
/// Assets live under `assets/sounds/<name>.wav`:
///   click, buy, unlock, event_good, event_bad, halving
class SoundService {
  static const List<String> _effects = [
    'click',
    'buy',
    'unlock',
    'event_good',
    'event_bad',
    'halving',
  ];

  final Map<String, AudioPlayer> _players = {};
  bool _muted = false;

  SoundService() {
    for (final name in _effects) {
      final player = AudioPlayer();
      player.setReleaseMode(ReleaseMode.stop);
      // The mine click fires rapidly; give it the low-latency path.
      if (name == 'click') {
        player.setPlayerMode(PlayerMode.lowLatency);
      }
      _players[name] = player;
    }
  }

  bool get isMuted => _muted;

  void setMuted(bool muted) {
    _muted = muted;
    if (_muted) {
      for (final p in _players.values) {
        p.stop();
      }
    }
  }

  Future<void> _play(String name) async {
    if (_muted) return;
    final player = _players[name];
    if (player == null) return;
    try {
      await player.play(AssetSource('sounds/$name.wav'));
    } catch (e) {
      // Missing/invalid asset must not crash the game or spam the user.
      debugPrint('SoundService: could not play sounds/$name.wav: $e');
    }
  }

  /// Mining tap. Bundled low-latency asset instead of SystemSound, which was
  /// silent when the OS "touch sounds" setting was off and ignored the mute.
  Future<void> playMine() => _play('click');

  Future<void> playSound(String soundName) => _play(soundName);

  Future<void> playBuy() => _play('buy');
  Future<void> playUnlock() => _play('unlock');
  Future<void> playEventGood() => _play('event_good');
  Future<void> playEventBad() => _play('event_bad');
  Future<void> playHalving() => _play('halving');
}
