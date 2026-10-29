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

/// Validates the 8-digit account ID used to sign in.
String cleanAccountId(String value) {
  final id = value.trim();
  if (!RegExp(r'^\d{8}$').hasMatch(id)) {
    throw const FormatException('Enter an 8-digit ID.');
  }
  return id;
}

/// Builds the private alias used by Supabase Auth. Users sign in with their ID.
String accountLoginEmail(String loginId) {
  return 'id-$loginId@chef.local';
}

String? loginIdFromAuthEmail(String? email) {
  if (email == null) return null;
  final match = RegExp(r'^(?:id-|emp-|employee-)(\d{8})@').firstMatch(email);
  return match?.group(1);
}
