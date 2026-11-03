import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zone/core/utils/formatters.dart';
import 'package:zone/features/attendance/domain/attendance.dart';
import 'package:zone/features/attendance/presentation/widgets/shift_attendance_groups.dart';
import 'package:zone/features/employees/data/shifts_repository.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/features/employees/domain/work_shift.dart';

class _FakeShiftsRepository implements ShiftsRepository {
  @override
  Future<List<WorkShift>> shiftsForOrganisation(String organisationId) async {
    return const [
      WorkShift(
        id: 'current-shift',
        organisationId: 'organisation-1',
        name: 'Current shift',
        startMinute: 0,
        endMinute: 1439,
      ),
      WorkShift(
        id: 'assigned-shift',
        organisationId: 'organisation-1',
        name: 'Assigned shift',
        startMinute: 0,
        endMinute: 1,
      ),
    ];
  }

  @override
  Future<void> createShift({
    required String organisationId,
    required String name,
    required int startMinute,
    required int endMinute,
  }) async {}

  @override
  Future<void> updateShift({
    required String organisationId,
    required WorkShift shift,
  }) async {}

  @override
  Future<void> deleteShift({
    required String organisationId,
    required String shiftId,
  }) async {}
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  testWidgets(
    'today pending clock-in appears under current shift for approval',
    (tester) async {
      final now = DateTime.now();
      final pendingRecord = AttendanceRecord(
        id: 'attendance-1',
        employeeId: 'employee-1',
        organisationId: 'organisation-1',
        date: DateTime(now.year, now.month, now.day),
        clockIn: now,
        clockOut: null,
        approvalStatus: 'pending',
        shiftId: 'current-shift',
        assignedShiftId: 'assigned-shift',
        shiftName: 'Night',
        assignedShiftName: 'Morning',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shiftsRepositoryProvider.overrideWithValue(_FakeShiftsRepository()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ShiftAttendanceGroups(
                organisationId: 'organisation-1',
                records: [pendingRecord],
                employees: const [
                  Employee(
                    id: 'employee-1',
                    organisationId: 'organisation-1',
                    name: 'Employee',
                    jobTitle: 'Worker',
                    hourlyRate: 1,
                    role: EmployeeRole.employee,
                    employmentStatus: EmploymentStatus.active,
                    shiftId: 'assigned-shift',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final currentShiftGroup = find.byKey(
        const Key('attendance-group-current-shift'),
      );
      expect(currentShiftGroup, findsOneWidget);
      expect(
        find.descendant(of: currentShiftGroup, matching: find.text('Employee')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: currentShiftGroup,
          matching: find.text(
            'Assigned: Morning · Clocked in during: Night\n'
            'Clock-in: ${formatDateTime(now)}\n'
            'Clock-out: Not clocked out',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: currentShiftGroup,
          matching: find.widgetWithText(FilledButton, 'Approve'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('attendance-group-assigned-shift')),
          matching: find.text('No attendance records for this shift.'),
        ),
        findsOneWidget,
      );

      await tester
          .state<ShiftAttendanceGroupsState>(find.byType(ShiftAttendanceGroups))
          .reload();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
