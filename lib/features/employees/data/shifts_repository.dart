import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zone/core/config/supabase_config.dart';
import 'package:zone/features/employees/domain/work_shift.dart';

class ShiftsRepository {
  ShiftsRepository(this._client);

  final SupabaseClient _client;

  Future<List<WorkShift>> shiftsForOrganisation(String organisationId) async {
    final rows = await _client
        .from('organisation_shifts')
        .select()
        .eq('organisation_id', organisationId)
        .order('start_time')
        .order('name');
    return List<Map<String, dynamic>>.from(rows)
        .map(WorkShift.fromRow)
        .toList();
  }

  Future<void> createShift({
    required String organisationId,
    required String name,
    required int startMinute,
    required int endMinute,
  }) async {
    await _client.from('organisation_shifts').insert({
      'organisation_id': organisationId,
      'name': name.trim(),
      'start_time': _formatTime(startMinute),
      'end_time': _formatTime(endMinute),
    });
  }

  Future<void> updateShift({
    required String organisationId,
    required WorkShift shift,
  }) async {
    await _client
        .from('organisation_shifts')
        .update({
          'name': shift.name.trim(),
          'start_time': _formatTime(shift.startMinute),
          'end_time': _formatTime(shift.endMinute),
        })
        .eq('id', shift.id)
        .eq('organisation_id', organisationId);
  }

  Future<void> deleteShift({
    required String organisationId,
    required String shiftId,
  }) async {
    await _client
        .from('organisation_shifts')
        .delete()
        .eq('id', shiftId)
        .eq('organisation_id', organisationId);
  }

  String _formatTime(int minuteOfDay) {
    final hour = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
    final minute = (minuteOfDay % 60).toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }
}

final shiftsRepositoryProvider = Provider<ShiftsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    throw StateError('Supabase is not configured.');
  }
  return ShiftsRepository(client);
});
