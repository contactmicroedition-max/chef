import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zone/core/config/supabase_config.dart';
import 'package:zone/core/models/attendance.dart';

class EmployeeAttendanceResult {
  const EmployeeAttendanceResult({
    required this.notificationSent,
    this.notificationMessage,
  });

  final bool notificationSent;
  final String? notificationMessage;
}

class AttendanceRepository {
  AttendanceRepository(this._client);

  final SupabaseClient _client;

  Future<EmployeeAttendanceResult> recordEmployeeShift({
    required String organisationId,
    required bool clockIn,
  }) async {
    final response = await _client.functions.invoke(
      'employee-attendance',
      body: {
        'organisation_id': organisationId,
        'action': clockIn ? 'clock_in' : 'clock_out',
      },
    );
    final result = response.data;
    final message = result is Map ? result['notification_message'] : null;
    return EmployeeAttendanceResult(
      notificationSent: result is Map && result['notification_sent'] == true,
      notificationMessage: message is String ? message : null,
    );
  }

  Future<List<AttendanceRecord>> attendanceForOrganisation(
    String organisationId,
  ) async {
    final rows = await _client
        .from('attendance_records')
        .select()
        .eq('organisation_id', organisationId)
        .order('shift_date', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows)
        .map(_attendanceFromRow)
        .toList();
  }

  AttendanceRecord _attendanceFromRow(Map<String, dynamic> row) {
    return AttendanceRecord(
      id: row['id'] as String,
      employeeId: row['employee_id'] as String,
      organisationId: row['organisation_id'] as String,
      date: DateTime.parse(row['shift_date'] as String),
      clockIn: DateTime.parse(row['clock_in'] as String),
      clockOut: row['clock_out'] == null
          ? null
          : DateTime.parse(row['clock_out'] as String),
      note: row['note'] as String?,
      status: row['status'] as String? ?? 'approved',
    );
  }
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    throw StateError('Supabase is not configured.');
  }
  return AttendanceRepository(client);
});
