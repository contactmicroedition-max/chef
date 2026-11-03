import 'package:flutter/material.dart';
import 'package:zone/features/employees/domain/work_shift.dart';

class EmployeeShiftSelection {
  const EmployeeShiftSelection(this.shiftId);

  final String? shiftId;
}

class EmployeeShiftDialog extends StatefulWidget {
  const EmployeeShiftDialog({
    super.key,
    required this.shifts,
    required this.currentShiftId,
    required this.employeeName,
  });

  final List<WorkShift> shifts;
  final String? currentShiftId;
  final String employeeName;

  @override
  State<EmployeeShiftDialog> createState() => _EmployeeShiftDialogState();
}

class _EmployeeShiftDialogState extends State<EmployeeShiftDialog> {
  static const _noShift = '';
  late String _selectedShiftId;

  @override
  void initState() {
    super.initState();
    _selectedShiftId = widget.currentShiftId ?? _noShift;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign shift to ${widget.employeeName}'),
      content: DropdownButtonFormField<String>(
        initialValue: _selectedShiftId,
        decoration: const InputDecoration(labelText: 'Shift'),
        items: [
          const DropdownMenuItem(value: _noShift, child: Text('No shift')),
          ...widget.shifts.map(
            (shift) => DropdownMenuItem(
              value: shift.id,
              child: Text(
                '${shift.name} (${shift.startTimeLabel}–${shift.endTimeLabel})',
              ),
            ),
          ),
        ],
        onChanged: (value) {
          if (value != null) setState(() => _selectedShiftId = value);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            EmployeeShiftSelection(
              _selectedShiftId == _noShift ? null : _selectedShiftId,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
