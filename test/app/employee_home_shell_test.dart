import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zone/app/home_shell.dart';
import 'package:zone/features/dashboard/presentation/screens/worker_panel_screen.dart';
import 'package:zone/features/employees/domain/employee.dart';
import 'package:zone/features/organisations/domain/organisation.dart';
import 'package:zone/providers/app_state.dart';

void main() {
  setUpAll(initializeDateFormatting);

  testWidgets(
    'employee home index shows panel under organisation title while loading',
    (tester) async {
      const state = AppState(
        isLoading: true,
        organisations: [
          Organisation(
            id: 'org-1',
            name: 'Test Organisation',
            currency: 'TND',
            timezone: 'Africa/Tunis',
            ownerId: 'owner-1',
          ),
        ],
        selectedOrganisationId: 'org-1',
        currentRole: EmployeeRole.employee,
        currentEmployeeId: 'employee-1',
        employees: [
          Employee(
            id: 'employee-1',
            organisationId: 'org-1',
            name: 'Test Employee',
            jobTitle: 'Cook',
            hourlyRate: 10,
            role: EmployeeRole.employee,
            employmentStatus: EmploymentStatus.active,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStateProvider.overrideWith(() => _TestAppStateNotifier(state)),
          ],
          child: const MaterialApp(home: HomeShellScreen()),
        ),
      );

      expect(find.text('Test Organisation'), findsOneWidget);
      expect(find.text('My employee panel'), findsOneWidget);
      final employeePanelList = find.descendant(
        of: find.byType(WorkerPanelScreen),
        matching: find.byType(ListView),
      );
      await tester.drag(employeePanelList, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Attendance calendar'), findsOneWidget);
      for (var index = 0;
          index < 5 && find.text('Advance history').evaluate().isEmpty;
          index++) {
        await tester.drag(employeePanelList, const Offset(0, -600));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Advance history'), findsOneWidget);
      for (var index = 0;
          index < 5 && find.text('Attendance history').evaluate().isEmpty;
          index++) {
        await tester.drag(employeePanelList, const Offset(0, -600));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Attendance history'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    },
  );
}

class _TestAppStateNotifier extends AppStateNotifier {
  _TestAppStateNotifier(this._initialState);

  final AppState _initialState;

  @override
  AppState build() => _initialState;
}
