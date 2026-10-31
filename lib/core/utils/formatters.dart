import 'package:intl/intl.dart';

String formatCurrency(double value, {String currency = 'TND'}) {
  final formatter = NumberFormat.currency(
    locale: 'fr_TN',
    symbol: currency,
    decimalDigits: 2,
  );
  return formatter.format(value);
}

String formatDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  return '$hours:$minutes';
}

String formatDate(DateTime value) {
  return DateFormat('dd MMM yyyy', 'fr').format(value);
}

String formatDateTime(DateTime value) {
  return DateFormat('dd MMM yyyy, HH:mm', 'fr').format(value.toLocal());
}
