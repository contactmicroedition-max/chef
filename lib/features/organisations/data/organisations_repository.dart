import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zone/core/config/supabase_config.dart';
import 'package:zone/features/organisations/domain/organisation.dart';
import 'package:zone/features/organisations/domain/organisation_zone.dart';

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

  Future<String> createOrganisationWithZone({
    required String name,
    String? address,
    String? phone,
    String? logoUrl,
    required String currency,
    required String timezone,
    required OrganisationZone zone,
  }) async {
    final result = await _client.rpc(
      'create_organisation_with_zone',
      params: {
        'p_name': name.trim(),
        'p_address': _optionalText(address),
        'p_phone': _optionalText(phone),
        'p_logo_url': _optionalText(logoUrl),
        'p_currency': currency,
        'p_timezone': timezone,
        'p_polygon': zone.toGeoJson(),
      },
    );
    if (result is! String || result.isEmpty) {
      throw StateError('Creating the organisation returned no id.');
    }
    return result;
  }

  Future<OrganisationZone?> getZone(String organisationId) async {
    final result = await _client.rpc(
      'get_organisation_zone_geojson',
      params: {'p_organisation_id': organisationId},
    );
    if (result == null) return null;
    if (result is! Map) {
      throw const FormatException('The organisation zone response is invalid.');
    }
    return OrganisationZone.fromGeoJson(Map<String, dynamic>.from(result));
  }

  Future<void> updateZone({
    required String organisationId,
    required OrganisationZone zone,
  }) {
    return _client.rpc(
      'update_organisation_zone',
      params: {
        'p_organisation_id': organisationId,
        'p_polygon': zone.toGeoJson(),
      },
    );
  }

  Future<List<Organisation>> listMyOrganisations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('A signed-in user is required to list organisations.');
    }

    final rows = await _client
        .from('organisations')
        .select()
        .eq('owner_id', userId)
        .order('created_at');
    final zones = await _client
        .from('organisation_zones')
        .select('organisation_id');
    final zonedOrganisationIds = List<Map<String, dynamic>>.from(zones)
        .map((row) => row['organisation_id'] as String)
        .toSet();

    return List<Map<String, dynamic>>.from(rows)
        .map(
          (row) => _organisationFromRow(
            row,
            hasWorkZone: zonedOrganisationIds.contains(row['id']),
          ),
        )
        .toList();
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

  Organisation _organisationFromRow(
    Map<String, dynamic> row, {
    bool hasWorkZone = false,
  }) {
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
      hasWorkZone: hasWorkZone,
    );
  }

  String? _optionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
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
