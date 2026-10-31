import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zone/core/utils/formatters.dart';
import 'package:zone/core/widgets/dialog_form_field.dart';
import 'package:zone/features/auth/domain/auth_formatters.dart';
import 'package:zone/features/attendance/domain/attendance.dart';
import 'package:zone/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:zone/features/dashboard/presentation/screens/worker_panel_screen.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/features/employees/presentation/screens/employees_screen.dart';
import 'package:zone/providers/app_state.dart';

class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final selectedOrganisation = state.selectedOrganisation;
    final isWorker = state.currentRole == EmployeeRole.employee;

    final pages = isWorker
        ? const [WorkerPanelScreen(), AttendanceScreen(), SettingsScreen()]
        : const [
            DashboardScreen(),
            EmployeesScreen(),
            AttendanceScreen(),
            EmployeeSalariesScreen(),
            SettingsScreen(),
          ];
    final destinations = isWorker
        ? const [
            NavigationDestination(
              icon: Icon(Icons.home_rounded),
              label: 'My panel',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_rounded),
              label: 'Attendance',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ]
        : const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_alt_rounded),
              label: 'Employees',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_rounded),
              label: 'Attendance',
            ),
            NavigationDestination(
              icon: Icon(Icons.attach_money_rounded),
              label: 'Salaries',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ];
    if (_selectedIndex >= pages.length) _selectedIndex = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedOrganisation?.name ?? 'CHEF'),
        actions: [
          if (state.organisations.length > 1)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              tooltip: 'Switch organisation',
              onPressed: () => _showOrgSwitcher(context, state),
            ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const CHEFBadge(),
                    const SizedBox(height: 12),
                    Text(
                      selectedOrganisation?.name ?? 'CHEF',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Signed in as ${state.currentRole?.name ?? 'member'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (state.organisations.length > 1)
                ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded),
                  title: const Text('Switch organisation'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showOrgSwitcher(context, state);
                  },
                ),
              if (state.organisations.length > 1) const Divider(),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _selectedIndex = pages.length - 1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Logout'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await ref.read(appStateProvider.notifier).signOut();
                },
              ),
            ],
          ),
        ),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: destinations,
      ),
    );
  }

  void _showOrgSwitcher(BuildContext context, AppState state) {
    showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose organisation'),
        children: state.organisations
            .map(
              (organisation) => SimpleDialogOption(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await ref
                        .read(appStateProvider.notifier)
                        .selectOrganisation(organisation.id);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(error.toString())));
                    }
                  }
                },
                child: ListTile(
                  leading: const Icon(Icons.business_rounded),
                  title: Text(organisation.name),
                  trailing: organisation.id == state.selectedOrganisationId
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class CHEFBadge extends StatelessWidget {
  const CHEFBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'CHEF',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── DASHBOARD ──────────────────────────────────────────────────

// ─── WORKER PANEL ───────────────────────────────────────────────

// ─── EMPLOYEES ──────────────────────────────────────────────────

// ─── ADD EMPLOYEE DIALOG ────────────────────────────────────────

// ─── ASSIGN ROLE DIALOG ─────────────────────────────────────────

class AssignRoleDialog extends ConsumerStatefulWidget {
  const AssignRoleDialog({super.key});

  @override
  ConsumerState<AssignRoleDialog> createState() => _AssignRoleDialogState();
}

class _AssignRoleDialogState extends ConsumerState<AssignRoleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _loginId = TextEditingController();
  String? _errorMessage;
  bool _saving = false;

  @override
  void dispose() {
    _loginId.dispose();
    super.dispose();
  }

  Future<void> _assign() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(appStateProvider.notifier)
          .assignOrganisationRole(
            loginIdentifier: _loginId.text,
            role: EmployeeRole.manager,
          );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Assign manager access'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DialogFormField(
              controller: _loginId,
              label: 'Employee email or legacy ID',
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.trim().contains('@')) {
                  try {
                    cleanEmployeeEmail(value);
                    return null;
                  } on FormatException catch (error) {
                    return error.message;
                  }
                }
                try {
                  cleanAccountId(value ?? '');
                  return null;
                } on FormatException catch (error) {
                  return error.message;
                }
              },
            ),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _assign,
          child: Text(_saving ? 'Assigning…' : 'Assign role'),
        ),
      ],
    );
  }
}

// ─── HELPERS ────────────────────────────────────────────────────

// ─── EMPLOYEE CARD ──────────────────────────────────────────────

// ─── GIVE ADVANCE DIALOG ────────────────────────────────────────

// ─── ATTENDANCE ─────────────────────────────────────────────────

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  bool _isRecording = false;

  Future<void> _recordShift(bool clockIn) async {
    setState(() => _isRecording = true);
    try {
      final notificationMessage = await ref
          .read(appStateProvider.notifier)
          .recordEmployeeShift(clockIn: clockIn);
      if (!mounted) return;
      final action = clockIn ? 'Clocked in' : 'Clocked out';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notificationMessage == null
                ? '$action successfully. The owner was notified.'
                : '$action successfully. $notificationMessage',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final employeeId = state.currentEmployeeId;
    final openShift = state.attendance
        .where(
          (record) =>
              record.employeeId == employeeId && record.clockOut == null,
        )
        .firstOrNull;

    // Filter attendance by role
    final records = state.currentRole == EmployeeRole.employee
        ? state.attendance.where((r) => r.employeeId == employeeId).toList()
        : state.attendance;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Attendance', style: Theme.of(context).textTheme.headlineSmall),
        if (state.currentRole == EmployeeRole.employee &&
            state.currentEmployeeId != null) ...[
          const SizedBox(height: 12),
          if (openShift != null)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.timer_rounded),
                    const SizedBox(width: 8),
                    Text('Shift started ${formatDateTime(openShift.clockIn)}'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _isRecording
                ? null
                : () => _recordShift(openShift == null),
            icon: Icon(
              openShift == null ? Icons.play_arrow_rounded : Icons.stop_rounded,
            ),
            label: Text(
              _isRecording
                  ? 'Recording…'
                  : openShift == null
                  ? 'Clock in'
                  : 'Clock out',
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (records.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No attendance records yet.'),
            ),
          )
        else
          ...records.map((record) => AttendanceCard(record: record)),
      ],
    );
  }
}

class AttendanceCard extends StatelessWidget {
  const AttendanceCard({super.key, required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final clockIn = record.clockIn.toLocal();
    final clockOut = record.clockOut?.toLocal();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('Shift ${formatDate(record.date)}'),
        subtitle: Text(
          '${clockIn.hour.toString().padLeft(2, '0')}:${clockIn.minute.toString().padLeft(2, '0')} - '
          '${clockOut?.hour.toString().padLeft(2, '0') ?? '--'}:${clockOut?.minute.toString().padLeft(2, '0') ?? '--'}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formatDuration(record.duration),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(record.status, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

// ─── SALARIES ───────────────────────────────────────────────────

class EmployeeSalariesScreen extends ConsumerWidget {
  const EmployeeSalariesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final currency = state.selectedOrganisation?.currency ?? 'TND';
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Employee salaries',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (state.employees.isEmpty)
          const Card(
            child: ListTile(title: Text('No employees have been added yet.')),
          ),
        ...state.employees.map((employee) {
          final records = state.attendance.where(
            (record) =>
                record.employeeId == employee.id &&
                record.date.year == now.year &&
                record.date.month == now.month,
          );
          final hours = records.fold<double>(
            0,
            (sum, record) => sum + record.hours,
          );

          final currentMonthAdvances = state.advances
              .where(
                (a) =>
                    a.employeeId == employee.id &&
                    a.requestedAt.toLocal().year == now.year &&
                    a.requestedAt.toLocal().month == now.month,
              )
              .fold<double>(0, (sum, a) => sum + a.amount);

          final currentMonthPayments = state.payments
              .where(
                (p) =>
                    p.employeeId == employee.id &&
                    p.paidAt.toLocal().year == now.year &&
                    p.paidAt.toLocal().month == now.month,
              )
              .fold<double>(0, (sum, p) => sum + p.amount);

          final earned = employee.salaryForHours(hours);
          final remaining =
              earned - currentMonthAdvances - currentMonthPayments;

          final employeeAdvances =
              state.advances
                  .where((advance) => advance.employeeId == employee.id)
                  .toList()
                ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
          final salaryLabel = employee.payType == EmployeePayType.hourly
              ? '${formatCurrency(employee.hourlyRate, currency: currency)} / hour'
              : '${formatCurrency(employee.monthlySalary ?? 0, currency: currency)} / month';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  employee.name.isNotEmpty
                      ? employee.name.substring(0, 1)
                      : '?',
                ),
              ),
              title: Text(employee.name),
              subtitle: Text(salaryLabel),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time_rounded),
                  title: Text(
                    employee.payType == EmployeePayType.hourly
                        ? 'Hours this month: ${hours.toStringAsFixed(1)}'
                        : 'Hours worked (reference): ${hours.toStringAsFixed(1)}',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_balance_wallet_rounded),
                  title: Text(
                    'Earned: ${formatCurrency(earned, currency: currency)}',
                  ),
                  subtitle: Text(
                    'Advances: ${formatCurrency(currentMonthAdvances, currency: currency)} • '
                    'Paid: ${formatCurrency(currentMonthPayments, currency: currency)}',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.savings_rounded,
                    color: remaining < 0
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    'Remaining: ${formatCurrency(remaining, currency: currency)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: remaining < 0
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ),
                const Divider(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Advances',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (employeeAdvances.isEmpty)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('No advances recorded.'),
                  )
                else
                  ...employeeAdvances.map(
                    (advance) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.money_off_csred_outlined),
                      title: Text(
                        formatCurrency(advance.amount, currency: currency),
                      ),
                      subtitle: Text(formatDateTime(advance.requestedAt)),
                      trailing: Text(advance.status),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ─── SETTINGS ───────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_rounded),
                title: Text(
                  state.currentRole == EmployeeRole.employee &&
                          state.currentUserLoginId == null
                      ? 'Email ${state.currentUserEmail ?? '—'}'
                      : 'ID ${state.currentUserLoginId ?? '—'}',
                ),
                subtitle: Text('Role: ${state.currentRole?.name ?? 'member'}'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.language_rounded),
                title: const Text('Language'),
                trailing: DropdownButton<Locale>(
                  value: state.locale,
                  items: const [
                    DropdownMenuItem(
                      value: Locale('fr'),
                      child: Text('Français'),
                    ),
                    DropdownMenuItem(
                      value: Locale('en'),
                      child: Text('English'),
                    ),
                    DropdownMenuItem(
                      value: Locale('ar'),
                      child: Text('العربية'),
                    ),
                  ],
                  onChanged: (locale) {
                    if (locale != null) {
                      ref.read(appStateProvider.notifier).setLocale(locale);
                    }
                  },
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.brightness_4_rounded),
                title: const Text('Theme'),
                trailing: DropdownButton<ThemeMode>(
                  value: state.themeMode,
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) {
                      ref.read(appStateProvider.notifier).setThemeMode(mode);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: () => ref.read(appStateProvider.notifier).signOut(),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}
