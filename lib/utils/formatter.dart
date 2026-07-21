import 'dart:math';

class Formatter {
  static const List<String> _suffixes = [
    '',
    'k',
    'M',
    'B',
    'T',
    'Qa',
    'Qi',
    'Sx',
    'Sp',
    'Oc',
    'No',
    'Dc',
  ];

  static String formatNumber(double number) {
    if (number < 1000) {
      if (number >= 10) {
        return number.toInt().toString();
      }
      // Small numbers precise? Or just int? User said "3 digits".
      // Let's keep small ints as ints (1, 999). 123.4 might be overkill for regular numbers < 1000 unless float.
      // But user said "format 123.4k" (for scaled).
      return number.toInt().toString();
    }

    final int index = (log(number) / log(1000)).floor();

    if (index >= _suffixes.length) {
      return number.toStringAsExponential(2);
    }

    final double base = number / pow(1000.0, index);
    final String suffix = _suffixes[index];

    // Always 1 decimal place for suffixes to match "123.4k" style
    // Use toInt() to ensure truncation (14.99 -> 14 -> 1.4)
    return '${((base * 10).toInt() / 10).toStringAsFixed(1)}$suffix';
  }

  static String formatBitcoin(double sats) {
    if (sats == 0) return '0 Ş';
    // 1 BTC = 100,000,000 Sats
    if (sats >= 100000000) {
      // >= 1 BTC. Display as BTC.
      double btc = sats / 100000000;
      if (btc < 1000) {
        // Show enough precision to represent halved block rewards faithfully.
        // Rewards halve as 50, 25, 12.5, 6.25, 3.125, 1.5625, ... so 2 decimals
        // (the old behaviour) rounded 3.125 -> "3.13" and corrupted every reward
        // from the 4th halving on. Format at high precision, then trim trailing
        // zeros (and a dangling '.') so whole/short values stay clean.
        String btcStr = btc.toStringAsFixed(4);
        if (btcStr.contains('.')) {
          btcStr = btcStr.replaceAll(RegExp(r'0+$'), '');
          btcStr = btcStr.replaceAll(RegExp(r'\.$'), '');
        }
        return '$btcStr ₿';
      }
      return '${formatNumber(btc)} ₿';
    }

    // < 1 BTC. Use Sats with suffixes.
    if (sats >= 1) {
      return '${formatNumber(sats)} Ş';
    }

    // Sub-Satoshi
    if (sats >= 0.001) {
      // >= 1 mSat
      return '${(sats * 1000).toStringAsFixed(1)} mŞ';
    }
    if (sats >= 0.000001) {
      // >= 1 uSat
      return '${(sats * 1000000).toStringAsFixed(1)} μŞ';
    }
    if (sats >= 0.000000001) {
      // >= 1 nSat
      return '${(sats * 1000000000).toStringAsFixed(1)} nŞ';
    }
    if (sats >= 0.000000000001) {
      // >= 1 pSat
      return '${(sats * 1000000000000).toStringAsFixed(1)} pŞ';
    }
    if (sats >= 0.000000000000001) {
      // >= 1 fSat
      return '${(sats * 1000000000000000).toStringAsFixed(1)} fŞ';
    }
    // Atto-Sat (1e-18)
    if (sats >= 1e-18) {
      return '${(sats * 1e18).toStringAsFixed(1)} aŞ';
    }

    // Extremely small numbers (Deep Deflation)
    // Uses 'Ş' symbol
    if (sats > 0) {
      return '${sats.toStringAsExponential(2)} Ş';
    }

    return '0 Ş';
  }

  static String formatCurrency(double amount) {
    return formatNumber(amount);
  }
}
