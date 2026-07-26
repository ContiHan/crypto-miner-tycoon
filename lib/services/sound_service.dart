import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays short sound effects for game events.
///
/// Each effect gets its OWN AudioPlayer. A single shared player was unreliable
/// on Android: replaying a new AssetSource on a player that had already played
/// another source did not always switch, so only one effect was ever audible.
/// Dedicated players also let effects overlap.
///
/// Assets live under `assets/sounds/<name>.wav`. Each distinct game action gets
/// its own most-fitting cue (no sharing): UI vs mining tap vs crit, rig-buy vs
/// crate vs SWEEP-win, research vs skill vs tab-unlock vs achievement, and the
/// forks/ending vs the halving.
class SoundService {
  static const List<String> _effects = [
    'click', // generic UI (nav, toggles)
    'mine', // mining tap
    'crit', // critical tap
    'buy', // rig purchase
    'coin', // SWEEP win / anomaly pickup / achievement claim
    'crate', // opening a supply crate
    'research', // TECH node completed
    'skill', // SKILL node bought
    'unlock', // a tab / feature unlocking
    'achievement', // an achievement unlocking
    'event_good', // market buff
    'event_bad', // market debuff
    'halving', // block-reward halving
    'prestige', // Soft/Hard Fork + New Blockchain reset
    'ending', // the true ending (21M-ever)
  ];

  final Map<String, AudioPlayer> _players = {};
  bool _muted = false;

  SoundService() {
    for (final name in _effects) {
      final player = AudioPlayer();
      player.setReleaseMode(ReleaseMode.stop);
      player.setVolume(1.0);
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

  Future<void> playSound(String soundName) => _play(soundName);

  /// Mining tap — a soft dedicated "chip" (distinct from the UI click). A bundled
  /// asset instead of SystemSound (silent with the OS "touch sounds" setting off)
  /// and instead of PlayerMode.lowLatency (which did not play on the emulator).
  Future<void> playMine() => _play('mine');

  Future<void> playClick() => _play('click'); // generic UI (nav, toggles)
  Future<void> playCrit() => _play('crit'); // critical tap
  Future<void> playBuy() => _play('buy'); // rig purchase
  Future<void> playCoin() => _play('coin'); // SWEEP win / anomaly / claim reward
  Future<void> playCrate() => _play('crate'); // open a supply crate
  Future<void> playResearch() => _play('research'); // TECH node done
  Future<void> playSkill() => _play('skill'); // SKILL node bought
  Future<void> playUnlock() => _play('unlock'); // tab / feature unlock
  Future<void> playAchievement() => _play('achievement'); // achievement unlock
  Future<void> playEventGood() => _play('event_good');
  Future<void> playEventBad() => _play('event_bad');
  Future<void> playHalving() => _play('halving');
  Future<void> playPrestige() => _play('prestige'); // fork / new-chain reset
  Future<void> playEnding() => _play('ending'); // the true ending
}
