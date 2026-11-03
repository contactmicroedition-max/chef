import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zone/features/employees/domain/work_shift.dart';
import 'package:zone/features/employees/presentation/dialogs/employee_shift_dialog.dart';

void main() {
  testWidgets('returns the selected shift assignment', (tester) async {
    const shift = WorkShift(
      id: 'shift-1',
      organisationId: 'organisation-1',
      name: 'Morning',
      startMinute: 8 * 60,
      endMinute: 16 * 60,
    );
    EmployeeShiftSelection? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<EmployeeShiftSelection>(
                  context: context,
                  builder: (_) => const EmployeeShiftDialog(
                    shifts: [shift],
                    currentShiftId: null,
                    employeeName: 'Alex',
                  ),
                );
              },
              child: const Text('Assign'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Assign'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Morning (08:00–16:00)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result?.shiftId, 'shift-1');
  });

  testWidgets('allows removing an employee shift assignment', (tester) async {
    const shift = WorkShift(
      id: 'shift-1',
      organisationId: 'organisation-1',
      name: 'Morning',
      startMinute: 8 * 60,
      endMinute: 16 * 60,
    );
    EmployeeShiftSelection? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<EmployeeShiftSelection>(
                  context: context,
                  builder: (_) => const EmployeeShiftDialog(
                    shifts: [shift],
                    currentShiftId: 'shift-1',
                    employeeName: 'Alex',
                  ),
                );
              },
              child: const Text('Change'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No shift').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.shiftId, isNull);
  });
}
