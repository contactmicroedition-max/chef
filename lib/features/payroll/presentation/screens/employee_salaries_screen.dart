import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zone/core/utils/formatters.dart';
import 'package:zone/core/widgets/widgets.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/providers/app_state.dart';

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
        PaginatedList(
          items: state.employees,
          itemBuilder: (context, employee, index) {
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
              key: ValueKey(employee.id),
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: EmployeeAvatar(name: employee.name),
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
                  PaginatedList(
                    key: ValueKey('advances-${employee.id}'),
                    items: employeeAdvances,
                    emptyBuilder: (context) => const ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('No advances recorded.'),
                    ),
                    itemBuilder: (context, advance, index) => ListTile(
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
          },
        ),
      ],
    );
  }
}
