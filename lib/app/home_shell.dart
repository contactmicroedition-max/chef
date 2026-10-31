import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zone/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:zone/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:zone/features/dashboard/presentation/screens/worker_panel_screen.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/features/employees/presentation/screens/employees_screen.dart';
import 'package:zone/features/organisations/presentation/dialogs/organisation_switcher_dialog.dart';
import 'package:zone/features/organisations/presentation/screens/organisations_screen.dart';
import 'package:zone/features/payroll/presentation/screens/employee_salaries_screen.dart';
import 'package:zone/features/settings/presentation/screens/settings_screen.dart';
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
    final isOwner = state.currentRole == EmployeeRole.owner;

    final pages = isWorker
        ? const [WorkerPanelScreen(), AttendanceScreen(), SettingsScreen()]
        : isOwner
        ? const [
            DashboardScreen(),
            EmployeesScreen(),
            AttendanceScreen(),
            EmployeeSalariesScreen(),
            OrganisationsScreen(),
            SettingsScreen(),
          ]
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
        : isOwner
        ? const [
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
              icon: Icon(Icons.business_rounded),
              label: 'Organisations',
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
      body: Stack(
        children: [
          IndexedStack(index: _selectedIndex, children: pages),
          if (state.isLoading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        labelBehavior: isWorker
            ? NavigationDestinationLabelBehavior.alwaysShow
            : NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: destinations,
      ),
    );
  }

  void _showOrgSwitcher(BuildContext context, AppState state) {
    showDialog<void>(
      context: context,
      builder: (context) => OrganisationSwitcherDialog(
        organisations: state.organisations,
        selectedOrganisationId: state.selectedOrganisationId,
        onSelect: (dialogContext, organisation) async {
          try {
            await ref
                .read(appStateProvider.notifier)
                .selectOrganisation(organisation.id);
          } catch (error) {
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext)
                  .showSnackBar(SnackBar(content: Text(error.toString())));
            }
          }
        },
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
