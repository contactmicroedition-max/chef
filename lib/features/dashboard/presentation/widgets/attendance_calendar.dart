import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zone/features/attendance/domain/attendance.dart';

class AttendanceCalendar extends StatefulWidget {
  const AttendanceCalendar({
    super.key,
    required this.records,
    required this.selectedDate,
    required this.onSelected,
  });

  final List<AttendanceRecord> records;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  State<AttendanceCalendar> createState() => _AttendanceCalendarState();
}

class _AttendanceCalendarState extends State<AttendanceCalendar> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + offset,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final localizations = MaterialLocalizations.of(context);
    final monthStart = DateTime(_displayedMonth.year, _displayedMonth.month);
    final leadingDays =
        (monthStart.weekday - 1 - localizations.firstDayOfWeekIndex) % 7;
    final daysInMonth = DateUtils.getDaysInMonth(
      _displayedMonth.year,
      _displayedMonth.month,
    );
    final attendanceDays = widget.records
        .map((record) => DateUtils.dateOnly(record.date.toLocal()))
        .toSet();
    final headers = List.generate(7, (index) {
      final weekday = (localizations.firstDayOfWeekIndex + index) % 7;
      final date = DateTime(2024, 1, 7 + weekday);
      return DateFormat.E(locale).format(date);
    });
    final cellCount = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    DateFormat.yMMMM(locale).format(_displayedMonth),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Row(
              children: [
                for (final header in headers)
                  Expanded(
                    child: Center(
                      child: Text(
                        header,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var row = 0; row < cellCount ~/ 7; row++)
              Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child: _buildDayCell(
                        context,
                        row * 7 + column - leadingDays + 1,
                        daysInMonth,
                        attendanceDays,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('Attendance recorded'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    int day,
    int daysInMonth,
    Set<DateTime> attendanceDays,
  ) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 42);
    final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
    final selected = DateUtils.isSameDay(
      date,
      DateUtils.dateOnly(widget.selectedDate),
    );
    final hasAttendance = attendanceDays.contains(date);
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => widget.onSelected(date),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: selected ? colors.primary : null,
            shape: BoxShape.circle,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  color: selected ? colors.onPrimary : null,
                  fontWeight: selected ? FontWeight.bold : null,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: hasAttendance
                      ? selected
                            ? colors.onPrimary
                            : colors.primary
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
