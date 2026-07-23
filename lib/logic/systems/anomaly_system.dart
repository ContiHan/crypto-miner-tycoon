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

  AnomalySystem({required this.onChanged, required this.onCollect});

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
      if (!active && _random.nextDouble() < 0.05) {
        position = Offset(_random.nextDouble() * _maxX, _random.nextDouble() * _maxY);
        active = true;
        onChanged();
        // Cancellable so it can't fire onChanged() after stop()/dispose.
        _despawnTimer?.cancel();
        _despawnTimer = Timer(const Duration(seconds: 4), () {
          if (active) {
            active = false;
            onChanged();
          }
        });
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _despawnTimer?.cancel();
    _despawnTimer = null;
    active = false; // never leave a stranded anomaly across pause/dispose
  }

  /// Collect the active anomaly (no-op if none active).
  void collect() {
    if (!active) return;
    active = false;
    _despawnTimer?.cancel();
    onCollect();
    onChanged();
  }
}
