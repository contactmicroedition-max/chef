import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zone/app/app.dart';
import 'package:zone/features/auth/domain/auth_formatters.dart';
import 'package:zone/features/employees/domain/employee.dart';

void main() {
  test('account IDs must contain exactly 8 digits', () {
    expect(cleanAccountId('95125268'), '95125268');
    expect(cleanAccountId('  95125268  '), '95125268');
    expect(() => cleanAccountId('1234'), throwsA(isA<FormatException>()));
    expect(() => cleanAccountId('12a45678'), throwsA(isA<FormatException>()));
  });

  test('employee ID is stored exactly as typed (no prefix logic)', () {
    expect(cleanEmployeeId('95125268'), '95125268');
    expect(cleanEmployeeId('  95125268  '), '95125268');
    expect(cleanEmployeeId('1234'), '1234');
    expect(() => cleanEmployeeId('ab'), throwsA(isA<FormatException>()));
  });

  test(
    'employee login emails are generated from names and can be suffixed',
    () {
      expect(
        employeeEmailAddress('John Smith', 'Tunis Cafe'),
        'john_smith@tunis-cafe.tn',
      );
      expect(
        employeeEmailAddress('John Smith', 'Tunis Cafe', suffix: 2),
        'john_smith2@tunis-cafe.tn',
      );
      expect(employeeEmailAddress('---', '---'), 'employee@organisation.tn');
      expect(cleanEmployeeEmail(' Worker@Tunis.tn '), 'worker@tunis.tn');
      expect(
        () => cleanEmployeeEmail('not an email'),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('Supabase login alias remains internal to the app', () {
    expect(accountLoginEmail('95125268'), 'id-95125268@chef.local');
    expect(loginIdFromAuthEmail('id-95125268@chef.local'), '95125268');
  });

  test('phone numbers are normalized for Supabase Auth', () {
    expect(normalizeAuthPhone('+216 95 125 268'), '+21695125268');
    expect(normalizeAuthPhone('95125268'), '+21695125268');
    expect(normalizeAuthPhone('0021612345678'), '+21612345678');
    expect(() => normalizeAuthPhone('123'), throwsA(isA<FormatException>()));
  });

  test('monthly salary is independent of recorded hours', () {
    const employee = Employee(
      id: 'employee',
      organisationId: 'organisation',
      name: 'Monthly employee',
      jobTitle: 'Cook',
      hourlyRate: 0,
      payType: EmployeePayType.monthly,
      monthlySalary: 1200,
      role: EmployeeRole.employee,
      employmentStatus: EmploymentStatus.active,
    );

    expect(employee.salaryForHours(0), 1200);
    expect(employee.salaryForHours(200), 1200);
  });

  test('hourly salary follows the hours worked', () {
    const employee = Employee(
      id: 'employee',
      organisationId: 'organisation',
      name: 'Hourly employee',
      jobTitle: 'Cook',
      hourlyRate: 10,
      role: EmployeeRole.employee,
      employmentStatus: EmploymentStatus.active,
    );

    expect(employee.salaryForHours(20), 200);
  });

  test('remaining salary calculation with advances and payments', () {
    const employee = Employee(
      id: 'emp1',
      organisationId: 'org1',
      name: 'Yassine',
      jobTitle: 'Barista',
      hourlyRate: 0,
      payType: EmployeePayType.monthly,
      monthlySalary: 900,
      role: EmployeeRole.employee,
      employmentStatus: EmploymentStatus.active,
    );

    final earned = employee.salaryForHours(0); // 900
    const advances = 100.0 + 100.0; // 200
    const payments = 200.0;
    final remaining = earned - advances - payments;

    expect(earned, 900);
    expect(remaining, 500);
  });

  testWidgets('CHEF login screen shows expected fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ZoneApp()));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    // Tap sign in without filling fields
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    // Validation messages should appear
    expect(
      find.text('Enter your email, phone number, or employee ID'),
      findsOneWidget,
    );
    expect(find.text('Enter your password'), findsOneWidget);
  });
}
