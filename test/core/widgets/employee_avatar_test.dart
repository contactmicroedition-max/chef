import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zone/core/widgets/widgets.dart';

void main() {
  testWidgets('avatar shows employee initial and follows dark theme', (
    tester,
  ) async {
    final theme = ThemeData.dark();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: EmployeeAvatar(name: 'Samira')),
        ),
      ),
    );

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundColor, theme.colorScheme.primaryContainer);
    expect(find.text('S'), findsOneWidget);
  });

  testWidgets('avatar uses a fallback for an empty name', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: EmployeeAvatar(name: '')),
      ),
    );

    expect(find.text('?'), findsOneWidget);
  });
}
