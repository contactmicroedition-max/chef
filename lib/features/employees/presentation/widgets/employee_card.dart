import 'package:flutter/material.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/features/employees/presentation/dialogs/give_advance_dialog.dart';

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
