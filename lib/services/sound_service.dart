import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class SoundService {
  final AudioPlayer _player = AudioPlayer();
  bool _muted = false;

  bool get isMuted => _muted;

  void setMuted(bool muted) {
    _muted = muted;
    if (_muted) {
      _player.stop();
    }
  }

  Future<void> playSound(String soundName) async {
    if (_muted) return;
    try {
      // Using test_sound.wav for all sounds for now to verify audio works
      // In production, matching files should be used: '$soundName.wav'
      await _player.play(AssetSource('sounds/test_sound.wav'));
    } catch (e) {
      // Suppress massive error logs for missing assets in dev
      // print('Error playing sound: $e');
    }
  }

  // Define sound types
  // Use SystemSound for mining click for immediate feedback and low latency
  Future<void> playMine() async {
    if (_muted) return;
    await SystemSound.play(SystemSoundType.click);
  }

  Future<void> playBuy() async => playSound('buy');
  Future<void> playUnlock() async => playSound('unlock');
  Future<void> playEventGood() async => playSound('event_good');
  Future<void> playEventBad() async => playSound('event_bad');
  Future<void> playHalving() async => playSound('halving');
}
