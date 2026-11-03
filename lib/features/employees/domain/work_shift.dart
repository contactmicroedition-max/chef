class WorkShift {
  const WorkShift({
    required this.id,
    required this.organisationId,
    required this.name,
    required this.startMinute,
    required this.endMinute,
  });

  final String id;
  final String organisationId;
  final String name;
  final int startMinute;
  final int endMinute;

  int get durationMinutes => endMinute - startMinute;

  String get startTimeLabel => _formatTime(startMinute);
  String get endTimeLabel => _formatTime(endMinute);

  bool containsClockInMinute(int minuteOfDay, {int gracePeriodMinutes = 0}) {
    final startWithGrace = startMinute - gracePeriodMinutes;
    final endWithGrace = endMinute + gracePeriodMinutes;
    return minuteOfDay >= startWithGrace && minuteOfDay <= endWithGrace ||
        startWithGrace < 0 && minuteOfDay >= 24 * 60 + startWithGrace ||
        endWithGrace >= 24 * 60 && minuteOfDay <= endWithGrace - 24 * 60;
  }

  static String? validateSchedule(Iterable<WorkShift> shifts) {
    var totalMinutes = 0;
    for (final shift in shifts) {
      if (shift.name.trim().isEmpty) return 'Enter a shift name.';
      if (shift.startMinute < 0 ||
          shift.startMinute >= 24 * 60 ||
          shift.endMinute < 0 ||
          shift.endMinute >= 24 * 60 ||
          shift.endMinute <= shift.startMinute) {
        return 'Each shift must end later on the same day than it starts.';
      }
      totalMinutes += shift.durationMinutes;
    }
    if (totalMinutes > 24 * 60) {
      return 'The total duration of all shifts cannot exceed 24 hours.';
    }
    return null;
  }

  static WorkShift fromRow(Map<String, dynamic> row) {
    return WorkShift(
      id: row['id'] as String,
      organisationId: row['organisation_id'] as String,
      name: row['name'] as String,
      startMinute: _parseTime(row['start_time'] as String),
      endMinute: _parseTime(row['end_time'] as String),
    );
  }

  static int _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length < 2) {
      throw FormatException('Invalid shift time: $value');
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw FormatException('Invalid shift time: $value');
    }
    return hour * 60 + minute;
  }

  static String _formatTime(int minuteOfDay) {
    final hour = (minuteOfDay ~/ 60).toString().padLeft(2, '0');
    final minute = (minuteOfDay % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
