import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/logic/systems/chaos_event_system.dart';
import 'package:crypto_miner_tycoon/models/news_event.dart';
import 'package:crypto_miner_tycoon/content/news_flavor.dart';

void main() {
  test('every rolled event type has flavour lines (byType is complete)', () {
    // triggerRandom does byType[type]! — a random effect type with no pool would
    // crash. info is the only type excluded from the random roll.
    for (final t in EventType.values) {
      if (t == EventType.info) continue;
      expect(NewsFlavor.byType[t], isNotNull, reason: '$t has no flavour lines');
      expect(NewsFlavor.byType[t]!, isNotEmpty, reason: '$t flavour pool is empty');
    }
  });

  test('stop() clears the banner and resets multipliers (no stale news)', () {
    final sys = ChaosEventSystem(
      onChanged: () {},
      onBreach: () {},
      onAirdropGain: () => 0,
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

  group('multipliers are per-axis independent', () {
    ChaosEventSystem makeSystem() => ChaosEventSystem(
          onChanged: () {},
          onBreach: () {},
          onAirdropGain: () => 0,
          onEventSound: (_) {},
        );

    test('an income event does not reset an active cost buff', () {
      final sys = makeSystem();
      sys.applyChaosForTest(1.0, 0.7, 120); // Cheap Energy (cost only)
      expect(sys.costMultiplier, 0.7);
      expect(sys.incomeMultiplier, 1.0);

      sys.applyChaosForTest(2.0, 1.0, 100); // Bull Run (income only)
      expect(sys.incomeMultiplier, 2.0);
      expect(sys.costMultiplier, 0.7,
          reason: 'an unrelated income event must not wipe the cost discount');
      sys.stop();
    });

    test('a no-op event (1.0/1.0) leaves active buffs intact', () {
      final sys = makeSystem();
      sys.applyChaosForTest(2.0, 1.0, 120); // Bull Run active
      sys.applyChaosForTest(1.0, 1.0, 60); // info/hack: must not clear it
      expect(sys.incomeMultiplier, 2.0,
          reason: 'a flavour/wallet-only event must not strand the buff');
      sys.stop();
    });

    test('the newer event wins on the same axis', () {
      final sys = makeSystem();
      sys.applyChaosForTest(0.5, 1.0, 90); // Market Crash
      sys.applyChaosForTest(2.0, 1.0, 90); // Bull Run replaces it
      expect(sys.incomeMultiplier, 2.0);
      sys.stop();
    });
  });
}
