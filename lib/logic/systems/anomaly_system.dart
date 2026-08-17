import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';

/// Spawns clickable "anomalies" on a timer; collecting one grants a chip.
///
/// Extracted from the GameLogic god-object. GameLogic owns an instance and
/// supplies the callbacks: [onChanged] (notifyListeners) and [onCollect] (grant
/// the chip / play sound / save). This keeps all anomaly state and timing in one
/// small, testable place.
class AnomalySystem {
  bool active = false;
  Offset position = Offset.zero;
  Timer? _timer;
  Timer? _despawnTimer;
  final _random = Random();

  // Spawnable area (Stack-local), set from the real view size so the anomaly
  // never spawns off-screen (landscape/small screens) or clusters in a corner.
  // Conservative defaults cover the first spawn before the first layout.
  double _maxX = 280;
  double _maxY = 420;

  final void Function() onChanged;
  final void Function() onCollect;

  /// Luck factor (>=1) read at each spawn tick; higher Luck => anomalies (chips)
  /// appear more often, up to a hard cap so they never become guaranteed.
  final double Function()? luckFactor;

  static const double _baseSpawnChance = 0.05; // per 5s tick
  static const double _spawnChanceCap = 0.30;

  // Forced spawns queued by an ability (Solo LUCKY NONCE). The system renders one
  // anomaly at a time, so a burst is delivered sequentially: spawn one now, and
  // chain the next when the current is collected or despawns.
  int _forcedQueue = 0;

  AnomalySystem({
    required this.onChanged,
    required this.onCollect,
    this.luckFactor,
  });

  /// Current per-tick spawn chance, scaled by Luck and capped.
  @visibleForTesting
  double get spawnChance =>
      (_baseSpawnChance * (luckFactor?.call() ?? 1.0))
          .clamp(0.0, _spawnChanceCap);

  /// Update the spawnable area from the actual view size. The full 50x50 widget
  /// is inset so it always stays fully on-screen (and clear of the bottom
  /// sticky button).
  void setViewport(double width, double height) {
    final w = width - 50;
    final h = height - 60;
    _maxX = w > 0 ? w : 0;
    _maxY = h > 0 ? h : 0;
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!active && _random.nextDouble() < spawnChance) _spawnNow();
    });
  }

  /// Places an anomaly and arms its 4s despawn. Shared by the random timer and
  /// forced (ability) spawns. On despawn it chains the next forced spawn.
  void _spawnNow() {
    position = Offset(_random.nextDouble() * _maxX, _random.nextDouble() * _maxY);
    active = true;
    onChanged();
    // Cancellable so it can't fire onChanged() after stop()/dispose.
    _despawnTimer?.cancel();
    _despawnTimer = Timer(const Duration(seconds: 4), () {
      if (active) {
        active = false;
        onChanged();
        _drainForced(); // an uncollected forced anomaly still yields to the next
      }
    });
  }

  /// Queue [count] guaranteed anomalies (Solo LUCKY NONCE). Delivered one at a
  /// time on the single render slot; the next spawns as each is collected/expires.
  void forceSpawn(int count) {
    if (count <= 0) return;
    _forcedQueue += count;
    _drainForced();
  }

  void _drainForced() {
    if (active || _forcedQueue <= 0) return;
    _forcedQueue--;
    _spawnNow();
  }

  /// Pending forced spawns not yet shown (for tests/telemetry).
  @visibleForTesting
  int get forcedQueueLength => _forcedQueue;

  void stop() {
    _timer?.cancel();
    _timer = null;
    _despawnTimer?.cancel();
    _despawnTimer = null;
    active = false; // never leave a stranded anomaly across pause/dispose
    _forcedQueue = 0; // don't resurrect a forced burst after pause/dispose
  }

  /// Collect the active anomaly (no-op if none active).
  void collect() {
    if (!active) return;
    active = false;
    _despawnTimer?.cancel();
    onCollect();
    onChanged();
    _drainForced(); // deliver the next of a forced burst immediately
  }
}
