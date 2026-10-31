import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zone/core/config/supabase_config.dart';
import 'package:zone/features/attendance/domain/attendance.dart';
import 'package:zone/features/organisations/domain/organisation_zone.dart';

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
    double? latitude,
    double? longitude,
  }) async {
    if (clockIn && (latitude == null || longitude == null)) {
      throw StateError('Current location is required to clock in.');
    }
    late final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'employee-attendance',
        body: {
          'organisation_id': organisationId,
          'action': clockIn ? 'clock_in' : 'clock_out',
          if (clockIn) 'latitude': latitude,
          if (clockIn) 'longitude': longitude,
        },
      );
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map && details['error'] is String) {
        throw StateError(details['error'] as String);
      }
      throw StateError(
        'Could not record attendance (HTTP ${error.status}).',
      );
    }
    final result = response.data;
    final message = result is Map ? result['notification_message'] : null;
    return EmployeeAttendanceResult(
      notificationSent: result is Map && result['notification_sent'] == true,
      notificationMessage: message is String ? message : null,
    );
  }

  Future<OrganisationZone> employeeWorkZone(String organisationId) async {
    final result = await _client.rpc(
      'get_employee_work_zone_status',
      params: {
        'p_organisation_id': organisationId,
        'p_latitude': null,
        'p_longitude': null,
      },
    );
    if (result is! Map || result['polygon'] is! Map) {
      throw const FormatException(
        'The employee work zone response is invalid.',
      );
    }
    return OrganisationZone.fromGeoJson(
      Map<String, dynamic>.from(result['polygon'] as Map),
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
