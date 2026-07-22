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
  final _random = Random();

  final void Function() onChanged;
  final void Function() onCollect;

  AnomalySystem({required this.onChanged, required this.onCollect});

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!active && _random.nextDouble() < 0.05) {
        position = Offset(_random.nextDouble() * 300, _random.nextDouble() * 500);
        active = true;
        onChanged();
        Future.delayed(const Duration(seconds: 4), () {
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
  }

  /// Collect the active anomaly (no-op if none active).
  void collect() {
    if (!active) return;
    active = false;
    onCollect();
    onChanged();
  }
}
