import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/features/employees/presentation/dialogs/add_employee_dialog.dart';
import 'package:zone/features/employees/presentation/widgets/employee_card.dart';
import 'package:zone/providers/app_state.dart';

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
