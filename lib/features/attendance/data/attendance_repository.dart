import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zone/core/config/supabase_config.dart';
import 'package:zone/features/attendance/domain/attendance.dart';
import 'package:zone/features/organisations/domain/organisation_zone.dart';

class EmployeeAttendanceResult {
  const EmployeeAttendanceResult({
    required this.notificationSent,
    required this.approvalStatus,
    this.assignedShiftName,
    this.attendanceShiftName,
    this.notificationMessage,
  });

  final bool notificationSent;
  final String approvalStatus;
  final String? assignedShiftName;
  final String? attendanceShiftName;
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
      throw StateError('Could not record attendance (HTTP ${error.status}).');
    }
    final result = response.data;
    final message = result is Map ? result['notification_message'] : null;
    final approvalStatus = result is Map && result['approval_status'] is String
        ? result['approval_status'] as String
        : 'approved';
    return EmployeeAttendanceResult(
      notificationSent: result is Map && result['notification_sent'] == true,
      approvalStatus: approvalStatus,
      assignedShiftName:
          result is Map && result['assigned_shift_name'] is String
          ? result['assigned_shift_name'] as String
          : null,
      attendanceShiftName:
          result is Map && result['attendance_shift_name'] is String
          ? result['attendance_shift_name'] as String
          : null,
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
    final results = await Future.wait([
      _client
          .from('attendance_records')
          .select()
          .eq('organisation_id', organisationId)
          .order('shift_date', ascending: false)
          .limit(200),
      _client
          .from('attendance_records')
          .select()
          .eq('organisation_id', organisationId)
          .eq('approval_status', 'pending')
          .order('shift_date', ascending: false),
      _client
          .from('organisation_shifts')
          .select('id, name')
          .eq('organisation_id', organisationId),
    ]);
    final shiftNames = {
      for (final row in List<Map<String, dynamic>>.from(results[2]))
        row['id'] as String: row['name'] as String,
    };
    final attendanceById = {
      for (final row in List<Map<String, dynamic>>.from(results[0]))
        row['id'] as String: row,
      for (final row in List<Map<String, dynamic>>.from(results[1]))
        row['id'] as String: row,
    };
    final records = attendanceById.values.toList()
      ..sort((first, second) {
        final dateComparison = (second['shift_date'] as String).compareTo(
          first['shift_date'] as String,
        );
        return dateComparison != 0
            ? dateComparison
            : (second['clock_in'] as String).compareTo(
                first['clock_in'] as String,
              );
      });
    return records.map((row) => _attendanceFromRow(row, shiftNames)).toList();
  }

  Future<void> reviewAttendanceRecord({
    required String attendanceId,
    required bool approve,
  }) async {
    await _client.rpc(
      'review_attendance_record',
      params: {
        'p_attendance_id': attendanceId,
        'p_approval_status': approve ? 'approved' : 'rejected',
      },
    );
  }

  AttendanceRecord _attendanceFromRow(
    Map<String, dynamic> row,
    Map<String, String> shiftNames,
  ) {
    final shiftId = row['shift_id'] as String?;
    final assignedShiftId = row['assigned_shift_id'] as String?;
    final displayedShiftId = shiftId ?? assignedShiftId;
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
      approvalStatus: row['approval_status'] as String? ?? 'approved',
      shiftId: shiftId,
      assignedShiftId: assignedShiftId,
      shiftName: displayedShiftId == null ? null : shiftNames[displayedShiftId],
      assignedShiftName: assignedShiftId == null
          ? null
          : shiftNames[assignedShiftId],
      autoClosed: row['auto_closed'] as bool? ?? false,
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
