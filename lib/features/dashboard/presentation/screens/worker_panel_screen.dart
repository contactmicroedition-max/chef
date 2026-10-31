import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zone/core/utils/formatters.dart';
import 'package:zone/features/attendance/domain/attendance.dart';
import 'package:zone/features/dashboard/presentation/widgets/attendance_calendar.dart';
import 'package:zone/features/dashboard/presentation/widgets/employee_attendance_tables.dart';
import 'package:zone/features/dashboard/presentation/widgets/metric_card.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/providers/app_state.dart';

class WorkerPanelScreen extends ConsumerStatefulWidget {
  const WorkerPanelScreen({super.key});

  @override
  ConsumerState<WorkerPanelScreen> createState() => _WorkerPanelScreenState();
}

class _WorkerPanelScreenState extends ConsumerState<WorkerPanelScreen> {
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final employeeId = state.currentEmployeeId;
    final employee = state.employees
        .where((item) => item.id == employeeId)
        .firstOrNull;
    final now = DateTime.now();
    final attendance =
        state.attendance
            .where((record) => record.employeeId == employeeId)
            .toList()
          ..sort((first, second) => second.date.compareTo(first.date));
    final monthRecords = attendance
        .where(
          (record) =>
              record.date.year == now.year && record.date.month == now.month,
        )
        .toList();
    final selectedDayRecords =
        attendance
            .where((record) => DateUtils.isSameDay(record.date, _selectedDate))
            .toList()
          ..sort((first, second) => first.clockIn.compareTo(second.clockIn));
    final advances =
        state.advances
            .where((advance) => advance.employeeId == employeeId)
            .toList()
          ..sort(
            (first, second) => second.requestedAt.compareTo(first.requestedAt),
          );
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
    final hours = monthRecords.fold<double>(
      0,
      (sum, record) => sum + record.hours,
    );
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
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
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
            ],
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
                  title: Text('${attendance.length} attendance records'),
                  subtitle: Text(
                    'Advances this month: ${formatCurrency(currentMonthAdvances, currency: currency)}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Attendance calendar',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          AttendanceCalendar(
            records: attendance,
            selectedDate: _selectedDate,
            onSelected: (date) => setState(() => _selectedDate = date),
          ),
          const SizedBox(height: 8),
          _SelectedDayAttendance(
            date: _selectedDate,
            records: selectedDayRecords,
          ),
          const SizedBox(height: 20),
          Text(
            'Advance history',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          AdvanceHistoryTable(advances: advances, currency: currency),
          const SizedBox(height: 20),
          Text(
            'Attendance history',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          EmployeeAttendanceTable(records: attendance),
        ],
      ],
    );
  }
}

class _SelectedDayAttendance extends StatelessWidget {
  const _SelectedDayAttendance({required this.date, required this.records});

  final DateTime date;
  final List<AttendanceRecord> records;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatDate(date),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (records.isEmpty)
              const Text('No attendance recorded for this day.')
            else
              for (final record in records) ...[
                Row(
                  children: [
                    const Icon(Icons.login_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Clock in: ${formatDateTime(record.clockIn)}'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      record.clockOut == null
                          ? Icons.hourglass_top_rounded
                          : Icons.logout_rounded,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      record.clockOut == null
                          ? 'Clock out: Not recorded'
                          : 'Clock out: ${formatDateTime(record.clockOut!)}',
                    ),
                  ],
                ),
                if (records.last != record) const Divider(height: 20),
              ],
          ],
        ),
      ),
    );
  }
}
