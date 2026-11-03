import 'package:flutter_test/flutter_test.dart';
import 'package:zone/features/employees/domain/work_shift.dart';

WorkShift shift(String id, int startMinute, int endMinute) {
  return WorkShift(
    id: id,
    organisationId: 'organisation-1',
    name: id,
    startMinute: startMinute,
    endMinute: endMinute,
  );
}

void main() {
  group('WorkShift.validateSchedule', () {
    test('allows a schedule totaling exactly 24 hours', () {
      expect(
        WorkShift.validateSchedule([
          shift('first', 0, 8 * 60),
          shift('second', 8 * 60, 16 * 60),
          shift('third', 0, 8 * 60),
        ]),
        isNull,
      );
    });

    test('rejects a schedule whose total is over 24 hours', () {
      expect(
        WorkShift.validateSchedule([
          shift('first', 0, 8 * 60),
          shift('second', 8 * 60, 16 * 60),
          shift('third', 0, 8 * 60),
          shift('extra', 0, 1),
        ]),
        'The total duration of all shifts cannot exceed 24 hours.',
      );
    });

    test('rejects same-day shifts that end at or before their start', () {
      expect(
        WorkShift.validateSchedule([shift('overnight', 22 * 60, 6 * 60)]),
        'Each shift must end later on the same day than it starts.',
      );
      expect(
        WorkShift.validateSchedule([shift('zero-length', 8 * 60, 8 * 60)]),
        'Each shift must end later on the same day than it starts.',
      );
    });
  });

  test('reads and formats database time values', () {
    final parsed = WorkShift.fromRow({
      'id': 'shift-1',
      'organisation_id': 'organisation-1',
      'name': 'Morning',
      'start_time': '08:30:00',
      'end_time': '16:45:00',
    });

    expect(parsed.startMinute, 8 * 60 + 30);
    expect(parsed.endMinute, 16 * 60 + 45);
    expect(parsed.startTimeLabel, '08:30');
    expect(parsed.endTimeLabel, '16:45');
    expect(parsed.durationMinutes, 8 * 60 + 15);
  });

  test('clock-in window includes the five-minute grace at both ends', () {
    final morning = shift('morning', 8 * 60, 16 * 60);
    expect(
      morning.containsClockInMinute(7 * 60 + 55, gracePeriodMinutes: 5),
      isTrue,
    );
    expect(
      morning.containsClockInMinute(16 * 60 + 5, gracePeriodMinutes: 5),
      isTrue,
    );
    expect(
      morning.containsClockInMinute(7 * 60 + 54, gracePeriodMinutes: 5),
      isFalse,
    );
    expect(
      morning.containsClockInMinute(16 * 60 + 6, gracePeriodMinutes: 5),
      isFalse,
    );
  });

  test('clock-in grace wraps at midnight', () {
    final early = shift('early', 2, 8 * 60);
    final late = shift('late', 16 * 60, 1438);
    expect(early.containsClockInMinute(1437, gracePeriodMinutes: 5), isTrue);
    expect(late.containsClockInMinute(2, gracePeriodMinutes: 5), isTrue);
  });
}
