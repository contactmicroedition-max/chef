import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zone/features/dashboard/presentation/widgets/metric_card.dart';

void main() {
  testWidgets('metric card renders values with dark theme colors', (
    tester,
  ) async {
    final theme = ThemeData.dark();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: MetricCard(
            title: 'Active employees',
            value: '12',
            icon: Icons.people_alt_rounded,
          ),
        ),
      ),
    );

    expect(find.text('Active employees'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.people_alt_rounded));
    expect(icon.color, theme.colorScheme.primary);
  });
}
