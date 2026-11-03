import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zone/core/utils/formatters.dart';
import 'package:zone/core/widgets/paginated_list.dart';
import 'package:zone/features/attendance/domain/attendance.dart';
import 'package:zone/features/employees/data/shifts_repository.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/features/employees/domain/work_shift.dart';
import 'package:zone/providers/app_state.dart';

class ShiftAttendanceGroups extends ConsumerStatefulWidget {
  const ShiftAttendanceGroups({
    super.key,
    required this.organisationId,
    required this.records,
    required this.employees,
  });

  final String organisationId;
  final List<AttendanceRecord> records;
  final List<Employee> employees;

  @override
  ConsumerState<ShiftAttendanceGroups> createState() =>
      ShiftAttendanceGroupsState();
}

class ShiftAttendanceGroupsState extends ConsumerState<ShiftAttendanceGroups> {
  late Future<List<WorkShift>> _shifts;

  @override
  void initState() {
    super.initState();
    _shifts = _loadShifts();
  }

  @override
  void didUpdateWidget(covariant ShiftAttendanceGroups oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organisationId != widget.organisationId) {
      _shifts = _loadShifts();
    }
  }

  Future<List<WorkShift>> _loadShifts() {
    return ref
        .read(shiftsRepositoryProvider)
        .shiftsForOrganisation(widget.organisationId);
  }

  Future<void> reload() async {
    final request = _loadShifts();
    setState(() {
      _shifts = request;
    });
    await request;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WorkShift>>(
      future: _shifts,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline_rounded),
              title: const Text('Could not load shifts.'),
              subtitle: Text('${snapshot.error}'),
              trailing: IconButton(
                tooltip: 'Retry loading shifts',
                onPressed: () => reload(),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        return _buildShiftGroups(context, snapshot.data!);
      },
    );
  }

  Widget _buildShiftGroups(BuildContext context, List<WorkShift> shifts) {
    final now = DateTime.now();
    final todayMinute = now.hour * 60 + now.minute;
    final currentShift = _currentShift(shifts, todayMinute);
    final grouped = <String, List<AttendanceRecord>>{
      for (final shift in shifts) shift.id: [],
    };
    final unassigned = <AttendanceRecord>[];

    for (final record in widget.records) {
      final employeeShiftId = widget.employees
          .where((employee) => employee.id == record.employeeId)
          .firstOrNull
          ?.shiftId;
      final groupId =
          record.shiftId ?? record.assignedShiftId ?? employeeShiftId;
      if (groupId == null || !grouped.containsKey(groupId)) {
        unassigned.add(record);
      } else {
        grouped[groupId]!.add(record);
      }
    }

    final orderedShifts = [...shifts]
      ..sort((first, second) {
        if (first.id == currentShift?.id) return -1;
        if (second.id == currentShift?.id) return 1;
        return first.startMinute.compareTo(second.startMinute);
      });

    if (orderedShifts.isEmpty) {
      return _unassignedSection(
        title: 'No shifts configured',
        records: unassigned,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final shift in orderedShifts)
          _ShiftAttendanceSection(
            shift: shift,
            badgeLabel: shift.id != currentShift?.id
                ? null
                : shift.containsClockInMinute(todayMinute)
                ? 'Current shift'
                : 'Next shift',
            records: grouped[shift.id]!,
            employees: widget.employees,
          ),
        if (unassigned.isNotEmpty)
          _unassignedSection(title: 'Unassigned shift', records: unassigned),
      ],
    );
  }

  WorkShift? _currentShift(List<WorkShift> shifts, int minuteOfDay) {
    if (shifts.isEmpty) return null;
    for (final shift in shifts) {
      if (shift.containsClockInMinute(minuteOfDay)) return shift;
    }
    final upcoming =
        shifts.where((shift) => shift.startMinute > minuteOfDay).toList()..sort(
          (first, second) => first.startMinute.compareTo(second.startMinute),
        );
    if (upcoming.isNotEmpty) return upcoming.first;
    return shifts.reduce(
      (first, second) =>
          first.startMinute <= second.startMinute ? first : second,
    );
  }

  Widget _unassignedSection({
    required String title,
    required List<AttendanceRecord> records,
  }) {
    return _ShiftAttendanceSection.unassigned(
      title: title,
      records: records,
      employees: widget.employees,
    );
  }
}

class _ShiftAttendanceSection extends StatelessWidget {
  const _ShiftAttendanceSection({
    required this.shift,
    required this.badgeLabel,
    required this.records,
    required this.employees,
  }) : title = null;

  const _ShiftAttendanceSection.unassigned({
    required this.title,
    required this.records,
    required this.employees,
  }) : shift = null,
       badgeLabel = null;

  final WorkShift? shift;
  final String? title;
  final String? badgeLabel;
  final List<AttendanceRecord> records;
  final List<Employee> employees;

  @override
  Widget build(BuildContext context) {
    final label = title ?? shift!.name;
    final time = shift == null
        ? null
        : '${shift!.startTimeLabel} – ${shift!.endTimeLabel}';
    return Card(
      key: Key('attendance-group-${shift?.id ?? 'unassigned'}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (time != null)
                        Text(
                          time,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (badgeLabel != null)
                  Chip(
                    label: Text(badgeLabel!),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text('No attendance records for this shift.'),
            )
          else
            PaginatedList(
              items: records,
              itemBuilder: (context, record, index) => _ShiftAttendanceTile(
                record: record,
                clockedShiftName: record.shiftName,
                assignedShiftName: record.assignedShiftName,
                employeeName:
                    employees
                        .where((employee) => employee.id == record.employeeId)
                        .firstOrNull
                        ?.name ??
                    'Employee',
              ),
            ),
        ],
      ),
    );
  }
}

class _ShiftAttendanceTile extends ConsumerStatefulWidget {
  const _ShiftAttendanceTile({
    required this.record,
    required this.clockedShiftName,
    required this.assignedShiftName,
    required this.employeeName,
  });

  final AttendanceRecord record;
  final String? clockedShiftName;
  final String? assignedShiftName;
  final String employeeName;

  @override
  ConsumerState<_ShiftAttendanceTile> createState() =>
      _ShiftAttendanceTileState();
}

class _ShiftAttendanceTileState extends ConsumerState<_ShiftAttendanceTile> {
  bool _isReviewing = false;

  Future<void> _review(bool approve) async {
    setState(() => _isReviewing = true);
    try {
      await ref
          .read(appStateProvider.notifier)
          .reviewAttendanceRecord(
            attendanceId: widget.record.id,
            approve: approve,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Attendance approved.' : 'Attendance rejected.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not review attendance: $error')),
      );
    } finally {
      if (mounted) setState(() => _isReviewing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final clockOut = record.clockOut == null
        ? 'Not clocked out'
        : formatDateTime(record.clockOut!);
    final pending = record.approvalStatus == 'pending';
    final shiftSummary = widget.assignedShiftName == null
        ? 'Clocked in during ${widget.clockedShiftName ?? 'an unassigned shift'}'
        : widget.assignedShiftName == widget.clockedShiftName
        ? 'Assigned shift: ${widget.assignedShiftName}'
        : 'Assigned: ${widget.assignedShiftName} · Clocked in during: ${widget.clockedShiftName ?? 'outside a scheduled shift'}';
    return Column(
      children: [
        ListTile(
          title: Text(widget.employeeName),
          subtitle: Text(
            '$shiftSummary\n'
            'Clock-in: ${formatDateTime(record.clockIn)}\n'
            'Clock-out: $clockOut',
          ),
          isThreeLine: true,
          trailing: Text(
            pending ? 'Needs approval' : record.approvalStatus,
            style: TextStyle(
              color: pending ? Theme.of(context).colorScheme.error : null,
              fontWeight: pending ? FontWeight.w600 : null,
            ),
          ),
          minVerticalPadding: 12,
        ),
        if (pending)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 16,
              end: 16,
              bottom: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isReviewing ? null : () => _review(false),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isReviewing ? null : () => _review(true),
                  child: _isReviewing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Approve'),
                ),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}
