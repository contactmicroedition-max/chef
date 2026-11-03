import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zone/features/attendance/domain/attendance.dart';
import 'package:zone/features/dashboard/presentation/widgets/attendance_calendar.dart';
import 'package:zone/features/dashboard/presentation/widgets/employee_attendance_tables.dart';
import 'package:zone/features/payroll/domain/payroll.dart';

void main() {
  setUpAll(initializeDateFormatting);

  testWidgets('calendar selects a date containing attendance', (tester) async {
    final record = AttendanceRecord(
      id: 'attendance-1',
      employeeId: 'employee-1',
      organisationId: 'organisation-1',
      date: DateTime(2026, 10, 14),
      clockIn: DateTime(2026, 10, 14, 8),
      clockOut: DateTime(2026, 10, 14, 16),
    );
    DateTime? selectedDate;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttendanceCalendar(
            records: [record],
            selectedDate: DateTime(2026, 10, 14),
            onSelected: (date) => selectedDate = date,
          ),
        ),
      ),
    );

    await tester.tap(find.text('14').first);
    expect(selectedDate, DateTime(2026, 10, 14));
  });

  testWidgets(
    'calendar marks days red only for two distinct fully approved shifts',
    (tester) async {
      AttendanceRecord record({
        required int day,
        required String id,
        required String shiftId,
        String approvalStatus = 'approved',
      }) {
        return AttendanceRecord(
          id: id,
          employeeId: 'employee-1',
          organisationId: 'organisation-1',
          date: DateTime(2026, 10, day),
          clockIn: DateTime(2026, 10, day, 8),
          clockOut: DateTime(2026, 10, day, 16),
          shiftId: shiftId,
          approvalStatus: approvalStatus,
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceCalendar(
              records: [
                record(day: 14, id: 'approved-1', shiftId: 'morning'),
                record(day: 14, id: 'approved-2', shiftId: 'evening'),
                record(day: 15, id: 'pending-1', shiftId: 'morning'),
                record(
                  day: 15,
                  id: 'pending-2',
                  shiftId: 'evening',
                  approvalStatus: 'pending',
                ),
                record(day: 16, id: 'same-shift-1', shiftId: 'morning'),
                record(day: 16, id: 'same-shift-2', shiftId: 'morning'),
              ],
              selectedDate: DateTime(2026, 10, 1),
              onSelected: (_) {},
            ),
          ),
        ),
      );

      final onError = ThemeData().colorScheme.onError;
      expect(tester.widget<Text>(find.text('14')).style?.color, onError);
      expect(tester.widget<Text>(find.text('15')).style?.color, isNull);
      expect(tester.widget<Text>(find.text('16')).style?.color, isNull);
      expect(find.text('Two approved shifts'), findsOneWidget);
    },
  );

  testWidgets('advance table paginates at ten rows', (tester) async {
    final advances = List.generate(
      11,
      (index) => SalaryAdvance(
        id: 'advance-$index',
        employeeId: 'employee-1',
        organisationId: 'organisation-1',
        amount: 10 + index.toDouble(),
        requestedAt: DateTime(2026, 10, 1 + index),
        status: 'paid',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdvanceHistoryTable(advances: advances, currency: 'TND'),
        ),
      ),
    );

    expect(find.text('0–10 of 11'), findsOneWidget);
    expect(find.text('paid'), findsNWidgets(10));

    await tester.tap(find.byTooltip('Next advances'));
    await tester.pumpAndSettle();

    expect(find.text('10–11 of 11'), findsOneWidget);
    expect(find.text('paid'), findsOneWidget);
  });

  testWidgets('attendance table paginates at ten rows', (tester) async {
    final records = List.generate(
      11,
      (index) => AttendanceRecord(
        id: 'attendance-$index',
        employeeId: 'employee-1',
        organisationId: 'organisation-1',
        date: DateTime(2026, 10, 1 + index),
        clockIn: DateTime(2026, 10, 1 + index, 8),
        clockOut: DateTime(2026, 10, 1 + index, 16),
        approvalStatus: 'shift-$index',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EmployeeAttendanceTable(records: records)),
      ),
    );

    expect(find.text('0–10 of 11'), findsOneWidget);
    expect(find.text('shift-0'), findsOneWidget);
    expect(find.text('shift-10'), findsNothing);

    await tester.tap(find.byTooltip('Next attendance'));
    await tester.pumpAndSettle();

    expect(find.text('10–11 of 11'), findsOneWidget);
    expect(find.text('shift-10'), findsOneWidget);
    expect(find.text('shift-0'), findsNothing);
  });
}
