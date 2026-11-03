import 'package:flutter/material.dart';
import 'package:zone/features/employees/domain/work_shift.dart';

class WorkShiftDialog extends StatefulWidget {
  const WorkShiftDialog({
    super.key,
    required this.organisationId,
    required this.shifts,
    this.initialShift,
  });

  final String organisationId;
  final List<WorkShift> shifts;
  final WorkShift? initialShift;

  @override
  State<WorkShiftDialog> createState() => _WorkShiftDialogState();
}

class _WorkShiftDialogState extends State<WorkShiftDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String? _scheduleError;

  @override
  void initState() {
    super.initState();
    final shift = widget.initialShift;
    _nameController = TextEditingController(text: shift?.name ?? '');
    _startTime = shift == null
        ? const TimeOfDay(hour: 8, minute: 0)
        : _timeOfDay(shift.startMinute);
    _endTime = shift == null
        ? const TimeOfDay(hour: 16, minute: 0)
        : _timeOfDay(shift.endMinute);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int get _startMinute => _startTime.hour * 60 + _startTime.minute;
  int get _endMinute => _endTime.hour * 60 + _endTime.minute;

  Future<void> _pickTime({required bool isStart}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startTime = selected;
      } else {
        _endTime = selected;
      }
      _scheduleError = null;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final candidate = WorkShift(
      id: widget.initialShift?.id ?? '',
      organisationId: widget.organisationId,
      name: _nameController.text.trim(),
      startMinute: _startMinute,
      endMinute: _endMinute,
    );
    final schedule = [
      ...widget.shifts.where((shift) => shift.id != candidate.id),
      candidate,
    ];
    final error = WorkShift.validateSchedule(schedule);
    if (error != null) {
      setState(() => _scheduleError = error);
      return;
    }
    Navigator.of(context).pop(candidate);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialShift == null ? 'Add shift' : 'Edit shift'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Shift name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a shift name.'
                    : null,
              ),
              const SizedBox(height: 12),
              _TimePickerTile(
                label: 'Start time',
                time: _startTime,
                onTap: () => _pickTime(isStart: true),
              ),
              _TimePickerTile(
                label: 'End time',
                time: _endTime,
                onTap: () => _pickTime(isStart: false),
              ),
              const SizedBox(height: 8),
              Text(
                'End time must be later than start time. Overnight shifts are not supported.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_scheduleError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _scheduleError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  TimeOfDay _timeOfDay(int minuteOfDay) {
    return TimeOfDay(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60);
  }
}

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: TextButton(onPressed: onTap, child: Text(time.format(context))),
    );
  }
}
