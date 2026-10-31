import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zone/core/models/attendance.dart';
import 'package:zone/core/models/employee.dart';
import 'package:zone/core/utils/formatters.dart';
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

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final now = DateTime.now();
    final currency = state.selectedOrganisation?.currency ?? 'TND';

    final activeEmployees = state.employees
        .where((e) => e.employmentStatus == EmploymentStatus.active)
        .length;

    // This month's attendance
    final thisMonthAttendance = state.attendance.where(
      (r) => r.date.year == now.year && r.date.month == now.month,
    );
    final totalHours = thisMonthAttendance.fold<double>(
      0,
      (sum, record) => sum + record.hours,
    );
    final openShifts = state.attendance.where((r) => r.clockOut == null).length;

    // This month's advances
    final thisMonthAdvances = state.advances
        .where(
          (a) =>
              a.requestedAt.toLocal().year == now.year &&
              a.requestedAt.toLocal().month == now.month,
        )
        .fold<double>(0, (sum, a) => sum + a.amount);

    // This month's payments
    final thisMonthPayments = state.payments
        .where(
          (p) =>
              p.paidAt.toLocal().year == now.year &&
              p.paidAt.toLocal().month == now.month,
        )
        .fold<double>(0, (sum, p) => sum + p.amount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          state.currentRole == EmployeeRole.manager
              ? 'Manager overview'
              : 'Owner overview',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _MetricCard(
              title: 'Active employees',
              value: '$activeEmployees',
              icon: Icons.people_alt_rounded,
            ),
            _MetricCard(
              title: 'Currently working',
              value: '$openShifts',
              icon: Icons.work_rounded,
            ),
            _MetricCard(
              title: 'Hours this month',
              value: '${totalHours.toStringAsFixed(1)}h',
              icon: Icons.access_time_rounded,
            ),
            _MetricCard(
              title: 'Advances this month',
              value: formatCurrency(thisMonthAdvances, currency: currency),
              icon: Icons.money_off_rounded,
            ),
            _MetricCard(
              title: 'Payments this month',
              value: formatCurrency(thisMonthPayments, currency: currency),
              icon: Icons.payment_rounded,
            ),
            _MetricCard(
              title: 'Total records',
              value: '${state.attendance.length}',
              icon: Icons.calendar_month_rounded,
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (state.errorMessage != null) ...[
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── WORKER PANEL ───────────────────────────────────────────────

class WorkerPanelScreen extends ConsumerWidget {
  const WorkerPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final employeeId = state.currentEmployeeId;
    final employee = state.employees
        .where((item) => item.id == employeeId)
        .firstOrNull;
    final now = DateTime.now();
    final records = state.attendance
        .where(
          (record) =>
              record.employeeId == employeeId &&
              record.date.year == now.year &&
              record.date.month == now.month,
        )
        .toList();
    final advances =
        state.advances
            .where((advance) => advance.employeeId == employeeId)
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    final currentMonthAdvances = advances
        .where(
          (advance) =>
              advance.requestedAt.toLocal().year == now.year &&
              advance.requestedAt.toLocal().month == now.month,
        )
        .fold<double>(0, (sum, item) => sum + item.amount);
    final payments = state.payments
        .where(
          (payment) =>
              payment.employeeId == employeeId &&
              payment.paidAt.toLocal().year == now.year &&
              payment.paidAt.toLocal().month == now.month,
        )
        .fold<double>(0, (sum, item) => sum + item.amount);
    final hours = records.fold<double>(0, (sum, record) => sum + record.hours);
    final monthlyPay = employee?.salaryForHours(hours) ?? 0;
    final remainingPay = monthlyPay - currentMonthAdvances - payments;
    final currency = state.selectedOrganisation?.currency ?? 'TND';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'My employee panel',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(employee?.name ?? 'Employee'),
        const SizedBox(height: 16),
        if (employee == null)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Your account is not linked to an employee profile yet. Ask your organisation owner to link it.',
              ),
            ),
          )
        else ...[
          _MetricCard(
            title: 'Hours recorded',
            value: '${hours.toStringAsFixed(1)}h',
            icon: Icons.access_time_rounded,
          ),
          _MetricCard(
            title: 'Salary remaining this month',
            value: formatCurrency(remainingPay, currency: currency),
            icon: Icons.account_balance_wallet_rounded,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.work_outline_rounded),
                  title: Text(employee.jobTitle),
                  subtitle: Text(
                    employee.payType == EmployeePayType.hourly
                        ? '${formatCurrency(employee.hourlyRate, currency: currency)} / hour'
                        : '${formatCurrency(employee.monthlySalary ?? 0, currency: currency)} / month',
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: Text('${records.length} attendance records'),
                  subtitle: Text(
                    'Advances this month: ${formatCurrency(currentMonthAdvances, currency: currency)}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Advance history',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (advances.isEmpty)
            const Card(
              child: ListTile(title: Text('No salary advances recorded yet.')),
            )
          else
            ...advances.map(
              (advance) => Card(
                child: ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(
                    formatCurrency(advance.amount, currency: currency),
                  ),
                  subtitle: Text(formatDateTime(advance.requestedAt)),
                  trailing: Text(advance.status),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ─── EMPLOYEES ──────────────────────────────────────────────────

class EmployeesScreen extends ConsumerWidget {
  const EmployeesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final employees = state.employees;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Employees',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (state.currentRole == EmployeeRole.owner)
              FilledButton.icon(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AddEmployeeDialog(),
                ),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (employees.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Icons.people_outline_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text('No employees yet.'),
                  if (state.currentRole == EmployeeRole.owner) ...[
                    const SizedBox(height: 8),
                    const Text('Tap "Add" to create your first employee.'),
                  ],
                ],
              ),
            ),
          )
        else
          ...employees.map((employee) => EmployeeCard(employee: employee)),
      ],
    );
  }
}

// ─── ADD EMPLOYEE DIALOG ────────────────────────────────────────

class AddEmployeeDialog extends ConsumerStatefulWidget {
  const AddEmployeeDialog({super.key});

  @override
  ConsumerState<AddEmployeeDialog> createState() => _AddEmployeeDialogState();
}

class _AddEmployeeDialogState extends ConsumerState<AddEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _loginEmail = TextEditingController();
  final _jobTitle = TextEditingController();
  final _salaryAmount = TextEditingController();
  final _password = TextEditingController();
  String? _errorMessage;
  bool _saving = false;
  bool _obscurePassword = true;
  bool _emailEdited = false;
  EmployeePayType _payType = EmployeePayType.hourly;

  void _updateGeneratedEmail(String name, String organisationName) {
    if (_emailEdited) return;
    final baseEmail = employeeEmailAddress(name, organisationName);
    var email = baseEmail;
    var suffix = 2;
    final existingEmails = ref
        .read(appStateProvider)
        .employees
        .map((employee) => employee.loginEmail?.toLowerCase())
        .whereType<String>()
        .toSet();
    while (existingEmails.contains(email)) {
      email = employeeEmailAddress(name, organisationName, suffix: suffix++);
    }
    _loginEmail.value = TextEditingValue(
      text: email,
      selection: TextSelection.collapsed(offset: email.length),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _loginEmail.dispose();
    _jobTitle.dispose();
    _salaryAmount.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      final createdLoginEmail = await ref
          .read(appStateProvider.notifier)
          .createEmployee(
            name: _name.text,
            loginEmail: _loginEmail.text,
            jobTitle: _jobTitle.text,
            payType: _payType,
            salaryAmount: double.parse(_salaryAmount.text),
            password: _password.text,
          );
      _loginEmail.text = createdLoginEmail;
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
      title: const Text('Add employee'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                onChanged: (name) => _updateGeneratedEmail(
                  name,
                  ref.read(appStateProvider).selectedOrganisation?.name ?? '',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name'
                    : null,
              ),
              TextFormField(
                controller: _loginEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Employee login email',
                  helperText:
                      'Generated from the employee and organisation names.',
                ),
                onChanged: (_) => _emailEdited = true,
                validator: (value) {
                  try {
                    cleanEmployeeEmail(value ?? '');
                    return null;
                  } on FormatException catch (error) {
                    return error.message;
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<EmployeePayType>(
                initialValue: _payType,
                decoration: const InputDecoration(labelText: 'Pay type'),
                items: const [
                  DropdownMenuItem(
                    value: EmployeePayType.hourly,
                    child: Text('Paid by hour'),
                  ),
                  DropdownMenuItem(
                    value: EmployeePayType.monthly,
                    child: Text('Fixed monthly salary'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (payType) {
                        if (payType != null) {
                          setState(() => _payType = payType);
                        }
                      },
              ),
              _dialogField(_jobTitle, 'Job title'),
              _dialogField(
                _salaryAmount,
                _payType == EmployeePayType.hourly
                    ? 'Hourly wage'
                    : 'Monthly salary',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  return amount == null || !amount.isFinite || amount <= 0
                      ? 'Enter an amount greater than zero'
                      : null;
                },
              ),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Initial password (min 8 chars)',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => value == null || value.length < 8
                    ? 'Use at least 8 characters'
                    : null,
              ),
              const SizedBox(height: 8),
              Text(
                'The employee signs in with this email and the password you set.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

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
            _dialogField(
              _loginId,
              'Employee email or legacy ID',
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

Widget _dialogField(
  TextEditingController controller,
  String label, {
  TextInputType? keyboardType,
  String? Function(String?)? validator,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator:
          validator ??
          (value) => value == null || value.trim().isEmpty ? 'Required' : null,
    ),
  );
}

// ─── EMPLOYEE CARD ──────────────────────────────────────────────

class EmployeeCard extends StatelessWidget {
  const EmployeeCard({super.key, required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                employee.name.isNotEmpty ? employee.name.substring(0, 1) : '?',
              ),
            ),
            title: Text(employee.name),
            subtitle: Text(
              '${employee.jobTitle} • ${employee.loginEmail ?? 'Legacy ID ${employee.loginId ?? ""}'}',
            ),
            trailing: Chip(label: Text(employee.employmentStatus.name)),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 8),
              child: TextButton.icon(
                onPressed: employee.employmentStatus == EmploymentStatus.active
                    ? () => showDialog<void>(
                        context: context,
                        builder: (_) => GiveAdvanceDialog(employee: employee),
                      )
                    : null,
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Give advance'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── GIVE ADVANCE DIALOG ────────────────────────────────────────

class GiveAdvanceDialog extends ConsumerStatefulWidget {
  const GiveAdvanceDialog({super.key, required this.employee});

  final Employee employee;

  @override
  ConsumerState<GiveAdvanceDialog> createState() => _GiveAdvanceDialogState();
}

class _GiveAdvanceDialogState extends ConsumerState<GiveAdvanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  String? _errorMessage;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });
    try {
      await ref
          .read(appStateProvider.notifier)
          .giveEmployeeAdvance(
            employeeId: widget.employee.id,
            amount: double.parse(_amount.text),
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
    final currency =
        ref.watch(appStateProvider).selectedOrganisation?.currency ?? 'TND';
    return AlertDialog(
      title: Text('Give advance to ${widget.employee.name}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(labelText: 'Amount ($currency)'),
              validator: (value) {
                final amount = double.tryParse(value ?? '');
                return amount == null || !amount.isFinite || amount <= 0
                    ? 'Enter an amount greater than zero'
                    : null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Record advance'),
        ),
      ],
    );
  }
}

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

// ─── METRIC CARD ────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const Spacer(),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
