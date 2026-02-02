import 'package:flutter_test/flutter_test.dart';
import 'package:crypto_miner_tycoon/utils/formatter.dart';

void main() {
  test('Format Number Rounding Check', () {
    expect(Formatter.formatNumber(1400), '1.4k');
    expect(Formatter.formatNumber(1450), '1.4k'); // User says this shows 1.5k?
    expect(Formatter.formatNumber(1499), '1.4k');
    expect(Formatter.formatNumber(1500), '1.5k');

    expect(Formatter.formatNumber(1400000), '1.4M');
    expect(Formatter.formatNumber(1450000), '1.4M');
    expect(Formatter.formatNumber(1490000), '1.4M');
  });
}
