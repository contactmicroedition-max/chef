import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zone/core/config/supabase_config.dart';
import 'package:zone/core/models/attendance.dart';
import 'package:zone/core/models/employee.dart';
import 'package:zone/core/models/organisation.dart';
import 'package:zone/core/models/payroll.dart';
import 'package:zone/core/services/push_notification_service.dart';
import 'package:zone/core/utils/formatters.dart';

class AppState {
  const AppState({
    this.organisations = const [],
    this.employees = const [],
    this.attendance = const [],
    this.advances = const [],
    this.payments = const [],
    this.isAuthenticated = false,
    this.isLoading = false,
    this.locale = const Locale('fr'),
    this.themeMode = ThemeMode.system,
    this.selectedOrganisationId,
    this.currentUserId,
    this.currentUserEmail,
    this.currentRole,
    this.currentEmployeeId,
    this.errorMessage,
  });

  final List<Organisation> organisations;
  final List<Employee> employees;
  final List<AttendanceRecord> attendance;
  final List<SalaryAdvance> advances;
  final List<SalaryPayment> payments;
  final bool isAuthenticated;
  final bool isLoading;
  final Locale locale;
  final ThemeMode themeMode;
  final String? selectedOrganisationId;
  final String? currentUserId;
  final String? currentUserEmail;
  final EmployeeRole? currentRole;
  final String? currentEmployeeId;
  final String? errorMessage;

  Organisation? get selectedOrganisation {
    for (final organisation in organisations) {
      if (organisation.id == selectedOrganisationId) return organisation;
    }
    return null;
  }

  AppState copyWith({
    List<Organisation>? organisations,
    List<Employee>? employees,
    List<AttendanceRecord>? attendance,
    List<SalaryAdvance>? advances,
    List<SalaryPayment>? payments,
    bool? isAuthenticated,
    bool? isLoading,
    Locale? locale,
    ThemeMode? themeMode,
    String? selectedOrganisationId,
    String? currentUserId,
    String? currentUserEmail,
    EmployeeRole? currentRole,
    String? currentEmployeeId,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
    bool clearOrganisation = false,
  }) {
    return AppState(
      organisations: organisations ?? this.organisations,
      employees: employees ?? this.employees,
      attendance: attendance ?? this.attendance,
      advances: advances ?? this.advances,
      payments: payments ?? this.payments,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      selectedOrganisationId: clearOrganisation
          ? null
          : selectedOrganisationId ?? this.selectedOrganisationId,
      currentUserId: clearUser ? null : currentUserId ?? this.currentUserId,
      currentUserEmail: clearUser
          ? null
          : currentUserEmail ?? this.currentUserEmail,
      currentRole: clearUser ? null : currentRole ?? this.currentRole,
      currentEmployeeId: clearUser
          ? null
          : currentEmployeeId ?? this.currentEmployeeId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AppStateNotifier extends Notifier<AppState> {
  bool _authListenerAttached = false;

  @override
  AppState build() {
    final client = SupabaseConfig.client;
    if (client != null && !_authListenerAttached) {
      _authListenerAttached = true;
      client.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        final user = data.session?.user;
        if (event == AuthChangeEvent.signedOut || user == null) {
          state = AppState(
            locale: state.locale,
            themeMode: state.themeMode,
          );
        } else if (state.currentUserId != user.id) {
          unawaited(_loadUser(user));
        }
      });

      final user = client.auth.currentUser;
      if (user != null) {
        Future.microtask(() => _loadUser(user));
        return AppState(
          isLoading: true,
          locale: const Locale('fr'),
          themeMode: ThemeMode.system,
        );
      }
    }
    return const AppState();
  }

  // ─── SIGN IN ────────────────────────────────────────────────────

  /// Owner signs in with email, employee signs in with their ID (digits).
  Future<void> signIn(String identifier, String password) async {
    final client = _requireSupabase();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final trimmed = identifier.trim();
      final isEmail = trimmed.contains('@');
      AuthResponse response;

      if (isEmail) {
        // Owner / manager email login
        response = await client.auth.signInWithPassword(
          email: trimmed,
          password: password,
        );
      } else {
        // Employee login: the ID is used to build a fake email
        final empId = cleanEmployeeId(trimmed);
        final email = employeeLoginEmail(empId);
        response = await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }

      final user = response.user;
      if (user == null) {
        throw const AuthException('Authentication returned no user.');
      }
      await _loadUser(user);
    } on AuthException catch (error) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        errorMessage: error.message,
      );
    } on FormatException catch (error) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        errorMessage: error.message,
      );
    } on PostgrestException catch (error) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        errorMessage: error.message,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        errorMessage: error.toString(),
      );
    }
  }

  // ─── REGISTER ───────────────────────────────────────────────────

  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final client = _requireSupabase();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': name.trim()},
      );
      if (response.user == null) {
        throw const AuthException('Registration returned no user.');
      }
      if (response.session != null) {
        await _loadUser(response.user!);
      } else {
        // Auto-confirm trigger may have fired — try signing in immediately
        try {
          final loginRes = await client.auth.signInWithPassword(
            email: email.trim(),
            password: password,
          );
          if (loginRes.user != null) {
            await _loadUser(loginRes.user!);
            return loginRes;
          }
        } catch (_) {
          state = state.copyWith(
            isLoading: false,
            errorMessage:
                'Account created. Disable "Confirm email" in Supabase Auth settings, or run migration 007.',
          );
        }
      }
      return response;
    } on AuthException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
      rethrow;
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    final client = _requireSupabase();
    await client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> signOut() async {
    final client = _requireSupabase();
    await client.auth.signOut();
    state = AppState(locale: state.locale, themeMode: state.themeMode);
  }

  // ─── ORGANISATION ───────────────────────────────────────────────

  Future<void> createOrganisation({
    required String name,
    String? address,
    String? phone,
    String currency = 'TND',
  }) async {
    final client = _requireSupabase();
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await client.rpc(
        'create_organisation',
        params: {
          'p_name': name.trim(),
          'p_address': address?.trim().isEmpty == true ? null : address?.trim(),
          'p_phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
          'p_currency': currency,
        },
      );
      final user = client.auth.currentUser;
      if (user == null) throw const AuthException('Session expired.');
      await _loadUser(user);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> selectOrganisation(String organisationId) async {
    final selected = state.organisations
        .where((organisation) => organisation.id == organisationId)
        .firstOrNull;
    if (selected == null) {
      throw StateError('The selected organisation is not accessible.');
    }
    final membership = await _membershipFor(organisationId);
    final user = _requireSupabase().auth.currentUser;
    if (user == null) throw const AuthException('Session expired.');
    await _loadUser(
      user,
      preferredOrganisationId: organisationId,
      preferredMembership: membership,
    );
  }

  // ─── CREATE EMPLOYEE ───────────────────────────────────────────

  Future<void> createEmployee({
    required String name,
    required String empId,
    required String jobTitle,
    required EmployeePayType payType,
    required double salaryAmount,
    required String password,
  }) async {
    final client = _requireSupabase();
    final organisationId = state.selectedOrganisationId;
    if (organisationId == null) {
      throw StateError('Select an organisation before adding an employee.');
    }
    if (state.currentRole != EmployeeRole.owner) {
      throw StateError(
        'Only the organisation owner can create employee accounts.',
      );
    }
    final id = cleanEmployeeId(empId);

    // Call PostgreSQL RPC — stores ID as-is, no phone logic
    try {
      await client.rpc(
        'create_employee_account',
        params: {
          'p_organisation_id': organisationId,
          'p_name': name.trim(),
          'p_phone': id,
          'p_job_title': jobTitle.trim(),
          'p_pay_type': payType.name,
          'p_salary_amount': salaryAmount,
          'p_password': password,
        },
      );
    } on PostgrestException catch (e) {
      if (e.code == '42883' || e.message.contains('does not exist')) {
        throw StateError(
          'Run migration 007 in Supabase SQL Editor first.',
        );
      }
      rethrow;
    }

    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Session expired.');
    await _loadUser(user, preferredOrganisationId: organisationId);
  }

  // ─── ADVANCE ────────────────────────────────────────────────────

  Future<void> giveEmployeeAdvance({
    required String employeeId,
    required double amount,
  }) async {
    final client = _requireSupabase();
    final organisationId = state.selectedOrganisationId;
    if (organisationId == null) {
      throw StateError('Select an organisation before recording an advance.');
    }
    if (state.currentRole != EmployeeRole.owner &&
        state.currentRole != EmployeeRole.manager) {
      throw StateError('Only organisation managers can record advances.');
    }
    await client.from('salary_advances').insert({
      'organisation_id': organisationId,
      'employee_id': employeeId,
      'amount': amount,
      'status': 'approved',
    });
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Session expired.');
    await _loadUser(user, preferredOrganisationId: organisationId);
  }

  // ─── ATTENDANCE ─────────────────────────────────────────────────

  Future<String?> recordEmployeeShift({required bool clockIn}) async {
    final client = _requireSupabase();
    final organisationId = state.selectedOrganisationId;
    if (state.currentRole != EmployeeRole.employee ||
        state.currentEmployeeId == null ||
        organisationId == null) {
      throw StateError('Only a linked employee can record their own shift.');
    }

    final response = await client.functions.invoke(
      'employee-attendance',
      body: {
        'organisation_id': organisationId,
        'action': clockIn ? 'clock_in' : 'clock_out',
      },
    );
    final result = response.data;
    final notificationSent =
        result is Map && result['notification_sent'] == true;
    final notificationMessage = result is Map
        ? result['notification_message']
        : null;
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Session expired.');
    await _loadUser(user, preferredOrganisationId: organisationId);
    return notificationSent
        ? null
        : notificationMessage is String
        ? notificationMessage
        : 'The owner push notification could not be sent.';
  }

  // ─── ROLE ASSIGNMENT ────────────────────────────────────────────

  Future<void> assignOrganisationRole({
    required String email,
    required EmployeeRole role,
    String? employeeId,
  }) async {
    final client = _requireSupabase();
    final organisationId = state.selectedOrganisationId;
    if (organisationId == null) {
      throw StateError('Select an organisation before assigning a role.');
    }
    if (role == EmployeeRole.owner) {
      throw ArgumentError('An organisation owner cannot be assigned here.');
    }
    await client.rpc(
      'add_organisation_member',
      params: {
        'p_organisation_id': organisationId,
        'p_email': email.trim(),
        'p_role': role.name,
        'p_employee_id': role == EmployeeRole.employee ? employeeId : null,
      },
    );
    final user = client.auth.currentUser;
    if (user == null) throw const AuthException('Session expired.');
    await _loadUser(user, preferredOrganisationId: organisationId);
  }

  // ─── SETTINGS ───────────────────────────────────────────────────

  void setLocale(Locale locale) {
    state = state.copyWith(locale: locale);
  }

  void setThemeMode(ThemeMode themeMode) {
    state = state.copyWith(themeMode: themeMode);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  // ─── INTERNAL ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> _membershipFor(String organisationId) async {
    final client = _requireSupabase();
    final userId = client.auth.currentUser!.id;
    final row = await client
        .from('organisation_members')
        .select('organisation_id, role, employee_id')
        .eq('organisation_id', organisationId)
        .eq('user_id', userId)
        .single();
    return row;
  }

  Future<void> _loadUser(
    User user, {
    String? preferredOrganisationId,
    Map<String, dynamic>? preferredMembership,
  }) async {
    state = AppState(
      isLoading: true,
      isAuthenticated: true,
      currentUserId: user.id,
      currentUserEmail: user.email,
      locale: state.locale,
      themeMode: state.themeMode,
    );

    try {
      final client = _requireSupabase();

      final memberships = await client
          .from('organisation_members')
          .select('organisation_id, role, employee_id')
          .eq('user_id', user.id);
      final membershipRows = List<Map<String, dynamic>>.from(memberships);

      final organisationIds = membershipRows
          .map((row) => row['organisation_id'] as String)
          .toList();
      final organisations = organisationIds.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              await client
                  .from('organisations')
                  .select()
                  .inFilter('id', organisationIds),
            );
      final organisationModels = organisations
          .map(_organisationFromRow)
          .toList();

      final selectedId =
          preferredOrganisationId ??
          (organisationModels.any(
                (item) => item.id == state.selectedOrganisationId,
              )
              ? state.selectedOrganisationId
              : organisationModels.firstOrNull?.id);
      final selectedMembership =
          preferredMembership ??
          membershipRows
              .where((row) => row['organisation_id'] == selectedId)
              .firstOrNull;

      if (selectedId == null || selectedMembership == null) {
        state = state.copyWith(
          organisations: organisationModels,
          employees: const [],
          attendance: const [],
          advances: const [],
          payments: const [],
          isAuthenticated: true,
          isLoading: false,
          currentUserId: user.id,
          currentUserEmail: user.email,
          clearOrganisation: true,
          currentRole: null,
          currentEmployeeId: null,
        );
        return;
      }

      final role = _parseRole(selectedMembership['role'] as String);
      final employeeId = selectedMembership['employee_id'] as String?;

      final employeeRows = await client
          .from('employees')
          .select()
          .eq('organisation_id', selectedId);
      final employees = List<Map<String, dynamic>>.from(employeeRows)
          .map(_employeeFromRow)
          .toList();

      List<AttendanceRecord> attendanceList = [];
      try {
        final attendanceRows = await client
            .from('attendance_records')
            .select()
            .eq('organisation_id', selectedId)
            .order('shift_date', ascending: false)
            .limit(200);
        attendanceList = List<Map<String, dynamic>>.from(attendanceRows)
            .map(_attendanceFromRow)
            .toList();
      } catch (e) {
        debugPrint('Could not load attendance: $e');
      }

      List<SalaryAdvance> advancesList = [];
      try {
        final advancesRows = await client
            .from('salary_advances')
            .select()
            .eq('organisation_id', selectedId)
            .order('requested_at', ascending: false)
            .limit(200);
        advancesList = List<Map<String, dynamic>>.from(advancesRows)
            .map(_advanceFromRow)
            .toList();
      } catch (e) {
        debugPrint('Could not load advances: $e');
      }

      List<SalaryPayment> paymentsList = [];
      try {
        final paymentRows = await client
            .from('salary_payments')
            .select()
            .eq('organisation_id', selectedId)
            .order('paid_at', ascending: false)
            .limit(200);
        paymentsList = List<Map<String, dynamic>>.from(paymentRows)
            .map(_paymentFromRow)
            .toList();
      } catch (e) {
        debugPrint('Could not load payments: $e');
      }

      state = state.copyWith(
        organisations: organisationModels,
        employees: employees,
        attendance: attendanceList,
        advances: advancesList,
        payments: paymentsList,
        isAuthenticated: true,
        isLoading: false,
        currentUserId: user.id,
        currentUserEmail: user.email,
        selectedOrganisationId: selectedId,
        currentRole: role,
        currentEmployeeId: employeeId,
        clearError: true,
      );

      if (role == EmployeeRole.owner) {
        unawaited(
          PushNotificationService.registerOwnerDevice(
            client: client,
            userId: user.id,
          ).catchError((Object error, StackTrace stackTrace) {
            debugPrint('Could not register owner push notifications: $error');
          }),
        );
      }
    } catch (error) {
      debugPrint('_loadUser error: $error');
      state = state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        errorMessage: 'Could not load data: $error',
      );
    }
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

  Employee _employeeFromRow(Map<String, dynamic> row) {
    return Employee(
      id: row['id'] as String,
      organisationId: row['organisation_id'] as String,
      name: row['full_name'] as String,
      email: row['email'] as String?,
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
      phone: row['phone'] as String?,
      hireDate: DateTime.tryParse(row['hire_date'] as String? ?? ''),
    );
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

  EmployeeRole _parseRole(String role) => switch (role) {
    'owner' => EmployeeRole.owner,
    'manager' => EmployeeRole.manager,
    _ => EmployeeRole.employee,
  };

  EmploymentStatus _parseEmploymentStatus(String status) => switch (status) {
    'inactive' => EmploymentStatus.inactive,
    'suspended' => EmploymentStatus.suspended,
    _ => EmploymentStatus.active,
  };

  SupabaseClient _requireSupabase() {
    final client = SupabaseConfig.client;
    if (client == null) {
      throw StateError(
        'Supabase is not configured. Check SUPABASE_URL and SUPABASE_ANON_KEY in .env',
      );
    }
    return client;
  }
}

final appStateProvider = NotifierProvider<AppStateNotifier, AppState>(
  AppStateNotifier.new,
);
