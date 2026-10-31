import 'package:flutter/material.dart';
import 'package:zone/core/utils/formatters.dart';
import 'package:zone/features/attendance/domain/attendance.dart';

class AttendanceCard extends StatelessWidget {
  const AttendanceCard({super.key, required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final clockIn = record.clockIn.toLocal();
    final clockOut = record.clockOut?.toLocal();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('Shift ${formatDate(record.date)}'),
        subtitle: Text(
          '${clockIn.hour.toString().padLeft(2, '0')}:${clockIn.minute.toString().padLeft(2, '0')} - '
          '${clockOut?.hour.toString().padLeft(2, '0') ?? '--'}:${clockOut?.minute.toString().padLeft(2, '0') ?? '--'}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formatDuration(record.duration),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(record.status, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
