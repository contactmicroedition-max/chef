import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zone/core/utils/formatters.dart';
import 'package:zone/features/attendance/presentation/widgets/attendance_card.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/providers/app_state.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  bool _isRecording = false;

  Future<void> _recordShift(bool clockIn) async {
    setState(() => _isRecording = true);
    try {
      final notificationMessage = await ref
          .read(appStateProvider.notifier)
          .recordEmployeeShift(clockIn: clockIn);
      if (!mounted) return;
      final action = clockIn ? 'Clocked in' : 'Clocked out';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notificationMessage == null
                ? '$action successfully. The owner was notified.'
                : '$action successfully. $notificationMessage',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final employeeId = state.currentEmployeeId;
    final openShift = state.attendance
        .where(
          (record) =>
              record.employeeId == employeeId && record.clockOut == null,
        )
        .firstOrNull;

    // Filter attendance by role
    final records = state.currentRole == EmployeeRole.employee
        ? state.attendance.where((r) => r.employeeId == employeeId).toList()
        : state.attendance;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Attendance', style: Theme.of(context).textTheme.headlineSmall),
        if (state.currentRole == EmployeeRole.employee &&
            state.currentEmployeeId != null) ...[
          const SizedBox(height: 12),
          if (openShift != null)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.timer_rounded),
                    const SizedBox(width: 8),
                    Text('Shift started ${formatDateTime(openShift.clockIn)}'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _isRecording
                ? null
                : () => _recordShift(openShift == null),
            icon: Icon(
              openShift == null ? Icons.play_arrow_rounded : Icons.stop_rounded,
            ),
            label: Text(
              _isRecording
                  ? 'Recording…'
                  : openShift == null
                  ? 'Clock in'
                  : 'Clock out',
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (records.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No attendance records yet.'),
            ),
          )
        else
          ...records.map((record) => AttendanceCard(record: record)),
      ],
    );
  }
}
