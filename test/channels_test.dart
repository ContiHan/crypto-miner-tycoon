import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/logic/channels.dart';

void main() {
  group('Channels (additive within, multiplicative across)', () {
    test('bonuses in a channel sum additively', () {
      final c = Channels();
      c.add(Channel.hash, 0.05);
      c.add(Channel.hash, 0.10);
      c.add(Channel.hash, 0.02);
      expect(c.sum(Channel.hash), closeTo(0.17, 1e-9));
      expect(c.multiplier(Channel.hash), closeTo(1.17, 1e-9));
    });

    test('channels are independent', () {
      final c = Channels();
      c.add(Channel.hash, 0.5);
      c.add(Channel.click, 0.2);
      expect(c.multiplier(Channel.hash), closeTo(1.5, 1e-9));
      expect(c.multiplier(Channel.click), closeTo(1.2, 1e-9));
      expect(c.multiplier(Channel.income), 1.0); // untouched channel
    });

    test('100 small additive bonuses stay tame (no runaway)', () {
      final c = Channels();
      for (var i = 0; i < 100; i++) {
        c.add(Channel.hash, 0.08);
      }
      // Additive: 1 + 100*0.08 = 9x. (Multiplicative would be 1.08^100 ≈ 2199x.)
      expect(c.multiplier(Channel.hash), closeTo(9.0, 1e-6));
    });

    test('adding zero is a no-op', () {
      final c = Channels();
      c.add(Channel.hash, 0);
      expect(c.multiplier(Channel.hash), 1.0);
    });
  });

  group('softcap', () {
    test('identity below the start', () {
      expect(softcap(5, 10, 0.5), 5);
      expect(softcap(10, 10, 0.5), 10);
    });

    test('decelerates above the start', () {
      // 10 * (100/10)^0.5 = 10 * sqrt(10) ≈ 31.62
      expect(softcap(100, 10, 0.5), closeTo(31.6227, 1e-3));
    });

    test('multiplier can be soft-capped', () {
      final c = Channels();
      c.add(Channel.hash, 19.0); // raw multiplier 20
      final capped = c.multiplier(Channel.hash, softStart: 10, power: 0.5);
      // softcap(20, 10, 0.5) = 10 * sqrt(2) ≈ 14.14
      expect(capped, closeTo(14.142, 1e-2));
    });

    test('non-finite input is returned unchanged (no crash)', () {
      expect(softcap(double.infinity, 10, 0.5), double.infinity);
    });

    test('a channel debuffed below -100% floors at a small positive, never <=0',
        () {
      final c = Channels();
      c.add(Channel.income, -1.5); // raw 1 + (-1.5) = -0.5
      final m = c.multiplier(Channel.income);
      expect(m, greaterThan(0), reason: 'income multiplier must never go <= 0');
      expect(m, closeTo(0.01, 1e-9), reason: 'floored at the epsilon');
    });

    test('a mild debuff (still > -100%) is untouched by the floor', () {
      final c = Channels();
      c.add(Channel.volatility, -0.25); // Pool: fewer events -> 0.75x
      expect(c.multiplier(Channel.volatility), closeTo(0.75, 1e-9));
    });
  });
}
