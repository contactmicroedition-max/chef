import 'package:flutter/material.dart';
import 'package:zone/core/utils/formatters.dart';
import 'package:zone/features/attendance/domain/attendance.dart';
import 'package:zone/features/payroll/domain/payroll.dart';

class AdvanceHistoryTable extends StatefulWidget {
  const AdvanceHistoryTable({
    super.key,
    required this.advances,
    required this.currency,
  });

  final List<SalaryAdvance> advances;
  final String currency;

  @override
  State<AdvanceHistoryTable> createState() => _AdvanceHistoryTableState();
}

class _AdvanceHistoryTableState extends State<AdvanceHistoryTable> {
  static const _rowsPerPage = 10;
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant AdvanceHistoryTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lastPage = widget.advances.isEmpty
        ? 0
        : (widget.advances.length - 1) ~/ _rowsPerPage;
    if (_currentPage > lastPage) _currentPage = lastPage;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.advances.isEmpty) {
      return const Card(
        child: ListTile(title: Text('No salary advances recorded yet.')),
      );
    }

    final start = _currentPage * _rowsPerPage;
    final pageItems = widget.advances.skip(start).take(_rowsPerPage).toList();
    final end = start + pageItems.length;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Amount')),
                DataColumn(label: Text('Status')),
              ],
              rows: pageItems
                  .map(
                    (advance) => DataRow(
                      cells: [
                        DataCell(Text(formatDateTime(advance.requestedAt))),
                        DataCell(
                          Text(
                            formatCurrency(
                              advance.amount,
                              currency: widget.currency,
                            ),
                          ),
                        ),
                        DataCell(Text(advance.status)),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('$start–$end of ${widget.advances.length}'),
                IconButton(
                  tooltip: 'Previous advances',
                  onPressed: _currentPage == 0
                      ? null
                      : () => setState(() => _currentPage--),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  tooltip: 'Next advances',
                  onPressed: end >= widget.advances.length
                      ? null
                      : () => setState(() => _currentPage++),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class EmployeeAttendanceTable extends StatefulWidget {
  const EmployeeAttendanceTable({super.key, required this.records});

  final List<AttendanceRecord> records;

  @override
  State<EmployeeAttendanceTable> createState() =>
      _EmployeeAttendanceTableState();
}

class _EmployeeAttendanceTableState extends State<EmployeeAttendanceTable> {
  static const _rowsPerPage = 10;
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant EmployeeAttendanceTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lastPage = widget.records.isEmpty
        ? 0
        : (widget.records.length - 1) ~/ _rowsPerPage;
    if (_currentPage > lastPage) _currentPage = lastPage;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.records.isEmpty) {
      return const Card(
        child: ListTile(title: Text('No attendance records yet.')),
      );
    }

    final start = _currentPage * _rowsPerPage;
    final pageItems = widget.records.skip(start).take(_rowsPerPage).toList();
    final end = start + pageItems.length;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Clock in')),
                DataColumn(label: Text('Clock out')),
                DataColumn(label: Text('Hours')),
                DataColumn(label: Text('Status')),
              ],
              rows: pageItems.map((record) {
                final clockIn = record.clockIn.toLocal();
                final clockOut = record.clockOut?.toLocal();
                return DataRow(
                  cells: [
                    DataCell(Text(formatDate(record.date.toLocal()))),
                    DataCell(Text(_formatTime(clockIn))),
                    DataCell(
                      Text(clockOut == null ? '—' : _formatTime(clockOut)),
                    ),
                    DataCell(Text(formatDuration(record.duration))),
                    DataCell(Text(record.status)),
                  ],
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('$start–$end of ${widget.records.length}'),
                IconButton(
                  tooltip: 'Previous attendance',
                  onPressed: _currentPage == 0
                      ? null
                      : () => setState(() => _currentPage--),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  tooltip: 'Next attendance',
                  onPressed: end >= widget.records.length
                      ? null
                      : () => setState(() => _currentPage++),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
