import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zone/core/config/supabase_config.dart';
import 'package:zone/features/organisations/domain/organisation.dart';

class OrganisationsRepository {
  OrganisationsRepository(this._client);

  final SupabaseClient _client;

  Future<void> createOrganisation({
    required String name,
    String? address,
    String? phone,
    required String currency,
  }) {
    return _client.rpc(
      'create_organisation',
      params: {
        'p_name': name.trim(),
        'p_address': address?.trim().isEmpty == true ? null : address?.trim(),
        'p_phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
        'p_currency': currency,
      },
    );
  }

  Future<List<Map<String, dynamic>>> membershipsForUser(String userId) async {
    final rows = await _client
        .from('organisation_members')
        .select('organisation_id, role, employee_id')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> membershipFor({
    required String organisationId,
    required String userId,
  }) {
    return _client
        .from('organisation_members')
        .select('organisation_id, role, employee_id')
        .eq('organisation_id', organisationId)
        .eq('user_id', userId)
        .single();
  }

  Future<List<Organisation>> organisationsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await _client
        .from('organisations')
        .select()
        .inFilter('id', ids);
    return List<Map<String, dynamic>>.from(rows)
        .map(_organisationFromRow)
        .toList();
  }

  Future<void> addMember({
    required String organisationId,
    required String loginIdentifier,
    required String role,
    String? employeeId,
  }) {
    return _client.rpc(
      'add_organisation_member',
      params: {
        'p_organisation_id': organisationId,
        'p_login_identifier': loginIdentifier,
        'p_role': role,
        'p_employee_id': employeeId,
      },
    );
  }

  Organisation _organisationFromRow(Map<String, dynamic> row) {
    return Organisation(
      id: row['id'] as String,
      name: row['name'] as String,
      currency: row['currency'] as String? ?? 'TND',
      timezone: row['timezone'] as String? ?? 'Africa/Tunis',
      ownerId: row['owner_id'] as String,
      logoUrl: row['logo_url'] as String?,
      address: row['address'] as String?,
      phone: row['phone'] as String?,
      status: row['status'] as String? ?? 'active',
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
    );
  }
}

final organisationsRepositoryProvider = Provider<OrganisationsRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    throw StateError('Supabase is not configured.');
  }
  return OrganisationsRepository(client);
});
