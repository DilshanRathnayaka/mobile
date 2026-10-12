import 'package:intl/intl.dart';
import '../../providers/currency_provider.dart';

class Formatters {
  static final _cryptoAmountFormat = NumberFormat('#,##0.0000');
  static final _dateFormat = DateFormat('MMM dd, yyyy');
  static final _timeFormat = DateFormat('HH:mm');

  static String currency(num amountInUsd, [CurrencyInfo? currency]) {
    final curr = currency ?? SupportedCurrencies.usdt;
    final converted = amountInUsd * curr.rateToUsd;

    if (curr.code == 'USDT' || curr.code == 'USD') {
      if (converted.abs() >= 1000000) {
        return '${NumberFormat.compact().format(converted)} USDT';
      }
      return '${NumberFormat('#,##0.00').format(converted)} USDT';
    }

    final formatter = NumberFormat.currency(
      symbol: curr.symbol,
      decimalDigits: curr.code == 'LKR' ? 0 : 2, // LKR doesn't need cents
    );

    if (converted.abs() >= 1000000) {
      return NumberFormat.compactCurrency(symbol: curr.symbol).format(converted);
    }
    return formatter.format(converted);
  }

  static String cryptoAmount(num amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toInt().toString();
    }
    final d = amount.toDouble();
    if (d.abs() < 0.0001 && d.abs() > 0) {
      return NumberFormat('#,##0.00000000').format(d);
    }
    return _cryptoAmountFormat.format(d);
  }

  static String cryptoPrice(num priceInUsd, [CurrencyInfo? currency]) {
    final curr = currency ?? SupportedCurrencies.usdt;
    final converted = priceInUsd * curr.rateToUsd;
    if (converted.abs() < 0.01 && converted.abs() > 0) {
      return '${converted.toStringAsFixed(8)} ${curr.code}';
    }
    return Formatters.currency(priceInUsd, currency);
  }

  static String percentage(num percent) {
    final prefix = percent >= 0 ? '+' : '';
    return '$prefix${percent.toStringAsFixed(2)}%';
  }

  static final _fullLkrFormat = NumberFormat('#,##0.00');
  static final _fullLkrNoDecimals = NumberFormat('#,##0');

  /// Full exact LKR representation (e.g. "Rs. 83,600.00" or "Rs. 83,600") - never compacted
  static String fullLkr(num amount, {bool showCents = true}) {
    if (showCents) {
      return 'Rs. ${_fullLkrFormat.format(amount)}';
    }
    return 'Rs. ${_fullLkrNoDecimals.format(amount)}';
  }

  static String compactNumber(num number) {
    return NumberFormat.compact().format(number);
  }

  static String date(DateTime dt) {
    return _dateFormat.format(dt);
  }

  static String dateTime(DateTime dt) {
    return '${_dateFormat.format(dt)} ${_timeFormat.format(dt)}';
  }
}
