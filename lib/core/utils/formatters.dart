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

/// Takes whatever the user typed, strips spaces/dashes, and returns it as-is.
/// This is a SIMPLE ID — not a phone number. No country code logic.
String cleanEmployeeId(String value) {
  final id = value.trim().replaceAll(RegExp(r'[\s\-]'), '');
  if (id.isEmpty || id.length < 4) {
    throw const FormatException('Enter an employee ID (at least 4 characters).');
  }
  return id;
}

/// Builds the internal email alias used for Supabase Auth login.
String employeeLoginEmail(String employeeId) {
  return 'emp-$employeeId@chef.local';
}
