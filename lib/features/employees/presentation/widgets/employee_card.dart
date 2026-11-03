import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zone/core/widgets/widgets.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/features/employees/domain/work_shift.dart';
import 'package:zone/features/employees/presentation/dialogs/employee_shift_dialog.dart';
import 'package:zone/features/employees/presentation/dialogs/give_advance_dialog.dart';
import 'package:zone/providers/app_state.dart';

class EmployeeCard extends ConsumerWidget {
  const EmployeeCard({super.key, required this.employee, required this.shifts});

  final Employee employee;
  final List<WorkShift> shifts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final canManage =
        state.currentRole == EmployeeRole.owner ||
        state.currentRole == EmployeeRole.manager;
    final assignedShift = shifts
        .where((shift) => shift.id == employee.shiftId)
        .firstOrNull;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            leading: EmployeeAvatar(name: employee.name),
            title: Text(employee.name),
            subtitle: Text(
              '${employee.jobTitle} • ${employee.loginEmail ?? 'Legacy ID ${employee.loginId ?? ""}'}'
              '${assignedShift == null ? '\nNo shift assigned' : '\n${assignedShift.name}: ${assignedShift.startTimeLabel}–${assignedShift.endTimeLabel}'}',
            ),
            trailing: Chip(label: Text(employee.employmentStatus.name)),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (canManage)
                  TextButton.icon(
                    onPressed: () => _assignShift(context, ref),
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(
                      assignedShift == null ? 'Assign shift' : 'Change shift',
                    ),
                  ),
                if (canManage &&
                    employee.employmentStatus == EmploymentStatus.active)
                  TextButton.icon(
                    onPressed: () => _archiveEmployee(context, ref),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Archive'),
                  ),
                TextButton.icon(
                  onPressed:
                      employee.employmentStatus == EmploymentStatus.active
                      ? () => showDialog<void>(
                          context: context,
                          builder: (_) => GiveAdvanceDialog(employee: employee),
                        )
                      : null,
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('Give advance'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assignShift(BuildContext context, WidgetRef ref) async {
    final selection = await showDialog<EmployeeShiftSelection>(
      context: context,
      builder: (context) => EmployeeShiftDialog(
        shifts: shifts,
        currentShiftId: employee.shiftId,
        employeeName: employee.name,
      ),
    );
    if (selection == null || !context.mounted) return;
    try {
      await ref
          .read(appStateProvider.notifier)
          .assignEmployeeShift(
            employeeId: employee.id,
            shiftId: selection.shiftId,
          );
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _archiveEmployee(BuildContext context, WidgetRef ref) async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive employee?'),
        content: Text(
          'Archive ${employee.name}? Their attendance and payroll history will be preserved, but they will no longer be able to clock in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (shouldArchive != true || !context.mounted) return;
    try {
      await ref.read(appStateProvider.notifier).archiveEmployee(employee.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Employee archived.')));
      }
    } catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not update employee: $error')),
    );
  }
}
