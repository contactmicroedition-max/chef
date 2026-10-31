import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zone/core/utils/formatters.dart';
import 'package:zone/features/dashboard/presentation/widgets/metric_card.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/providers/app_state.dart';

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
            MetricCard(
              title: 'Active employees',
              value: '$activeEmployees',
              icon: Icons.people_alt_rounded,
            ),
            MetricCard(
              title: 'Currently working',
              value: '$openShifts',
              icon: Icons.work_rounded,
            ),
            MetricCard(
              title: 'Hours this month',
              value: '${totalHours.toStringAsFixed(1)}h',
              icon: Icons.access_time_rounded,
            ),
            MetricCard(
              title: 'Advances this month',
              value: formatCurrency(thisMonthAdvances, currency: currency),
              icon: Icons.money_off_rounded,
            ),
            MetricCard(
              title: 'Payments this month',
              value: formatCurrency(thisMonthPayments, currency: currency),
              icon: Icons.payment_rounded,
            ),
            MetricCard(
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
