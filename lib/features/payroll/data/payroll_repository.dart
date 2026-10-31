import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zone/core/config/supabase_config.dart';
import 'package:zone/features/payroll/domain/payroll.dart';

class PayrollRepository {
  PayrollRepository(this._client);

  final SupabaseClient _client;

  Future<void> recordAdvance({
    required String organisationId,
    required String employeeId,
    required double amount,
  }) {
    return _client.from('salary_advances').insert({
      'organisation_id': organisationId,
      'employee_id': employeeId,
      'amount': amount,
      'status': 'approved',
    });
  }

  Future<List<SalaryAdvance>> advancesForOrganisation(
    String organisationId,
  ) async {
    final rows = await _client
        .from('salary_advances')
        .select()
        .eq('organisation_id', organisationId)
        .order('requested_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows).map(_advanceFromRow).toList();
  }

  Future<List<SalaryPayment>> paymentsForOrganisation(
    String organisationId,
  ) async {
    final rows = await _client
        .from('salary_payments')
        .select()
        .eq('organisation_id', organisationId)
        .order('paid_at', ascending: false)
        .limit(200);
    return List<Map<String, dynamic>>.from(rows).map(_paymentFromRow).toList();
  }

  SalaryAdvance _advanceFromRow(Map<String, dynamic> row) {
    return SalaryAdvance(
      id: row['id'] as String,
      employeeId: row['employee_id'] as String,
      organisationId: row['organisation_id'] as String,
      amount: (row['amount'] as num).toDouble(),
      requestedAt: DateTime.parse(row['requested_at'] as String),
      status: row['status'] as String? ?? 'pending',
    );
  }

  SalaryPayment _paymentFromRow(Map<String, dynamic> row) {
    return SalaryPayment(
      id: row['id'] as String,
      employeeId: row['employee_id'] as String,
      organisationId: row['organisation_id'] as String,
      amount: (row['amount'] as num).toDouble(),
      paidAt: DateTime.parse(row['paid_at'] as String),
      reference: row['reference'] as String? ?? '',
    );
  }
}

final payrollRepositoryProvider = Provider<PayrollRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    throw StateError('Supabase is not configured.');
  }
  return PayrollRepository(client);
});
