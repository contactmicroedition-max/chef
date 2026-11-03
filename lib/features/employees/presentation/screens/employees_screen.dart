import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zone/core/widgets/paginated_list.dart';
import 'package:zone/features/employees/data/shifts_repository.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/features/employees/domain/work_shift.dart';
import 'package:zone/features/employees/presentation/dialogs/add_employee_dialog.dart';
import 'package:zone/features/employees/presentation/widgets/employee_card.dart';
import 'package:zone/features/employees/presentation/widgets/shifts_section.dart';
import 'package:zone/providers/app_state.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  String? _loadedOrganisationId;
  late Future<List<WorkShift>> _shiftsFuture;

  @override
  void initState() {
    super.initState();
    _loadedOrganisationId = ref.read(appStateProvider).selectedOrganisationId;
    _shiftsFuture = _loadShifts(_loadedOrganisationId);
  }

  Future<List<WorkShift>> _loadShifts(String? organisationId) {
    if (organisationId == null) return Future.value(const <WorkShift>[]);
    return ref
        .read(shiftsRepositoryProvider)
        .shiftsForOrganisation(organisationId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final employees = state.employees;
    final organisationId = state.selectedOrganisationId;
    ref.listen(
      appStateProvider.select((state) => state.selectedOrganisationId),
      (previous, next) {
        if (previous != next) {
          _loadedOrganisationId = next;
          setState(() => _shiftsFuture = _loadShifts(next));
        }
      },
    );

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
          FutureBuilder<List<WorkShift>>(
            key: ValueKey(_loadedOrganisationId),
            future: _shiftsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Card(
                  child: ListTile(
                    title: Text(
                      'Could not load shift options: ${snapshot.error}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Retry loading shifts',
                      onPressed: () => setState(
                        () => _shiftsFuture = _loadShifts(organisationId),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return PaginatedList(
                items: employees,
                itemBuilder: (context, employee, index) =>
                    EmployeeCard(employee: employee, shifts: snapshot.data!),
              );
            },
          ),
        if (state.currentRole == EmployeeRole.owner ||
            state.currentRole == EmployeeRole.manager)
          ShiftsSection(
            onShiftsChanged: () {
              if (organisationId != null) {
                setState(() => _shiftsFuture = _loadShifts(organisationId));
              }
            },
          ),
      ],
    );
  }
}
