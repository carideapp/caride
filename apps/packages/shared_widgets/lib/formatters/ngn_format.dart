import 'package:intl/intl.dart';

abstract final class NgnFormat {
  static String whole(double amount) {
    return NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 0,
    ).format(amount);
  }

  static String currency(double amount, [int decimalDigits = 0]) {
    return NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: decimalDigits,
    ).format(amount);
  }
}
