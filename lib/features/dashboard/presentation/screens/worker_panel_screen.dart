import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zone/core/utils/formatters.dart';
import 'package:zone/features/dashboard/presentation/widgets/metric_card.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/providers/app_state.dart';

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
          MetricCard(
            title: 'Hours recorded',
            value: '${hours.toStringAsFixed(1)}h',
            icon: Icons.access_time_rounded,
          ),
          MetricCard(
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
