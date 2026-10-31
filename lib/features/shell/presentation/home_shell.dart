import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zone/core/widgets/dialog_form_field.dart';
import 'package:zone/features/auth/domain/auth_formatters.dart';
import 'package:zone/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:zone/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:zone/features/dashboard/presentation/screens/worker_panel_screen.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/features/employees/presentation/screens/employees_screen.dart';
import 'package:zone/features/payroll/presentation/screens/employee_salaries_screen.dart';
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

// ─── SALARIES ───────────────────────────────────────────────────

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
