import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/logic/systems/chaos_event_system.dart';
import 'package:crypto_miner_tycoon/models/news_event.dart';

void main() {
  test('stop() clears the banner and resets multipliers (no stale news)', () {
    final sys = ChaosEventSystem(
      onChanged: () {},
      onHackLoss: () => 0,
      onEventSound: (_) {},
    );

    sys.showNews(NewsEvent(
      message: 'BULL RUN',
      type: EventType.bullRun,
      value: 100,
      durationSeconds: 999, // long; stop() must cancel this timer
      color: Colors.green,
    ));
    sys.incomeMultiplier = 2.0;
    expect(sys.currentNews, isNotNull);

    sys.stop();

    // Banner must not outlive the (already reset) multiplier.
    expect(sys.currentNews, isNull);
    expect(sys.incomeMultiplier, 1.0);
    expect(sys.costMultiplier, 1.0);
  });
}
