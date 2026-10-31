import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zone/core/config/supabase_config.dart';
import 'package:zone/core/models/employee.dart';

class EmployeesRepository {
  EmployeesRepository(this._client);

  final SupabaseClient _client;

  Future<String> createEmployee({
    required String organisationId,
    required String name,
    required String loginEmail,
    required String jobTitle,
    required EmployeePayType payType,
    required double salaryAmount,
    required String password,
  }) async {
    final response = await _client.functions.invoke(
      'create-employee',
      body: {
        'organisation_id': organisationId,
        'name': name.trim(),
        'login_email': loginEmail,
        'job_title': jobTitle.trim(),
        'pay_type': payType.name,
        'salary_amount': salaryAmount,
        'password': password,
      },
    );
    final data = response.data;
    if (data is! Map || data['login_email'] is! String) {
      throw const FormatException(
        'The employee account service returned an invalid response.',
      );
    }
    return data['login_email'] as String;
  }

  Future<List<Employee>> employeesForOrganisation(String organisationId) async {
    final rows = await _client
        .from('employees')
        .select()
        .eq('organisation_id', organisationId);
    return List<Map<String, dynamic>>.from(rows).map(_employeeFromRow).toList();
  }

  Employee _employeeFromRow(Map<String, dynamic> row) {
    return Employee(
      id: row['id'] as String,
      organisationId: row['organisation_id'] as String,
      name: row['full_name'] as String,
      jobTitle: row['job_title'] as String,
      hourlyRate: (row['hourly_rate'] as num?)?.toDouble() ?? 0,
      payType: row['pay_type'] == 'monthly'
          ? EmployeePayType.monthly
          : EmployeePayType.hourly,
      monthlySalary: (row['monthly_salary'] as num?)?.toDouble(),
      role: EmployeeRole.employee,
      employmentStatus: _parseEmploymentStatus(
        row['employment_status'] as String? ?? 'active',
      ),
      loginId: row['login_id'] as String?,
      loginEmail: row['login_email'] as String?,
      hireDate: DateTime.tryParse(row['hire_date'] as String? ?? ''),
    );
  }

  EmploymentStatus _parseEmploymentStatus(String status) => switch (status) {
    'inactive' => EmploymentStatus.inactive,
    'suspended' => EmploymentStatus.suspended,
    _ => EmploymentStatus.active,
  };
}

final employeesRepositoryProvider = Provider<EmployeesRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) {
    throw StateError('Supabase is not configured.');
  }
  return EmployeesRepository(client);
});
