

class Formatter {
  static String formatNumber(double number) {
    if (number < 1000) {
      return number.toInt().toString();
    } else if (number < 1000000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    } else if (number < 1000000000) {
      return '${(number / 1000000).toStringAsFixed(2)}M';
    } else if (number < 1000000000000) {
      return '${(number / 1000000000).toStringAsFixed(2)}B';
    } else {
      return '${(number / 1000000000000).toStringAsFixed(2)}T';
    }
  }

  static String formatCurrency(double amount) {
    return formatNumber(amount);
  }
}
