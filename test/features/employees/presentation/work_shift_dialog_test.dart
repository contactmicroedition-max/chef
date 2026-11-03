import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zone/features/employees/domain/work_shift.dart';
import 'package:zone/features/employees/presentation/dialogs/work_shift_dialog.dart';

void main() {
  testWidgets('rejects adding a shift that would exceed 24 total hours', (
    tester,
  ) async {
    final existingShifts = [
      WorkShift(
        id: 'existing',
        organisationId: 'organisation-1',
        name: 'Existing shift',
        startMinute: 0,
        endMinute: 17 * 60,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<WorkShift>(
                context: context,
                builder: (_) => WorkShiftDialog(
                  organisationId: 'organisation-1',
                  shifts: existingShifts,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'New shift');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      find.text('The total duration of all shifts cannot exceed 24 hours.'),
      findsOneWidget,
    );
    expect(find.byType(WorkShiftDialog), findsOneWidget);
  });
}
