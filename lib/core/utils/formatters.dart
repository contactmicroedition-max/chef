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

/// Cleans a legacy employee ID used by older Supabase Auth accounts.
String cleanEmployeeId(String value) {
  final id = value.trim().toLowerCase().replaceAll(RegExp(r'[\s\-]'), '');
  if (id.isEmpty || id.length < 4) {
    throw const FormatException(
      'Enter an employee ID (at least 4 characters).',
    );
  }
  return id;
}

/// Builds the legacy email alias used for employee accounts.
String employeeLoginEmail(String employeeId) {
  return 'emp-$employeeId@chef.local';
}

String? loginIdFromAuthEmail(String? email) {
  if (email == null) return null;
  final match = RegExp(r'^(?:id-|emp-|employee-)(\d{8})@').firstMatch(email);
  return match?.group(1);
}

/// Returns a phone number in the E.164 format expected by Supabase Auth.
///
/// Local Tunisian 8-digit numbers are accepted because this application is
/// configured for Tunisia; international numbers must include their country
/// code.
String normalizeAuthPhone(String value) {
  var phone = value.trim().replaceAll(RegExp(r'[\s().-]'), '');
  if (phone.startsWith('00')) {
    phone = '+${phone.substring(2)}';
  } else if (!phone.startsWith('+') && RegExp(r'^\d{8}$').hasMatch(phone)) {
    phone = '+216$phone';
  }

  if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
    throw const FormatException(
      'Enter a valid phone number with country code, for example +21695125268.',
    );
  }
  return phone;
}

bool looksLikePhoneNumber(String value) {
  final trimmed = value.trim();
  return trimmed.startsWith('+') ||
      trimmed.startsWith('00') ||
      RegExp(r'^\d{8}$').hasMatch(trimmed.replaceAll(RegExp(r'[\s().-]'), ''));
}
