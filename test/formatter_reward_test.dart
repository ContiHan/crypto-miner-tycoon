import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/utils/formatter.dart';

void main() {
  group('formatBitcoin halving precision (bug #3)', () {
    const int sat = 100000000; // 1 BTC in sats

    test('exact halving rewards keep full precision', () {
      // Block reward sequence as it halves. The old 2-decimal formatter turned
      // 3.125 into "3.13" (wrong) from the 4th halving on.
      expect(Formatter.formatBitcoin(50.0 * sat), '50 ₿');
      expect(Formatter.formatBitcoin(25.0 * sat), '25 ₿');
      expect(Formatter.formatBitcoin(12.5 * sat), '12.5 ₿');
      expect(Formatter.formatBitcoin(6.25 * sat), '6.25 ₿');
      expect(Formatter.formatBitcoin(3.125 * sat), '3.125 ₿');
      expect(Formatter.formatBitcoin(1.5625 * sat), '1.5625 ₿');
    });

    test('compact values keep the old clean rendering (regression)', () {
      expect(Formatter.formatBitcoin(1.5 * sat), '1.5 ₿');
      expect(Formatter.formatBitcoin(2.0 * sat), '2 ₿');
    });

    test('sub-1-BTC rewards still fall back to the sats scale', () {
      // 0.78125 BTC after the 6th halving == 78,125,000 sats.
      expect(Formatter.formatBitcoin(0.78125 * sat), '78.1M Ş');
    });
  });
}
